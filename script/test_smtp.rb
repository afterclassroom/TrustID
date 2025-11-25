#!/usr/bin/env ruby
# Script to test SMTP connection and email sending

require 'net/smtp'

# SMTP Settings
smtp_address = ENV.fetch('SMTP_ADDRESS', 'email-smtp.us-east-1.amazonaws.com')
smtp_port = ENV.fetch('SMTP_PORT', 587).to_i
smtp_username = ENV['SMTP_USERNAME']
smtp_password = ENV['SMTP_PASSWORD']
smtp_domain = ENV.fetch('SMTP_DOMAIN', 'axiam.io')
from_email = ENV.fetch('MAILER_FROM', 'noreply@axiam.io')

puts "=" * 60
puts "Amazon SES SMTP Connection Test"
puts "=" * 60
puts "SMTP Address: #{smtp_address}"
puts "SMTP Port: #{smtp_port}"
puts "SMTP Username: #{smtp_username}"
puts "SMTP Domain: #{smtp_domain}"
puts "From Email: #{from_email}"
puts "=" * 60

# Test 1: TCP Connection
puts "\n[Test 1] Testing TCP connection to #{smtp_address}:#{smtp_port}..."
begin
  require 'socket'
  socket = Socket.tcp(smtp_address, smtp_port, connect_timeout: 5)
  socket.close
  puts "✅ TCP connection successful"
rescue => e
  puts "❌ TCP connection failed: #{e.message}"
  exit 1
end

# Test 2: SMTP Authentication
puts "\n[Test 2] Testing SMTP authentication..."
begin
  Net::SMTP.start(
    smtp_address,
    smtp_port,
    smtp_domain,
    smtp_username,
    smtp_password,
    :login,
    enable_starttls_auto: true,
    open_timeout: 10,
    read_timeout: 10
  ) do |smtp|
    puts "✅ SMTP authentication successful"
  end
rescue => e
  puts "❌ SMTP authentication failed: #{e.message}"
  puts "   Error class: #{e.class}"
  exit 1
end

# Test 3: Send test email
test_email = ARGV[0] || 'test@example.com'
puts "\n[Test 3] Sending test email to #{test_email}..."

message = <<~MESSAGE
  From: #{from_email}
  To: #{test_email}
  Subject: Test Email from Axiam Webclient
  
  This is a test email sent from the Axiam Webclient application.
  
  If you receive this, your SMTP configuration is working correctly!
  
  Timestamp: #{Time.now}
MESSAGE

begin
  Net::SMTP.start(
    smtp_address,
    smtp_port,
    smtp_domain,
    smtp_username,
    smtp_password,
    :login,
    enable_starttls_auto: true
  ) do |smtp|
    smtp.send_message(message, from_email, test_email)
  end
  puts "✅ Test email sent successfully to #{test_email}"
  puts "\nCheck your inbox (and spam folder) for the test email."
rescue => e
  puts "❌ Failed to send test email: #{e.message}"
  puts "   Error class: #{e.class}"
  exit 1
end

puts "\n" + "=" * 60
puts "All tests passed! SMTP is configured correctly."
puts "=" * 60
