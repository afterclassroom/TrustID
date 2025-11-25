# Request to Axiam Team: Improve Error Handling in Facial Login Widget

**Date:** November 9, 2025  
**Priority:** Medium  
**Component:** `facial-login.js` (Widget v2.0)  
**Issue:** Generic error messages don't show API `user_message`

---

## 🐛 Current Problem

When the push notification API fails (500 error), the widget shows a generic error:
```
"Failed to send push notification. Please try again."
```

**Code location:** `facial-login.js:373`
```javascript
// Current implementation
throw new Error('Something went wrong. Please try again later.');
```

**Console error:**
```
[Axiam Widget] Error sending push notification: Error: Something went wrong. Please try again later.
```

**Actual API Response** (not being used):
```json
{
  "success": false,
  "error": "device_not_registered",
  "user_message": "Please register your device first by scanning the QR code in your account settings."
}
```

---

## 📋 What We Need

### 1. Display `user_message` from API Response

Update error handling to extract and show the API's `user_message` field:

```javascript
// facial-login.js - sendPushNotification() method (line ~373)
async sendPushNotification(email) {
  try {
    const response = await fetch('/api/v1/facial_sign_on/client/send_push', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.authToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ email })
    });
    
    const data = await response.json();
    
    if (!response.ok) {
      // ✅ UPDATED: Extract user_message from API response
      const errorMessage = data.user_message || 
                          data.error || 
                          data.message ||
                          'Something went wrong. Please try again later.';
      throw new Error(errorMessage);
    }
    
    return data;
  } catch (error) {
    console.error('[Axiam Widget] Error sending push notification:', error);
    throw error;
  }
}
```

**Apply same pattern to all API calls in widget:**
- `sendVerificationCode()`
- `verifyCode()`
- `checkVerificationStatus()`

---

### 2. Add `onError` Callback to Widget Config (Optional but Recommended)

Allow webclient to customize error handling:

```javascript
// Widget initialization with error callback
AxiamFacialLogin.init({
  publicKey: 'xxx',
  authToken: 'yyy',
  formAction: '/facial_sign_on/verified_login',
  // ... other config
  
  // ✅ NEW: Error callback
  onError: (error, context) => {
    // context can be: 'push_notification', 'verification', 'api_error', etc.
    console.error(`[Widget Error - ${context}]:`, error.message);
    
    // Webclient can show custom error UI
    showCustomErrorModal(error.message);
  },
  
  // ✅ NEW: Success callback
  onSuccess: (data) => {
    console.log('[Widget Success]:', data);
  }
});
```

**Widget should call `onError` when:**
- API request fails
- Verification timeout
- User cancels verification
- Network error
- Invalid configuration

---

## 🎯 Expected API Response Format

Please ensure all API endpoints return consistent error format:

```json
{
  "success": false,
  "error": "technical_error_code",
  "user_message": "User-friendly error message in plain language",
  "details": {
    "field": "email",
    "reason": "not_found"
  }
}
```

### Examples of Good Error Messages

**1. User not found:**
```json
{
  "success": false,
  "error": "user_not_found",
  "user_message": "No account found with this email address. Please register first."
}
```

**2. Device not registered:**
```json
{
  "success": false,
  "error": "device_not_registered", 
  "user_message": "Please register your device first by scanning the QR code in your account settings."
}
```

**3. Service temporarily unavailable:**
```json
{
  "success": false,
  "error": "service_unavailable",
  "user_message": "Facial sign-in service is temporarily unavailable. Please use password login."
}
```

**4. Too many attempts:**
```json
{
  "success": false,
  "error": "rate_limit_exceeded",
  "user_message": "Too many sign-in attempts. Please try again in 5 minutes."
}
```

**5. Verification expired:**
```json
{
  "success": false,
  "error": "verification_expired",
  "user_message": "Verification code has expired. Please request a new one."
}
```

---

## ✅ Benefits

1. **Better UX** - Users see actionable error messages instead of generic "something went wrong"
2. **Easier debugging** - Clear error messages help users self-diagnose issues
3. **Flexibility** - Webclient can customize error handling via `onError` callback
4. **Consistency** - All errors follow the same format across all APIs
5. **Reduced support tickets** - Users understand what went wrong and how to fix it

---

## 📦 Files to Update

1. **`facial-login.js`** - Main widget file
   - Update error handling in all API methods
   - Add `onError` and `onSuccess` callbacks
   
2. **Widget Documentation** - Add examples:
   - `onError` callback usage
   - List of possible error codes
   - Recommended error handling patterns

3. **API Documentation** - Document error response format:
   - Standard error structure
   - List of error codes with `user_message` examples

---

## 🧪 Test Cases

Please test these scenarios return proper `user_message`:

| Scenario | Error Code | Expected `user_message` |
|----------|-----------|------------------------|
| Email not found | `user_not_found` | "No account found with this email address. Please register first." |
| Device not registered | `device_not_registered` | "Please register your device first by scanning the QR code in your account settings." |
| Push service down | `service_unavailable` | "Facial sign-in service is temporarily unavailable. Please use password login." |
| Network timeout | `network_error` | "Network connection failed. Please check your internet connection." |
| Invalid auth token | `invalid_token` | "Session expired. Please refresh the page and try again." |
| Rate limit exceeded | `rate_limit_exceeded` | "Too many sign-in attempts. Please try again in 5 minutes." |
| Verification expired | `verification_expired` | "Verification code has expired. Please request a new one." |

---

## 📸 Current vs Expected Behavior

### Current (Bad UX):
```
❌ Verification Failed
Failed to send push notification. Please try again.
```
User doesn't know why it failed or what to do next.

### Expected (Good UX):
```
⚠️ Device Not Registered
Please register your device first by scanning the QR code in your account settings.

[Go to Settings]  [Use Password Login]
```
User knows exactly what the problem is and how to fix it.

---

## 🚀 Implementation Timeline

**Suggested Priority:**
- **High Priority:** Update `user_message` extraction (Quick fix, big impact)
- **Medium Priority:** Add `onError` callback (Enables custom error handling)
- **Low Priority:** Documentation updates (Important for long-term maintenance)

**Estimated Effort:**
- Error message extraction: ~30 minutes
- Callback implementation: ~1-2 hours
- Testing all scenarios: ~2 hours
- Documentation: ~1 hour

**Total:** ~4-5 hours

---

## 📞 Contact

**Submitted by:** Webclient Team  
**Date:** November 9, 2025  
**For questions:** Please reach out to our development team

---

**Thank you for improving the widget!** This change will significantly enhance user experience across all Axiam integrations.
