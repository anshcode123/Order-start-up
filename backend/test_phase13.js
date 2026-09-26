/**
 * Phase 13 Verification Suite:
 * Food Variants (Half / Full) + Dining Type (DINE_IN / TAKEAWAY) +
 * Optional Table Number (requireTableNumber) + Order Status Update (COMPLETED removed)
 */
const http = require('http');
const { spawn } = require('child_process');
const { io } = require('socket.io-client');
const bcrypt = require('bcrypt');
const prisma = require('./lib/prisma');
require('dotenv').config();

const TEST_PORT = 5099;
const BASE_URL = `http://127.0.0.1:${TEST_PORT}`;
let serverProc = null;
let passed = 0;
let failed = 0;

function assert(condition, label, detail = '') {
  if (condition) {
    passed++;
    console.log(`  ✅ PASS: ${label}`);
  } else {
    failed++;
    console.error(`  ❌ FAIL: ${label} ${detail ? '— ' + detail : ''}`);
  }
}

function request(method, pathUrl, body = null, token = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(pathUrl, BASE_URL);
    const payload = body ? JSON.stringify(body) : null;
    const headers = {};
    if (payload) {
      headers['Content-Type'] = 'application/json';
      headers['Content-Length'] = Buffer.byteLength(payload);
    }
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    const req = http.request(
      {
        hostname: url.hostname,
        port: url.port,
        path: url.pathname + url.search,
        method,
        headers,
      },
      (res) => {
        let raw = '';
        res.on('data', (chunk) => (raw += chunk));
        res.on('end', () => {
          let parsed = null;
          try {
            parsed = JSON.parse(raw);
          } catch (_) {
            parsed = raw;
          }
          resolve({ status: res.statusCode, body: parsed });
        });
      }
    );
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

async function waitForServer(maxAttempts = 30) {
  for (let i = 0; i < maxAttempts; i++) {
    try {
      const res = await request('GET', '/api/health');
      if (res.status === 200) return;
    } catch (_) {}
    await new Promise((r) => setTimeout(r, 300));
  }
  throw new Error('Server failed to start on port ' + TEST_PORT);
}

async function run() {
  serverProc = spawn(process.execPath, ['server.js'], {
    cwd: __dirname,
    env: { ...process.env, PORT: String(TEST_PORT) },
    stdio: 'ignore',
  });

  await waitForServer();
  console.log(`\n🚀 Phase 13 Verification Server running on ${BASE_URL}`);

  // Ensure Super Admin exists
  const hashedPassword = await bcrypt.hash('Password123!', 10);
  await prisma.user.upsert({
    where: { email: 'superadmin@scanserve.com' },
    update: { password: hashedPassword, role: 'SUPER_ADMIN', isActive: true },
    create: {
      name: 'Super Admin',
      email: 'superadmin@scanserve.com',
      password: hashedPassword,
      role: 'SUPER_ADMIN',
      isActive: true,
    },
  });

  const saLogin = await request('POST', '/api/auth/login', {
    email: 'superadmin@scanserve.com',
    password: 'Password123!',
  });
  assert(saLogin.status === 200 && Boolean(saLogin.body?.token), 'Super Admin login succeeds');
  const saToken = saLogin.body.token;

  const restEmail = `phase13_${Date.now()}@scanserve.com`;
  const createRest = await request(
    'POST',
    '/api/admin/restaurants',
    {
      name: 'Tandoori Flames Phase 13',
      phone: '+919876543210',
      whatsappNumber: '+919876543210',
      email: restEmail,
      address: '13 Connaught Place',
      adminName: 'Chef Kabir',
      adminEmail: restEmail,
      adminPassword: 'Password123!',
    },
    saToken
  );
  assert(
    createRest.status === 201 && Boolean(createRest.body?.restaurant?.id),
    'Super Admin creates Phase 13 restaurant'
  );
  const restSlug = createRest.body.restaurant.slug;

  const raLogin = await request('POST', '/api/auth/login', {
    email: restEmail,
    password: 'Password123!',
  });
  assert(raLogin.status === 200 && Boolean(raLogin.body?.token), 'Restaurant Admin login succeeds');
  const raToken = raLogin.body.token;

  // Create category
  const catRes = await request(
    'POST',
    '/api/restaurant/categories',
    { name: 'Starters & Breads' },
    raToken
  );
  assert(catRes.status === 201, 'Restaurant Admin creates category');
  const catId = catRes.body.category.id;

  // ------------------------------------------------------------------
  // Section A — Variant Management
  // ------------------------------------------------------------------
  console.log('\n--- Section A: Variant Management (Half & Full) ---');

  // 1. Create single-price item (hasVariants = false)
  const naanRes = await request(
    'POST',
    '/api/restaurant/menu-items',
    {
      name: 'Butter Naan',
      description: 'Soft tandoori flatbread',
      price: '40.00',
      hasVariants: false,
      categoryId: catId,
      isAvailable: true,
    },
    raToken
  );
  assert(
    naanRes.status === 201 &&
      naanRes.body?.data?.hasVariants === false &&
      Number(naanRes.body?.data?.price) === 40 &&
      Array.isArray(naanRes.body?.data?.variants) &&
      naanRes.body.data.variants.length === 0,
    'Create normal menu item without variants (hasVariants = false)'
  );
  const naanId = naanRes.body.data.id;

  // 2. Create menu item with Half and Full variants
  const tikkaRes = await request(
    'POST',
    '/api/restaurant/menu-items',
    {
      name: 'Chicken Tikka',
      description: 'Charcoal grilled boneless chicken',
      hasVariants: true,
      variants: [
        { name: 'Half', price: '120.00', isAvailable: true },
        { name: 'Full', price: '220.00', isAvailable: true },
      ],
      categoryId: catId,
      isAvailable: true,
    },
    raToken
  );
  assert(
    tikkaRes.status === 201 &&
      tikkaRes.body?.data?.hasVariants === true &&
      tikkaRes.body?.data?.variants?.length === 2 &&
      tikkaRes.body.data.variants[0].name === 'Half' &&
      Number(tikkaRes.body.data.variants[0].price) === 120 &&
      tikkaRes.body.data.variants[1].name === 'Full' &&
      Number(tikkaRes.body.data.variants[1].price) === 220,
    'Create menu item with Half (₹120) and Full (₹220) variants'
  );
  const tikkaId = tikkaRes.body.data.id;
  const halfVariantId = tikkaRes.body.data.variants[0].id;
  const fullVariantId = tikkaRes.body.data.variants[1].id;

  // 3. Reject invalid variant configurations
  const badVariantRes = await request(
    'POST',
    '/api/restaurant/menu-items',
    {
      name: 'Broken Item',
      hasVariants: true,
      variants: [],
      categoryId: catId,
    },
    raToken
  );
  assert(badVariantRes.status === 400, 'Rejects hasVariants=true with empty variants array (400)');

  const dupVariantRes = await request(
    'POST',
    '/api/restaurant/menu-items',
    {
      name: 'Dup Variant Item',
      hasVariants: true,
      variants: [
        { name: 'Half', price: '100' },
        { name: 'half', price: '150' },
      ],
      categoryId: catId,
    },
    raToken
  );
  assert(dupVariantRes.status === 400, 'Rejects duplicate Half variants on same item (400)');

  // 4. Edit Half and Full prices and disable Half variant
  const updateTikkaRes = await request(
    'PUT',
    `/api/restaurant/menu-items/${tikkaId}`,
    {
      hasVariants: true,
      variants: [
        { name: 'Half', price: '140.00', isAvailable: false },
        { name: 'Full', price: '250.00', isAvailable: true },
      ],
    },
    raToken
  );
  assert(
    updateTikkaRes.status === 200 &&
      Number(updateTikkaRes.body?.data?.variants?.[0]?.price) === 140 &&
      updateTikkaRes.body?.data?.variants?.[0]?.isAvailable === false &&
      Number(updateTikkaRes.body?.data?.variants?.[1]?.price) === 250 &&
      updateTikkaRes.body?.data?.variants?.[1]?.isAvailable === true,
    'Edit Half/Full prices and disable Half variant'
  );

  // 5. Verify subscription usage counts MenuItem records (2), not MenuItemVariant records
  const subUsageRes = await request('GET', '/api/restaurant/subscription', null, raToken);
  assert(
    subUsageRes.status === 200 && subUsageRes.body?.usage?.menuItemCount === 2,
    'Subscription maxMenuItems counts MenuItem rows (2), not variant rows'
  );

  // ------------------------------------------------------------------
  // Section B — Public Menu
  // ------------------------------------------------------------------
  console.log('\n--- Section B: Public Menu Variant & Settings Exposure ---');
  const pubMenu1 = await request('GET', `/api/public/menu/${restSlug}`);
  const pubItems1 = pubMenu1.body?.data?.categories?.[0]?.items || [];
  const pubNaan = pubItems1.find((i) => i.id === naanId);
  const pubTikka = pubItems1.find((i) => i.id === tikkaId);

  assert(
    pubMenu1.status === 200 &&
      pubMenu1.body?.data?.restaurant?.requireTableNumber === true &&
      pubNaan?.hasVariants === false &&
      pubTikka?.hasVariants === true &&
      pubTikka?.variants?.length === 1 &&
      pubTikka.variants[0].name === 'Full',
    'Public menu exposes requireTableNumber=true and filters out disabled Half variant'
  );

  // Re-enable Half variant so both Half (₹140) and Full (₹250) are available
  await request(
    'PUT',
    `/api/restaurant/menu-items/${tikkaId}`,
    {
      hasVariants: true,
      variants: [
        { name: 'Half', price: '140.00', isAvailable: true },
        { name: 'Full', price: '250.00', isAvailable: true },
      ],
    },
    raToken
  );

  // ------------------------------------------------------------------
  // Section C — Cart & Order Validation with Variants
  // ------------------------------------------------------------------
  console.log('\n--- Section C: Order Creation with Variants & Price Integrity ---');

  // 1. Missing variant on variant-enabled item -> 400
  const missingVarOrder = await request('POST', '/api/public/orders', {
    restaurantSlug: restSlug,
    diningType: 'DINE_IN',
    tableNumber: 'T1',
    items: [{ menuItemId: tikkaId, quantity: 1 }],
  });
  assert(
    missingVarOrder.status === 400,
    'Rejects ordering variant-enabled item without selecting Half/Full (400)'
  );

  // 2. Variant passed for non-variant item -> 400
  const nonVarWithVarOrder = await request('POST', '/api/public/orders', {
    restaurantSlug: restSlug,
    diningType: 'DINE_IN',
    tableNumber: 'T1',
    items: [{ menuItemId: naanId, variantName: 'Half', quantity: 1 }],
  });
  assert(nonVarWithVarOrder.status === 400, 'Rejects variant selection on single-price item (400)');

  // 3. Invalid variant ID -> 400
  const invalidVarIdOrder = await request('POST', '/api/public/orders', {
    restaurantSlug: restSlug,
    diningType: 'DINE_IN',
    tableNumber: 'T1',
    items: [
      { menuItemId: tikkaId, variantId: '00000000-0000-0000-0000-000000000000', quantity: 1 },
    ],
  });
  assert(invalidVarIdOrder.status === 400, 'Rejects invalid variantId (400)');

  // 4. Order both Half (×2 @ ₹140 = ₹280) and Full (×1 @ ₹250 = ₹250) + Butter Naan (×3 @ ₹40 = ₹120) = ₹650
  const mixedOrderRes = await request('POST', '/api/public/orders', {
    restaurantSlug: restSlug,
    diningType: 'DINE_IN',
    tableNumber: 'T4',
    items: [
      { menuItemId: tikkaId, variantId: halfVariantId, quantity: 2, price: 1 },
      { menuItemId: tikkaId, variantId: fullVariantId, quantity: 1, price: 1 },
      { menuItemId: naanId, quantity: 3, price: 1 },
    ],
  });
  assert(
    mixedOrderRes.status === 201 &&
      mixedOrderRes.body?.data?.diningType === 'DINE_IN' &&
      mixedOrderRes.body?.data?.tableNumber === 'T4' &&
      Number(mixedOrderRes.body?.data?.total) === 650 &&
      mixedOrderRes.body?.data?.items?.length === 3,
    'Creates order with Half ×2, Full ×1, and single-price item ×3 using trusted DB prices (₹650)'
  );
  const mixedOrderId = mixedOrderRes.body.data.id;
  const mixedOrderRef = mixedOrderRes.body.data.orderId;

  const halfLine = mixedOrderRes.body.data.items.find((i) => i.variantName === 'Half');
  const fullLine = mixedOrderRes.body.data.items.find((i) => i.variantName === 'Full');
  const naanLine = mixedOrderRes.body.data.items.find((i) => i.menuItemId === naanId);
  assert(
    halfLine &&
      Number(halfLine.unitPrice) === 140 &&
      Number(halfLine.subtotal) === 280 &&
      fullLine &&
      Number(fullLine.unitPrice) === 250 &&
      Number(fullLine.subtotal) === 250 &&
      naanLine &&
      naanLine.variantName === null &&
      Number(naanLine.subtotal) === 120,
    'OrderItem snapshots preserve variantId, variantName (Half/Full), unitPrice, and subtotal'
  );

  // ------------------------------------------------------------------
  // Section D — Dining Type & Optional Table Number
  // ------------------------------------------------------------------
  console.log('\n--- Section D: Dining Type (DINE_IN / TAKEAWAY) & requireTableNumber Setting ---');

  // 1. DINE_IN when requireTableNumber = true without tableNumber -> 400
  const dineInNoTable = await request('POST', '/api/public/orders', {
    restaurantSlug: restSlug,
    diningType: 'DINE_IN',
    tableNumber: '',
    items: [{ menuItemId: naanId, quantity: 1 }],
  });
  assert(
    dineInNoTable.status === 400,
    'DINE_IN without tableNumber rejected when requireTableNumber=true (400)'
  );

  // 2. TAKEAWAY when requireTableNumber = true without tableNumber -> 201
  const takeawayOrder = await request('POST', '/api/public/orders', {
    restaurantSlug: restSlug,
    diningType: 'TAKEAWAY',
    items: [{ menuItemId: tikkaId, variantName: 'Half', quantity: 1 }],
  });
  assert(
    takeawayOrder.status === 201 &&
      takeawayOrder.body?.data?.diningType === 'TAKEAWAY' &&
      takeawayOrder.body?.data?.tableNumber === null,
    'TAKEAWAY order succeeds without tableNumber even when requireTableNumber=true'
  );

  // 3. Restaurant Admin updates requireTableNumber = false in settings
  const updateSettingsRes = await request(
    'PUT',
    '/api/restaurant/settings',
    { requireTableNumber: false },
    raToken
  );
  assert(
    updateSettingsRes.status === 200 && updateSettingsRes.body?.data?.requireTableNumber === false,
    'Restaurant Admin disables requireTableNumber via PUT /api/restaurant/settings'
  );

  const pubMenuAfterSetting = await request('GET', `/api/public/menu/${restSlug}`);
  assert(
    pubMenuAfterSetting.body?.data?.restaurant?.requireTableNumber === false,
    'Public menu reflects requireTableNumber = false'
  );

  // 4. DINE_IN without tableNumber when requireTableNumber = false -> 201
  const dineInOptionalTable = await request('POST', '/api/public/orders', {
    restaurantSlug: restSlug,
    diningType: 'DINE_IN',
    items: [{ menuItemId: naanId, quantity: 2 }],
  });
  assert(
    dineInOptionalTable.status === 201 &&
      dineInOptionalTable.body?.data?.diningType === 'DINE_IN' &&
      dineInOptionalTable.body?.data?.tableNumber === null,
    'DINE_IN without tableNumber succeeds when requireTableNumber=false'
  );

  // 5. DINE_IN with tableNumber when requireTableNumber = false -> 201
  const dineInWithTable = await request('POST', '/api/public/orders', {
    restaurantSlug: restSlug,
    diningType: 'DINE_IN',
    tableNumber: 'PATIO-3',
    items: [{ menuItemId: naanId, quantity: 1 }],
  });
  assert(
    dineInWithTable.status === 201 &&
      dineInWithTable.body?.data?.diningType === 'DINE_IN' &&
      dineInWithTable.body?.data?.tableNumber === 'PATIO-3',
    'DINE_IN with optional tableNumber saves tableNumber when provided'
  );

  // ------------------------------------------------------------------
  // Section E — Order Status Lifecycle (COMPLETED Removed, READY is Final)
  // ------------------------------------------------------------------
  console.log(
    '\n--- Section E: Order Status Lifecycle (PENDING -> ACCEPTED -> PREPARING -> READY) ---'
  );

  const sAccept = await request(
    'PATCH',
    `/api/restaurant/orders/${mixedOrderId}/status`,
    { status: 'ACCEPTED' },
    raToken
  );
  assert(sAccept.status === 200 && sAccept.body?.data?.status === 'ACCEPTED', 'PENDING -> ACCEPTED');

  const sPrep = await request(
    'PATCH',
    `/api/restaurant/orders/${mixedOrderId}/status`,
    { status: 'PREPARING' },
    raToken
  );
  assert(sPrep.status === 200 && sPrep.body?.data?.status === 'PREPARING', 'ACCEPTED -> PREPARING');

  const sReady = await request(
    'PATCH',
    `/api/restaurant/orders/${mixedOrderId}/status`,
    { status: 'READY' },
    raToken
  );
  assert(
    sReady.status === 200 && sReady.body?.data?.status === 'READY',
    'PREPARING -> READY (final happy-path status)'
  );

  const sCompleted = await request(
    'PATCH',
    `/api/restaurant/orders/${mixedOrderId}/status`,
    { status: 'COMPLETED' },
    raToken
  );
  assert(sCompleted.status === 400, 'COMPLETED status is removed and rejected with 400');

  const sReadyToCancel = await request(
    'PATCH',
    `/api/restaurant/orders/${mixedOrderId}/status`,
    { status: 'CANCELLED' },
    raToken
  );
  assert(sReadyToCancel.status === 400, 'READY is a final state and cannot transition further (400)');

  const trackRes = await request('GET', `/api/public/orders/${mixedOrderRef}/status`);
  assert(
    trackRes.status === 200 &&
      trackRes.body?.data?.status === 'READY' &&
      trackRes.body?.data?.diningType === 'DINE_IN' &&
      trackRes.body?.data?.items?.some((i) => i.variantName === 'Half'),
    'Public order tracking returns READY status, diningType, and item variantName'
  );

  // ------------------------------------------------------------------
  // Section F — Socket.IO & WhatsApp Format Verification
  // ------------------------------------------------------------------
  console.log('\n--- Section F: Socket.IO & WhatsApp Notification Payload ---');

  const decodedWa = decodeURIComponent(
    mixedOrderRes.body?.whatsappNotification?.whatsappUrl || ''
  );
  assert(
    decodedWa.includes('Dining Type:\nDine In') &&
      decodedWa.includes('Table:\nT4') &&
      decodedWa.includes('Chicken Tikka (Half) × 2 — ₹280') &&
      decodedWa.includes('Chicken Tikka (Full) × 1 — ₹250'),
    'WhatsApp notification message includes Dining Type, Table, and Variant names'
  );

  const decodedTakeawayWa = decodeURIComponent(
    takeawayOrder.body?.whatsappNotification?.whatsappUrl || ''
  );
  assert(
    decodedTakeawayWa.includes('Dining Type:\nTakeaway') &&
      !decodedTakeawayWa.includes('Table:'),
    'Takeaway WhatsApp notification includes Dining Type: Takeaway and omits Table'
  );

  await new Promise((resolve) => {
    const adminSocket = io(BASE_URL, {
      auth: { token: raToken },
      transports: ['websocket'],
    });

    adminSocket.on('connect', async () => {
      await request('POST', '/api/public/orders', {
        restaurantSlug: restSlug,
        diningType: 'TAKEAWAY',
        items: [{ menuItemId: tikkaId, variantName: 'Full', quantity: 2 }],
      });
    });

    adminSocket.on('order:new', (payload) => {
      assert(
        payload.diningType === 'TAKEAWAY' &&
          payload.tableNumber === null &&
          payload.items?.[0]?.variantName === 'Full',
        'Socket.IO order:new event carries diningType, tableNumber, and item variantName'
      );
      adminSocket.disconnect();
      resolve();
    });
  });

  // ------------------------------------------------------------------
  // Section G — Super Admin Analytics Compatibility
  // ------------------------------------------------------------------
  console.log('\n--- Section G: Super Admin Dashboard & Analytics ---');
  const saDash = await request('GET', '/api/super-admin/dashboard/stats', null, saToken);
  assert(
    saDash.status === 200 && saDash.body?.stats?.readyOrders >= 1,
    'Super Admin dashboard stats return readyOrders without COMPLETED enum error'
  );

  const saAnalytics = await request(
    'GET',
    '/api/super-admin/analytics/orders?period=today',
    null,
    saToken
  );
  assert(
    saAnalytics.status === 200 &&
      saAnalytics.body?.statusBreakdown?.READY !== undefined &&
      saAnalytics.body?.statusBreakdown?.COMPLETED === undefined,
    'Super Admin order analytics statusBreakdown uses READY and excludes COMPLETED'
  );

  serverProc.kill();
  await prisma.$disconnect();

  console.log(`\n==================================================`);
  console.log(`Phase 13 Test Results: ${passed} passed, ${failed} failed`);
  console.log(`==================================================\n`);
  process.exit(failed > 0 ? 1 : 0);
}

run().catch(async (err) => {
  console.error('Fatal error in Phase 13 tests:', err);
  if (serverProc) serverProc.kill();
  await prisma.$disconnect();
  process.exit(1);
});
