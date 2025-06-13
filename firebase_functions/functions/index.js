const functions = require('firebase-functions');
const admin = require('firebase-admin');

// تهيئة Firebase Admin SDK
admin.initializeApp();

/**
 * Cloud Function لإرسال الإشعارات عبر FCM
 * يستقبل طلب HTTP POST مع بيانات الإشعار
 */
exports.sendPushNotification = functions.https.onRequest(async (req, res) => {
  // السماح بـ CORS
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(200).send();
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const { userId, title, body, data } = req.body;

    // التحقق من البيانات المطلوبة
    if (!userId || !title || !body) {
      res.status(400).json({ 
        error: 'Missing required fields: userId, title, body' 
      });
      return;
    }

    console.log('📤 Sending notification to user:', userId);
    console.log('📝 Title:', title);
    console.log('📄 Body:', body);
    console.log('📦 Data:', data);

    // الحصول على FCM token للمستخدم من قاعدة البيانات
    const userTokenSnapshot = await admin.database()
      .ref(`users/${userId}/fcmToken`)
      .once('value');

    const fcmToken = userTokenSnapshot.val();

    if (!fcmToken) {
      console.log('❌ No FCM token found for user:', userId);
      res.status(404).json({ 
        error: 'FCM token not found for user',
        userId: userId 
      });
      return;
    }

    console.log('🔑 Found FCM token for user');

    // إعداد رسالة الإشعار
    const message = {
      token: fcmToken,
      notification: {
        title: title,
        body: body,
      },
      data: {
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        userId: userId,
        timestamp: new Date().toISOString(),
        ...data
      },
      android: {
        notification: {
          channel_id: 'road_helper_channel',
          priority: 'high',
          default_sound: true,
          default_vibrate_timings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: title,
              body: body,
            },
            badge: 1,
            sound: 'default',
          },
        },
      },
    };

    // إرسال الإشعار
    const response = await admin.messaging().send(message);
    
    console.log('✅ Notification sent successfully:', response);

    res.status(200).json({
      success: true,
      messageId: response,
      userId: userId,
      timestamp: new Date().toISOString(),
    });

  } catch (error) {
    console.error('❌ Error sending notification:', error);
    
    res.status(500).json({
      success: false,
      error: error.message,
      code: error.code || 'UNKNOWN_ERROR',
    });
  }
});

/**
 * Cloud Function لإرسال إشعار طلب مساعدة
 */
exports.sendHelpRequestNotification = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(200).send();
    return;
  }

  try {
    const { receiverId, senderName, requestId, additionalData } = req.body;

    const result = await exports.sendPushNotification({
      body: {
        userId: receiverId,
        title: 'طلب مساعدة جديد',
        body: `لديك طلب مساعدة جديد من ${senderName}`,
        data: {
          type: 'help_request',
          requestId: requestId,
          senderName: senderName,
          ...additionalData
        }
      }
    }, res);

    return result;

  } catch (error) {
    console.error('❌ Error sending help request notification:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

/**
 * Cloud Function لإرسال إشعار رد على طلب المساعدة
 */
exports.sendHelpResponseNotification = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(200).send();
    return;
  }

  try {
    const { senderId, responderName, requestId, accepted, additionalData } = req.body;

    const title = accepted ? 'تم قبول طلب المساعدة' : 'تم رفض طلب المساعدة';
    const body = accepted 
      ? `تم قبول طلب المساعدة من ${responderName}`
      : `تم رفض طلب المساعدة من ${responderName}`;

    const result = await exports.sendPushNotification({
      body: {
        userId: senderId,
        title: title,
        body: body,
        data: {
          type: 'help_response',
          requestId: requestId,
          responderName: responderName,
          accepted: accepted.toString(),
          ...additionalData
        }
      }
    }, res);

    return result;

  } catch (error) {
    console.error('❌ Error sending help response notification:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

/**
 * Cloud Function لإرسال إشعار رسالة شات
 */
exports.sendChatMessageNotification = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(200).send();
    return;
  }

  try {
    const { receiverId, senderName, messageContent, chatId, additionalData } = req.body;

    const truncatedMessage = messageContent.length > 50 
      ? `${messageContent.substring(0, 50)}...`
      : messageContent;

    const result = await exports.sendPushNotification({
      body: {
        userId: receiverId,
        title: `رسالة جديدة من ${senderName}`,
        body: truncatedMessage,
        data: {
          type: 'chat_message',
          senderName: senderName,
          chatId: chatId,
          messageContent: messageContent,
          ...additionalData
        }
      }
    }, res);

    return result;

  } catch (error) {
    console.error('❌ Error sending chat message notification:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

/**
 * Cloud Function لاختبار الإشعارات
 */
exports.testNotification = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(200).send();
    return;
  }

  try {
    const { userId } = req.body;

    const result = await exports.sendPushNotification({
      body: {
        userId: userId || 'temp_user_449806221',
        title: 'اختبار Firebase Functions',
        body: 'هذا اختبار لإرسال الإشعارات عبر Firebase Functions',
        data: {
          type: 'test',
          source: 'firebase_functions',
          timestamp: new Date().toISOString(),
        }
      }
    }, res);

    return result;

  } catch (error) {
    console.error('❌ Error sending test notification:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});
