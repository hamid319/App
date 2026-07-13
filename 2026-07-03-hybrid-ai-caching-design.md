# Hybrid AI-Caching Design for SwipeTrip

This specification outlines the hybrid architecture to solve the high cost of Google Places Enterprise data (descriptions and ratings) while maintaining rich, fast, and translated descriptions on the swipe cards.

---

## 1. Architecture Overview

```
[Flutter App] ──(1) Get Places──> [Firestore Cache]
                                       │ (Cache Miss)
                                       ▼
                              [Nearby Search Essentials] ($5/1,000)
                                       │
                                       ▼
                              [Gemini 1.5 Flash AI] (~$0.05/1,000)
                                       │ (Generates 1-Sentence Summary)
                                       ▼
                              [Save to Firestore]
```

### Google Places API (New) Essentials Tier
* **Fields fetched**: `places.id`, `places.displayName`, `places.location`, `places.types`, `places.formattedAddress`, `places.photos`
* **Cost**: $5.00 / 1,000 requests
* **Result**: We avoid the $32.00 / 1,000 Enterprise tier.

### Gemini 1.5 Flash Summarization
* **Trigger**: Executed on a cache miss for each newly discovered place.
* **Input**: Place Name, City Name, and Place Types.
* **Output**: A fun, 1-sentence summary optimized for swiping (Tinder-style).
* **Cost**: ~$0.05 / 1,000 descriptions.
* **Key benefit**: Allows dynamic translation and custom branding.

---

## 2. Firestore Schema and Caching

### Place Document Schema
The document in `/places/{google_place_id}` will store:
* `id` (String): Google Place ID.
* `name` (String): Display name.
* `description` (String): The AI-generated 1-sentence summary.
* `lat` (Double) & `lng` (Double): Coordinates.
* `address` (String): Formatted address.
* `imageUrls` (List<String>): Configured Google photo URLs.
* `types` (List<String>): Category types.
* `cityId` (String): Formatted city ID (e.g., `fr_paris`).

---

## 3. Step-by-Step Flow

1. **Session Start**: Admin starts a travel session for a city.
2. **Cache Check**: SwipeTrip queries Firestore `places` collection where `cityId == targetCityId`.
3. **Cache Hit**: If 20 places are found, they are returned instantly. **Zero API calls made**.
4. **Cache Miss**: If < 20 places are found:
   * Call `Nearby Search (New)` requesting **Essentials** fields.
   * For each fetched place:
     * Call Gemini 1.5 Flash: *"Generate a 1-sentence travel summary for {placeName} in {cityName}."*
     * Construct the photo media URL using `places.photos[0].name`.
     * Write the merged place details (with description) to `/places/{placeId}`.
5. **Return**: Return the list of places to the session.

---

## 4. Financial Comparison

| Metric | Google Enterprise Option | Hybrid AI-Caching (This Design) |
|---|---|---|
| Nearby Search Tier | Enterprise | Essentials |
| Description Source | Google Editorial Summary | Gemini 1.5 Flash |
| Cost / 1,000 Discoveries | $32.00 | $5.05 (Google + Gemini) |
| **Monthly Cost (10k cities)** | **$320.00** | **$50.50 (84.2% savings)** |

---

## 5. Next Steps

1. Configure Google Cloud Console credentials to restrict API Key to the Essentials/Pro APIs.
2. Integrate Gemini API calls in the backend functions (or directly via dev client for testing).
3. Implement the updated [places_repository.dart](file:///Users/ozanermis/Desktop/ProjectP/App/App/lib/features/swipe/data/places_repository.dart) logic.
