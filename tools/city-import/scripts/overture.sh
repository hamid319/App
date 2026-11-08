#!/bin/bash
# Exports Overture Maps food/drink places around a city from cities.json
# into data/overture/<cityId>.json (read by `npm run collect`).
# Needs the DuckDB CLI (brew install duckdb). Reads Overture's public S3
# bucket; no account. Licences per source (CDLA Permissive 2.0, Apache 2.0
# for Foursquare, CC0): all allow storing; see README.
#   bash scripts/overture.sh de_berlin [release]
set -euo pipefail
cd "$(dirname "$0")/.."
CITY="${1:?usage: overture.sh <cityId> [release]}"
RELEASE="${2:-$(curl -sf https://stac.overturemaps.org/catalog.json | node -e 'process.stdin.on("data",d=>process.stdout.write(JSON.parse(d).latest))')}"
read -r LAT LNG RADIUS < <(node -e '
  const c = require("./cities.json").find((c) => c.id === process.argv[1]);
  if (!c) { console.error("not in cities.json: " + process.argv[1]); process.exit(1); }
  console.log(c.lat, c.lng, c.venueRadiusKm ?? c.radiusKm ?? 25);' "$CITY")
# Bounding box around the centre; collect cuts it to the radius.
read -r XMIN XMAX YMIN YMAX < <(node -e '
  const [lat, lng, r] = process.argv.slice(1).map(Number);
  const dLat = r / 111, dLng = r / (111 * Math.cos(lat * Math.PI / 180));
  console.log(lng - dLng, lng + dLng, lat - dLat, lat + dLat);' "$LAT" "$LNG" "$RADIUS")
mkdir -p data/overture
OUT="data/overture/$CITY.json"
echo "Overture $RELEASE, $CITY, ${RADIUS} km"
duckdb -no-agent -c "
INSTALL httpfs; LOAD httpfs; SET s3_region='us-west-2';
COPY (
  SELECT id::VARCHAR AS id, names.primary AS name, taxonomy.primary AS \"primary\", taxonomy.hierarchy AS hierarchy,
         confidence, operating_status AS status, brand.names.primary AS brand, websites,
         (SELECT list(DISTINCT s.dataset) FROM unnest(sources) t(s) WHERE s.dataset <> 'Overture') AS datasets,
         (SELECT max(s.update_time) FROM unnest(sources) t(s) WHERE s.dataset <> 'Overture') AS updated,
         bbox.ymin AS lat, bbox.xmin AS lon
  FROM read_parquet('s3://overturemaps-us-west-2/release/$RELEASE/theme=places/type=place/*', hive_partitioning = 1)
  WHERE bbox.xmin BETWEEN $XMIN AND $XMAX AND bbox.ymin BETWEEN $YMIN AND $YMAX
    AND (taxonomy.hierarchy[1] = 'food_and_drink' OR taxonomy.hierarchy[2] = 'nightlife_venue')
) TO '$OUT' (FORMAT json, ARRAY true);"
echo "Wrote $OUT ($(node -e 'console.log(require("./'"$OUT"'").length)' ) rows)"
