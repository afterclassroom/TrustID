# Axiam Widget Integration Requirements

**Date:** November 5, 2025  
**From:** WebClient Development Team  
**To:** Axiam Development Team  
**Subject:** Security & Functionality Requirements for Axiam Facial Login Widget

---

## 🔴 Critical Security Issue

The current Axiam Widget (`AxiamFacialLogin`) submits the authentication form **immediately after user enters email**, WITHOUT waiting for facial verification on Axiam mobile app.

**This creates a major security vulnerability:** Anyone who knows a user's email address can login to their account without any facial verification.

---

## Current vs Expected Behavior

### ❌ Current Widget Behavior (INSECURE)

```
1. User enters email in widget form
2. Widget immediately submits form to formAction URL
3. Backend receives: { public_key, email }
4. User is logged in WITHOUT verification ⚠️ SECURITY BREACH
```

### ✅ Expected Widget Behavior (SECURE)

```
1. User enters email in widget form
2. Widget calls Axiam API to send push notification
3. Widget shows "Waiting for verification..." UI
4. User approves facial verification on Axiam mobile app
5. Widget receives "verified" event via WebSocket/ActionCable
6. Widget submits form to formAction with verification proof
7. Backend validates verification proof
8. User is logged in ✅ SECURE
```

---

## Required Widget Configuration Options

The widget needs to support configuration options to control verification flow:

```javascript
AxiamFacialLogin.init({
  publicKey: 'your_public_key',
  
  // Backend endpoint to receive verified login (REQUIRED)
  formAction: '/facial_sign_on/verified_login',
  
  // REQUIRED: Widget should NOT auto-submit until verification complete
  autoSubmit: false,  // Default should be false for security
  // OR
  requireVerification: true,  // Require facial verification before submission
  
  // OPTIONAL: Backend endpoint to trigger push notification
  // If provided, widget should call this first before Axiam API
  apiEndpoint: '/facial_sign_on/push_notification',
  
  // Container element
  container: '#axiam-facial-login',
  
  // UI customization
  buttonText: 'Login with Face',
  language: 'en',
  
  // REQUIRED: Lifecycle callbacks
  onSubmit: function(data) {
    // Called when user submits email (BEFORE verification)
    // data: { email: "user@example.com" }
    console.log('Email submitted, waiting for verification...');
  },
  
  onPending: function(data) {
    // Called when push notification sent, waiting for user approval
    // Widget should display waiting/pending UI at this stage
    console.log('Push notification sent, waiting for approval...');
  },
  
  onVerified: function(data) {
    // Called when user approves on Axiam app (BEFORE form submit)
    // data: { 
    //   email: "user@example.com",
    //   client_id: "d39220d1-ecd1-4b2f-a0d6-20fe07b300c1",
    //   verified: true,
    //   signature: "...",  // cryptographic proof
    //   timestamp: 1730779200
    // }
    console.log('User verified! Submitting to backend...');
    // Widget should submit form to formAction HERE (not before)
  },
  
  onSuccess: function(data) {
    // Called after successful form submission to formAction
    console.log('Login successful!');
  },
  
  onError: function(error) {
    // Called on any error during the flow
    console.error('Error:', error);
  },
  
  onRejected: function(data) {
    // Called if user rejects verification on Axiam app
    console.log('Verification rejected by user');
  },
  
  onTimeout: function(data) {
    // Called if verification times out
    console.log('Verification timeout');
  }
});
```

---

## Required Form Submission Data

When widget submits form to `formAction` URL (after verification), it **MUST** include the following data:

### Minimum Required Fields

```javascript
{
  email: "user@example.com",
  client_id: "d39220d1-ecd1-4b2f-a0d6-20fe07b300c1",  // User's axiam_uid
  verified: true  // Boolean flag indicating verification complete
}
```

### Recommended Additional Fields (for enhanced security)

```javascript
{
  email: "user@example.com",
  client_id: "d39220d1-ecd1-4b2f-a0d6-20fe07b300c1",
  verified: true,
  signature: "cryptographic_signature_here",  // HMAC or JWT signature
  verification_token: "token_from_axiam_api",
  timestamp: 1730779200,  // Unix timestamp of verification
  nonce: "unique_request_id"  // Prevent replay attacks
}
```

### Current Issue

Currently, the widget only submits:
```javascript
{
  public_key: "4872631159f20096cbc3e068f55dc82e",
  email: "user@example.com"
}
```

**Missing:** `client_id`, `verified` flag, `signature` - making it impossible to validate verification on backend.

---

## Widget Flow Requirements

### Option 1: Widget Handles Axiam API Directly (Recommended)

```
┌─────────┐         ┌────────────┐         ┌──────────┐         ┌────────────┐
│ User    │         │   Widget   │         │  Axiam   │         │  Backend   │
└────┬────┘         └─────┬──────┘         └────┬─────┘         └─────┬──────┘
     │                    │                     │                      │
     │ 1. Enter email     │                     │                      │
     ├───────────────────>│                     │                      │
     │                    │                     │                      │
     │                    │ 2. POST /api/push   │                      │
     │                    ├────────────────────>│                      │
     │                    │                     │                      │
     │                    │ 3. verification_token│                     │
     │                    │<────────────────────┤                      │
     │                    │                     │                      │
     │ 4. "Waiting..." UI │                     │                      │
     │<───────────────────┤                     │                      │
     │                    │                     │                      │
     │                    │ 5. Subscribe WS     │                      │
     │                    ├────────────────────>│                      │
     │                    │                     │                      │
     │ 6. Approve on app  │                     │                      │
     ├────────────────────┼─────────────────────>                      │
     │                    │                     │                      │
     │                    │ 7. "verified" event │                      │
     │                    │<────────────────────┤                      │
     │                    │                     │                      │
     │                    │ 8. POST /verified_login (email, client_id, verified)
     │                    ├──────────────────────────────────────────>│
     │                    │                     │                      │
     │                    │ 9. Login success    │                      │
     │                    │<──────────────────────────────────────────┤
     │                    │                     │                      │
     │ 10. Redirect       │                     │                      │
     │<───────────────────┤                     │                      │
```

### Option 2: Widget Uses Backend API Endpoint

```
┌─────────┐    ┌────────────┐    ┌──────────┐    ┌──────────┐    ┌────────────┐
│ User    │    │   Widget   │    │  Backend │    │  Axiam   │    │ActionCable │
└────┬────┘    └─────┬──────┘    └────┬─────┘    └────┬─────┘    └─────┬──────┘
     │               │                │               │                 │
     │ 1. Enter email│                │               │                 │
     ├──────────────>│                │               │                 │
     │               │                │               │                 │
     │               │ 2. POST /push  │               │                 │
     │               ├───────────────>│               │                 │
     │               │                │               │                 │
     │               │                │ 3. POST Axiam │                 │
     │               │                ├──────────────>│                 │
     │               │                │               │                 │
     │               │                │ 4. token      │                 │
     │               │                │<──────────────┤                 │
     │               │                │               │                 │
     │               │ 5. {success}   │               │                 │
     │               │<───────────────┤               │                 │
     │               │                │               │                 │
     │ 6. "Waiting..." UI             │               │                 │
     │<──────────────┤                │               │                 │
     │               │                │               │                 │
     │               │ 7. Subscribe to verification channel             │
     │               ├──────────────────────────────────────────────────>
     │               │                │               │                 │
     │ 8. Approve    │                │               │                 │
     ├───────────────┼────────────────┼──────────────>│                 │
     │               │                │               │                 │
     │               │                │               │ 9. verified msg │
     │               │                │               ├────────────────>│
     │               │                │               │                 │
     │               │ 10. {status: verified, client_id}                │
     │               │<──────────────────────────────────────────────────
     │               │                │               │                 │
     │               │ 11. POST /verified_login (email, client_id, verified)
     │               ├───────────────>│               │                 │
     │               │                │               │                 │
     │               │ 12. Login OK   │               │                 │
     │               │<───────────────┤               │                 │
     │               │                │               │                 │
     │ 13. Redirect  │                │               │                 │
     │<──────────────┤                │               │                 │
```

---

## Widget UI Requirements

### 1. Initial State
- Display email input field
- Display "Login with Face" button
- Button should be enabled

### 2. After Email Submission (Before Verification)
- Disable email input
- Change button to "Waiting for verification..." with loading spinner
- Display status message: "Push notification sent to your Axiam app. Please approve the login request."
- **DO NOT submit form to formAction yet**

### 3. During Verification Pending
- Show loading/pending UI
- Optional: Display countdown timer (e.g., "Expires in 4:32")
- Optional: Show QR code as alternative verification method
- Allow user to cancel and return to email input

### 4. After Verification Success
- Display "Verified! Logging you in..." message
- Show success animation (optional)
- **NOW submit form to formAction with verification data**

### 5. On Verification Failure/Rejection
- Display error message: "Verification rejected" or "Verification timeout"
- Re-enable form
- Allow user to try again

---

## WebSocket/ActionCable Integration Questions

We need clarification on how the widget receives verification events:

### Questions:

1. **Does the widget connect to Axiam ActionCable/WebSocket server?**
   - If YES, what is the WebSocket URL format?
   - What are the connection credentials required?

2. **What channel does the widget subscribe to?**
   - Channel name format?
   - Subscription parameters?

3. **What is the message format when user verifies?**
   ```javascript
   // Example:
   {
     "status": "verified",
     "client_id": "d39220d1-ecd1-4b2f-a0d6-20fe07b300c1",
     "email": "user@example.com",
     "timestamp": 1730779200,
     "signature": "..."
   }
   ```

4. **How does the widget handle verification rejection or timeout?**
   - What messages are sent?
   - What callbacks are triggered?

---

## Current Widget Implementation Issues

Based on our testing, we've identified these specific issues:

### Issue 1: Immediate Form Submission
**Problem:** Widget submits form to `formAction` immediately after user enters email, without waiting for verification.

**Evidence:**
```
Browser logs show form submission happens instantly:
- User enters email: client@123.com
- Widget submits: { public_key, email }
- No "waiting" or "pending" state
- No verification step
```

**Impact:** Critical security vulnerability - anyone can login with just an email address.

### Issue 2: Missing Verification Data
**Problem:** Widget does not include `client_id` or verification proof in form submission.

**Evidence:**
```
POST /facial_sign_on/verified_login
Parameters: {
  "public_key": "4872631159f20096cbc3e068f55dc82e",
  "email": "client@123.com"
}
```

**Expected:**
```
POST /facial_sign_on/verified_login
Parameters: {
  "public_key": "4872631159f20096cbc3e068f55dc82e",
  "email": "client@123.com",
  "client_id": "d39220d1-ecd1-4b2f-a0d6-20fe07b300c1",
  "verified": true,
  "signature": "cryptographic_proof"
}
```

**Impact:** Backend cannot validate if user actually verified on Axiam app.

### Issue 3: No Callback Support
**Problem:** Widget appears to ignore or not support lifecycle callbacks (`onSubmit`, `onVerified`, `onError`).

**Evidence:**
```javascript
// We configured callbacks but they are never called:
AxiamFacialLogin.init({
  onSubmit: function(data) {
    console.log('Never called');
  },
  onVerified: function(data) {
    console.log('Never called');
  }
});
```

**Impact:** Cannot intercept widget behavior or add custom logic.

### Issue 4: No Pending/Waiting UI
**Problem:** Widget does not show any "waiting for verification" state.

**Evidence:** After email submission, form immediately submits with page reload. No waiting screen, no progress indicator.

**Impact:** Poor user experience, no feedback to user that they need to approve on app.

### Issue 5: Configuration Options Ignored
**Problem:** Widget appears to ignore configuration options like `autoSubmit: false` or `requireVerification: true`.

**Evidence:**
```javascript
AxiamFacialLogin.init({
  autoSubmit: false,  // Ignored - widget still auto-submits
  requireVerification: true,  // Ignored - no verification required
  formAction: '/verified_login'
});
```

**Impact:** Cannot configure widget to behave securely.

---

## Required Widget Updates

### Priority 1: Critical Security Fixes

- [ ] **Stop immediate form submission** - Widget must NOT submit to `formAction` until verification is complete
- [ ] **Include verification proof** - Widget must send `client_id`, `verified` flag, and `signature` in form submission
- [ ] **Implement verification flow** - Widget must wait for user approval on Axiam app before submitting

### Priority 2: Essential Features

- [ ] **Support lifecycle callbacks** - `onSubmit`, `onVerified`, `onError`, `onRejected`, `onTimeout`
- [ ] **Show verification UI** - Display "waiting for approval" state with pending UI
- [ ] **Support configuration options** - Respect `autoSubmit`, `requireVerification`, `apiEndpoint`

### Priority 3: Nice-to-Have Features

- [ ] **Display countdown timer** - Show verification expiry time
- [ ] **QR code fallback** - Alternative verification method
- [ ] **Cancel verification** - Allow user to cancel and retry
- [ ] **Custom styling** - Support CSS customization

---

## Testing Checklist

Please ensure the updated widget passes these tests:

### Functional Tests

- [ ] User enters email → Widget calls Axiam API (NOT form submit)
- [ ] Widget displays "Waiting for verification..." UI
- [ ] User approves on app → Widget receives verified event
- [ ] Widget submits form to `formAction` with `client_id` and `verified: true`
- [ ] Backend receives all required verification data
- [ ] User is logged in successfully

### Security Tests

- [ ] User enters email and does NOT approve on app → Form is NOT submitted
- [ ] User tries to submit form manually → Prevented (no verified proof)
- [ ] Replay attack test → Each verification can only be used once
- [ ] Timeout test → Verification expires after 5 minutes

### Callback Tests

- [ ] `onSubmit` is called when email submitted
- [ ] `onPending` is called when waiting for verification
- [ ] `onVerified` is called when user approves on app
- [ ] `onError` is called on errors
- [ ] `onRejected` is called when user rejects
- [ ] `onTimeout` is called on timeout

### Configuration Tests

- [ ] `autoSubmit: false` → Widget waits for manual trigger
- [ ] `requireVerification: true` → Verification is enforced
- [ ] `apiEndpoint` → Widget calls backend API before Axiam
- [ ] All callbacks work as expected

---

## Example Usage (Expected Final Implementation)

```html
<!-- Load Axiam Widget -->
<script src="https://axiam.io/widget/facial-login.js"></script>
<link rel="stylesheet" href="https://axiam.io/widget/facial-login.css">

<!-- Widget Container -->
<div id="axiam-facial-login"></div>

<script>
document.addEventListener('DOMContentLoaded', function() {
  AxiamFacialLogin.init({
    // Public key for Axiam API
    publicKey: '4872631159f20096cbc3e068f55dc82e',
    
    // Backend endpoint - widget submits here AFTER verification
    formAction: '/facial_sign_on/verified_login',
    
    // Optional: Backend API to trigger push notification
    apiEndpoint: '/facial_sign_on/push_notification',
    
    // Security: Require verification before submission
    requireVerification: true,
    autoSubmit: false,  // Wait for verification
    
    // UI settings
    container: '#axiam-facial-login',
    buttonText: 'Login with Face',
    language: 'en',
    
    // Lifecycle callbacks
    onSubmit: function(data) {
      console.log('Email submitted:', data.email);
      // Widget should now send push notification
    },
    
    onPending: function(data) {
      console.log('Waiting for verification...');
      // Widget should show pending UI
    },
    
    onVerified: function(data) {
      console.log('User verified!', data);
      // data includes: email, client_id, verified, signature
      // Widget should now submit form to formAction
    },
    
    onSuccess: function(data) {
      console.log('Login successful!');
      // Redirect handled by backend
    },
    
    onError: function(error) {
      console.error('Error:', error);
      alert('Login failed: ' + error.message);
    },
    
    onRejected: function(data) {
      console.log('User rejected verification');
      alert('Verification was rejected. Please try again.');
    },
    
    onTimeout: function(data) {
      console.log('Verification timeout');
      alert('Verification timeout. Please try again.');
    }
  });
});
</script>
```

---

## Contact & Support

If you have any questions or need clarification on these requirements, please contact:

- **WebClient Development Team**
- **Email:** [Your contact email]
- **Issue Tracker:** [Your issue tracker URL]

We are available to discuss implementation details, provide testing support, and collaborate on the widget integration.

---

## Timeline

**Requested Delivery:** As soon as possible (CRITICAL security issue)

**Proposed Milestones:**
1. Week 1: Security fixes (stop immediate submission, add verification proof)
2. Week 2: Callback support and verification UI
3. Week 3: Configuration options and testing
4. Week 4: Final integration and production deployment

---

## Appendix: Current Configuration

For reference, here is our current widget configuration (which does not work as expected):

```javascript
AxiamFacialLogin.init({
  publicKey: '4872631159f20096cbc3e068f55dc82e',
  formAction: '/facial_sign_on/verified_login',
  autoSubmit: false,  // IGNORED by widget
  requireVerification: true,  // IGNORED by widget
  container: '#axiam-facial-login',
  buttonText: 'Login with Face',
  language: 'en',
  
  // These callbacks are never called:
  onSubmit: function(data) { console.log('Never called'); },
  onVerified: function(data) { console.log('Never called'); },
  onError: function(error) { console.log('Never called'); }
});
```

**Result:** Widget ignores all configuration and submits form immediately with only `{ public_key, email }`.

---

**Thank you for your attention to these critical security and functionality requirements. We look forward to working with you to resolve these issues and implement a secure facial authentication widget.**
