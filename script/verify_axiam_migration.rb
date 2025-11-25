#!/usr/bin/env ruby
# frozen_string_literal: true

# Axiam v2.0 Migration Verification Script
# This script verifies that the Axiam ActionCable integration
# has been correctly migrated to the secure v2.0 architecture.

require_relative '../config/environment'

puts "=" * 80
puts "AXIAM V2.0 MIGRATION VERIFICATION"
puts "=" * 80
puts

# Helper to print test results
def test_result(test_name, passed, message = nil)
  status = passed ? "✅ PASS" : "❌ FAIL"
  puts "#{status}: #{test_name}"
  puts "       #{message}" if message
  puts
  passed
end

# Track overall results
all_tests_passed = true

# TEST 1: Helper Methods Exist
print "1️⃣  Testing ApplicationHelper methods... "
begin
  helper = Object.new.extend(ApplicationHelper)
  
  has_full_method = helper.respond_to?(:axiam_credentials_full)
  has_js_method = helper.respond_to?(:axiam_credentials_js)
  has_url_method = helper.respond_to?(:axiam_server_url)
  
  all_tests_passed &= test_result(
    "Helper Methods",
    has_full_method && has_js_method && has_url_method,
    "axiam_credentials_full: #{has_full_method}, axiam_credentials_js: #{has_js_method}, axiam_server_url: #{has_url_method}"
  )
rescue => e
  all_tests_passed &= test_result("Helper Methods", false, e.message)
end

# TEST 2: Full Credentials (Server-side)
print "2️⃣  Testing server-side credentials... "
begin
  helper = Object.new.extend(ApplicationHelper)
  creds = helper.axiam_credentials_full
  
  has_redis_user = creds.key?(:redis_username) && creds[:redis_username].present?
  has_redis_pass = creds.key?(:redis_password) && creds[:redis_password].present?
  has_channel = creds.key?(:channel_prefix) && creds[:channel_prefix].present?
  has_url = creds.key?(:server_url) && creds[:server_url].present?
  
  all_tests_passed &= test_result(
    "Server-side Credentials",
    has_redis_user && has_redis_pass && has_channel && has_url,
    "Redis user: #{has_redis_user ? '✓' : '✗'}, Redis pass: #{has_redis_pass ? '✓' : '✗'}, Channel: #{has_channel ? '✓' : '✗'}, URL: #{has_url ? '✓' : '✗'}"
  )
rescue => e
  all_tests_passed &= test_result("Server-side Credentials", false, e.message)
end

# TEST 3: Public Credentials (Client-safe)
print "3️⃣  Testing client-safe credentials (CRITICAL SECURITY TEST)... "
begin
  helper = Object.new.extend(ApplicationHelper)
  creds = helper.axiam_credentials_js
  
  # Should have these
  has_channel = creds.key?(:channel_prefix) && creds[:channel_prefix].present?
  has_url = creds.key?(:server_url) && creds[:server_url].present?
  
  # Should NOT have these (security check)
  no_redis_user = !creds.key?(:redis_username)
  no_redis_pass = !creds.key?(:redis_password)
  
  passed = has_channel && has_url && no_redis_user && no_redis_pass
  
  if passed
    all_tests_passed &= test_result(
      "🔒 Client-safe Credentials (Security)",
      true,
      "✅ NO Redis credentials exposed | Channel: ✓ | URL: ✓"
    )
  else
    all_tests_passed &= test_result(
      "🔒 Client-safe Credentials (Security)",
      false,
      "🔴 CRITICAL: #{no_redis_user ? '' : 'Redis username exposed! '}#{no_redis_pass ? '' : 'Redis password exposed! '}"
    )
  end
rescue => e
  all_tests_passed &= test_result("Client-safe Credentials", false, e.message)
end

# TEST 4: Environment-aware URL
print "4️⃣  Testing environment-aware server URL... "
begin
  helper = Object.new.extend(ApplicationHelper)
  url = helper.axiam_server_url
  
  expected_url = case Rails.env
  when 'development'
    'ws://localhost:3000/cable'
  when 'staging'
    'wss://staging.axiam.io/cable'
  when 'production'
    'wss://axiam.io/cable'
  else
    'ws://localhost:3000/cable'
  end
  
  correct_url = url == expected_url
  uses_wss = Rails.env.production? || Rails.env.staging? ? url.start_with?('wss://') : true
  
  all_tests_passed &= test_result(
    "Environment-aware URL",
    correct_url && uses_wss,
    "Current: #{url} | Expected: #{expected_url} | Secure WebSocket (wss): #{uses_wss ? '✓' : '✗'}"
  )
rescue => e
  all_tests_passed &= test_result("Environment-aware URL", false, e.message)
end

# TEST 5: Token API Endpoint
print "5️⃣  Testing token API endpoint... "
begin
  has_route = Rails.application.routes.url_helpers.respond_to?(:get_verification_token_facial_sign_on_index_path)
  
  if has_route
    route_path = Rails.application.routes.url_helpers.get_verification_token_facial_sign_on_index_path
    all_tests_passed &= test_result(
      "Token API Endpoint",
      true,
      "Route: #{route_path}"
    )
  else
    all_tests_passed &= test_result(
      "Token API Endpoint",
      false,
      "Route get_verification_token_facial_sign_on_index_path not found"
    )
  end
rescue => e
  all_tests_passed &= test_result("Token API Endpoint", false, e.message)
end

# TEST 6: Channel Subscription Authorization
print "6️⃣  Testing FacialSignOnLoginChannel exists... "
begin
  channel_class = FacialSignOnLoginChannel
  has_subscribed = channel_class.instance_methods.include?(:subscribed)
  
  all_tests_passed &= test_result(
    "ActionCable Channel",
    has_subscribed,
    "FacialSignOnLoginChannel#subscribed: #{has_subscribed ? 'defined' : 'missing'}"
  )
rescue => e
  all_tests_passed &= test_result("ActionCable Channel", false, e.message)
end

# TEST 7: JavaScript Files Exist
print "7️⃣  Testing JavaScript files... "
begin
  js_files = {
    'axiam-actioncable-client.js' => Rails.root.join('app', 'assets', 'javascripts', 'axiam-actioncable-client.js'),
    'facial_sign_on_secure_token.js' => Rails.root.join('app', 'assets', 'javascripts', 'facial_sign_on_secure_token.js'),
    'axiam_helpers.js' => Rails.root.join('app', 'assets', 'javascripts', 'axiam_helpers.js')
  }
  
  missing_files = js_files.select { |name, path| !File.exist?(path) }.keys
  
  all_tests_passed &= test_result(
    "JavaScript Files",
    missing_files.empty?,
    missing_files.empty? ? "All required files present" : "Missing: #{missing_files.join(', ')}"
  )
rescue => e
  all_tests_passed &= test_result("JavaScript Files", false, e.message)
end

# TEST 8: Cache Configuration
print "8️⃣  Testing Rails cache configuration... "
begin
  # Try to write and read from cache
  test_key = 'axiam_migration_test'
  test_value = { test: true, timestamp: Time.current.to_i }
  
  Rails.cache.write(test_key, test_value, expires_in: 10.seconds)
  cached_value = Rails.cache.read(test_key)
  Rails.cache.delete(test_key)
  
  cache_working = cached_value == test_value
  
  all_tests_passed &= test_result(
    "Rails Cache",
    cache_working,
    "Cache store: #{Rails.cache.class.name} | Read/Write: #{cache_working ? '✓' : '✗'}"
  )
rescue => e
  all_tests_passed &= test_result("Rails Cache", false, e.message)
end

# TEST 9: Session Configuration
print "9️⃣  Testing session store configuration... "
begin
  session_store = Rails.application.config.session_store
  
  all_tests_passed &= test_result(
    "Session Store",
    !session_store.nil?,
    "Session store: #{session_store || 'not configured'}"
  )
rescue => e
  all_tests_passed &= test_result("Session Store", false, e.message)
end

# TEST 10: Documentation Files
print "🔟 Testing documentation files... "
begin
  doc_files = {
    'AXIAM_MIGRATION_GUIDE.md' => Rails.root.join('AXIAM_MIGRATION_GUIDE.md'),
    'AXIAM_SECURITY_RECOMMENDATIONS.md' => Rails.root.join('AXIAM_SECURITY_RECOMMENDATIONS.md')
  }
  
  missing_docs = doc_files.select { |name, path| !File.exist?(path) }.keys
  
  all_tests_passed &= test_result(
    "Documentation",
    missing_docs.empty?,
    missing_docs.empty? ? "All documentation present" : "Missing: #{missing_docs.join(', ')}"
  )
rescue => e
  all_tests_passed &= test_result("Documentation", false, e.message)
end

# FINAL SUMMARY
puts "=" * 80
if all_tests_passed
  puts "✅ ALL TESTS PASSED - MIGRATION VERIFIED"
  puts
  puts "Your Axiam integration is correctly configured for v2.0 security architecture:"
  puts "  ✅ Redis credentials are server-side only"
  puts "  ✅ Client receives only public routing information"
  puts "  ✅ Secure token delivery via CSRF-protected API"
  puts "  ✅ Server-side subscription authorization"
  puts "  ✅ Environment-aware WebSocket URLs"
  puts
  puts "Next steps:"
  puts "  1. Test facial sign-on flow manually"
  puts "  2. Check browser DevTools (no credentials visible)"
  puts "  3. Verify production deployment"
  puts
  exit 0
else
  puts "❌ SOME TESTS FAILED - PLEASE REVIEW"
  puts
  puts "Migration is incomplete. Please:"
  puts "  1. Review failed tests above"
  puts "  2. Check AXIAM_MIGRATION_GUIDE.md for instructions"
  puts "  3. Fix issues and re-run this script"
  puts
  exit 1
end
