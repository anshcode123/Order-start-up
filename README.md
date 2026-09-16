# ScanServe — Phase 1

Digital QR Menu + Table Ordering System. This is Phase 1 only: project
scaffolding, landing page, login UI (no auth logic), and a health-check
backend. See "Not implemented yet" below for what's intentionally left out.

## A note on how this was built

This container has Node.js but **no Flutter SDK and no internet access**,
so I wrote the Flutter source files by hand instead of running
`flutter create` / `flutter pub get`, and I couldn't run `npm install` to
fetch backend packages either. The backend JS was syntax-checked with
`node --check` and is straightforward Express, but neither side has been
run end-to-end here. The first-run steps below matter more than usual —
follow them in order.

## Project structure

```
scanserve/
├── backend/            Node.js + Express API
│   ├── config/db.js         MongoDB connection
│   ├── controllers/         (empty - Phase 2+)
│   ├── middleware/          errorHandler.js, notFound.js
│   ├── models/               (empty - Phase 2+)
│   ├── routes/health.js     GET /api/health
│   ├── services/             (empty - Phase 2+)
│   ├── utils/                 (empty - Phase 2+)
│   └── server.js
│
└── frontend/           Flutter Web app
    └── lib/
        ├── core/            theme, router, constants, network, utils
        ├── features/
        │   ├── landing/     marketing page ("/")
        │   ├── auth/        login screen UI ("/login")
        │   ├── super_admin/       (empty - Phase 2+)
        │   ├── restaurant_admin/  (empty - Phase 2+)
        │   └── customer_menu/     (empty - Phase 2+)
        ├── shared/          reusable widgets/models
        └── main.dart
```

## Backend: setup & run

```bash
cd scanserve/backend
cp .env.example .env
# edit .env and set MONGODB_URI (a local mongod or a MongoDB Atlas URI both work)
npm install
npm run dev        # or: npm start
```

Verify:

```bash
curl http://localhost:5000/api/health
# {"success":true,"message":"ScanServe API is running"}
```

The server refuses to start if MongoDB isn't reachable — that's
intentional per the spec (Express only starts after the DB connects).

## Frontend: setup & run

Because this environment has no Flutter SDK, the `web/`, `android/`,
`ios/`, etc. platform folders that `flutter create` normally generates
(icons, launch config, `.metadata`) are **not** present — only
`web/index.html` and `web/manifest.json`, written by hand. Regenerate the
rest before running:

```bash
cd scanserve/frontend
flutter create --platforms=web .    # fills in missing platform files; keeps lib/ and pubspec.yaml
flutter pub get
flutter run -d chrome                # or: flutter build web
```

If `flutter create` overwrites `web/index.html` or `web/manifest.json`,
diff them against what's here — the app title/theme-color/manifest name
were set to ScanServe branding.

Verify:
- Landing page loads at `/` with header, hero, how-it-works, features,
  pricing, and FAQ sections.
- "Restaurant Login" navigates to `/login` and shows the login card
  (email/password fields, disabled "Log in" button — no auth wired up
  yet, by design).
- Resize the window (or use device toolbar) to confirm the layout
  adapts across desktop, tablet, and mobile widths.

## Environment variables (backend/.env)

```
PORT=5000
MONGODB_URI=
JWT_SECRET=
```

Never commit a real `.env` — only `.env.example` is tracked.

## Not implemented yet (by design — later phases)

- User / Restaurant / Category / Menu / Order models
- Authentication (login button is intentionally disabled)
- Super Admin / Restaurant Admin functionality
- WhatsApp Business Cloud API
- Socket.IO
- QR code generation
- Customer cart & ordering

## Known gaps from the environment constraints

- Neither `npm install` nor `flutter pub get` has actually been run —
  do this locally before anything else.
- Flutter web platform files (icons, `.metadata`, etc.) need
  `flutter create --platforms=web .` to be generated, as noted above.
- MongoDB itself isn't running anywhere here — point `MONGODB_URI` at
  your own local or Atlas instance.
