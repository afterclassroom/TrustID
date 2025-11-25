# Axiam Facial Sign-On Widget Integration

## Tích hợp Axiam Widget vào Webclient

### 1. Cấu hình môi trường

Thêm các biến môi trường sau vào `config/application.yml`:

```yaml
# Axiam API Configuration
AXIAM_API_BASE: 'https://staging.axiam.io'  # hoặc production URL
AXIAM_PUBLIC_KEY: 'your_public_key_here'     # Public key từ Axiam
AXIAM_API_KEY: 'your_api_key'                # API key (nếu khác public key)
```

### 2. Routes có sẵn

- **Widget Login** (Khuyến nghị): `/facial_sign_on/widget`
  - Sử dụng Axiam Widget - tự động handle mọi thứ
  
- **Legacy Manual Login**: `/facial_sign_on/login`
  - Form manual cũ - vẫn hoạt động nhưng không khuyến nghị

### 3. Cách hoạt động của Widget

#### Flow tự động:
1. User vào trang `/facial_sign_on/widget`
2. Axiam widget tự động load và hiển thị "Sign in with Face" button
3. User click button → Widget hiển thị modal nhập email
4. Widget tự động validate và gọi API push_notification
5. Widget tự động subscribe ActionCable channel
6. Widget hiển thị trạng thái: waiting/success/error
7. Khi success → Widget callback `onSuccess` với data
8. Webclient verify user và tạo session

#### Webclient chỉ cần:
- Embed widget code (đã có trong view)
- Handle `onSuccess` callback để verify và sign in user
- Handle `onError` callback để hiển thị lỗi

### 4. Code đã được tích hợp

**View:** `app/views/facial_sign_on/widget_login.html.erb`
```erb
<!-- Widget container -->
<div id="axiam-facial-login"></div>

<!-- Widget scripts tự động load từ Axiam server -->
<script src="<%= axiam_base %>/widget/facial-login.js"></script>
<link rel="stylesheet" href="<%= axiam_base %>/widget/facial-login.css">

<!-- Initialize widget với callbacks -->
<script>
AxiamFacialLogin.init({
  publicKey: '<%= public_key %>',
  onSuccess: function(data) { /* auto verify & sign in */ },
  onError: function(error) { /* show error */ }
});
</script>
```

**Controller:** `app/controllers/facial_sign_on_controller.rb`
```ruby
def widget_login
  render 'facial_sign_on/widget_login'
end

def verified_login
  # Verify user từ Axiam callback
  # Sign in user nếu hợp lệ
end
```

### 5. Testing

**Development:**
```
http://localhost:3030/facial_sign_on/widget
```

**Staging:**
```
https://webclientstaging.axiam.io/facial_sign_on/widget
```

### 6. Migration từ Legacy Login

Nếu bạn muốn chuyển hoàn toàn sang Widget:

1. Cập nhật link "Login with Axiam" thành:
```erb
<%= link_to "Sign in with Face", facial_sign_on_widget_path, class: "btn btn-primary" %>
```

2. Hoặc thay thế route mặc định:
```ruby
# config/routes.rb
get '/facial_sign_on/login', to: 'facial_sign_on#widget_login', as: :facial_sign_on_login
```

### 7. Lợi ích của Widget

- ✅ Không cần maintain form HTML/CSS/JS
- ✅ Không cần handle ActionCable subscription
- ✅ Không cần handle push_notification API call
- ✅ Tự động update khi Axiam release tính năng mới
- ✅ UI/UX consistent với Axiam standard
- ✅ Security được handle bởi Axiam
- ✅ Webclient code gọn gàng hơn nhiều

### 8. Troubleshooting

**Widget không load:**
- Kiểm tra `AXIAM_API_BASE` trong ENV
- Kiểm tra network tab trong DevTools
- Verify URL `<axiam_base>/widget/facial-login.js` accessible

**onSuccess không được gọi:**
- Kiểm tra `AXIAM_PUBLIC_KEY` đúng chưa
- Xem console log có lỗi không
- Verify user đã được tạo trong Axiam

**Login failed sau onSuccess:**
- Kiểm tra `axiam_uid` có trong database chưa
- Verify `verified_login` endpoint hoạt động
- Check Rails logs để debug

### 9. Support

Nếu cần hỗ trợ, liên hệ Axiam team hoặc check docs:
- Widget API: `<axiam_base>/docs/widget`
- Support: support@axiam.io
