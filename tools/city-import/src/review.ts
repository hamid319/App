// Local review page: pick the photos (cover first) and exclude places.
// Runs on 127.0.0.1 only and writes photo-picks.json / exclusions.json.

import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { readFileSync, writeFileSync } from "node:fs";
import { DEFAULTS } from "./config.js";
import type { CityCollection, PlaceDraft } from "./model.js";
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
  const collection = collections.find((c) => c.city.id === body.cityId);
  const place = (collection ? allDrafts(collection) : [])
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

/** Sights and venues of a city. */
function allDrafts(c: CityCollection): PlaceDraft[] {
  return [...c.places, ...(c.venues ?? [])];
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
    return allDrafts(c).filter((p) => picks[p.id]?.length || excluded.has(p.id)).length;
  };
  const nav = collections.map((c) =>
    `<a href="/?city=${esc(c.city.id)}"${c === current ? ' class="on"' : ""}>${esc(c.city.nameEn)} <span>${reviewed(c)}/${allDrafts(c).length}</span></a>`,
  ).join("");
  const excluded = new Set(exclusions[current.city.id] ?? []);
  const card = (p: PlaceDraft) => {
    const selected = selectPhotos(p, picks).map((ph) => ph.pageId);
    const thumbs = p.photos.map((ph) => {
      const order = selected.indexOf(ph.pageId);
      return `<button class="thumb" data-page="${ph.pageId}" title="${esc(`${ph.creator} · ${ph.licenseName} · ${ph.width}×${ph.height}`)}">
<img loading="lazy" src="${esc(previewUrl(ph.thumbnailUrl))}" alt=""><b>${order >= 0 ? order + 1 : ""}</b></button>`;
    }).join("");
    const state = excluded.has(p.id) ? "excluded" : picks[p.id]?.length ? "picked" : "auto";
    return `<article class="card ${state}" data-id="${esc(p.id)}" data-selected="${selected.join(",")}">
<div class="head"><div><div class="name">${p.rank}. ${esc(p.names.en ?? p.names.de ?? p.catalogName)}</div>
<div class="muted">${esc(p.category)}${p.cuisine ? ` · ${esc(p.cuisine)}` : ""} · ${p.photos.length} photos · <a href="${p.wikidataId ? `https://www.wikidata.org/wiki/${esc(p.wikidataId)}` : esc(p.osm?.url ?? "#")}" target="_blank" rel="noopener">Source</a> · <code>${esc(p.id)}</code></div></div>
<span class="state"></span></div>
<div class="thumbs">${thumbs}</div>
<div class="actions"><button data-act="ok">✓ Looks good</button><button data-act="reset">Reset</button><button data-act="exclude">Exclude</button></div>
</article>`;
  };
  const venues = current.venues ?? [];
  // One tab per category (catalog category for sights, type for venues), largest first.
  const groups = (list: PlaceDraft[], kind: string) => {
    const byCategory = new Map<string, PlaceDraft[]>();
    for (const p of list) {
      if (!byCategory.has(p.category)) byCategory.set(p.category, []);
      byCategory.get(p.category)!.push(p);
    }
    return [...byCategory].sort((a, b) => b[1].length - a[1].length)
      .map(([category, places]) => ({ key: `${kind}:${category}`, category, places }));
  };
  const sightGroups = groups(current.places, "sight");
  const venueGroups = groups(venues, "venue");
  const tab = (g: { key: string; category: string; places: PlaceDraft[] }) =>
    `<button data-tab="${esc(g.key)}">${esc(g.category)} <span>${g.places.length}</span></button>`;
  const tabs = `<nav class="tabs"><button data-tab="" class="on">All <span>${current.places.length + venues.length}</span></button>
<b>Sights</b>${sightGroups.map(tab).join("")}${venueGroups.length ? `<b>Venues</b>${venueGroups.map(tab).join("")}` : ""}</nav>`;
  const section = (g: { key: string; category: string; places: PlaceDraft[] }) =>
    `<section data-cat="${esc(g.key)}"><h3>${esc(g.category)} <span class="muted">${g.places.length}</span></h3>${g.places.map(card).join("")}</section>`;
  const cards = `<div data-kind="sight"><h2>Sights</h2>${sightGroups.map(section).join("")}</div>
<div data-kind="venue"><h2>Venues (Tonight)</h2>${venues.length
    ? `<p class="muted">Without a photo the app shows a placeholder. Excluded venues are replaced by the next best ones on the next collect.</p>${venueGroups.map(section).join("")}`
    : '<p class="muted">No venues collected.</p>'}</div>`;
  const skipped = current.skipped.length
    ? `<details><summary>${current.skipped.length} catalog entries missing</summary><p class="muted">${
      current.skipped.map((s) => `${s.rank}. ${esc(s.name)} (${esc(s.reason)})`).join(" · ")}</p></details>`
    : "";
  return `<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Review photos · ${esc(current.city.nameEn)}</title>
<style>
:root{--bg:#F6F7F9;--card:#fff;--ink:#15171C;--muted:#5B616E;--line:#E7E9EE;--accent:#FF5A36;--ok:#1E9E62;--bad:#D9344F}
@media (prefers-color-scheme:dark){:root{--bg:#0E0F12;--card:#17191E;--ink:#F2F3F5;--muted:#A9AFBB;--line:#2A2E37}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.5 system-ui,-apple-system,sans-serif;padding:0 16px 64px}
header,main{max-width:1200px;margin:0 auto}header{padding:24px 0 8px}h1{margin:0;font-size:26px}h2{margin:32px 0 0;font-size:20px}.muted{color:var(--muted);font-size:13px}
nav{display:flex;flex-wrap:wrap;gap:6px;margin:12px 0}nav a{padding:4px 10px;border-radius:999px;background:var(--card);border:1px solid var(--line);color:var(--ink);text-decoration:none;font-size:13px}
nav a.on{border-color:var(--accent)}nav a span{color:var(--muted)}a{color:var(--accent)}code{font-size:11px}
.card{background:var(--card);border:2px solid var(--line);border-radius:16px;padding:12px;margin-top:14px}
.card.picked{border-color:var(--ok)}.card.excluded{border-color:var(--bad);opacity:.5}
.head{display:flex;justify-content:space-between;gap:8px}.name{font-weight:700}
.state{font-size:12px;white-space:nowrap}.card.auto .state::after{content:"automatic";color:var(--muted)}
.card.picked .state::after{content:"✓ reviewed";color:var(--ok)}.card.excluded .state::after{content:"excluded";color:var(--bad)}
.thumbs{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:6px;margin:10px 0}
.thumb{position:relative;padding:0;border:3px solid transparent;border-radius:10px;overflow:hidden;cursor:pointer;background:var(--line);aspect-ratio:3/4}
.thumb img{width:100%;height:100%;object-fit:cover;display:block}
.thumb b{position:absolute;top:6px;left:6px;min-width:24px;height:24px;border-radius:12px;background:var(--accent);color:#fff;font-size:13px;display:grid;place-items:center}
.thumb b:empty{display:none}.thumb:has(b:not(:empty)){border-color:var(--accent)}
.thumb[data-page]:first-child{}
.actions{display:flex;gap:6px;flex-wrap:wrap}.actions button{padding:6px 12px;border-radius:999px;border:1px solid var(--line);background:var(--bg);color:var(--ink);cursor:pointer}
.tabs{display:flex;flex-wrap:wrap;align-items:center;gap:6px;margin:12px 0;position:sticky;top:0;z-index:1;background:var(--bg);padding:8px 0}
.tabs b{font-size:12px;color:var(--muted);margin-left:8px}
.tabs button{padding:4px 10px;border-radius:999px;background:var(--card);border:1px solid var(--line);color:var(--ink);font-size:13px;cursor:pointer}
.tabs button.on{border-color:var(--accent)}.tabs button span{color:var(--muted)}
h3{margin:24px 0 0;font-size:17px}[hidden]{display:none!important}
</style></head><body>
<header><h1>Review photos: ${esc(current.city.nameEn)}</h1>
<p class="muted">Click photos in the order you want them (1 = cover, at most ${DEFAULTS.photosPerPlace}). Saved immediately. “Looks good” keeps the automatic choice.</p>
<nav>${nav}</nav>${skipped}${tabs}</header>
<main>${cards}</main>
<script>
const cityId=${JSON.stringify(current.city.id)};const max=${DEFAULTS.photosPerPlace};
async function save(card,body){
  const r=await fetch("/api/place",{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify({cityId,placeId:card.dataset.id,...body})});
  if(!r.ok)alert("Saving failed: "+await r.text());
}
function show(card,sel,state){
  card.dataset.selected=sel.join(",");card.className="card "+state;
  card.querySelectorAll(".thumb").forEach(t=>{const i=sel.indexOf(Number(t.dataset.page));t.querySelector("b").textContent=i>=0?i+1:"";});
}
const ids=card=>card.dataset.selected?card.dataset.selected.split(",").map(Number):[];
// Category tabs; the tab is kept in the URL hash, so a reload stays on it.
function showTab(key){
  if(!document.querySelector('.tabs [data-tab="'+CSS.escape(key)+'"]'))key="";
  document.querySelectorAll(".tabs [data-tab]").forEach(b=>b.classList.toggle("on",b.dataset.tab===key));
  document.querySelectorAll("section[data-cat]").forEach(s=>s.hidden=key!==""&&s.dataset.cat!==key);
  document.querySelectorAll("[data-kind]").forEach(k=>k.hidden=key!==""&&!key.startsWith(k.dataset.kind+":"));
}
showTab(decodeURIComponent(location.hash.slice(1)));
addEventListener("hashchange",()=>showTab(decodeURIComponent(location.hash.slice(1))));
document.addEventListener("click",async e=>{
  const tab=e.target.closest("[data-tab]");
  if(tab){history.replaceState(null,"",tab.dataset.tab?"#"+encodeURIComponent(tab.dataset.tab):location.pathname+location.search);showTab(tab.dataset.tab);scrollTo(0,0);return;}
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
