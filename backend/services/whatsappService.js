function deriveOrderNumber(publicToken) {
  return publicToken ? publicToken.slice(0, 4).toUpperCase() : '----';
}

function normalizePhoneNumber(rawNumber) {
  if (!rawNumber || typeof rawNumber !== 'string') return '';
  return rawNumber.replace(/\D/g, '');
}

function formatOrderMessage({ order, restaurantName }) {
  const orderRef = `#${deriveOrderNumber(order.publicToken)}`;
  const diningLabel = order.diningType === 'TAKEAWAY' ? 'Takeaway' : 'Dine In';

  const itemsLines = (order.items || [])
    .map((item) => {
      const displayName = item.variantName
        ? `${item.itemName} (${item.variantName})`
        : item.itemName;
      return `${displayName} × ${item.quantity} — ₹${item.subtotal}`;
    })
    .join('\n');

  const lines = [
    'ScanServe',
    'New Order',
    '',
    'Order reference:',
    orderRef,
    '',
    'Restaurant:',
    restaurantName || 'ScanServe Partner',
    '',
    'Dining Type:',
    diningLabel,
  ];

  if (order.tableNumber && String(order.tableNumber).trim() !== '') {
    lines.push('', 'Table:', String(order.tableNumber).trim());
  }

  lines.push(
    '',
    'Items:',
    itemsLines,
    '',
    'Total:',
    `₹${order.totalAmount}`,
    '',
    'Status:',
    order.status || 'PENDING'
  );

  return lines.join('\n');
}

async function sendOrderNotification({ order, restaurant }) {
  const orderRef = deriveOrderNumber(order.publicToken);

  try {
    const accessToken = process.env.WHATSAPP_ACCESS_TOKEN;
    const phoneNumberId = process.env.WHATSAPP_PHONE_NUMBER_ID;

    if (!accessToken || !phoneNumberId) {
      console.log(
        `[WhatsApp Dev Mode] Credentials not configured. Skipping WhatsApp notification for order #${orderRef}.`
      );
      return { sent: false, reason: 'DEV_MODE_NO_CREDENTIALS' };
    }

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
        Authorization: `Bearer ${accessToken}`,
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
