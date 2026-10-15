# lingua — engineering notes for Claude

Advanced Database Systems course project (team: Dũng – Dương – Hiệp). Flutter mobile +
Express/Mongoose backend + React admin-web on MongoDB 7. See `README.md` for the
architecture and database design rationale.

**Ground rules**
- Remote is a **private** GitHub repo — keep it private; never make it public or add
  other remotes unless explicitly asked.
- All docs, comments, commit messages: **English**.
- Never commit `backend/.env` or any secret (`GEMINI_API_KEY`, `JWT_SECRET`, seed passwords).
- Do not label new files/simulators/artifacts with the course code.

## Running the stack

```bash
docker start it2011-mongo || docker run -d --name it2011-mongo -p 27017:27017 mongo:7
cd backend && npm i && npm run seed:admin && npm run seed:data
npm run db:sync    # DB-layer validators + index sync (idempotent)
npm run seed:rich  # optional bulk data (15 learners, ~2.5k histories) for demos/benchmarks
node server.js     # port 5001 — NOT 5000 (macOS AirPlay Receiver owns 5000)
cd ../mobile && flutter build ios --debug --simulator
# install on simulator "iPhone 16 Pro (18.2)" — x86_64/Rosetta, see iOS pitfalls below
```

Seed accounts: `user1@example.com / User@123` (user), `admin@example.com / Admin@123`
(admin). `backend/.env` is gitignored; `GEMINI_API_KEY` is **empty** → the AI tab shows an
error bubble by design until a real key is provided.

## Database protection layers (do not remove when touching the backend)

- **Query-driven indexes** declared in the Mongoose schemas (compound
  `{user, createdAt}`, `{user, updatedAt}`, …). If you add or change a query, add the
  matching index and run `npm run db:sync`.
- **`$jsonSchema` validators** on all 7 collections (`backend/scripts/sync-db.js`),
  including the polymorphic constraint on `translationhistories` (`conversation` requires
  `segments >= 1`; other types require `sourceText` + `translatedText`). Direct `mongosh`
  writes are validated too.
- **User deletion cascades** vocabulary/history/conversations — in a transaction when
  MongoDB is a replica set, sequential fallback on standalone (response carries `atomic`).
- **Language deletion is guarded**: HTTP 409 when the code is still referenced by
  models/vocabulary/history — soft-delete via `isActive` instead (mobile only lists
  active languages).
- **`messages[]` is bounded**: app rejects at 200 messages (409 `CONVERSATION_FULL`),
  DB validator hard-caps at 400. Never make an embedded array unbounded.
- Keep the backend's JSON response shapes stable — mobile and admin-web depend on them.

## iOS pitfalls (app was Android-first; all handled — do not regress)

1. **Simulator must be x86_64 (Rosetta).** Every version of `google_mlkit_translation`
   (incl. 0.15.1) pins the GoogleMLKit pod 9.0.0, which has **no arm64-simulator slice**
   → arm64 simulators are rejected by Xcode. Use the existing "iPhone 16 Pro (18.2)"
   x86_64 simulator. Real arm64 devices are fine.
2. **`vosk_flutter` has no iOS implementation.** Every code path into Vosk must go
   through `VoskService.isSupported` (already guarded; plugin fields are `late` so
   constructing the service doesn't crash). The mic UI is hidden on iOS.
3. iOS deployment target = **15.5** (Podfile + pbxproj) — required by ML Kit.
4. `baseUrl` in `mobile/lib/core/constants.dart` is platform-aware (Android `10.0.2.2` /
   iOS `localhost`, both port 5001). For a physical device, switch to the LAN IP.
5. ATS exception for `http://localhost` is set in `ios/Runner/Info.plist`.
6. Word splitting in translation results uses the Unicode regex `[^\p{L}\p{N}]+` — the
   old Latin-only regex deleted CJK text and blanked the result card.

## UI (v2) conventions

- Design source of truth: `docs/prototype/prototype_v2.html` (clickable, standalone
  HTML, iOS + Android frames). The v1 prototype (`prototype.html`) is reference-only.
- 5 screens: Translate (home, auto-translate on typing with 650 ms debounce, "Recents"
  inline), AI chat, Vocabulary (+ flashcards), Profile, merged login/register.
- History is committed only on "settle" moments (clear input / swap direction / open a
  recent / dispose) so auto-translate doesn't spam one entry per keystroke.
- Every interactive control (word chips, recent cards, ✕ clear, swap, language pickers,
  flashcard) is wrapped in `Semantics(button: true, label: …)` — required for VoiceOver
  and UI automation. Keep this for any new control.
- `flutter analyze` crashes in this setup (analysis server exit 255) — use
  `dart analyze lib` instead.
- After changing Flutter UI: rebuild, re-run on the simulator, and capture screenshots of
  the changed screens.
