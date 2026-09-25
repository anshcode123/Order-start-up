const http = require('http');

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
        resolve({ status: res.statusCode, body: json, raw: data });
      });
    });

    req.on('error', reject);
    if (body) {
      req.write(JSON.stringify(body));
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

async function runTests() {
  console.log('======================================================');
  console.log('  SCANSERVE PHASE 11 — SUBSCRIPTIONS & PLANS SUITE');
  console.log('======================================================\n');

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

  // 1. Login as Super Admin & Restaurant Admin
  const saLogin = await request('POST', '/api/auth/login', {
    email: 'superadmin@scanserve.com',
    password: 'Password123!',
  });
  assert(saLogin.status === 200 && saLogin.body?.token, 'Super Admin login succeeds');
  const saToken = saLogin.body.token;

  const raLogin = await request('POST', '/api/auth/login', {
    email: 'admin@spicegarden.com',
    password: 'Password123!',
  });
  assert(raLogin.status === 200 && raLogin.body?.token, 'Restaurant Admin login succeeds');
  const raToken = raLogin.body.token;
  const restaurantId = raLogin.body.user.restaurantId;

  // 2. Test 1-3: Subscription Plans CRUD
  console.log('\n--- Section 1: Subscription Plans CRUD ---');
  const getPlansRes = await request('GET', '/api/super-admin/plans', null, saToken);
  assert(getPlansRes.status === 200 && Array.isArray(getPlansRes.body?.plans), 'GET /api/super-admin/plans returns plans list');

  const planNames = getPlansRes.body.plans.map((p) => p.name);
  assert(
    planNames.includes('FREE') && planNames.includes('BASIC') && planNames.includes('PRO'),
    'Default plans FREE, BASIC, PRO exist'
  );

  const freePlan = getPlansRes.body.plans.find((p) => p.name === 'FREE');
  const basicPlan = getPlansRes.body.plans.find((p) => p.name === 'BASIC');
  const proPlan = getPlansRes.body.plans.find((p) => p.name === 'PRO');

  assert(freePlan.maxMenuItems === 20 && freePlan.maxCategories === 5, 'FREE plan has maxMenuItems=20, maxCategories=5');
  assert(basicPlan.maxMenuItems === 100 && basicPlan.maxCategories === 15, 'BASIC plan has maxMenuItems=100, maxCategories=15');
  assert(proPlan.maxMenuItems === null && proPlan.maxCategories === null, 'PRO plan has unlimited menuItems and categories');

  // Create custom plan
  const customPlanName = `ENTERPRISE_${Date.now()}`;
  const createPlanRes = await request(
    'POST',
    '/api/super-admin/plans',
    {
      name: customPlanName,
      priceMonthly: 2999,
      maxCategories: 5,
      maxMenuItems: 5,
      whatsappEnabled: true,
      analyticsEnabled: true,
      isActive: true,
    },
    saToken
  );
  assert(createPlanRes.status === 201 && createPlanRes.body?.plan?.id, 'Super Admin can create a subscription plan');
  const customPlanId = createPlanRes.body.plan.id;

  // Update custom plan
  const updatePlanRes = await request(
    'PUT',
    `/api/super-admin/plans/${customPlanId}`,
    {
      priceMonthly: 3499,
      maxMenuItems: 5,
    },
    saToken
  );
  assert(
    updatePlanRes.status === 200 && updatePlanRes.body?.plan?.priceMonthly === '3499',
    'Super Admin can edit a subscription plan'
  );

  // Patch plan status
  const patchPlanRes = await request(
    'PATCH',
    `/api/super-admin/plans/${customPlanId}/status`,
    { isActive: true },
    saToken
  );
  assert(patchPlanRes.status === 200 && patchPlanRes.body?.plan?.isActive === true, 'Super Admin can toggle plan status');

  // 3. Test 18-19: Unauthorized / Role Security
  console.log('\n--- Section 2: Role Protection & Security ---');
  const unauthPlans = await request('GET', '/api/super-admin/plans');
  assert(unauthPlans.status === 401, 'Unauthenticated request to /api/super-admin/plans blocked (401)');

  const raAccessSaPlans = await request('GET', '/api/super-admin/plans', null, raToken);
  assert(raAccessSaPlans.status === 403, 'Restaurant Admin blocked from /api/super-admin/plans (403)');

  const raModifySub = await request(
    'PATCH',
    `/api/super-admin/restaurants/${restaurantId}/subscription`,
    { status: 'ACTIVE', planId: proPlan.id },
    raToken
  );
  assert(raModifySub.status === 403, 'Restaurant Admin cannot modify their own subscription via Super Admin API (403)');

  // 4. Test 4-9: Super Admin Subscription Management
  console.log('\n--- Section 3: Super Admin Subscription Management ---');
  const listSubsRes = await request('GET', '/api/super-admin/subscriptions', null, saToken);
  assert(
    listSubsRes.status === 200 &&
      Array.isArray(listSubsRes.body?.subscriptions) &&
      listSubsRes.body?.summary !== undefined,
    'GET /api/super-admin/subscriptions returns subscriptions and summary stats'
  );

  const getRestSubRes = await request('GET', `/api/super-admin/restaurants/${restaurantId}/subscription`, null, saToken);
  assert(
    getRestSubRes.status === 200 && getRestSubRes.body?.subscription?.restaurantId === restaurantId,
    'GET /api/super-admin/restaurants/:id/subscription returns restaurant subscription'
  );

  // Assign PRO plan & Activate
  const futureEndDate = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
  const assignPlanRes = await request(
    'PATCH',
    `/api/super-admin/restaurants/${restaurantId}/subscription`,
    {
      planId: proPlan.id,
      status: 'ACTIVE',
      startDate: new Date().toISOString(),
      endDate: futureEndDate,
      notes: 'Upgraded to PRO plan',
    },
    saToken
  );
  assert(
    assignPlanRes.status === 200 &&
      assignPlanRes.body?.subscription?.plan?.name === 'PRO' &&
      assignPlanRes.body?.subscription?.status === 'ACTIVE',
    'Super Admin can assign PRO plan and activate subscription'
  );

  // 5. Test 11: Restaurant Admin Subscription View
  console.log('\n--- Section 4: Restaurant Admin Subscription View ---');
  const mySubRes = await request('GET', '/api/restaurant/subscription', null, raToken);
  assert(
    mySubRes.status === 200 &&
      mySubRes.body?.subscription?.plan?.name === 'PRO' &&
      mySubRes.body?.subscription?.usage?.categoriesUsed !== undefined &&
      mySubRes.body?.subscription?.usage?.menuItemsUsed !== undefined,
    'GET /api/restaurant/subscription returns current plan, status, dates, and usage metrics'
  );

  // 6. Test 8, 9, 10, 12, 13, 16: Subscription Expiration, Cancellation, Suspension & Order Blocking
  console.log('\n--- Section 5: Order Placement Enforcement (Expired / Suspended / Cancelled / Active) ---');

  // Fetch public menu to get valid restaurantSlug and menuItemId
  const restDetail = await request('GET', `/api/admin/restaurants/${restaurantId}`, null, saToken);
  const slug = restDetail.body.restaurant.slug;
  const publicMenuRes = await request('GET', `/api/public/menu/${slug}`);
  assert(publicMenuRes.status === 200, 'Public menu loads for active restaurant');

  let testMenuItemId = null;
  for (const cat of publicMenuRes.body.categories || []) {
    if (cat.items && cat.items.length > 0) {
      testMenuItemId = cat.items[0].id;
      break;
    }
  }
  assert(Boolean(testMenuItemId), 'Found available menu item for order testing');

  // Test 12: Active subscription allows order placement
  const activeOrderRes = await request('POST', '/api/public/orders', {
    restaurantSlug: slug,
    tableNumber: 'T-11',
    items: [{ menuItemId: testMenuItemId, quantity: 1 }],
  });
  assert(activeOrderRes.status === 201 && activeOrderRes.body?.order?.id, 'Active subscription allows public order placement');

  // Test 8: Suspend subscription -> blocks order placement
  const suspendRes = await request(
    'PATCH',
    `/api/super-admin/restaurants/${restaurantId}/subscription`,
    { status: 'SUSPENDED' },
    saToken
  );
  assert(suspendRes.status === 200 && suspendRes.body?.subscription?.status === 'SUSPENDED', 'Super Admin can suspend subscription');

  const suspendedOrderRes = await request('POST', '/api/public/orders', {
    restaurantSlug: slug,
    tableNumber: 'T-11',
    items: [{ menuItemId: testMenuItemId, quantity: 1 }],
  });
  assert(
    suspendedOrderRes.status === 403 &&
      suspendedOrderRes.body?.message === 'This restaurant is currently unavailable for online ordering.',
    'Suspended subscription blocks customer order placement with clean message'
  );

  // Test 9: Cancel subscription -> blocks order placement
  const cancelRes = await request(
    'PATCH',
    `/api/super-admin/restaurants/${restaurantId}/subscription`,
    { status: 'CANCELLED' },
    saToken
  );
  assert(cancelRes.status === 200 && cancelRes.body?.subscription?.status === 'CANCELLED', 'Super Admin can cancel subscription');

  const cancelledOrderRes = await request('POST', '/api/public/orders', {
    restaurantSlug: slug,
    tableNumber: 'T-11',
    items: [{ menuItemId: testMenuItemId, quantity: 1 }],
  });
  assert(
    cancelledOrderRes.status === 403 &&
      cancelledOrderRes.body?.message === 'This restaurant is currently unavailable for online ordering.',
    'Cancelled subscription blocks customer order placement'
  );

  // Test 10 & 13: Automatic Expiration Detection when endDate < now
  const pastDate = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  await request(
    'PATCH',
    `/api/super-admin/restaurants/${restaurantId}/subscription`,
    {
      status: 'ACTIVE',
      endDate: pastDate,
    },
    saToken
  );

  const expiredOrderRes = await request('POST', '/api/public/orders', {
    restaurantSlug: slug,
    tableNumber: 'T-11',
    items: [{ menuItemId: testMenuItemId, quantity: 1 }],
  });
  assert(
    expiredOrderRes.status === 403 &&
      expiredOrderRes.body?.message === 'This restaurant is currently unavailable for online ordering.',
    'Past endDate automatically marks subscription EXPIRED and blocks public ordering'
  );

  const verifyExpiredStatus = await request('GET', '/api/restaurant/subscription', null, raToken);
  assert(
    verifyExpiredStatus.body?.subscription?.status === 'EXPIRED',
    'Subscription status in DB automatically transitioned to EXPIRED'
  );

  // Test 7: Extend subscription -> restores ACTIVE status and ordering
  const extendRes = await request(
    'PATCH',
    `/api/super-admin/restaurants/${restaurantId}/subscription`,
    {
      status: 'ACTIVE',
      endDate: futureEndDate,
    },
    saToken
  );
  assert(
    extendRes.status === 200 && extendRes.body?.subscription?.status === 'ACTIVE',
    'Super Admin can extend subscription endDate and reactivate'
  );

  // 7. Test 14, 15, 17 & Section 21 Scenario: Plan Limit Enforcement
  console.log('\n--- Section 6: Plan Limits & Section 21 Scenario (Max 5 Items -> 6th Blocked -> Upgrade to PRO -> 6th Allowed) ---');

  // Create a brand new restaurant to test default TRIAL subscription + exact 5-item scenario cleanly
  const testRestEmail = `limit_test_${Date.now()}@scanserve.com`;
  const createRestRes = await request(
    'POST',
    '/api/admin/restaurants',
    {
      name: 'Limit Test Bistro',
      phone: '9876543210',
      email: testRestEmail,
      address: '100 SaaS Way',
      adminName: 'Limit Admin',
      adminEmail: testRestEmail,
      adminPassword: 'Password123!',
    },
    saToken
  );
  assert(createRestRes.status === 201 && createRestRes.body?.restaurant?.id, 'Created new restaurant for limit testing');
  const newRestId = createRestRes.body.restaurant.id;

  // Verify default TRIAL subscription was automatically created (Section 4)
  const newRestSubRes = await request('GET', `/api/super-admin/restaurants/${newRestId}/subscription`, null, saToken);
  assert(
    newRestSubRes.status === 200 &&
      newRestSubRes.body?.subscription?.status === 'TRIAL' &&
      newRestSubRes.body?.subscription?.plan?.name === 'FREE',
    'New restaurant automatically receives FREE plan with TRIAL status (14 days)'
  );

  // Login as the new restaurant admin
  const newRaLogin = await request('POST', '/api/auth/login', {
    email: testRestEmail,
    password: 'Password123!',
  });
  const newRaToken = newRaLogin.body.token;

  // Assign our custom plan with maxCategories = 1, maxMenuItems = 5
  await request(
    'PUT',
    `/api/super-admin/plans/${customPlanId}`,
    { maxCategories: 1, maxMenuItems: 5 },
    saToken
  );
  await request(
    'PATCH',
    `/api/super-admin/restaurants/${newRestId}/subscription`,
    { planId: customPlanId, status: 'ACTIVE', endDate: futureEndDate },
    saToken
  );

  // Create 1st category -> should succeed
  const cat1Res = await request('POST', '/api/categories', { name: 'Starters' }, newRaToken);
  assert(cat1Res.status === 201 && cat1Res.body?.category?.id, '1st category created within plan limit (1/1)');
  const cat1Id = cat1Res.body.category.id;

  // Create 2nd category -> should be blocked (maxCategories = 1)
  const cat2Res = await request('POST', '/api/categories', { name: 'Mains' }, newRaToken);
  assert(
    cat2Res.status === 403 &&
      cat2Res.body?.message === 'You have reached the maximum number of categories for your current plan.',
    '2nd category blocked with exact message when maxCategories limit reached'
  );

  // Create 5 menu items -> all 5 should succeed
  let createdItemsCount = 0;
  for (let i = 1; i <= 5; i++) {
    const itemRes = await request(
      'POST',
      '/api/menu',
      {
        name: `Test Dish ${i}`,
        price: '150',
        categoryId: cat1Id,
        isAvailable: true,
      },
      newRaToken
    );
    if (itemRes.status === 201) createdItemsCount++;
  }
  assert(createdItemsCount === 5, 'Created 5 menu items successfully on 5-item limit plan');

  // Attempt 6th menu item -> must fail with exact message
  const item6BlockedRes = await request(
    'POST',
    '/api/menu',
    {
      name: 'Test Dish 6',
      price: '180',
      categoryId: cat1Id,
      isAvailable: true,
    },
    newRaToken
  );
  assert(
    item6BlockedRes.status === 403 &&
      item6BlockedRes.body?.message === 'You have reached the maximum number of menu items for your current plan.',
    '6th menu item blocked with exact message when maxMenuItems=5 limit reached'
  );

  // Super Admin upgrades restaurant to PRO plan (unlimited)
  const upgradeToProRes = await request(
    'PATCH',
    `/api/super-admin/restaurants/${newRestId}/subscription`,
    { planId: proPlan.id, status: 'ACTIVE' },
    saToken
  );
  assert(upgradeToProRes.status === 200 && upgradeToProRes.body?.subscription?.plan?.name === 'PRO', 'Super Admin upgrades restaurant to PRO plan');

  // Attempt 6th menu item again -> must succeed now!
  const item6AllowedRes = await request(
    'POST',
    '/api/menu',
    {
      name: 'Test Dish 6 (After PRO Upgrade)',
      price: '180',
      categoryId: cat1Id,
      isAvailable: true,
    },
    newRaToken
  );
  assert(item6AllowedRes.status === 201 && item6AllowedRes.body?.menuItem?.id, '6th menu item creation succeeds after upgrading to PRO plan');

  // Attempt 2nd category again -> must succeed now!
  const cat2AllowedRes = await request('POST', '/api/categories', { name: 'Mains' }, newRaToken);
  assert(cat2AllowedRes.status === 201 && cat2AllowedRes.body?.category?.id, '2nd category creation succeeds after upgrading to PRO plan');

  console.log('\n======================================================');
  console.log(`  RESULTS: ${passed} passed, ${failed} failed`);
  console.log('======================================================');
  process.exit(failed > 0 ? 1 : 0);
}

runTests().catch((err) => {
  console.error('Unhandled test error:', err);
  process.exit(1);
});
