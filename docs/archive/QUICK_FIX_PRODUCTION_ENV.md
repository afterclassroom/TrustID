# Quick Fix: staging.log → production.log

## Vấn đề
Container đang chạy với `RAILS_ENV=staging` thay vì `production`, dẫn đến:
- Log ghi vào `/log/staging.log` thay vì `production.log`
- Rails không load production config
- Cache/credentials có thể sai environment

## Giải pháp nhanh (trên Production Server)

### Bước 1: Kiểm tra RAILS_ENV hiện tại

```bash
cd /var/www/axiam-client  # hoặc thư mục project của bạn

# Check container environment
docker compose exec web bash -c "echo RAILS_ENV=\$RAILS_ENV"

# Nếu output là "staging" → cần fix
```

### Bước 2: Stop containers hiện tại

```bash
docker compose down
```

### Bước 3: Sử dụng docker-compose.production.yml

**Option A: Tạo symlink (khuyến nghị)**

```bash
# Backup file cũ nếu có
mv docker-compose.yml docker-compose.yml.backup

# Tạo symlink tới production config
ln -s docker-compose.production.yml docker-compose.yml

# Từ giờ chạy docker compose như bình thường
docker compose up -d --build
```

**Option B: Chỉ định file khi chạy**

```bash
# Luôn thêm -f docker-compose.production.yml
docker compose -f docker-compose.production.yml up -d --build
docker compose -f docker-compose.production.yml logs -f web
docker compose -f docker-compose.production.yml exec web bash
```

**Option C: Sửa trực tiếp docker-compose.yml trên server**

```bash
nano docker-compose.yml

# Tìm dòng:
#   environment:
#     RAILS_ENV: staging  # hoặc development
#
# Sửa thành:
#   environment:
#     RAILS_ENV: production

# Hoặc xóa và để .env.production quyết định:
#   env_file:
#     - .env.production
#   # RAILS_ENV sẽ load từ .env.production

# Save và exit (Ctrl+O, Enter, Ctrl+X)
```

### Bước 4: Khởi động lại với production config

```bash
# Nếu dùng Option A (symlink)
docker compose up -d --build

# Nếu dùng Option B (specify file)
docker compose -f docker-compose.production.yml up -d --build
```

### Bước 5: Verify RAILS_ENV

```bash
# Check environment
docker compose exec web bash -c "echo RAILS_ENV=\$RAILS_ENV"
# Expected: RAILS_ENV=production

# Check log directory
docker compose exec web ls -la log/
# Expected: production.log tồn tại và đang được ghi

# Tail production log
docker compose exec web tail -f log/production.log
```

### Bước 6: Verify toàn bộ hệ thống

```bash
# Run health check
docker compose exec web bash -c "RAILS_ENV=production bin/rails runner script/health_check.rb"

# Check cache store
docker compose exec web bash -c "RAILS_ENV=production bin/rails runner 'puts Rails.cache.class.name'"
# Expected: ActiveSupport::Cache::RedisCacheStore

# Test web app
curl https://webclient.axiam.io
```

---

## Checklist sau khi fix

- [ ] `docker compose exec web bash -c "echo \$RAILS_ENV"` trả về `production`
- [ ] File `log/production.log` tồn tại và đang được ghi
- [ ] `script/health_check.rb` chạy thành công (all ✅)
- [ ] Web app accessible qua HTTPS
- [ ] Facial sign-on flow hoạt động
- [ ] Browser Network tab không hiển thị Redis credentials

---

## Nếu vẫn thấy staging.log

### Nguyên nhân có thể:
1. Container cũ vẫn chạy → `docker compose down` rồi `up` lại
2. ENV variable trong .env.production sai → check `RAILS_ENV=production`
3. Puma đang cache environment → restart: `docker compose restart web`

### Debug:

```bash
# Check tất cả containers đang chạy
docker ps

# Check environment variables trong container
docker compose exec web env | grep RAILS

# Check puma process
docker compose exec web ps aux | grep puma

# Force rebuild without cache
docker compose down
docker compose up -d --build --force-recreate
```

---

## Lưu ý quan trọng

1. **Luôn dùng `docker-compose.production.yml` cho production**
   - File này đã config đúng RAILS_ENV=production
   - Có healthcheck cho DB và web
   - Auto-run migrations
   - Bind đúng port (127.0.0.1:6000)

2. **Không commit `.env.production` hoặc `production.key`**
   - Chỉ copy/tạo trực tiếp trên server
   - Chmod 600 để bảo mật

3. **Check logs thường xuyên**
   ```bash
   # Production log
   docker compose exec web tail -f log/production.log
   
   # Container log
   docker compose logs -f web
   
   # Nginx error log
   sudo tail -f /var/log/nginx/error.log
   ```

4. **Nếu thay đổi .env.production hoặc credentials**
   ```bash
   docker compose down
   docker compose up -d  # không cần --build nếu chỉ đổi env
   ```

---

**Sau khi fix xong, commit `docker-compose.production.yml` vào git** (nếu chưa có):

```bash
git add docker-compose.production.yml
git commit -m "Add production docker-compose configuration"
git push origin main
```
