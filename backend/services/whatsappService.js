/**
 * Short label for display only ("Order #A8F2") derived from publicToken.
 */
function deriveOrderNumber(publicToken) {
  return publicToken ? publicToken.slice(0, 4).toUpperCase() : '----';
}

/**
 * Normalizes phone numbers to digits only for WhatsApp Cloud API (E.164 format without '+').
 * E.g. "+91 98765-43210" -> "919876543210"
 */
function normalizePhoneNumber(rawNumber) {
  if (!rawNumber || typeof rawNumber !== 'string') return '';
  return rawNumber.replace(/\D/g, '');
}

/**
 * Formats the order notification message text per Phase 8 specification:
 *
 * ScanServe
 * New Order
 *
 * Order reference:
 * #XXXX
 *
 * Restaurant:
 * <Restaurant Name>
 *
 * Table:
 * <Table Number>
 *
 * Items:
 *
 * <Item Name> × <Quantity>
 * ₹<Subtotal>
 *
 * Total:
 * ₹<Total Amount>
 *
 * Status:
 * PENDING
 */
function formatOrderMessage({ order, restaurantName }) {
  const orderRef = `#${deriveOrderNumber(order.publicToken)}`;

  const itemsLines = (order.items || [])
    .map((item) => `${item.itemName} × ${item.quantity}\n₹${item.subtotal}`)
    .join('\n\n');

  return [
    'ScanServe',
    'New Order',
    '',
    'Order reference:',
    orderRef,
    '',
    'Restaurant:',
    restaurantName || 'ScanServe Partner',
    '',
    'Table:',
    order.tableNumber,
    '',
    'Items:',
    '',
    itemsLines,
    '',
    'Total:',
    `₹${order.totalAmount}`,
    '',
    'Status:',
    order.status || 'PENDING',
  ].join('\n');
}

/**
 * Sends a WhatsApp order notification to the restaurant's configured WhatsApp number.
 *
 * Responsibilities:
 * - Formats order details strictly per spec.
 * - Checks environment credentials (WHATSAPP_ACCESS_TOKEN, WHATSAPP_PHONE_NUMBER_ID).
 * - Operates safely in Development Mode when credentials are not configured.
 * - Uses Meta's WhatsApp Cloud API.
 * - Isolates errors so order creation in PostgreSQL never fails or rolls back because of WhatsApp.
 * - Never logs or exposes access tokens.
 */
async function sendOrderNotification({ order, restaurant }) {
  const orderRef = deriveOrderNumber(order.publicToken);

  try {
    const accessToken = process.env.WHATSAPP_ACCESS_TOKEN;
    const phoneNumberId = process.env.WHATSAPP_PHONE_NUMBER_ID;

    // 1. Dev Mode check - missing WhatsApp Cloud API credentials
    if (!accessToken || !phoneNumberId) {
      console.log(
        `[WhatsApp Dev Mode] Credentials not configured. Skipping WhatsApp notification for order #${orderRef}.`
      );
      return { sent: false, reason: 'DEV_MODE_NO_CREDENTIALS' };
    }

    // 2. Destination phone number check
    const rawNumber = restaurant.whatsappNumber || restaurant.phone;
    const cleanNumber = normalizePhoneNumber(rawNumber);

    if (!cleanNumber) {
      console.log(
        `[WhatsApp] Restaurant "${restaurant.name || order.restaurantId}" has no WhatsApp number configured. Skipping notification for order #${orderRef}.`
      );
      return { sent: false, reason: 'NO_WHATSAPP_NUMBER' };
    }

    const messageText = formatOrderMessage({
      order,
      restaurantName: restaurant.name,
    });

    const apiUrl = `https://graph.facebook.com/v19.0/${phoneNumberId}/messages`;

    const response = await fetch(apiUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        messaging_product: 'whatsapp',
        recipient_type: 'individual',
        to: cleanNumber,
        type: 'text',
        text: {
          preview_url: false,
          body: messageText,
        },
      }),
    });

    const responseData = await response.json();

    if (!response.ok) {
      const errorMsg =
        responseData && responseData.error && responseData.error.message
          ? responseData.error.message
          : `HTTP ${response.status}`;
      console.error(`[WhatsApp] Failed to send notification for order #${orderRef}: ${errorMsg}`);
      return { sent: false, error: errorMsg };
    }

    console.log(`[WhatsApp] Notification sent successfully for order #${orderRef} to ${cleanNumber}.`);
    return { sent: true, messageId: responseData?.messages?.[0]?.id };
  } catch (err) {
    // Isolated error handling: log safe error message without token leakage
    console.error(
      `[WhatsApp] Unexpected error sending notification for order #${orderRef}:`,
      err.message || 'Unknown error'
    );
    return { sent: false, error: err.message };
  }
}

module.exports = {
  normalizePhoneNumber,
  formatOrderMessage,
  sendOrderNotification,
};
