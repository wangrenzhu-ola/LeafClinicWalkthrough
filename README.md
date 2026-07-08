# Leaf Clinic Walkthrough

Native SwiftUI rough app for a local plant leaf recovery walkthrough. The app lets a plant owner create a leaf symptom case, review editable local triage suggestions, save a seven-day recovery path, add a revisit note, and manage the archive with a premium/privacy boundary.

## PM requirement coverage

- `REQ-CRUD-001`: Leaf Intake creates cases, Recovery updates care steps, Archive deletes with confirmation.
- `REQ-PERSIST-001`: `FileLeafClinicPersistence` saves cases, care steps, revisit notes, and entitlement state as local JSON.
- `REQ-VIS-001`: Warm botanical clinic direction with hero leaf art, severity ring, empty illustration, sage/cream/amber palette.
- `REQ-EMPTY-001`: Home shows “No leaf checks yet.” and a “Start a Leaf Check” CTA.
- `REQ-ERROR-001`: Missing plant nickname and persistence failures surface recoverable English error copy.
- `REQ-PRIVACY-001`: Premium/Privacy card states photos and notes stay local by default.
- `REQ-PREMIUM-001`: Premium route exposes StoreKit product IDs and an unavailable fallback until App Store Connect evidence exists.
- `REQ-AI-001`: Local heuristic suggestions are editable, skippable, and confirmed before saving; no cloud AI or Kimi key is used.

## Checks

```bash
swift test
xcodebuild -scheme LeafClinicWalkthrough -destination 'generic/platform=iOS' build
```
