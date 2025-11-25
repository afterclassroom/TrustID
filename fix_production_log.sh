#!/bin/bash
# Fix script - chạy trên production server
# File: fix_production_log.sh

echo "=========================================="
echo "FIX: Force Rails to use production.log"
echo "=========================================="
echo

# 1. Remove old log files
echo "1️⃣ Removing old log files..."
docker compose exec app bash -c "cd /home/app/axiam-web-client && rm -f log/*.log"
echo "✅ Old logs removed"
echo

# 2. Create production.log
echo "2️⃣ Creating production.log..."
docker compose exec app bash -c "cd /home/app/axiam-web-client && touch log/production.log && chmod 666 log/production.log"
echo "✅ production.log created"
echo

# 3. Clear tmp/cache
echo "3️⃣ Clearing Rails cache..."
docker compose exec app bash -c "cd /home/app/axiam-web-client && rm -rf tmp/cache/*"
echo "✅ Cache cleared"
echo

# 4. Restart container
echo "4️⃣ Restarting app container..."
docker compose restart app
echo "✅ Container restarted"
echo

# Wait for container to be ready
echo "⏳ Waiting 10 seconds for container to start..."
sleep 10
echo

# 5. Verify
echo "5️⃣ Verification:"
echo "RAILS_ENV:"
docker compose exec app bash -c "echo \$RAILS_ENV"
echo

echo "Rails.env:"
docker compose exec app bash -c "cd /home/app/axiam-web-client && bin/rails runner 'puts Rails.env'"
echo

echo "Log files:"
docker compose exec app ls -lh /home/app/axiam-web-client/log/
echo

# 6. Test write to log
echo "6️⃣ Testing log write..."
docker compose exec app bash -c "cd /home/app/axiam-web-client && bin/rails runner 'Rails.logger.info(\"TEST LOG ENTRY FROM FIX SCRIPT\")'"
echo

echo "Check which log was written:"
docker compose exec app bash -c "cd /home/app/axiam-web-client && grep 'TEST LOG ENTRY' log/*.log 2>/dev/null || echo 'No log entry found in log/*.log'"
echo

echo "=========================================="
echo "✅ Fix complete - check output above"
echo "=========================================="
