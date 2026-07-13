# Group Swipe & Matching Feature Design

This document describes the design for the Group Swipe and Matching feature in the Traveller App.

---

## 1. Feature Goal

To help a group of travelers decide on places to visit together. Each member swipes on the same list of places. Each member then ranks their personal favorites. Once everyone is done, the app calculates and shows the final consensus list to all group members.

---

## 2. User Flow

### Step 1: Place Distribution
* The group admin starts a swipe session.
* All group members receive the exact same list of candidate places to swipe on.

### Step 2: Personal Swiping
* Members swipe through the list:
  * **Swipe Right**: Like the place.
  * **Swipe Left**: Dislike the place.
* The liked places are added to their personal session list.

### Step 3: Preference Ranking (Draggable List)
* Once swiping is done, the member views their personal session list.
* The list is **draggable and adjustable**.
* The user can drag and drop items to reorder the places by priority (e.g., #1 choice at the top).
* The user taps "Submit Rankings" when finished.

### Step 4: Final Consensus Popup
* The app checks if all group members have submitted their lists.
* When the last member submits:
  * The app calculates the final group ranking.
  * A popup screen appears for all group members.
  * The popup shows the final list ordered from **most liked** to **least liked** based on the group's input.

---

## 3. Data Models (Firestore)

### Group Swipe Session Document
Path: `/groups/{groupId}/sessions/{sessionId}`

```json
{
  "sessionId": "string",
  "status": "swiping | completed",
  "candidatePlaces": ["place_id_1", "place_id_2", "place_id_3"],
  "memberStatus": {
    "user_id_1": "swiping | submitted",
    "user_id_2": "swiping | submitted"
  },
  "userRankings": {
    "user_id_1": ["place_id_3", "place_id_1"], 
    "user_id_2": ["place_id_1", "place_id_3"]
  },
  "finalConsensusList": ["place_id_1", "place_id_3"]
}
```

---

## 4. UI Components

### 1. Swipe Screen
* Standard swipe cards showing place details.
* Tracks progress (e.g., "12 / 20 places").

### 2. Draggable Ranking Screen
* Displays liked places in a list.
* Uses Flutter's `ReorderableListView` widget to support dragging and reordering.
* "Submit" button to save rankings to Firestore.

### 3. Final Decision Popup
* A modal overlay or new screen that triggers when the session status becomes `completed`.
* Lists places with aggregated rankings.
* Highlights the top-voted place (the winner).

---

## 5. Consensus Calculation Algorithm

To determine the final list, the app will use a point-based ranking system (Borda Count-inspired):

1. **Assign Points per User List**:
   * For a user's ranked list of $N$ places:
     * Position 1 gets $N$ points.
     * Position 2 gets $N - 1$ points.
     * ...
     * Position $N$ gets 1 point.
   * Disliked or unranked places get 0 points.
2. **Aggregate Points**:
   * Sum the points for each place across all group members.
3. **Sort Results**:
   * Sort the places by total points in descending order.
   * In case of a tie, the place with more "like" swipes wins.
