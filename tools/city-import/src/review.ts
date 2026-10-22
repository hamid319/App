// Local review page: pick the photos (cover first) and exclude places.
// Runs on 127.0.0.1 only and writes photo-picks.json / exclusions.json.

import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { readFileSync, writeFileSync } from "node:fs";
import { DEFAULTS } from "./config.js";
import type { CityCollection } from "./model.js";
import { previewUrl, selectPhotos, type PhotoPicks } from "./picks.js";

export interface ReviewFiles {
  picksPath: string;
  exclusionsPath: string;
  /** Collected cities, in cities.json order. */
  loadCollections: () => CityCollection[];
}

const PLACE_ID = /^(wd_Q\d+|osm_(node|way|relation)_\d+)$/;

export function startReview(files: ReviewFiles, port: number): Promise<string> {
  const server = createServer((req, res) => {
    handle(files, port, req, res).catch((error) => send(res, 500, "text/plain", (error as Error).message));
  });
  return new Promise((resolve) => server.listen(port, "127.0.0.1", () => resolve(`http://127.0.0.1:${port}`)));
}

async function handle(files: ReviewFiles, port: number, req: IncomingMessage, res: ServerResponse) {
  // Only this machine, and no requests from other web pages (DNS rebinding, CSRF).
  if (req.headers.host !== `127.0.0.1:${port}`) return send(res, 403, "text/plain", "forbidden");
  const url = new URL(req.url ?? "/", `http://127.0.0.1:${port}`);
  const collections = files.loadCollections();

  if (req.method === "GET") {
    const city = collections.find((c) => c.city.id === url.searchParams.get("city")) ?? collections[0];
    if (!city) return send(res, 404, "text/plain", "No collected cities in out/ – run collect first.");
    return send(res, 200, "text/html; charset=utf-8",
      renderReviewPage(collections, city, readPicks(files.picksPath), readExclusions(files.exclusionsPath)));
  }

  if (req.method !== "POST" || url.pathname !== "/api/place") return send(res, 404, "text/plain", "not found");
  if (!String(req.headers["content-type"]).startsWith("application/json")) return send(res, 415, "text/plain", "json only");
  let body: { cityId?: unknown; placeId?: unknown; pageIds?: unknown; excluded?: unknown };
  try {
    body = JSON.parse(await readBody(req));
  } catch {
    return send(res, 400, "text/plain", "invalid json");
  }
  const place = collections
    .find((c) => c.city.id === body.cityId)?.places
    .find((p) => p.id === body.placeId && PLACE_ID.test(p.id));
  if (!place) return send(res, 400, "text/plain", "unknown place");
  const candidates = new Set(place.photos.map((p) => p.pageId));

  if (Array.isArray(body.pageIds)) {
    const pageIds = body.pageIds.filter((id): id is number => candidates.has(id as number)).slice(0, DEFAULTS.photosPerPlace);
    const picks = readPicks(files.picksPath);
    if (pageIds.length) picks[place.id] = pageIds;
    else delete picks[place.id];
    writeJson(files.picksPath, { ...readRaw(files.picksPath), places: sortKeys(picks) });
  }
  if (typeof body.excluded === "boolean") {
    const cityId = place.cityId;
    const exclusions = readExclusions(files.exclusionsPath);
    const ids = new Set(exclusions[cityId] ?? []);
    if (body.excluded) ids.add(place.id);
    else ids.delete(place.id);
    if (ids.size) exclusions[cityId] = [...ids].sort();
    else delete exclusions[cityId];
    writeJson(files.exclusionsPath, { ...readRaw(files.exclusionsPath), places: sortKeys(exclusions) });
  }
  send(res, 204, "text/plain", "");
}

export function readPicks(path: string): PhotoPicks {
  try {
    return (JSON.parse(readFileSync(path, "utf8")) as { places?: PhotoPicks }).places ?? {};
  } catch {
    return {};
  }
}

function readExclusions(path: string): Record<string, string[]> {
  return (JSON.parse(readFileSync(path, "utf8")) as { places?: Record<string, string[]> }).places ?? {};
}

/** The whole file, so writes keep keys like _comment. */
function readRaw(path: string): Record<string, unknown> {
  try {
    return JSON.parse(readFileSync(path, "utf8")) as Record<string, unknown>;
  } catch {
    return {};
  }
}

function writeJson(path: string, value: unknown) {
  writeFileSync(path, JSON.stringify(value, null, 2) + "\n");
}

function sortKeys<T>(record: Record<string, T>): Record<string, T> {
  return Object.fromEntries(Object.entries(record).sort(([a], [b]) => a.localeCompare(b)));
}

function readBody(req: IncomingMessage): Promise<string> {
  return new Promise((resolve, reject) => {
    let data = "";
    req.on("data", (chunk) => {
      data += chunk;
      if (data.length > 10_000) reject(new Error("body too large"));
    });
    req.on("end", () => resolve(data));
    req.on("error", reject);
  });
}

function send(res: ServerResponse, status: number, type: string, body: string) {
  res.writeHead(status, { "content-type": type, "cache-control": "no-store" });
  res.end(body);
}

/** One city: every place with all photo candidates. */
export function renderReviewPage(
  collections: CityCollection[],
  current: CityCollection,
  picks: PhotoPicks,
  exclusions: Record<string, string[]>,
): string {
  const reviewed = (c: CityCollection) => {
    const excluded = new Set(exclusions[c.city.id] ?? []);
    return c.places.filter((p) => picks[p.id]?.length || excluded.has(p.id)).length;
  };
  const nav = collections.map((c) =>
    `<a href="/?city=${esc(c.city.id)}"${c === current ? ' class="on"' : ""}>${esc(c.city.nameDe)} <span>${reviewed(c)}/${c.places.length}</span></a>`,
  ).join("");
  const excluded = new Set(exclusions[current.city.id] ?? []);
  const cards = current.places.map((p) => {
    const selected = selectPhotos(p, picks).map((ph) => ph.pageId);
    const thumbs = p.photos.map((ph) => {
      const order = selected.indexOf(ph.pageId);
      return `<button class="thumb" data-page="${ph.pageId}" title="${esc(`${ph.creator} · ${ph.licenseName} · ${ph.width}×${ph.height}`)}">
<img loading="lazy" src="${esc(previewUrl(ph.thumbnailUrl))}" alt=""><b>${order >= 0 ? order + 1 : ""}</b></button>`;
    }).join("");
    const state = excluded.has(p.id) ? "excluded" : picks[p.id]?.length ? "picked" : "auto";
    return `<article class="card ${state}" data-id="${esc(p.id)}" data-selected="${selected.join(",")}">
<div class="head"><div><div class="name">${p.rank}. ${esc(p.names.de ?? p.names.en ?? p.catalogName)}</div>
<div class="muted">${esc(p.category)} · ${p.photos.length} Fotos · <a href="${p.wikidataId ? `https://www.wikidata.org/wiki/${esc(p.wikidataId)}` : esc(p.osm?.url ?? "#")}" target="_blank" rel="noopener">Quelle</a> · <code>${esc(p.id)}</code></div></div>
<span class="state"></span></div>
<div class="thumbs">${thumbs}</div>
<div class="actions"><button data-act="ok">✓ Passt so</button><button data-act="reset">Zurücksetzen</button><button data-act="exclude">Ausschließen</button></div>
</article>`;
  }).join("");
  const skipped = current.skipped.length
    ? `<details><summary>${current.skipped.length} Katalog-Einträge fehlen</summary><p class="muted">${
      current.skipped.map((s) => `${s.rank}. ${esc(s.name)} (${esc(s.reason)})`).join(" · ")}</p></details>`
    : "";
  return `<!doctype html><html lang="de"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Fotos prüfen · ${esc(current.city.nameDe)}</title>
<style>
:root{--bg:#F6F7F9;--card:#fff;--ink:#15171C;--muted:#5B616E;--line:#E7E9EE;--accent:#FF5A36;--ok:#1E9E62;--bad:#D9344F}
@media (prefers-color-scheme:dark){:root{--bg:#0E0F12;--card:#17191E;--ink:#F2F3F5;--muted:#A9AFBB;--line:#2A2E37}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.5 system-ui,-apple-system,sans-serif;padding:0 16px 64px}
header,main{max-width:1200px;margin:0 auto}header{padding:24px 0 8px}h1{margin:0;font-size:26px}.muted{color:var(--muted);font-size:13px}
nav{display:flex;flex-wrap:wrap;gap:6px;margin:12px 0}nav a{padding:4px 10px;border-radius:999px;background:var(--card);border:1px solid var(--line);color:var(--ink);text-decoration:none;font-size:13px}
nav a.on{border-color:var(--accent)}nav a span{color:var(--muted)}a{color:var(--accent)}code{font-size:11px}
.card{background:var(--card);border:2px solid var(--line);border-radius:16px;padding:12px;margin-top:14px}
.card.picked{border-color:var(--ok)}.card.excluded{border-color:var(--bad);opacity:.5}
.head{display:flex;justify-content:space-between;gap:8px}.name{font-weight:700}
.state{font-size:12px;white-space:nowrap}.card.auto .state::after{content:"automatisch";color:var(--muted)}
.card.picked .state::after{content:"✓ geprüft";color:var(--ok)}.card.excluded .state::after{content:"ausgeschlossen";color:var(--bad)}
.thumbs{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:6px;margin:10px 0}
.thumb{position:relative;padding:0;border:3px solid transparent;border-radius:10px;overflow:hidden;cursor:pointer;background:var(--line);aspect-ratio:3/4}
.thumb img{width:100%;height:100%;object-fit:cover;display:block}
.thumb b{position:absolute;top:6px;left:6px;min-width:24px;height:24px;border-radius:12px;background:var(--accent);color:#fff;font-size:13px;display:grid;place-items:center}
.thumb b:empty{display:none}.thumb:has(b:not(:empty)){border-color:var(--accent)}
.thumb[data-page]:first-child{}
.actions{display:flex;gap:6px;flex-wrap:wrap}.actions button{padding:6px 12px;border-radius:999px;border:1px solid var(--line);background:var(--bg);color:var(--ink);cursor:pointer}
</style></head><body>
<header><h1>Fotos prüfen: ${esc(current.city.nameDe)}</h1>
<p class="muted">Fotos anklicken in der gewünschten Reihenfolge (1 = Titelbild, höchstens ${DEFAULTS.photosPerPlace}). Wird sofort gespeichert. „Passt so“ übernimmt die automatische Auswahl.</p>
<nav>${nav}</nav>${skipped}</header>
<main>${cards}</main>
<script>
const cityId=${JSON.stringify(current.city.id)};const max=${DEFAULTS.photosPerPlace};
async function save(card,body){
  const r=await fetch("/api/place",{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify({cityId,placeId:card.dataset.id,...body})});
  if(!r.ok)alert("Speichern fehlgeschlagen: "+await r.text());
}
function show(card,sel,state){
  card.dataset.selected=sel.join(",");card.className="card "+state;
  card.querySelectorAll(".thumb").forEach(t=>{const i=sel.indexOf(Number(t.dataset.page));t.querySelector("b").textContent=i>=0?i+1:"";});
}
const ids=card=>card.dataset.selected?card.dataset.selected.split(",").map(Number):[];
document.addEventListener("click",async e=>{
  const card=e.target.closest(".card");if(!card)return;
  const thumb=e.target.closest(".thumb");const act=e.target.closest("[data-act]")?.dataset.act;
  if(thumb){
    let sel=card.classList.contains("picked")?ids(card):[];const page=Number(thumb.dataset.page);
    sel=sel.includes(page)?sel.filter(p=>p!==page):[...sel,page].slice(0,max);
    if(card.classList.contains("excluded"))await save(card,{excluded:false});
    await save(card,{pageIds:sel});
    if(sel.length)show(card,sel,"picked");else location.reload();
  }else if(act==="ok"){await save(card,{pageIds:ids(card),excluded:false});show(card,ids(card),"picked");}
  else if(act==="reset"){await save(card,{pageIds:[],excluded:false});location.reload();}
  else if(act==="exclude"){await save(card,{excluded:true});card.className="card excluded";}
});
</script></body></html>`;
}

function esc(value: string): string {
  return value.replace(/[&<>"']/g, (ch) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[ch]!);
}
