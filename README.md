# ScanServe — through Phase 7 (PostgreSQL/Prisma + Socket.IO)

Digital QR Menu + Table Ordering System. Implemented so far:
Phase 1 (scaffolding), Phase 2 (auth), Phase 3 (Super Admin restaurant
management), Phase 4 (Restaurant Admin menu management), Phase 5
(public customer menu + cart + table number), Phase 6 (the ordering
system), and Phase 7 (real-time order updates via Socket.IO) - all on
PostgreSQL + Prisma. See "Not implemented yet" for what's intentionally
left out.

## A note on how this was built

This container has Node.js but **no Flutter SDK, no PostgreSQL, and no
internet access**. That means:
- Every backend `.js` file was syntax-checked with `node --check`
  (38 files, all pass), but `npm install` and `prisma generate` could
  not actually be run here - and no Socket.IO connection has actually
  been opened or tested against a running server.
- Flutter/Dart source was hand-written; every file's imports were
  cross-checked against files that exist, widget/helper call sites were
  checked against their definitions, and brace/paren balance was
  checked programmatically - but nothing was compiled with `flutter
  analyze` or run, so no socket event has actually round-tripped
  end-to-end.

## Project structure (Phase 7 additions marked)

```
scanserve/backend/
├── lib/socket.js                   NEW - initializeSocket()/getIO(), room joins
├── middleware/socketAuth.js        NEW - JWT handshake auth for sockets
├── services/socketService.js       NEW - emitToRestaurant()/emitToOrder()
├── services/orderService.js        MODIFIED - emits "order:new" after the
│                                    order+items transaction commits
├── controllers/orderController.js  MODIFIED - emits "order:status_updated"
│                                    after a successful status update
├── server.js                       MODIFIED - http.createServer(app) +
│                                    initializeSocket(server), same Express app
└── package.json                    + socket.io

scanserve/frontend/lib/
├── core/network/
│   ├── socket_client.dart          NEW - derives the Socket.IO base URL
│   │                                from the existing Dio base URL
│   └── socket_connection_status.dart NEW - shared connecting/connected/
│                                      disconnected/error enum
├── features/customer_menu/
│   ├── providers/customer_order_socket_provider.dart NEW
│   ├── providers/public_order_status_provider.dart   MODIFIED - now a
│   │                                StateNotifier so socket events can
│   │                                patch it in place, not just REST
│   └── screens/order_success_screen.dart             MODIFIED - live
│                                    updates, connection badge, status
│                                    progress stepper
├── features/restaurant_admin/
│   ├── providers/restaurant_order_socket_provider.dart NEW
│   ├── providers/order_providers.dart      MODIFIED - restaurantOrdersProvider
│   │                                is now a StateNotifier patched by socket
│   │                                events; added newOrderEventProvider
│   ├── widgets/restaurant_admin_scaffold.dart MODIFIED - owns the socket
│   │                                connection for the whole dashboard
│   │                                session, shows the connection dot,
│   │                                shows the "New order" SnackBar
│   └── screens/orders_screen.dart          MODIFIED - tabbed
│                                    (New/Accepted/Preparing/Ready/
│                                    Completed/Cancelled)
├── shared/models/restaurant_order.dart MODIFIED - added
│                                    fromNewOrderEvent()/copyWith()
└── pubspec.yaml                    + socket_io_client
```

## Backend: setup & run

No schema/migration changes this phase - Socket.IO is a delivery layer
on top of the existing Order/OrderItem tables.

```bash
cd scanserve/backend
cp .env.example .env   # CLIENT_ORIGIN is reused for Socket.IO's CORS too
npm install             # now also pulls in socket.io
npx prisma generate      # only if you haven't already
npm run dev
```

## Frontend: setup & run

```bash
cd scanserve/frontend
flutter pub get   # now also pulls in socket_io_client
flutter run -d chrome
```

## Testing the Phase 7 flow

**Restaurant Admin (do this first, keep the tab open):**
1. Log in, open `/dashboard/orders` - notice the small dot next to the
   logo/app bar: "Connecting" → "Live" once the socket connects.
2. Leave Orders and go to Menu or Settings - the dot should still show
   "Live" (the connection lives at the dashboard shell level, not just
   on the Orders screen).

**Customer (in another tab/window):**
3. Open `/menu/<slug>`, add items, enter a table number, Place Order.
4. On the success screen, confirm its own connection badge also reaches
   "Live", and the progress stepper shows PENDING highlighted with
   nothing after it marked done.

**Back to Restaurant Admin:**
5. Without refreshing, confirm: a SnackBar appears ("New order
   received — Table X") with a "View" action; the Orders page's "New"
   tab count increments and the order appears highlighted, with no
   manual refresh.
6. Open the order, Accept it (PENDING → ACCEPTED).

**Back to Customer:**
7. Without refreshing, confirm the stepper on the success/status screen
   moves to ACCEPTED automatically.
8. Repeat for PREPARING → READY → COMPLETED - confirm each hop shows up
   live on the customer side within a second or two, with earlier steps
   shown as done (checkmarked) and nothing beyond the current step ever
   shown as complete.
9. Try REJECTED or CANCELLED on a fresh order instead - confirm the
   customer screen shows the distinct terminal banner, not the stepper.

**Isolation (two restaurants):**
10. Log in as Restaurant B in a separate session. Place an order for
    Restaurant A → confirm Restaurant B's Orders page does NOT light up
    or receive a notification. Only Restaurant A does.
11. As a sanity check on the auth boundary itself: connecting a socket
    with no token, an expired token, or a tampered token is refused (no
    token = fine, treated as an anonymous customer connection with no
    room auto-joined; a bad token = the connection is rejected outright).

**Reconnection:**
12. On either the customer or admin screen, kill and restart the
    backend (or toggle devtools "offline"). Confirm the dot goes to
    "Reconnecting"/"Offline", the UI doesn't crash, and once the backend
    is back, the dot returns to "Live" and the list/status resyncs via
    a fresh REST call (not just whatever was last cached).

**Regression (Phases 1-6):** confirm `/login`, `/super-admin/*`,
`/dashboard/menu`, `/dashboard/categories`, QR generation, and placing
an order via `POST /api/public/orders` still all work exactly as
before - nothing about the REST API's request/response shape changed
in this phase, only that a successful write now also emits an event.

## Socket.IO architecture

- **One shared instance**: `lib/socket.js` exports `initializeSocket(server)`
  / `getIO()`, following the exact `let io; ... module.exports` shape
  the brief suggested. Called once from `server.js` against the same
  `http.createServer(app)` instance Express already uses - there is
  only one HTTP server and one Socket.IO server, never two.
- **Restaurant Admin auth**: the JWT is sent via `socket.handshake.auth.token`
  at connect time (not a header, since Socket.IO's own auth mechanism
  is the handshake payload). `middleware/socketAuth.js` verifies it and
  re-fetches the user from Postgres (same pattern as the HTTP `protect`
  middleware) to catch a deactivated account even with a still-valid
  token. `restaurantId` on the resulting `socket.data.user` comes only
  from that DB record - never anything the client sends.
- **Restaurant room**: `restaurant:{restaurantId}`, joined automatically
  on connect for `RESTAURANT_ADMIN` only. `SUPER_ADMIN` is authenticated
  but not auto-joined to anything (per the brief - no blanket
  cross-restaurant visibility).
- **Customer room**: `order:{publicToken}` - customers never carry a
  JWT, so instead the client emits `order:subscribe` with the same
  `publicToken` from Phase 6's public order API, and the server only
  joins the room after confirming that token maps to a real order.
  There's no `order:{id}` room keyed by the internal database id.
- **Events**: `order:new` (to the restaurant room, emitted from
  `orderService.js` only after the create transaction commits) and
  `order:status_updated` (to both the restaurant room and the order
  room, emitted from `orderController.js` only after the status update
  succeeds and passes the existing transition-validity check).
- **REST stays authoritative**: both socket emit helpers
  (`services/socketService.js`) swallow their own errors - a failed
  broadcast can never turn an already-successful database write into a
  failed HTTP response, and every socket provider on the Flutter side
  re-syncs via the existing REST endpoints on every connect/reconnect,
  never trusting the socket alone for correctness.

## Dependencies added

- Backend: `socket.io`
- Frontend: `socket_io_client`

## Environment variables added

None - Socket.IO's CORS reuses the existing `CLIENT_ORIGIN`.

## Not implemented yet (by design — later phases)

- WhatsApp, SMS, email, push notifications, payments, customer
  accounts/login, delivery, coupons, ratings/reviews, kitchen display
  system.
- **Sound notification on new order (Phase 7 spec #22, explicitly
  optional)**: deliberately skipped. `SystemSound.play` has no verified
  behavior on Flutter Web in this environment (no browser available
  here to test it, and it's primarily built out for mobile/desktop
  platforms), and the spec explicitly says to skip audio rather than
  force it in if it complicates things or risks an unverified
  dependency. The in-app SnackBar notification (required) is
  implemented; only the optional sound was left out.
- Super Admin order monitoring - intentionally not added (spec #20).

## Known gaps from the environment constraints

- No Socket.IO connection has actually been opened here - no Postgres,
  no Flutter SDK, no browser in this container. Please work through the
  test list above locally.
- Run `flutter analyze` after `pub get` and fix anything it flags
  before relying on this beyond code review.
