const http = require('http');
const { io } = require('socket.io-client');

const BASE_URL = 'http://localhost:5000';
let passed = 0;
let failed = 0;

function request(method, path, body = null, token = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const options = {
      method,
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      headers: {
        'Content-Type': 'application/json',
      },
    };
    if (token) {
      options.headers['Authorization'] = `Bearer ${token}`;
    }

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        let json = null;
        try {
          json = JSON.parse(data);
        } catch (_) {}
        resolve({ status: res.statusCode, headers: res.headers, body: json, raw: data });
      });
    });

    req.on('error', reject);
    if (body) {
      req.write(typeof body === 'string' ? body : JSON.stringify(body));
    }
    req.end();
  });
}

function assert(condition, label) {
  if (condition) {
    console.log(`  ✅ PASS: ${label}`);
    passed++;
  } else {
    console.error(`  ❌ FAIL: ${label}`);
    failed++;
  }
}

async function runPhase12Tests() {
  console.log('================================================================');
  console.log('  SCANSERVE PHASE 12 — FINAL PRODUCTION LAUNCH & SECURITY AUDIT');
  console.log('================================================================\n');

  // ------------------------------------------------------------------
  // Ensure test Super Admin & Spice Garden Restaurant Admin exist
  const bcrypt = require('bcrypt');
  const prisma = require('./lib/prisma');
  const hashedPassword = await bcrypt.hash('Password123!', 10);
  await prisma.user.upsert({
    where: { email: 'superadmin@scanserve.com' },
    update: { password: hashedPassword, role: 'SUPER_ADMIN', isActive: true },
    create: { name: 'Super Admin', email: 'superadmin@scanserve.com', password: hashedPassword, role: 'SUPER_ADMIN', isActive: true },
  });
  let spiceRest = await prisma.restaurant.findUnique({ where: { slug: 'spice-garden' } });
  if (!spiceRest) {
    spiceRest = await prisma.restaurant.create({
      data: { name: 'Spice Garden', slug: 'spice-garden', phone: '9876543210', email: 'admin@spicegarden.com', isActive: true },
    });
  } else if (!spiceRest.isActive) {
    await prisma.restaurant.update({ where: { id: spiceRest.id }, data: { isActive: true } });
  }
  await prisma.user.upsert({
    where: { email: 'admin@spicegarden.com' },
    update: { password: hashedPassword, role: 'RESTAURANT_ADMIN', restaurantId: spiceRest.id, isActive: true },
    create: { name: 'Spice Admin', email: 'admin@spicegarden.com', password: hashedPassword, role: 'RESTAURANT_ADMIN', restaurantId: spiceRest.id, isActive: true },
  });
  const existingCat = await prisma.category.findFirst({ where: { restaurantId: spiceRest.id } });
  const cat = existingCat || await prisma.category.create({ data: { name: 'Mains', restaurantId: spiceRest.id } });
  const existingItem = await prisma.menuItem.findFirst({ where: { restaurantId: spiceRest.id, isAvailable: true } });
  if (!existingItem) {
    await prisma.menuItem.create({
      data: { name: 'Paneer Tikka', price: 250, categoryId: cat.id, restaurantId: spiceRest.id, isAvailable: true },
    });
  }

  // 1. Health Check & Security Headers
  // ------------------------------------------------------------------
  console.log('--- 1. Health Endpoint & Security Headers ---');
  const healthRes = await request('GET', '/api/health');
  assert(healthRes.status === 200, 'GET /api/health returns 200 OK');
  assert(
    healthRes.body?.status === 'ok' &&
      healthRes.body?.service === 'scanserve-backend' &&
      Boolean(healthRes.body?.timestamp),
    'GET /api/health returns exact { status: "ok", service: "scanserve-backend", timestamp }'
  );
  assert(healthRes.headers['x-content-type-options'] === 'nosniff', 'Security header X-Content-Type-Options: nosniff is set');
  assert(['DENY', 'SAMEORIGIN'].includes(healthRes.headers['x-frame-options']), 'Security header X-Frame-Options is set');
  assert(healthRes.headers['x-powered-by'] === undefined, 'X-Powered-By header is hidden');

  // ------------------------------------------------------------------
  // 2. Authentication & Role Isolation
  // ------------------------------------------------------------------
  console.log('\n--- 2. Authentication & Role Security ---');
  const badLogin = await request('POST', '/api/auth/login', {
    email: 'superadmin@scanserve.com',
    password: 'WrongPassword!',
  });
  assert(badLogin.status === 401 && !badLogin.body?.stack, 'Invalid password returns 401 without stack trace');

  const emptyLogin = await request('POST', '/api/auth/login', { email: '', password: '' });
  assert(emptyLogin.status === 400, 'Empty credentials return 400');

  const saLogin = await request('POST', '/api/auth/login', {
    email: 'superadmin@scanserve.com',
    password: 'Password123!',
  });
  assert(saLogin.status === 200 && Boolean(saLogin.body?.token), 'Super Admin login succeeds');
  const saToken = saLogin.body.token;
  assert(saLogin.body.user?.password === undefined && saLogin.body.user?.passwordHash === undefined, 'Login response never leaks password hash');

  const ra1Login = await request('POST', '/api/auth/login', {
    email: 'admin@spicegarden.com',
    password: 'Password123!',
  });
  assert(ra1Login.status === 200 && Boolean(ra1Login.body?.token), 'Restaurant A Admin login succeeds');
  const ra1Token = ra1Login.body.token;
  const restAId = ra1Login.body.user.restaurantId;

  // Check /api/auth/me with valid, invalid, and missing tokens
  const meValid = await request('GET', '/api/auth/me', null, ra1Token);
  assert(meValid.status === 200 && meValid.body?.user?.restaurantId === restAId, 'GET /api/auth/me returns authenticated user');

  const meInvalid = await request('GET', '/api/auth/me', null, 'invalid.jwt.token');
  assert(meInvalid.status === 401, 'Invalid JWT token rejected with 401');

  const meMissing = await request('GET', '/api/auth/me');
  assert(meMissing.status === 401, 'Missing JWT token rejected with 401');

  // Role isolation checks
  const raToSuperAdmin = await request('GET', '/api/super-admin/dashboard/stats', null, ra1Token);
  assert(raToSuperAdmin.status === 403, 'RESTAURANT_ADMIN blocked from /api/super-admin/* (403)');

  const raToAdminRests = await request('GET', '/api/admin/restaurants', null, ra1Token);
  assert(raToAdminRests.status === 403, 'RESTAURANT_ADMIN blocked from /api/admin/restaurants (403)');

  const saToRestCategories = await request('GET', '/api/categories', null, saToken);
  assert(saToRestCategories.status === 403, 'SUPER_ADMIN blocked from RESTAURANT_ADMIN-only /api/categories (403)');

  const anonToOrders = await request('GET', '/api/restaurant/orders');
  assert(anonToOrders.status === 401, 'Anonymous user blocked from /api/restaurant/orders (401)');

  // ------------------------------------------------------------------
  // 3. Multi-Tenant Isolation (Restaurant A vs Restaurant B)
  // ------------------------------------------------------------------
  console.log('\n--- 3. Multi-Tenant Restaurant Isolation (Restaurant A vs Restaurant B) ---');
  // Create Restaurant B via Super Admin
  const restBEmail = `restb_${Date.now()}@scanserve.com`;
  const createRestB = await request(
    'POST',
    '/api/admin/restaurants',
    {
      name: 'Ocean Breeze Cafe',
      phone: '9123456789',
      email: restBEmail,
      address: '42 Marine Drive',
      adminName: 'Ocean Admin',
      adminEmail: restBEmail,
      adminPassword: 'Password123!',
    },
    saToken
  );
  assert(createRestB.status === 201 && createRestB.body?.restaurant?.id, 'Super Admin creates Restaurant B');
  const restBId = createRestB.body.restaurant.id;
  const restBSlug = createRestB.body.restaurant.slug;

  const ra2Login = await request('POST', '/api/auth/login', {
    email: restBEmail,
    password: 'Password123!',
  });
  assert(ra2Login.status === 200 && Boolean(ra2Login.body?.token), 'Restaurant B Admin login succeeds');
  const ra2Token = ra2Login.body.token;

  // Create category & menu item in Restaurant B
  const catBRes = await request('POST', '/api/categories', { name: 'Seafood Specials' }, ra2Token);
  assert(catBRes.status === 201, 'Restaurant B creates a category');
  const catBId = catBRes.body.category.id;

  const itemBRes = await request(
    'POST',
    '/api/menu',
    {
      name: 'Grilled Prawns',
      description: 'Fresh coastal prawns',
      price: '450.00',
      categoryId: catBId,
      isAvailable: true,
    },
    ra2Token
  );
  assert(itemBRes.status === 201, 'Restaurant B creates a menu item');
  const itemBId = itemBRes.body.menuItem.id;

  // Place an order for Restaurant B
  const orderBRes = await request('POST', '/api/public/orders', {
    restaurantSlug: restBSlug,
    tableNumber: 'B1',
    customerName: 'Rahul',
    items: [{ menuItemId: itemBId, quantity: 2 }],
  });
  assert(orderBRes.status === 201, 'Customer places order at Restaurant B');
  const orderBId = orderBRes.body.order.id;

  // Restaurant A tries to read/edit/delete Restaurant B's category
  const ra1EditCatB = await request('PUT', `/api/categories/${catBId}`, { name: 'Hacked' }, ra1Token);
  assert(ra1EditCatB.status === 404, 'Restaurant A cannot edit Restaurant B category (404)');

  const ra1DelCatB = await request('DELETE', `/api/categories/${catBId}`, null, ra1Token);
  assert(ra1DelCatB.status === 404, 'Restaurant A cannot delete Restaurant B category (404)');

  // Restaurant A tries to read/edit/delete Restaurant B's menu item
  const ra1GetItemB = await request('GET', `/api/menu/${itemBId}`, null, ra1Token);
  assert(ra1GetItemB.status === 404, 'Restaurant A cannot view Restaurant B menu item (404)');

  const ra1EditItemB = await request('PUT', `/api/menu/${itemBId}`, { name: 'Hacked Dish' }, ra1Token);
  assert(ra1EditItemB.status === 404, 'Restaurant A cannot edit Restaurant B menu item (404)');

  const ra1PatchItemB = await request('PATCH', `/api/menu/${itemBId}/availability`, { isAvailable: false }, ra1Token);
  assert(ra1PatchItemB.status === 404, 'Restaurant A cannot toggle Restaurant B menu item availability (404)');

  const ra1DelItemB = await request('DELETE', `/api/menu/${itemBId}`, null, ra1Token);
  assert(ra1DelItemB.status === 404, 'Restaurant A cannot delete Restaurant B menu item (404)');

  // Restaurant A tries to create a menu item under Restaurant B's category
  const ra1CrossCatItem = await request(
    'POST',
    '/api/menu',
    { name: 'Cross Tenant Item', price: '100', categoryId: catBId },
    ra1Token
  );
  assert(ra1CrossCatItem.status === 404, 'Restaurant A cannot create menu item in Restaurant B category');

  // Restaurant A tries to view or update Restaurant B's order
  const ra1GetOrderB = await request('GET', `/api/restaurant/orders/${orderBId}`, null, ra1Token);
  assert(ra1GetOrderB.status === 404, 'Restaurant A cannot view Restaurant B order (404)');

  const ra1PatchOrderB = await request(
    'PATCH',
    `/api/restaurant/orders/${orderBId}/status`,
    { status: 'CONFIRMED' },
    ra1Token
  );
  assert(ra1PatchOrderB.status === 404, 'Restaurant A cannot update Restaurant B order status (404)');

  // Verify Restaurant A's order list does NOT contain Restaurant B's order
  const ra1Orders = await request('GET', '/api/restaurant/orders', null, ra1Token);
  const leakedOrder = (ra1Orders.body?.orders || []).find((o) => o.id === orderBId);
  assert(!leakedOrder, 'Restaurant A order list does not leak Restaurant B orders');

  // ------------------------------------------------------------------
  // 4. Customer Menu & Order Integrity / Price Tampering Prevention
  // ------------------------------------------------------------------
  console.log('\n--- 4. Customer Order Validation & Price Integrity ---');
  // Customer attempts to spoof price in payload (e.g. price: 0.01 when DB price is 450.00)
  const spoofOrderRes = await request('POST', '/api/public/orders', {
    restaurantSlug: restBSlug,
    tableNumber: 'B2',
    customerName: 'Attacker',
    totalAmount: 1,
    items: [{ menuItemId: itemBId, quantity: 2, price: 0.01 }],
  });
  assert(spoofOrderRes.status === 201, 'Order with extra/spoofed price fields is processed using DB price');
  assert(
    Number(spoofOrderRes.body?.order?.totalAmount) === 900,
    'Backend calculates totalAmount strictly from DB price (2 * 450 = 900), ignoring client price'
  );

  // Invalid quantities
  const zeroQtyOrder = await request('POST', '/api/public/orders', {
    restaurantSlug: restBSlug,
    tableNumber: 'B2',
    items: [{ menuItemId: itemBId, quantity: 0 }],
  });
  assert(zeroQtyOrder.status === 400, 'Order with quantity 0 rejected (400)');

  const negativeQtyOrder = await request('POST', '/api/public/orders', {
    restaurantSlug: restBSlug,
    tableNumber: 'B2',
    items: [{ menuItemId: itemBId, quantity: -3 }],
  });
  assert(negativeQtyOrder.status === 400, 'Order with negative quantity rejected (400)');

  const excessiveQtyOrder = await request('POST', '/api/public/orders', {
    restaurantSlug: restBSlug,
    tableNumber: 'B2',
    items: [{ menuItemId: itemBId, quantity: 500 }],
  });
  assert(excessiveQtyOrder.status === 400, 'Order with excessive quantity (>99) rejected (400)');

  const emptyTableOrder = await request('POST', '/api/public/orders', {
    restaurantSlug: restBSlug,
    tableNumber: '   ',
    items: [{ menuItemId: itemBId, quantity: 1 }],
  });
  assert(emptyTableOrder.status === 400, 'Order with blank tableNumber rejected (400)');

  // Cross-restaurant menu item injection in public order
  const restAMenu = await request('GET', '/api/public/menu/spice-garden');
  const restAItemId = restAMenu.body?.categories?.[0]?.items?.[0]?.id;
  if (restAItemId) {
    const crossRestOrder = await request('POST', '/api/public/orders', {
      restaurantSlug: restBSlug,
      tableNumber: 'B3',
      items: [{ menuItemId: restAItemId, quantity: 1 }],
    });
    assert(crossRestOrder.status === 400, 'Customer cannot order Restaurant A item under Restaurant B slug');
  }

  // Unavailable item ordering rejected
  await request('PATCH', `/api/menu/${itemBId}/availability`, { isAvailable: false }, ra2Token);
  const unavailOrder = await request('POST', '/api/public/orders', {
    restaurantSlug: restBSlug,
    tableNumber: 'B3',
    items: [{ menuItemId: itemBId, quantity: 1 }],
  });
  assert(unavailOrder.status === 400, 'Customer cannot order unavailable menu item (400)');
  await request('PATCH', `/api/menu/${itemBId}/availability`, { isAvailable: true }, ra2Token);

  // ------------------------------------------------------------------
  // 5. Order Status Lifecycle & WhatsApp Non-Blocking Safety
  // ------------------------------------------------------------------
  console.log('\n--- 5. Order Status Transitions & WhatsApp Link Generation ---');
  const statusConfirm = await request(
    'PATCH',
    `/api/restaurant/orders/${orderBId}/status`,
    { status: 'CONFIRMED' },
    ra2Token
  );
  assert(statusConfirm.status === 200 && statusConfirm.body?.order?.status === 'CONFIRMED', 'Order status transitions PENDING -> CONFIRMED');

  const statusPrep = await request(
    'PATCH',
    `/api/restaurant/orders/${orderBId}/status`,
    { status: 'PREPARING' },
    ra2Token
  );
  assert(statusPrep.status === 200 && statusPrep.body?.order?.status === 'PREPARING', 'Order status transitions CONFIRMED -> PREPARING');

  const statusReady = await request(
    'PATCH',
    `/api/restaurant/orders/${orderBId}/status`,
    { status: 'READY' },
    ra2Token
  );
  assert(statusReady.status === 200 && statusReady.body?.order?.status === 'READY', 'Order status transitions PREPARING -> READY');

  const statusComp = await request(
    'PATCH',
    `/api/restaurant/orders/${orderBId}/status`,
    { status: 'COMPLETED' },
    ra2Token
  );
  assert(statusComp.status === 200 && statusComp.body?.order?.status === 'COMPLETED', 'Order status transitions READY -> COMPLETED');

  const statusInvalid = await request(
    'PATCH',
    `/api/restaurant/orders/${orderBId}/status`,
    { status: 'INVALID_STATE' },
    ra2Token
  );
  assert(statusInvalid.status === 400, 'Invalid order status rejected with 400');

  // Configure WhatsApp number on Restaurant B and verify wa.me link generation
  const updateProfileB = await request(
    'PUT',
    '/api/restaurant/profile',
    {
      name: 'Ocean Breeze Cafe',
      whatsappNumber: '+91 98765 43210',
    },
    ra2Token
  );
  assert(updateProfileB.status === 200, 'Restaurant Admin updates WhatsApp number in settings');

  const waOrderRes = await request('POST', '/api/public/orders', {
    restaurantSlug: restBSlug,
    tableNumber: 'W1',
    items: [{ menuItemId: itemBId, quantity: 1 }],
  });
  assert(
    waOrderRes.status === 201 &&
      waOrderRes.body?.whatsappNotification?.whatsappUrl?.startsWith('https://wa.me/919876543210?text='),
    'Order creation generates valid wa.me link when WhatsApp number is configured'
  );

  // ------------------------------------------------------------------
  // 6. Socket.IO Real-Time Room Isolation & Security
  // ------------------------------------------------------------------
  console.log('\n--- 6. Socket.IO Real-Time Isolation & Auth ---');
  await new Promise((resolve) => {
    let socketAEventReceived = false;
    let socketBEventReceived = false;

    const socketA = io(BASE_URL, {
      auth: { token: ra1Token },
      transports: ['websocket'],
    });
    const socketB = io(BASE_URL, {
      auth: { token: ra2Token },
      transports: ['websocket'],
    });

    socketA.on('new_order', () => {
      socketAEventReceived = true;
    });
    socketB.on('new_order', (payload) => {
      if (payload?.order?.restaurantId === restBId) {
        socketBEventReceived = true;
      }
    });

    setTimeout(async () => {
      // Trigger an order for Restaurant B
      await request('POST', '/api/public/orders', {
        restaurantSlug: restBSlug,
        tableNumber: 'SOCK-1',
        items: [{ menuItemId: itemBId, quantity: 1 }],
      });

      setTimeout(() => {
        assert(socketBEventReceived === true, 'Restaurant B socket receives new_order event for Restaurant B');
        assert(socketAEventReceived === false, 'Restaurant A socket does NOT receive Restaurant B new_order event');
        socketA.disconnect();
        socketB.disconnect();
        resolve();
      }, 400);
    }, 400);
  });

  // ------------------------------------------------------------------
  // 7. Inactive Restaurant Admin Login & Public Ordering Block
  // ------------------------------------------------------------------
  console.log('\n--- 7. Inactive Restaurant Enforcement ---');
  const deactivateB = await request(
    'PATCH',
    `/api/admin/restaurants/${restBId}/status`,
    { status: 'INACTIVE' },
    saToken
  );
  assert(deactivateB.status === 200 && deactivateB.body?.restaurant?.isActive === false, 'Super Admin deactivates Restaurant B');

  const inactiveRaLogin = await request('POST', '/api/auth/login', {
    email: restBEmail,
    password: 'Password123!',
  });
  assert(inactiveRaLogin.status === 403, 'Deactivated Restaurant Admin cannot login (403)');

  const inactiveRaMe = await request('GET', '/api/auth/me', null, ra2Token);
  assert(inactiveRaMe.status === 403, 'Existing JWT for deactivated Restaurant Admin is rejected by auth middleware (403)');

  const inactivePublicMenu = await request('GET', `/api/public/menu/${restBSlug}`);
  assert(inactivePublicMenu.status === 404, 'Deactivated restaurant public menu is inaccessible (404)');

  const inactivePublicOrder = await request('POST', '/api/public/orders', {
    restaurantSlug: restBSlug,
    tableNumber: 'B9',
    items: [{ menuItemId: itemBId, quantity: 1 }],
  });
  assert(inactivePublicOrder.status === 403, 'Deactivated restaurant rejects public orders (403)');

  // Reactivate Restaurant B
  await request('PATCH', `/api/admin/restaurants/${restBId}/status`, { status: 'ACTIVE' }, saToken);

  // ------------------------------------------------------------------
  // 8. Error Handling & Malformed JSON Safety
  // ------------------------------------------------------------------
  console.log('\n--- 8. Error Handling & Malformed Payloads ---');
  const malformedRes = await request('POST', '/api/auth/login', '{bad_json:', null);
  assert(malformedRes.status === 400 && malformedRes.body?.success === false, 'Malformed JSON body returns clean 400 JSON error without crashing');

  const unknownRouteRes = await request('GET', '/api/non-existent-endpoint');
  assert(unknownRouteRes.status === 404 && unknownRouteRes.body?.message === 'Route not found', 'Unknown route returns 404 JSON');

  console.log('\n================================================================');
  console.log(`  PHASE 12 AUDIT RESULTS: ${passed} passed, ${failed} failed`);
  console.log('================================================================');
  process.exit(failed > 0 ? 1 : 0);
}

runPhase12Tests().catch((err) => {
  console.error('Unhandled test failure:', err);
  process.exit(1);
});
