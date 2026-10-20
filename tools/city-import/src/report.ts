import type { CityCollection } from "./model.js";

/** One self-contained HTML page to review all collected cities before publishing. */
export function renderReport(collections: CityCollection[], excluded: Record<string, string[]>): string {
  const total = collections.reduce((sum, c) => sum + c.places.length, 0);
  const nav = collections
    .map((c) => `<a href="#${esc(c.city.id)}">${esc(c.city.nameDe)} <span>${c.places.length}</span></a>`)
    .join("");
  const sections = collections.map((c) => renderCity(c, new Set(excluded[c.city.id] ?? []))).join("");
  return `<!doctype html>
<html lang="de"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>SwipeTrip Import-Bericht</title>
<style>
:root{--bg:#F6F7F9;--card:#fff;--ink:#15171C;--muted:#5B616E;--line:#E7E9EE;--accent:#FF5A36;--bad:#D9344F}
@media (prefers-color-scheme:dark){:root{--bg:#0E0F12;--card:#17191E;--ink:#F2F3F5;--muted:#A9AFBB;--line:#2A2E37}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.5 system-ui,-apple-system,sans-serif;padding:0 16px 64px}
header{max-width:1200px;margin:0 auto;padding:32px 0 8px}h1{margin:0 0 4px;font-size:30px}h2{margin:48px 0 4px;font-size:24px}
.muted{color:var(--muted)}nav{display:flex;flex-wrap:wrap;gap:8px;margin:16px 0}
nav a{padding:6px 12px;border-radius:999px;background:var(--card);border:1px solid var(--line);color:var(--ink);text-decoration:none}
nav a span{color:var(--muted)}main{max-width:1200px;margin:0 auto}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:16px;margin-top:16px}
.card{background:var(--card);border:1px solid var(--line);border-radius:16px;overflow:hidden;display:flex;flex-direction:column}
.card.excluded{opacity:.45;border-color:var(--bad)}
.photos{display:grid;grid-template-columns:2fr 1fr;gap:2px;height:180px;background:var(--line)}
.photos img{width:100%;height:100%;object-fit:cover;display:block}.photos .side{display:grid;gap:2px}
.photos .side:empty{display:none}.photos:has(.side:empty){grid-template-columns:1fr}
.body{padding:12px 14px;display:grid;gap:6px}.name{font-weight:700;font-size:16px}
.tags{display:flex;flex-wrap:wrap;gap:4px}.tag{font-size:12px;padding:2px 8px;border-radius:999px;background:var(--bg);border:1px solid var(--line)}
.tag.i{border-color:var(--accent);color:var(--accent)}p{margin:0;font-size:13px}.credit{font-size:11px;color:var(--muted)}
code{font-size:12px;background:var(--bg);padding:1px 6px;border-radius:6px}
details{margin-top:12px}summary{cursor:pointer;color:var(--muted)}
</style></head><body>
<header><h1>Import-Bericht</h1>
<p class="muted">${collections.length} Städte · ${total} Orte · Orte, die nicht passen, mit ihrer Wikidata-ID in <code>exclusions.json</code> eintragen und neu berichten.</p>
<nav>${nav}</nav></header>
<main>${sections}</main></body></html>`;
}

function renderCity(c: CityCollection, excluded: Set<string>): string {
  const cards = c.places.map((p) => {
    const [main, ...rest] = p.photos;
    const img = (url: string) => `<img loading="lazy" src="${esc(url)}" alt="">`;
    const credits = p.photos.map((ph) => `${esc(ph.creator)} (${esc(ph.licenseName)})`).join(" · ");
    const tags = [
      ...p.interests.map((i) => `<span class="tag i">${esc(i)}</span>`),
      ...p.types.map((t) => `<span class="tag">${esc(t)}</span>`),
    ].join("");
    return `<article class="card${excluded.has(p.wikidataId) ? " excluded" : ""}">
<div class="photos">${main ? img(main.thumbnailUrl) : ""}<div class="side">${rest.map((r) => img(r.thumbnailUrl)).join("")}</div></div>
<div class="body"><div class="name">${esc(p.names.de ?? p.names.en ?? p.wikidataId)}</div>
${p.names.en && p.names.en !== p.names.de ? `<div class="muted">${esc(p.names.en)}</div>` : ""}
<div class="tags">${tags}</div>
<p>${esc(p.descriptions.de ?? p.descriptions.en ?? "— keine Beschreibung —")}</p>
<div class="credit">Beliebtheit ${p.popularity} · ${p.distanceKm} km · <a href="https://www.wikidata.org/wiki/${esc(p.wikidataId)}" target="_blank" rel="noopener"><code>${esc(p.wikidataId)}</code></a></div>
<div class="credit">Fotos: ${credits}</div></div></article>`;
  }).join("");
  const skipped = c.skipped.length
    ? `<details><summary>${c.skipped.length} Kandidaten ohne brauchbares Foto oder Namen</summary><p class="muted">${
      c.skipped.map((s) => `${esc(s.name)} (${esc(s.wikidataId)}: ${esc(s.reason)})`).join(" · ")
    }</p></details>`
    : "";
  return `<section id="${esc(c.city.id)}"><h2>${esc(c.city.nameDe)}</h2>
<p class="muted">${c.places.length} Orte aus ${c.candidateCount} Kandidaten · gesammelt ${esc(c.collectedAt.slice(0, 16).replace("T", " "))}</p>
${skipped}<div class="grid">${cards}</div></section>`;
}

function esc(value: string): string {
  return value.replace(/[&<>"']/g, (ch) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[ch]!);
}
