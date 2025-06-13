const functions = require('firebase-functions');
const admin = require('firebase-admin');

// تهيئة Firebase Admin SDK
admin.initializeApp();

/**
 * Firebase Function لإرسال Push Notifications
 * يستخدم Firebase Admin SDK بدلاً من FCM Server Key
 */
exports.sendNotification = functions.https.onRequest(async (req, res) => {
  // تفعيل CORS
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  // التعامل مع OPTIONS request
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  // التأكد من أن الطلب POST
  if (req.method !== 'POST') {
    res.status(405).json({ success: false, error: 'Method not allowed' });
    return;
  }

  try {
    console.log('🔔 Firebase Function: Received notification request');
    console.log('📦 Request body:', JSON.stringify(req.body, null, 2));

    const { token, title, body, data, android, apns } = req.body;

    // التحقق من البيانات المطلوبة
    if (!token || !title || !body) {
      console.log('❌ Missing required fields');
      res.status(400).json({ 
        success: false, 
        error: 'Missing required fields: token, title, body' 
      });
      return;
    }

    // إعداد رسالة الإشعار
    const message = {
      token: token,
      notification: {
        title: title,
        body: body,
      },
      data: data || {},
      android: android || {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'road_helper_notifications',
          priority: 'high',
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: apns || {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
            contentAvailable: 1,
          },
        },
      },
    };

    console.log('🚀 Sending notification via Firebase Admin SDK...');
    console.log('📱 Target token:', token.substring(0, 20) + '...');

    // إرسال الإشعار
    const response = await admin.messaging().send(message);
    
    console.log('✅ Notification sent successfully:', response);

    // حفظ الإشعار في قاعدة البيانات للتتبع
    await saveNotificationLog(token, title, body, data, response);

    res.status(200).json({ 
      success: true, 
      messageId: response,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('❌ Error sending notification:', error);
    
    res.status(500).json({ 
      success: false, 
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

/**
 * Firebase Function لإرسال إشعارات متعددة
 */
exports.sendMultipleNotifications = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ success: false, error: 'Method not allowed' });
    return;
  }

  try {
    console.log('🔔 Firebase Function: Received multiple notifications request');

    const { notifications } = req.body;

    if (!notifications || !Array.isArray(notifications)) {
      res.status(400).json({ 
        success: false, 
        error: 'notifications array is required' 
      });
      return;
    }

    const results = [];

    for (const notification of notifications) {
      try {
        const { token, title, body, data } = notification;

        if (!token || !title || !body) {
          results.push({ success: false, error: 'Missing required fields' });
          continue;
        }

        const message = {
          token: token,
          notification: { title, body },
          data: data || {},
        };

        const response = await admin.messaging().send(message);
        results.push({ success: true, messageId: response });

      } catch (error) {
        console.error('❌ Error sending individual notification:', error);
        results.push({ success: false, error: error.message });
      }
    }

    res.status(200).json({ 
      success: true, 
      results: results,
      total: notifications.length,
      successful: results.filter(r => r.success).length,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('❌ Error sending multiple notifications:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * اختبار الاتصال
 */
exports.testConnection = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  console.log('🧪 Firebase Function: Connection test');

  res.status(200).json({ 
    success: true, 
    message: 'Firebase Functions is working!',
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  });
});

/**
 * حفظ سجل الإشعارات
 */
async function saveNotificationLog(token, title, body, data, messageId) {
  try {
    const logRef = admin.database().ref('notification_logs').push();
    
    await logRef.set({
      token: token.substring(0, 20) + '...', // إخفاء جزء من التوكن للأمان
      title: title,
      body: body,
      data: data,
      messageId: messageId,
      timestamp: admin.database.ServerValue.TIMESTAMP,
      createdAt: new Date().toISOString(),
    });

    console.log('📝 Notification log saved successfully');
  } catch (error) {
    console.error('❌ Error saving notification log:', error);
  }
}

/**
 * Firebase Function لإرسال إشعار طلب مساعدة
 */
exports.sendHelpRequestNotification = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ success: false, error: 'Method not allowed' });
    return;
  }

  try {
    const { receiverToken, senderName, requestId, additionalData } = req.body;

    if (!receiverToken || !senderName || !requestId) {
      res.status(400).json({ 
        success: false, 
        error: 'Missing required fields: receiverToken, senderName, requestId' 
      });
      return;
    }

    const message = {
      token: receiverToken,
      notification: {
        title: 'طلب مساعدة جديد',
        body: `لديك طلب مساعدة جديد من ${senderName}`,
      },
      data: {
        type: 'help_request',
        requestId: requestId,
        senderName: senderName,
        ...additionalData,
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'help_requests',
          priority: 'high',
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
    };

    const response = await admin.messaging().send(message);
    
    console.log('✅ Help request notification sent:', response);

    res.status(200).json({ 
      success: true, 
      messageId: response,
      type: 'help_request',
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('❌ Error sending help request notification:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * Firebase Function لإرسال إشعار رسالة شات
 */
exports.sendChatMessageNotification = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ success: false, error: 'Method not allowed' });
    return;
  }

  try {
    const { receiverToken, senderName, messageContent, chatId } = req.body;

    if (!receiverToken || !senderName || !messageContent) {
      res.status(400).json({ 
        success: false, 
        error: 'Missing required fields: receiverToken, senderName, messageContent' 
      });
      return;
    }

    const message = {
      token: receiverToken,
      notification: {
        title: `رسالة جديدة من ${senderName}`,
        body: messageContent.length > 50 
          ? messageContent.substring(0, 50) + '...' 
          : messageContent,
      },
      data: {
        type: 'chat_message',
        senderName: senderName,
        chatId: chatId || '',
        messageContent: messageContent,
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'chat_messages',
          priority: 'high',
        },
      },
    };

    const response = await admin.messaging().send(message);
    
    console.log('✅ Chat message notification sent:', response);

    res.status(200).json({ 
      success: true, 
      messageId: response,
      type: 'chat_message',
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('❌ Error sending chat message notification:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});
