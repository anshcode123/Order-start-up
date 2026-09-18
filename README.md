# ScanServe — through Phase 4 (PostgreSQL/Prisma)

Digital QR Menu + Table Ordering System. Implemented so far:
Phase 1 (scaffolding + landing page), Phase 2 (auth foundation),
Phase 3 (Super Admin restaurant management), and Phase 4 (Restaurant
Admin menu management: categories, menu items, prices, images,
availability) - all on PostgreSQL + Prisma. See "Not implemented yet"
for what's intentionally left out.

## A note on how this was built

This container has Node.js but **no Flutter SDK, no PostgreSQL, no
Cloudinary account, and no internet access**. That means:
- Every backend `.js` file was syntax-checked with `node --check`
  (28 files, all pass), cross-referenced against `prisma/schema.prisma`,
  but `npm install`, `prisma generate`, and `prisma migrate dev` could
  not actually be run here (confirmed: `npm install` gets a 403 from
  the registry in this sandbox).
- Nothing has been run against a real PostgreSQL instance, and no
  image has actually been uploaded to Cloudinary.
- Flutter/Dart source was hand-written; every new file's imports were
  cross-checked against files that exist, and brace/paren balance was
  checked programmatically, but nothing was compiled with `flutter
  analyze` or run.

Run the commands under "Backend: setup & run" locally, in order.

## Project structure

```
scanserve/
├── backend/
│   ├── prisma/schema.prisma  Restaurant, User, Category, MenuItem models
│   ├── lib/prisma.js         shared PrismaClient instance
│   ├── controllers/          auth, restaurant (super admin), restaurantSelf
│   │                         (Phase 4: dashboard+QR), dashboard, category,
│   │                         menuItem
│   ├── middleware/           auth.js, restaurantAccess.js, upload.js (Phase 4),
│   │                         errorHandler.js, notFound.js
│   ├── routes/               auth, admin, restaurants, categories (Phase 4),
│   │                         menuItems (Phase 4), restaurantSelf (Phase 4), health
│   ├── services/             restaurantService, qrService, cloudinaryService (Phase 4)
│   ├── scripts/               seedSuperAdmin.js
│   └── server.js
│
└── frontend/lib/
    ├── core/                  theme, router (+ auth guard), constants, network, utils
    ├── features/
    │   ├── landing/           marketing page ("/")
    │   ├── auth/              login ("/login")
    │   ├── restaurant_admin/  dashboard, categories, menu, menu item form,
    │   │                      QR, settings - all under "/dashboard/*" (Phase 4)
    │   ├── super_admin/       dashboard, restaurants list/create/detail/QR
    │   └── customer_menu/     (empty - later phase)
    ├── shared/                widgets, data models (Category, MenuItem added)
    └── main.dart
```

## Backend: setup & run

Requires PostgreSQL and a Cloudinary account (free tier is fine).

```bash
cd scanserve/backend
cp .env.example .env
# set DATABASE_URL, JWT_SECRET, FRONTEND_URL, and the three CLOUDINARY_* vars

npm install
npx prisma generate
npx prisma migrate dev --name add_menu_management   # adds categories/menu_items tables;
                                                       # does NOT touch existing users/restaurants data

npm run dev

# If you don't already have one from Phase 3:
SUPER_ADMIN_NAME="Jane Doe" SUPER_ADMIN_EMAIL="jane@scanserve.com" \
SUPER_ADMIN_PASSWORD="a-strong-password" npm run seed:super-admin
```

## Frontend: setup & run

```bash
cd scanserve/frontend
flutter create --platforms=web .   # only needed once, if not already done
flutter pub get                    # picks up image_picker, added this round
flutter run -d chrome
```

## Testing the Phase 4 flow

1. Log in as a Restaurant Admin (create one via Super Admin → Create
   Restaurant if you don't have one) → `/dashboard` now shows real
   Categories/Menu Items/Available/Unavailable counts.
2. `/dashboard/categories` → Add Category ("Starters") → appears in the
   list with an item count of 0.
3. Try adding "Starters" again → rejected (duplicate name within your
   restaurant).
4. `/dashboard/menu` → Add Menu Item → pick "Starters", set a price,
   optionally pick an image → saves and shows up grouped under
   "Starters" on the Menu screen.
5. Edit the item, change its category, price, and toggle availability
   from the card's Disable/Enable button - watch the dashboard counts
   update accordingly.
6. Try deleting "Starters" while it still has that item → rejected with
   "Cannot delete category because menu items are assigned to it."
   Delete the item first, then the category succeeds.
7. Isolation check: log in as a *different* Restaurant Admin (a second
   restaurant) and confirm `GET /api/restaurant/categories` and
   `/api/restaurant/menu-items` only ever return their own restaurant's
   data - there's no way to pass another restaurant's id in, since the
   backend never reads restaurantId from the request.
8. `/dashboard/qr` shows this restaurant's own QR (no id in the URL -
   self-service, scoped to req.user.restaurantId).

## Environment variables (backend/.env)

```
PORT=5000
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/scanserve?schema=public
JWT_SECRET=
JWT_EXPIRES_IN=7d
FRONTEND_URL=http://localhost:3000
SUPER_ADMIN_NAME=
SUPER_ADMIN_EMAIL=
SUPER_ADMIN_PASSWORD=

# Phase 4 - image uploads
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_API_KEY=
CLOUDINARY_API_SECRET=
```

Never commit a real `.env` — only `.env.example` is tracked.

## API response format (Phase 4 endpoints)

New in this phase: `/api/restaurant/categories`, `/api/restaurant/menu-items`,
`/api/restaurant/dashboard`, and `/api/restaurant/qr` all respond as
`{ success, message, data }` (or `{ success, message }` on error), per
the Phase 4 spec. Phase 3's existing endpoints (`/api/admin/*`,
`/api/auth/*`) were intentionally left in their original shape -
retrofitting a working, already-integrated API wasn't asked for and
risked breaking the Super Admin screens for no benefit.

## Not implemented yet (by design — later phases)

- Customer-facing menu page, cart, table numbers
- Orders, order statuses, Socket.IO, WhatsApp, payments
- Customer accounts/login
- Restaurant Admin password change / restaurant profile editing
  (Settings page is a minimal placeholder for now)
- Permanent restaurant/category/menu-item hard-delete beyond what's
  specified (categories with items can't be deleted; menu items delete
  freely since orders don't exist yet to reference them)

## Known gaps from the environment constraints

- `npm install`, `prisma generate`, `prisma migrate dev`, and
  `flutter pub get` have not actually been run here.
- No image has been uploaded to Cloudinary; the upload path was
  written against Cloudinary's documented API but not exercised.
- Nothing has been run against a real PostgreSQL instance.
- Flutter/Dart code was hand-written and cross-checked (imports, widget
  constructor signatures, brace balance) but never compiled - run
  `flutter analyze` after `pub get` and fix anything it flags.
