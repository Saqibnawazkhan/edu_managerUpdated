# Subscription System Setup Guide

## How the Subscription System Works

### 1. Payment Flow
1. User fills payment form and submits
2. Payment request saved to `payment_requests` collection in Firestore
3. User sends payment details via WhatsApp

### 2. Admin Activation (Manual)
When you verify a payment, you need to activate the subscription in Firestore.

**Option A: Firebase Console (Manual)**
1. Go to Firebase Console > Firestore
2. Create a new document in `subscriptions` collection:
```json
{
  "userId": "<user's UID from Firebase Auth>",
  "userEmail": "user@email.com",
  "package": "Monthly",  // or "Yearly" or "Lifetime"
  "amount": 500,
  "startDate": <server timestamp>,
  "expiryDate": <calculated date>,  // null for Lifetime
  "status": "active",
  "paymentMethod": "JazzCash",
  "transactionId": "TXN123456"
}
```

**Expiry Date Calculation:**
- Monthly: startDate + 30 days
- Yearly: startDate + 365 days
- Lifetime: null (never expires)

### 3. Automatic Expiry Notifications

#### Option A: Firebase Cloud Functions (Recommended)

Create a scheduled function to check for expiring subscriptions daily.

**Setup Firebase Functions:**
```bash
cd your-project
firebase init functions
cd functions
npm install
```

**functions/index.js:**
```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Run daily at 9 AM
exports.checkExpiringSubscriptions = functions.pubsub
  .schedule('0 9 * * *')
  .timeZone('Asia/Karachi')
  .onRun(async (context) => {
    const db = admin.firestore();
    const now = new Date();

    // Check for subscriptions expiring in 3 days
    const threeDaysFromNow = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);
    const oneDayFromNow = new Date(now.getTime() + 1 * 24 * 60 * 60 * 1000);

    // Get subscriptions expiring soon
    const expiringSnapshot = await db.collection('subscriptions')
      .where('status', '==', 'active')
      .where('expiryDate', '<=', threeDaysFromNow)
      .where('expiryDate', '>', now)
      .get();

    for (const doc of expiringSnapshot.docs) {
      const sub = doc.data();
      const expiryDate = sub.expiryDate.toDate();
      const daysLeft = Math.ceil((expiryDate - now) / (1000 * 60 * 60 * 24));

      // Save notification to Firestore
      await db.collection('notifications').add({
        userId: sub.userId,
        userEmail: sub.userEmail,
        type: 'subscription_expiring',
        title: 'Subscription Expiring Soon',
        message: `Your ${sub.package} subscription expires in ${daysLeft} day(s). Renew now to avoid interruption.`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        read: false,
      });

      // Optional: Send push notification via FCM
      // Optional: Send email via SendGrid/Mailgun
    }

    // Check for expired subscriptions and mark them
    const expiredSnapshot = await db.collection('subscriptions')
      .where('status', '==', 'active')
      .where('expiryDate', '<=', now)
      .get();

    for (const doc of expiredSnapshot.docs) {
      await doc.ref.update({
        status: 'expired',
        expiredAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const sub = doc.data();
      await db.collection('notifications').add({
        userId: sub.userId,
        userEmail: sub.userEmail,
        type: 'subscription_expired',
        title: 'Subscription Expired',
        message: `Your ${sub.package} subscription has expired. Please renew to continue using Edu Manager.`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        read: false,
      });
    }

    console.log(`Processed ${expiringSnapshot.size} expiring and ${expiredSnapshot.size} expired subscriptions`);
    return null;
  });

// Send WhatsApp reminder (requires Twilio or similar)
exports.sendWhatsAppReminder = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notification = snap.data();

    // You can integrate Twilio WhatsApp API here
    // Or use any other WhatsApp Business API

    console.log(`Would send WhatsApp to: ${notification.userEmail}`);
    return null;
  });
```

**Deploy:**
```bash
firebase deploy --only functions
```

#### Option B: In-App Check (Already Implemented)

The app already checks subscription status when user opens the app:
- Shows warning banner if expiring in 3 days or less
- Shows error banner if expired
- User can tap to renew

### 4. Firestore Security Rules

Add these rules to protect subscription data:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Subscriptions - only readable by the user
    match /subscriptions/{subscriptionId} {
      allow read: if request.auth != null &&
                  resource.data.userId == request.auth.uid;
      allow write: if false; // Only admin can write
    }

    // Payment requests - user can create, only admin can read
    match /payment_requests/{requestId} {
      allow create: if request.auth != null || true; // Allow unauthenticated for new users
      allow read: if false; // Only admin reads via console
    }

    // Notifications - user can read their own
    match /notifications/{notificationId} {
      allow read: if request.auth != null &&
                  resource.data.userId == request.auth.uid;
      allow update: if request.auth != null &&
                   resource.data.userId == request.auth.uid &&
                   request.resource.data.diff(resource.data).affectedKeys().hasOnly(['read']);
    }
  }
}
```

### 5. Admin Panel (Future Enhancement)

Consider building a simple admin panel to:
- View payment requests
- Activate subscriptions with one click
- View all users and their subscription status
- Send manual notifications

### 6. WhatsApp Business API Integration (Optional)

For automated WhatsApp notifications:
1. Apply for WhatsApp Business API (via Twilio, MessageBird, etc.)
2. Create message templates for subscription reminders
3. Integrate in Cloud Functions

**Twilio WhatsApp Example:**
```javascript
const twilio = require('twilio');
const client = twilio(accountSid, authToken);

await client.messages.create({
  from: 'whatsapp:+14155238886',
  to: `whatsapp:+${userPhone}`,
  body: `Your Edu Manager subscription expires in ${daysLeft} days. Renew now!`
});
```

## Summary

| Notification Type | Method | Timing |
|------------------|--------|--------|
| 3 days before expiry | In-app banner + Firebase notification | Daily check |
| 1 day before expiry | In-app banner + Firebase notification | Daily check |
| On expiry day | In-app banner + Firebase notification | Daily check |
| After expiry | Block app access + In-app banner | On app open |

The system is now set up to:
1. Track subscriptions with expiry dates
2. Show warnings in the app
3. Allow easy renewal via payment screen
