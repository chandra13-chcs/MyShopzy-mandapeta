const GRAPH_API_VERSION = 'v25.0';

class OtpDeliveryError extends Error {
  constructor() {
    super('WhatsApp did not accept the OTP message.');
    this.name = 'OtpDeliveryError';
  }
}

function createWhatsAppOtpProvider({
  config,
  fetchImpl = fetch,
  timeoutMs = 10_000,
}) {
  return {
    async send({ phoneNumber, otp }) {
      const whatsapp = config.whatsapp;
      if (
        !whatsapp ||
        typeof whatsapp.accessToken !== 'string' ||
        !whatsapp.accessToken ||
        typeof whatsapp.phoneNumberId !== 'string' ||
        !whatsapp.phoneNumberId ||
        typeof whatsapp.templateName !== 'string' ||
        !whatsapp.templateName ||
        typeof whatsapp.templateLanguage !== 'string' ||
        !whatsapp.templateLanguage
      ) {
        throw new OtpDeliveryError();
      }

      let response;
      let result;
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), timeoutMs);
      try {
        response = await fetchImpl(
          `https://graph.facebook.com/${whatsapp.graphApiVersion || GRAPH_API_VERSION}/${encodeURIComponent(whatsapp.phoneNumberId)}/messages`,
          {
            method: 'POST',
            headers: {
              Authorization: `Bearer ${whatsapp.accessToken}`,
              'Content-Type': 'application/json',
            },
            signal: controller.signal,
            body: JSON.stringify({
              messaging_product: 'whatsapp',
              recipient_type: 'individual',
              to: phoneNumber,
              type: 'template',
              template: {
                name: whatsapp.templateName,
                language: { code: whatsapp.templateLanguage },
                components: [
                  {
                    type: 'body',
                    parameters: [{ type: 'text', text: otp }],
                  },
                  {
                    type: 'button',
                    sub_type: 'url',
                    index: '0',
                    parameters: [{ type: 'text', text: otp }],
                  },
                ],
              },
            }),
          },
        );
        result = await response.json();
      } catch (_) {
        throw new OtpDeliveryError();
      } finally {
        clearTimeout(timeout);
      }
      const messageId = result?.messages?.[0]?.id;
      if (
        !response.ok ||
        typeof messageId !== 'string' ||
        !messageId.startsWith('wamid.')
      ) {
        throw new OtpDeliveryError();
      }
      return messageId;
    },
  };
}

module.exports = { createWhatsAppOtpProvider, OtpDeliveryError };
