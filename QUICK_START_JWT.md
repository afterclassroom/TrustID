# Quick Start: Deploy JWT Authentication

## 🚀 Deployment trong 5 Phút

### Bước 1: Install JWT Gem (2 phút)

```bash
cd /var/www/app
bundle install
```

**Output mong đợi:**
```
Fetching jwt 2.x.x
Installing jwt 2.x.x
Bundle complete!
```

---

### Bước 2: Restart Application (1 phút)

```bash
# Development
docker-compose restart

# Production
docker-compose restart veritrust
```

---

### Bước 3: Verify JWT Endpoint (1 phút)

```bash
# Test endpoint
curl http://localhost:8000/auth/axiam-token

# Response mong đợi:
# {
#   "success": true,
#   "token": "eyJhbGc...",
#   "expires_in": 7200
# }
```

---

### Bước 4: Test Facial Login (1 phút)

1. Vào: http://localhost:8000/users/sign_in
2. Nhập email và click "Sign In With Face"
3. Mở Console (F12) - should see:
   ```
   JWT Token: eyJ...
   ActionCable consumer created
   ```

---

## ✅ Done!

JWT authentication đang hoạt động. Các tính năng:

- ✅ Token tự động expire sau 2 giờ
- ✅ Auto-refresh trước 5 phút
- ✅ Bảo mật ActionCable WebSocket
- ✅ Backward compatible với code cũ

---

## 🔧 Configuration Files Đã Có

Tất cả files đã được tạo/update:

### Backend
- ✅ `app/controllers/auth_controller.rb`
- ✅ `app/services/axiam_api.rb`
- ✅ `app/services/jwt_revocation_service.rb`
- ✅ `app/channels/application_cable/connection.rb`
- ✅ `app/channels/facial_sign_on_login_channel.rb`
- ✅ `app/channels/facial_sign_on_device_channel.rb`

### Frontend
- ✅ `app/views/devise/sessions/new.html.erb`
- ✅ `app/views/facial_signup/facial_signup/show_qr.html.erb`
- ✅ `app/views/devise/registrations/enable_facial_sign_on.html.erb`

### Config
- ✅ `config/routes.rb`
- ✅ `config/application.yml`
- ✅ `Gemfile`

### Docs
- ✅ `AXIAM_JWT_IMPLEMENTATION.md` (chi tiết technical)
- ✅ `JWT_DEPLOYMENT_CHECKLIST.md` (deployment steps)
- ✅ `AXIAM_JWT_SUMMARY_VI.md` (tóm tắt tiếng Việt)
- ✅ `QUICK_START_JWT.md` (file này)

---

## 🏃 Nếu Cần Deploy Ngay Production

```bash
# 1. SSH vào production
ssh root@167.71.206.103

# 2. Navigate to app
cd /root/axiam_client_app

# 3. Install gem
docker-compose exec veritrust bundle install

# 4. Restart
docker-compose restart veritrust

# 5. Test
curl https://veritrustai.net/auth/axiam-token

# 6. Done!
```

---

## ❓ Troubleshooting Nhanh

### "gem jwt not found"
```bash
# Check Gemfile có jwt chưa
grep jwt Gemfile

# Re-install
bundle install
```

### "Failed to get JWT token"
```bash
# Check env vars
rails console
puts ENV['AXIAM_API_KEY']
puts ENV['AXIAM_SECRET_KEY']
```

### "Unauthorized connection"
```bash
# Check logs
docker logs axiam_client_app-veritrust_1 | tail -50
```

---

## 📚 Tài Liệu Chi Tiết

Nếu cần thêm thông tin:

1. **Technical details:** `AXIAM_JWT_IMPLEMENTATION.md`
2. **Deployment checklist:** `JWT_DEPLOYMENT_CHECKLIST.md`
3. **Tóm tắt tiếng Việt:** `AXIAM_JWT_SUMMARY_VI.md`

---

**Ready to deploy! 🚀**
