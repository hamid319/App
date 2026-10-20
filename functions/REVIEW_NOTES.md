# Review-Notiz zur City-Pipeline (für Ozan)

Hallo Ozan,

Hamid und ich (Claude) haben deine Pipeline auf `feature/city-collection-pipeline`
geprüft, weil wir sie als Datenquelle für die Startstädte nutzen wollen:
Orte, Fotos und Texte aus Wikidata/Wikimedia (kostenlos, dauerhaft
speicherbar), Bewertungen und Öffnungszeiten später aus Google.

Die Fixes liegen auf dem Branch `fix/city-pipeline-review`, abgezweigt von
deinem Stand `46eea39`. Dein Branch ist unverändert. Schau dir den Diff an
und übernimm, was du für richtig hältst.

## Gesamteindruck

Sehr solide: Kostenbremsen, Lizenzprüfung, Idempotenz, sicheres HTTP und
Tests sind durchdacht. Die Qualität der gefundenen Orte ist sehr gut
(Brandenburger Tor, Louvre, Stephansdom, Kunsthalle …). Drei Probleme haben
wir gefunden.

## 1. Viel zu wenige Orte pro Stadt (behoben)

**Befund:** Der Probe lieferte 11–35 Kandidaten statt der angestrebten 50.
Paris nur 11, obwohl Wikidata im 15-km-Umkreis mehrere hundert
fotografierte Sehenswürdigkeiten hat.

**Ursache:** Die erste SPARQL-Abfrage nahm die 150 Einträge mit den meisten
Sitelinks im Umkreis *ohne* Typfilter. Das sind vor allem Stadtteile,
Bahnhöfe und Universitäten. Erst danach wurde nach Sehenswürdigkeiten
gefiltert, und dann bleibt wenig übrig.

**Fix (`src/adapters/wikimedia.ts`, `findAttractions`):**
- Eine kleine Umkreis-Abfrage **pro Attraktionstyp** (9 Abfragen), Ergebnisse
  zusammengeführt, dedupliziert, nach Sitelinks sortiert und auf
  `candidateLimit` gekappt.
- Eine einzige Abfrage mit allen Typen und Unterklassen-Pfaden haben wir auch
  probiert. Sie lief bei dichten Städten auf dem öffentlichen Endpoint ins
  Timeout (Paris: HTTP 504 nach 60 s). Pro Typ antwortet Paris in ~3 s.
- Neues Limit `minSitelinks: 3` (`domain/config.ts`). Filtert sehr Unbekanntes
  und hält die Abfragen schnell.
- SPARQL-Aufrufe bekommen `timeoutMs: 60_000` (Endpoint-Limit) statt 20 s.
- Die Klassifizierung mit vier Unterklassen-Ebenen und die Ausschlüsse
  (Shop, Restaurant, …) laufen unverändert danach.
- **Kirchen und Kathedralen:** Mit nur einer Unterklassen-Stufe fehlten
  Stephansdom und Notre-Dame (Kathedrale → Kirchengebäude → religiöses
  Gebäude = zwei Stufen). Deshalb sucht die Umkreis-Abfrage zusätzlich nach
  `EXTRA_DISCOVERY_ROOTS` (Kirchengebäude, Kathedrale, Moschee, Synagoge,
  Tempel). Die Zuordnung zu „religious building“ macht wie bisher die
  Klassifizierung.

**Kosten:** 14 statt 1 SPARQL-Request pro Stadt. Liegt weit unter dem
Budget von 200 Metadaten-Requests.

## 2. Los Angeles wird abgelehnt (behoben)

**Befund:** `resolveCity("Q65")` → `invalid-city-type` („Entity is not a
settlement“).

**Ursache:** Für P31 wurde nur der *preferred*-Claim ausgewertet. Bei
Los Angeles ist das „charter city“ (Q13218391). „city“ (Q515) und
„metropolis“ (Q200250) sind *normal*-rank und wurden ignoriert. Das betrifft
vermutlich viele US-Städte.

**Fix:** Für die Typprüfung zählen alle nicht-deprecated P31-Claims
(`liveEntityIds`). Für Land und Koordinaten bleibt es bei
preferred-vor-normal, dort ist das richtig.
Regressionstest: `test/wikimedia.test.ts` mit Fixture `Q65`.

## 3. Zwei Pipeline-Tests schlugen fehl (behoben)

**Befund:** In `test/pipeline.test.ts` scheiterten die Fälle „30“ und „50
qualified places“: veröffentlicht wurde nur 1 Ort.

**Ursache:** Der Test lieferte für jeden Ort **dasselbe Bild**. Die Pipeline
verwirft zu Recht Fotos, deren Output-Hash schon gespeichert ist
(`seenOutputHashes`), also kam nur der erste Ort durch. Der Fehler lag im
Test, nicht in der Pipeline.

**Fix:** Der Test erzeugt pro Thumbnail-URL ein eigenes Bild.

## Ergebnisse

`npm run typecheck` sauber, `npm test`: 20/20 grün (vorher 17/19).

Read-only-Probe gegen Wikidata, Kandidaten pro Stadt:

| Stadt | vorher | nachher |
|---|---|---|
| Hamburg | 16 | 87 |
| Berlin | 35 | 149 |
| München | 28 | 112 |
| Wien | 21 | 148 |
| Paris | 11 | 146 |
| Lissabon | 21 | 137 |
| Los Angeles | Fehler (`invalid-city-type`) | 91 |

Top-Orte nachher, z. B. Wien: Stephansdom, Hofburg, Kunsthistorisches
Museum, Albertina, Karlskirche. Paris: Eiffelturm, Louvre, Notre-Dame,
Musée d'Orsay, Centre Pompidou, Panthéon, Sacré-Cœur.
22 Metadaten-Requests pro Stadt (Budget: 200).
Hamburg, Berlin und München wurden vor dem Kirchen-Fix (siehe Abschnitt 1)
gemessen, die Zahlen sind danach eher etwas höher.

## Offen, nicht angefasst

- **Nur englische Labels/Beschreibungen** (`languages=en`). Die App ist jetzt
  zweisprachig (DE/EN). `de` mitzuladen wäre günstig.
- **Lauf auf Node 25** statt der vorgesehenen 22 (lokal). Hat funktioniert,
  ist aber nicht die Zielversion.
- **Rate-Limits des öffentlichen Query-Service:** Bei vielen schnellen
  Abfragen hintereinander kamen kurz Fehler zurück. Für den Job-Betrieb
  wären Retries mit Backoff bei 429/504 sinnvoll.
- Rules-Tests mit dem Emulator haben wir nicht ausgeführt.
- `scripts/probe-wikimedia.ts` zeigt jetzt die ersten 8 statt 5 Kandidaten
  (nur Ausgabe).

Viele Grüße
Hamid & Claude
