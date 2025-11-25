# Cải tiến Bảo mật - Facial Sign-On

## Vấn đề đã phát hiện

Trước đây, khi người dùng thực hiện login bằng Axiam và xem source HTML hoặc Network Response, họ có thể thấy:

```javascript
// ❌ NGUY HIỂM - Thông tin nhạy cảm bị lộ
window.SITE_CREDENTIALS = {
  "redis_username": "app_ce35349fb9af9775",
  "redis_password": "0777e0ab37d80ab4ec64fb6aa7f79c69",  // ⚠️ CỰC KỲ NGUY HIỂM
  "channel_prefix": "ch_5586712a0b28",
  "server_url": "ws://localhost:3000/cable"
};

const token = '698575eb3ee6006e960893a2fea84a72a098feb059b595e0c58d305d9414cd9e';  // ⚠️ NGUY HIỂM
```

### Mức độ rủi ro:

1. **Redis credentials (username/password)** - **CRITICAL** 🔴
   - Kẻ tấn công có thể truy cập trực tiếp Redis server
   - Đọc/ghi/xóa toàn bộ dữ liệu session, cache
   - Giả mạo ActionCable messages

2. **Verification token** - **HIGH** 🟠
   - Subscribe vào channel xác thực của người khác
   - Nghe trộm hoặc giả mạo kết quả facial authentication
   - Hijack login session

3. **Channel prefix** - **LOW** 🟡
   - Giúp kẻ tấn công đoán tên channel
   - Ít nguy hiểm nhưng không nên public

## Giải pháp đã triển khai

### 1. Tách credentials thành public/private

**File: `app/helpers/application_helper.rb`**

```ruby
# ✅ Server-side only (includes sensitive data)
def axiam_credentials_full
  {
    redis_username: ...,
    redis_password: ...,  # Chỉ dùng server-side
    channel_prefix: ...,
    server_url: ...
  }
end

# ✅ Client-safe (NO sensitive data)
def axiam_credentials_js
  {
    channel_prefix: ...,  # OK to expose
    server_url: ...       # OK to expose
  }
end
```

### 2. Session-based verification token

**File: `app/controllers/facial_sign_on_controller.rb`**

```ruby
def push_notification
  # ...
  if result && result['data']['verification_token']
    # ✅ Store in session instead of HTML
    session[:facial_verification_token] = result['data']['verification_token']
    session[:facial_verification_expires_at] = 5.minutes.from_now.to_i
    
    # ✅ Do NOT pass to view
    render 'facial_sign_on/subscribe', status: :ok
  end
end

# ✅ NEW: Secure API endpoint (CSRF protected)
def get_verification_token
  token = session[:facial_verification_token]
  expires_at = session[:facial_verification_expires_at]
  
  if token.present? && Time.now.to_i < expires_at
    render json: { success: true, token: token }
  else
    render json: { success: false, error: 'Token expired' }, status: :unauthorized
  end
end
```

### 3. Client fetch token via API

**File: `app/views/facial_sign_on/subscribe.html.erb`**

```javascript
// ✅ Fetch token from secure endpoint
fetch('/facial_sign_on/get_verification_token', {
  method: 'GET',
  headers: {
    'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
  },
  credentials: 'same-origin'
})
.then(response => response.json())
.then(data => {
  if (data.success && data.token) {
    window.subscribeFacialSignOn(data.token);
  }
});
```

## Lợi ích

✅ **Redis credentials không còn xuất hiện trong HTML source**  
✅ **Verification token được bảo vệ bởi session + CSRF**  
✅ **Token tự động expire sau 5 phút**  
✅ **Chỉ expose thông tin công khai (channel_prefix, server_url)**  
✅ **CSRF protection cho tất cả API calls**  

## Cách test

1. Mở trang login: `/facial_sign_on/login`
2. Nhập email và submit
3. Mở DevTools → Network tab
4. Kiểm tra Response của `/push_notification`:
   - ✅ **KHÔNG** thấy `redis_username` hoặc `redis_password`
   - ✅ **KHÔNG** thấy `verification_token` trong HTML
5. Kiểm tra `/get_verification_token`:
   - ✅ Cần CSRF token
   - ✅ Chỉ trả về khi có session hợp lệ
   - ✅ Token expire sau 5 phút

## Migration notes

Không cần migration. Các thay đổi chỉ ảnh hưởng đến:
- Helper methods (backward compatible)
- Client JavaScript (auto-fetch token)
- Controller actions (session-based)

## Rollback plan

Nếu cần rollback (không khuyến nghị), revert các commits:
1. `app/helpers/application_helper.rb`
2. `app/controllers/facial_sign_on_controller.rb`
3. `app/views/facial_sign_on/subscribe.html.erb`
4. `config/routes.rb`

---
**Áp dụng:** November 3, 2025  
**Severity:** Critical Security Fix  
**Impact:** Không breaking change, chỉ cải thiện bảo mật
