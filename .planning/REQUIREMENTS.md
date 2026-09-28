# Requirements

## Core Features

- **REQ-01: Authentication**
  - Users can sign up, log in, and log out.
  - Done status: ✅ Done

- **REQ-02: Onboarding**
  - First-time users see onboarding screens.
  - Text must be in English.
  - Done status: ✅ Done

- **REQ-03: Swipe UI**
  - Tinder-style swipe cards showing place details.
  - Swiping right likes, swiping left skips.
  - Done status: ✅ Done

- **REQ-04: Place Detail**
  - View full details, ratings, and open in maps.
  - Add/remove favorites toggle button.
  - Done status: ✅ Done

- **REQ-05: Favorites**
  - View favorites list on a dedicated screen.
  - Remove favorites reactively.
  - Done status: ✅ Done

- **REQ-06: Places API & Hybrid Caching**
  - Fetch real place data using Google Places API Essentials.
  - Generate 1-sentence description using Gemini AI.
  - Cache places in Firestore by city.
  - Done status: ✅ Done

- **REQ-07: Group Sessions**
  - Create group, set location, join via 6-digit code.
  - Done status: ✅ Done

- **REQ-08: Group Voting & Consensus**
  - Record member swipes with Firestore transactions.
  - Draggable ranking list for members to prioritize favorites.
  - Calculate final consensus list (Borda count).
  - Done status: ❌ Missing (ranking and consensus algorithm)

- **REQ-09: Profile & Settings**
  - Upload profile picture.
  - View settings screen.
  - English copy only.
  - Done status: ⚠️ Needs SettingsScreen translation.
