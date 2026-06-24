'use strict';

/**
 * SMS service abstraction. Supports MSG91 and Twilio.
 * Falls back to console logging if no provider is configured.
 */

const config = {
  provider: process.env.SMS_PROVIDER || 'console',
  msg91: {
    apiKey: process.env.MSG91_API_KEY || '',
    senderId: process.env.MSG91_SENDER_ID || 'ICMS',
  },
  twilio: {
    accountSid: process.env.TWILIO_ACCOUNT_SID || '',
    authToken: process.env.TWILIO_AUTH_TOKEN || '',
    fromNumber: process.env.TWILIO_FROM_NUMBER || '',
  },
};

/**
 * Send an SMS message.
 * @param {string} to - Phone number (E.164 format preferred)
 * @param {string} message - SMS body
 */
async function sendSms(to, message) {
  const provider = config.provider.toLowerCase();

  if (provider === 'msg91' && config.msg91.apiKey) {
    return sendViaMSG91(to, message);
  }

  if (provider === 'twilio' && config.twilio.accountSid) {
    return sendViaTwilio(to, message);
  }

  // Fallback: log to console (development)
  console.log(`[SMS → ${to}] ${message}`);
  return { success: true, provider: 'console' };
}

async function sendViaMSG91(to, message) {
  try {
    const phone = to.replace(/^\+/, '');
    const url = 'https://control.msg91.com/api/v5/flow/';
    
    // MSG91 transactional SMS via Send OTP API
    const response = await fetch(`https://control.msg91.com/api/v5/otp?template_id=&mobile=${phone}&authkey=${config.msg91.apiKey}&otp_length=6&otp=${message.match(/\d{6}/)?.[0] || ''}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
    });

    if (!response.ok) {
      // Fallback to simple SMS API
      const smsResponse = await fetch('https://api.msg91.com/api/v2/sendsms', {
        method: 'POST',
        headers: {
          'authkey': config.msg91.apiKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          sender: config.msg91.senderId,
          route: '4', // Transactional
          country: '91',
          sms: [{
            message,
            to: [phone],
          }],
        }),
      });
      const result = await smsResponse.json();
      console.log('[MSG91] SMS sent:', result);
      return { success: true, provider: 'msg91' };
    }

    console.log('[MSG91] OTP sent to', phone);
    return { success: true, provider: 'msg91' };
  } catch (err) {
    console.error('[MSG91] Failed:', err.message);
    // Don't throw — log and continue (OTP is still stored)
    console.log(`[SMS Fallback → ${to}] ${message}`);
    return { success: false, provider: 'msg91', error: err.message };
  }
}

async function sendViaTwilio(to, message) {
  try {
    const url = `https://api.twilio.com/2010-04-01/Accounts/${config.twilio.accountSid}/Messages.json`;
    const auth = Buffer.from(`${config.twilio.accountSid}:${config.twilio.authToken}`).toString('base64');

    const body = new URLSearchParams({
      To: to,
      From: config.twilio.fromNumber,
      Body: message,
    });

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${auth}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: body.toString(),
    });

    const result = await response.json();
    if (result.error_code) {
      throw new Error(result.message || 'Twilio error');
    }
    console.log('[Twilio] SMS sent:', result.sid);
    return { success: true, provider: 'twilio', sid: result.sid };
  } catch (err) {
    console.error('[Twilio] Failed:', err.message);
    console.log(`[SMS Fallback → ${to}] ${message}`);
    return { success: false, provider: 'twilio', error: err.message };
  }
}

module.exports = { sendSms };
