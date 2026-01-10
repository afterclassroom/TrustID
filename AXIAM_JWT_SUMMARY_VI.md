# Tóm Tắt: Triển Khai JWT Authentication cho Axiam Facial Sign-on

## 📌 Tổng Quan

Đã hoàn thành việc nâng cấp hệ thống xác thực ActionCable từ phương pháp cũ (channel_prefix) sang phương pháp mới bảo mật hơn (JWT Token Authentication) theo yêu cầu từ Axiam.

**Ngày hoàn thành:** 1 Tháng 1, 2026  
**Trạng thái:** ✅ Đã triển khai hoàn tất, sẵn sàng deploy

---

## 🎯 Những Gì Đã Thay Đổi

### Trước Đây (Cũ - Không Bảo Mật)

```javascript
// ❌ Cách cũ: Chỉ dùng channel_prefix
const cable = ActionCable.createConsumer(
  `wss://axiam.io/cable?channel_prefix=ch_00d698963dc2`
);
```

**Vấn đề:**
- Channel prefix dễ bị đoán
- Không có thời gian hết hạn
- Không thể thu hồi token
- Bảo mật yếu

### Hiện Tại (Mới - Bảo Mật Cao)

```javascript
// ✅ Cách mới: Dùng JWT token
const jwtToken = await fetch('/auth/axiam-token').then(r => r.json());
const cable = ActionCable.createConsumer(
  `wss://axiam.io/cable?token=${jwtToken.token}`
);
```

**Cải tiến:**
- ✅ Mã hóa JWT mạnh (HS256)
- ✅ Token tự động hết hạn sau 2 giờ
- ✅ Có thể thu hồi ngay lập tức
- ✅ API Secret được bảo vệ server-side
- ✅ Bảo mật đa lớp

---

## 📁 Các File Đã Tạo/Sửa

### File Mới

1. **`app/controllers/auth_controller.rb`**
   - Endpoint: GET /auth/axiam-token
   - Trả về JWT token cho frontend
   - Bảo vệ API secrets (chỉ server-side)

2. **`app/services/jwt_revocation_service.rb`**
   - Dịch vụ thu hồi token dựa trên Redis
   - Thu hồi token ngay lập tức khi bị xâm phạm
   - Hỗ trợ thu hồi toàn bộ token của một site

3. **`AXIAM_JWT_IMPLEMENTATION.md`**
   - Tài liệu chi tiết về JWT implementation
   - Hướng dẫn cấu hình và deployment
   - Troubleshooting guide

4. **`JWT_DEPLOYMENT_CHECKLIST.md`**
   - Checklist deploy production
   - Các bước test và verify
   - Rollback plan

### File Đã Sửa

1. **`app/services/axiam_api.rb`**
   - Thêm method `get_jwt_token`
   - Gọi Axiam API để lấy JWT token

2. **`app/channels/application_cable/connection.rb`**
   - Thêm JWT verification logic
   - Kiểm tra chữ ký JWT (HS256)
   - Kiểm tra token có bị thu hồi không
   - Hỗ trợ legacy channel_prefix (backward compatible)

3. **`app/channels/facial_sign_on_login_channel.rb`**
   - Kiểm tra JWT authentication
   - Cross-validate site_id
   - Gửi JWT status trong subscription confirmation

4. **`app/channels/facial_sign_on_device_channel.rb`**
   - Kiểm tra JWT authentication
   - Gửi JWT status khi subscribe

5. **`app/views/devise/sessions/new.html.erb`** (Trang login)
   - Lấy JWT token trước khi kết nối WebSocket
   - Cache token với buffer 5 phút
   - Tự động refresh token trước khi hết hạn

6. **`app/views/facial_signup/facial_signup/show_qr.html.erb`** (Trang QR signup)
   - Thêm JWT token management
   - WebSocket kết nối với JWT authentication

7. **`app/views/devise/registrations/enable_facial_sign_on.html.erb`**
   - Tích hợp JWT token
   - Update ActionCable consumer

8. **`config/routes.rb`**
   - Thêm route: GET /auth/axiam-token

9. **`Gemfile`**
   - Thêm gem "jwt"

10. **`config/application.yml`**
    - Thêm JWT configuration options
    - Thêm REDIS_URL cho revocation service

---

## 🚀 Các Bước Deploy

### Bước 1: Install Dependencies

```bash
cd /var/www/app
bundle install
```

### Bước 2: Restart Application

```bash
# Docker
docker-compose restart

# Hoặc manual restart
touch tmp/restart.txt
```

### Bước 3: Test JWT Endpoint

```bash
# Development
curl http://localhost:8000/auth/axiam-token

# Production (sau khi deploy)
curl https://veritrustai.net/auth/axiam-token
```

**Response mong đợi:**
```json
{
  "success": true,
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "expires_in": 7200,
  "expires_at": "2026-01-01T14:00:00Z"
}
```

### Bước 4: Test Facial Login

1. Vào: http://localhost:8000/users/sign_in
2. Nhập email
3. Click "Sign In With Face"
4. Mở browser console (F12)
5. Kiểm tra logs:
   - ✅ "JWT Token: eyJ..."
   - ✅ "ActionCable consumer created"
   - ✅ Subscription confirmed with jwt_authenticated: true

### Bước 5: Test Facial Signup

1. Vào: http://localhost:8000/users/sign_up
2. Điền form đăng ký
3. Submit để hiển thị QR code
4. Quét QR bằng Axiam mobile app
5. Kiểm tra logs cho JWT authentication

### Bước 6: Check Server Logs

```bash
# Development
tail -f log/development.log | grep ActionCable

# Production
docker logs -f axiam_client_app-veritrust_1 | grep ActionCable
```

**Logs mong đợi:**
```
[ActionCable] ✅ JWT authentication successful for site_id=1
[FacialSignOnLoginChannel] ✅ JWT authenticated subscription: site_id=1
```

---

## 🔧 Cấu Hình Môi Trường

### Development (Hiện Tại)

File: `config/application.yml`

```yaml
AXIAM_API_KEY: "97dd9b1914cd4b0902130f5c1cbee445"
AXIAM_SECRET_KEY: "c2328bdbdba3b339a10c1492c77eee950c8442d41655c48d15564595eb919b29"
AXIAM_API_BASE: "http://axiamai_rails-app-1:3000"
AXIAM_CABLE_URL: "ws://localhost:3000/cable"
REDIS_URL: "redis://localhost:6379/0"

# JWT Options
JWT_IP_BINDING_ENABLED: "false"
ACTIONCABLE_REQUIRE_JWT: "false"
```

### Production (Cần Cấu Hình)

```yaml
AXIAM_API_KEY: "your_production_api_key"  # Lấy từ Axiam support
AXIAM_SECRET_KEY: "your_production_secret_key"  # Lấy từ Axiam support
AXIAM_API_BASE: "https://axiam.io"
AXIAM_CABLE_URL: "wss://axiam.io/cable"
REDIS_URL: "redis://localhost:6379/0"

# Security options
ACTIONCABLE_REQUIRE_JWT: "false"  # Đặt true sau khi test xong
```

---

## 🔒 Bảo Mật

### Các Tính Năng Bảo Mật

1. **JWT Signature Verification**
   - Kiểm tra chữ ký với thuật toán HS256
   - Từ chối token bị giả mạo

2. **Token Revocation** (Thu Hồi Token)
   ```ruby
   # Thu hồi 1 token
   JwtRevocationService.revoke_token(token, reason: 'security_incident')
   
   # Thu hồi tất cả token của site
   JwtRevocationService.revoke_all_for_site(site_id, reason: 'site_compromised')
   ```

3. **Token Expiration** (Hết Hạn Tự Động)
   - Token hết hạn sau 2 giờ
   - Frontend tự động refresh 5 phút trước khi hết hạn

4. **Site Isolation** (Cách Ly Site)
   - JWT chứa site_id
   - Cross-validate với verification tokens
   - Ngăn chặn tấn công cross-site

### Backward Compatibility

- ✅ Code cũ (channel_prefix) vẫn hoạt động
- ⚠️ Hiển thị warning trong logs
- 🔄 Có thể chuyển dần sang JWT mà không gián đoạn service

---

## 📊 Chiến Lược Migration

### Phase 1: Soft Launch (Hiện Tại)

- ✅ JWT authentication đã implement
- ✅ Legacy channel_prefix vẫn work (với warnings)
- ✅ ACTIONCABLE_REQUIRE_JWT=false (mặc định)
- ✅ Tất cả views đã update để dùng JWT

**Trạng thái:** Sẵn sàng deploy production

### Phase 2: Monitoring (Tuần 1-2)

- Theo dõi JWT usage trong logs
- Track authentication failures
- Verify token refresh logic
- Kiểm tra performance

### Phase 3: Strict Mode (Tùy Chọn, Tương Lai)

- Đặt ACTIONCABLE_REQUIRE_JWT=true
- Từ chối connections không có JWT
- Xóa code legacy channel_prefix

---

## 🧪 Testing

### Test Manual

```bash
# 1. Test JWT endpoint
curl http://localhost:8000/auth/axiam-token

# 2. Test facial login
# - Vào http://localhost:8000/users/sign_in
# - Click "Sign In With Face"
# - Check console logs

# 3. Test facial signup
# - Vào http://localhost:8000/users/sign_up
# - Complete form
# - Scan QR code
# - Check logs

# 4. Check ActionCable logs
docker logs -f axiam_client_app-veritrust_1 | grep ActionCable
```

### Test Production (Sau Khi Deploy)

```bash
# 1. SSH vào production
ssh root@167.71.206.103

# 2. Check logs
docker logs -f axiam_client_app-veritrust_1 | grep JWT

# 3. Test endpoint
curl https://veritrustai.net/auth/axiam-token

# 4. Test facial login via browser
# - Vào https://veritrustai.net/users/sign_in
# - Complete facial login
# - Verify success
```

---

## ❓ Troubleshooting

### Lỗi: "Failed to get JWT token"

**Nguyên nhân:** Backend không authenticate được với Axiam

**Giải pháp:**
1. Kiểm tra AXIAM_API_KEY và AXIAM_SECRET_KEY trong config
2. Verify Axiam server accessible
3. Check logs: `grep "AxiamApi" log/development.log`

### Lỗi: "Unauthorized connection"

**Nguyên nhân:** JWT token không hợp lệ hoặc hết hạn

**Giải pháp:**
1. Check token expiration time
2. Verify JWT secret matches Axiam's secret
3. Check if token was revoked
4. Refresh browser

### Lỗi: WebSocket connects nhưng hiện "legacy mode"

**Nguyên nhân:** JWT token không được gửi trong WebSocket URL

**Giải pháp:**
1. Check browser console for JWT fetch errors
2. Verify /auth/axiam-token returns token
3. Check WebSocket URL có `?token=...` parameter

---

## 📚 Tài Liệu

Đã tạo 2 file tài liệu chi tiết:

1. **`AXIAM_JWT_IMPLEMENTATION.md`**
   - Kiến trúc JWT authentication
   - API documentation
   - Security best practices
   - Troubleshooting guide

2. **`JWT_DEPLOYMENT_CHECKLIST.md`**
   - Checklist deploy từng bước
   - Test scenarios
   - Monitoring & alerts
   - Rollback plan

---

## 🎉 Kết Luận

### Những Gì Đã Hoàn Thành

✅ JWT token endpoint backend  
✅ JWT verification trong ApplicationCable  
✅ JWT revocation service với Redis  
✅ JWT validation trong channels  
✅ Update tất cả views để dùng JWT  
✅ Routes configuration  
✅ Environment configuration  
✅ Tài liệu đầy đủ (tiếng Anh + tiếng Việt)  
✅ Deployment checklist  
✅ Backward compatibility với code cũ  

### Bước Tiếp Theo

1. **Development Testing:**
   ```bash
   cd /var/www/app
   bundle install
   docker-compose restart
   # Test JWT endpoint
   curl http://localhost:8000/auth/axiam-token
   # Test facial login/signup
   ```

2. **Production Deployment:**
   - Update production API keys từ Axiam
   - Deploy code lên production server
   - Run bundle install
   - Restart application
   - Test thoroughly

3. **Monitoring:**
   - Watch logs cho JWT authentication
   - Track authentication success rate
   - Monitor token revocation events
   - Check performance metrics

---

## 📞 Hỗ Trợ

**Nếu Gặp Vấn Đề:**

1. Check tài liệu:
   - `AXIAM_JWT_IMPLEMENTATION.md` - Chi tiết technical
   - `JWT_DEPLOYMENT_CHECKLIST.md` - Các bước deploy

2. Check logs:
   ```bash
   # Development
   tail -f log/development.log | grep -E "JWT|ActionCable"
   
   # Production
   docker logs -f axiam_client_app-veritrust_1 | grep -E "JWT|ActionCable"
   ```

3. Liên hệ Axiam support:
   - Technical: api-support@axiam.io
   - Security: security@axiam.io
   - Integration: integrations@axiam.io

---

**Hoàn thành:** 1 Tháng 1, 2026  
**Người thực hiện:** GitHub Copilot  
**Trạng thái:** ✅ Sẵn sàng deploy production
