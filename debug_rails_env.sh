#!/bin/bash
# Debug script - chạy trên production server
# File: debug_rails_env.sh

echo "=========================================="
echo "DEBUG: Rails Environment on Production"
echo "=========================================="
echo

# 1. Check container RAILS_ENV
echo "1️⃣ Container RAILS_ENV:"
docker compose exec app bash -c "echo \$RAILS_ENV"
echo

# 2. Check Rails.env từ bên trong Rails
echo "2️⃣ Rails.env from Rails console:"
docker compose exec app bash -c "cd /home/app/axiam-web-client && bin/rails runner 'puts Rails.env'"
echo

# 3. List log files
echo "3️⃣ Log files in /log:"
docker compose exec app ls -lah /home/app/axiam-web-client/log/
echo

# 4. Check which log file is being written
echo "4️⃣ Recent log files (modified in last 5 minutes):"
docker compose exec app find /home/app/axiam-web-client/log/ -name "*.log" -mmin -5 -exec ls -lh {} \;
echo

# 5. Check Rails logger config
echo "5️⃣ Rails logger configuration:"
docker compose exec app bash -c "cd /home/app/axiam-web-client && bin/rails runner 'puts Rails.logger.class.name; puts Rails.logger.instance_variable_get(:@logdev)&.filename || \"STDOUT\"'"
echo

# 6. Check if staging.log is a symlink
echo "6️⃣ Check staging.log (is it a symlink?):"
docker compose exec app bash -c "cd /home/app/axiam-web-client && ls -la log/staging.log 2>/dev/null || echo 'staging.log not found'"
echo

# 7. Check production.log
echo "7️⃣ Check production.log:"
docker compose exec app bash -c "cd /home/app/axiam-web-client && ls -la log/production.log 2>/dev/null || echo 'production.log not found'"
echo

# 8. Tail last 10 lines of staging.log if exists
echo "8️⃣ Last 10 lines of staging.log (if exists):"
docker compose exec app bash -c "cd /home/app/axiam-web-client && tail -10 log/staging.log 2>/dev/null || echo 'Cannot read staging.log'"
echo

# 9. Check loaded environment files
echo "9️⃣ Environment variables in container:"
docker compose exec app bash -c "env | grep -E 'RAILS_ENV|RACK_ENV|RAKE_ENV'"
echo

echo "=========================================="
echo "✅ Debug complete"
echo "=========================================="
