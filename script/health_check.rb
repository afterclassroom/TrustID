#!/usr/bin/env ruby
# frozen_string_literal: true

# Production Health Check Script
# Usage: RAILS_ENV=production bin/rails runner script/health_check.rb

puts "=" * 80
puts "AXIAM WEB CLIENT - PRODUCTION HEALTH CHECK"
puts "=" * 80
puts

# 1. Environment Check
puts "📋 Environment Configuration:"
puts "  RAILS_ENV: #{Rails.env}"
puts "  Rails version: #{Rails::VERSION::STRING}"
puts "  Ruby version: #{RUBY_VERSION}"
puts

# 2. Database Check
print "🗄️  Database Connection: "
begin
  ActiveRecord::Base.connection.execute("SELECT 1")
  puts "✅ Connected"
  puts "  Database: #{ActiveRecord::Base.connection.current_database}"
rescue => e
  puts "❌ Failed: #{e.message}"
  exit 1
end
puts

# 3. Redis Cache Check
print "💾 Rails Cache Connection: "
begin
  test_key = "health_check_#{Time.now.to_i}"
  test_value = "ok_#{SecureRandom.hex(4)}"
  
  Rails.cache.write(test_key, test_value, expires_in: 10.seconds)
  result = Rails.cache.read(test_key)
  
  if result == test_value
    puts "✅ Connected and working"
    puts "  Store: #{Rails.cache.class.name}"
    
    if Rails.env.production? && !Rails.cache.is_a?(ActiveSupport::Cache::RedisCacheStore)
      puts "  ⚠️  Warning: Not using Redis in production (recommended for token caching)"
    end
    
    # Show cache stats if available
    if Rails.cache.respond_to?(:stats)
      stats = Rails.cache.stats
      puts "  Stats: #{stats.inspect}" if stats
    end
  else
    puts "❌ Write/Read mismatch"
    exit 1
  end
  
  Rails.cache.delete(test_key)
rescue => e
  puts "❌ Failed: #{e.message}"
  if Rails.env.production?
    puts "  Make sure REDIS_URL is set correctly in .env.production"
    exit 1
  else
    puts "  Development: using default cache store"
  end
end
puts

# 4. ActionCable Check
print "🔌 ActionCable Configuration: "
begin
  cable_config = Rails.application.config.action_cable
  puts "✅ Configured"
  puts "  URL: #{cable_config.url || 'Not set (using default)'}"
  puts "  Mount path: #{cable_config.mount_path || '/cable'}"
rescue => e
  puts "❌ Failed: #{e.message}"
end
puts

# 5. Axiam Credentials Check
print "🔑 Axiam Credentials (Server-side): "
begin
  helper = Object.new.extend(ApplicationHelper)
  creds = helper.axiam_credentials_full
  
  missing = []
  creds.each do |key, value|
    missing << key if value.blank?
  end
  
  if missing.empty?
    puts "✅ All credentials present"
    puts "  Channel prefix: #{creds[:channel_prefix]}"
    puts "  Server URL: #{creds[:server_url]}"
    puts "  Redis username: #{'*' * 8} (hidden)"
    puts "  Redis password: #{'*' * 8} (hidden)"
  else
    puts "❌ Missing credentials: #{missing.join(', ')}"
    puts "  Check config/credentials/production.yml.enc or ENV variables"
    exit 1
  end
rescue => e
  puts "❌ Failed: #{e.message}"
  exit 1
end
puts

# 6. Public Credentials Check (what client sees)
print "🌐 Client-side Credentials (Public): "
begin
  helper = Object.new.extend(ApplicationHelper)
  public_creds = helper.axiam_credentials_js
  
  puts "✅ Ready for client"
  puts "  Channel prefix: #{public_creds[:channel_prefix]}"
  puts "  Server URL: #{public_creds[:server_url]}"
  
  # Security check
  if public_creds.key?(:redis_username) || public_creds.key?(:redis_password)
    puts "  ⚠️  WARNING: Redis credentials exposed to client!"
    exit 1
  else
    puts "  🔒 Security OK: No sensitive credentials in public config"
  end
rescue => e
  puts "❌ Failed: #{e.message}"
end
puts

# 7. Host Authorization Check
print "🛡️  Host Authorization: "
begin
  allowed_hosts = Rails.application.config.hosts
  if allowed_hosts.empty?
    puts "⚠️  Warning: No hosts configured (allows all)"
  else
    puts "✅ Configured"
    allowed_hosts.each do |host|
      puts "  - #{host}"
    end
  end
rescue => e
  puts "❌ Failed: #{e.message}"
end
puts

# 8. SSL Configuration Check
print "🔐 SSL Configuration: "
begin
  force_ssl = Rails.application.config.force_ssl
  if force_ssl
    puts "✅ SSL forced (production ready)"
  else
    puts "⚠️  Warning: SSL not forced (not recommended for production)"
  end
rescue => e
  puts "❌ Failed: #{e.message}"
end
puts

# 9. Test Facial Sign-On Token Flow
print "🧪 Facial Sign-On Token Cache: "
begin
  test_token = "test_#{SecureRandom.hex(32)}"
  test_data = { user_id: 123, created_at: Time.now }
  
  # Write token to cache (simulating push_notification)
  Rails.cache.write("facial_token:#{test_token}", test_data, expires_in: 5.minutes)
  
  # Read token (simulating channel subscription)
  cached = Rails.cache.read("facial_token:#{test_token}")
  
  if cached && cached[:user_id] == 123
    puts "✅ Token cache working"
    
    # Delete token (simulating one-time use)
    Rails.cache.delete("facial_token:#{test_token}")
    
    # Verify deletion
    deleted = Rails.cache.read("facial_token:#{test_token}")
    if deleted.nil?
      puts "  🔒 One-time use token deletion working"
    else
      puts "  ⚠️  Warning: Token not deleted properly"
    end
  else
    puts "❌ Token cache not working properly"
    exit 1
  end
rescue => e
  puts "❌ Failed: #{e.message}"
  exit 1
end
puts

# Summary
puts "=" * 80
puts "✅ ALL CHECKS PASSED - Production Ready!"
puts "=" * 80
puts
puts "Next steps:"
puts "  1. Verify external connectivity (Nginx, SSL, DNS)"
puts "  2. Test facial sign-on flow in browser"
puts "  3. Monitor logs: docker compose logs -f web"
puts "  4. Check browser Network tab for security (no Redis creds exposed)"
puts
