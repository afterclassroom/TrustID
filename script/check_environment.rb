#!/usr/bin/env ruby
# frozen_string_literal: true

# VeriTrust Environment Checker
# Usage: ruby script/check_environment.rb

puts "\n" + "="*80
puts "VeriTrust Environment Checker"
puts "="*80 + "\n"

# Color codes
GREEN = "\e[32m"
RED = "\e[31m"
YELLOW = "\e[33m"
RESET = "\e[0m"

def check_pass(message)
  puts "#{GREEN}✓#{RESET} #{message}"
end

def check_fail(message)
  puts "#{RED}✗#{RESET} #{message}"
end

def check_warn(message)
  puts "#{YELLOW}⚠#{RESET} #{message}"
end

# Check Rails environment
puts "\n1. Rails Environment:"
puts "-" * 80
rails_env = ENV['RAILS_ENV'] || 'development'
puts "Environment: #{rails_env}"
check_pass("Rails environment detected: #{rails_env}")

# Check required environment variables
puts "\n2. Axiam Configuration:"
puts "-" * 80

required_vars = {
  'AXIAM_API_BASE' => 'Axiam API Base URL',
  'AXIAM_API_KEY' => 'Axiam API Key',
  'AXIAM_SECRET_KEY' => 'Axiam Secret Key',
  'AXIAM_DOMAIN' => 'Axiam Domain',
  'AXIAM_CABLE_URL' => 'Axiam Cable URL'
}

all_present = true
required_vars.each do |var, description|
  value = ENV[var]
  if value.nil? || value.empty?
    check_fail("#{description} (#{var}) is not set")
    all_present = false
  else
    # Mask sensitive values
    display_value = var.include?('SECRET') || var.include?('KEY') ? 
      "#{value[0..3]}***#{value[-4..-1]}" : value
    check_pass("#{description}: #{display_value}")
  end
end

# Check environment-specific values
puts "\n3. Environment-Specific Validation:"
puts "-" * 80

api_base = ENV['AXIAM_API_BASE']
cable_url = ENV['AXIAM_CABLE_URL']
domain = ENV['AXIAM_DOMAIN']

if rails_env == 'development'
  # Development checks
  if api_base == 'http://localhost:3000'
    check_pass("Development API base is correct")
  else
    check_warn("Expected http://localhost:3000 for development, got: #{api_base}")
  end
  
  if cable_url&.start_with?('ws://')
    check_pass("Development cable URL uses WS (non-secure)")
  else
    check_warn("Development should use ws:// not wss://")
  end
  
  if domain == 'localhost'
    check_pass("Development domain is correct")
  else
    check_warn("Expected 'localhost' for development domain, got: #{domain}")
  end
  
elsif rails_env == 'production'
  # Production checks
  if api_base == 'https://axiam.io/api'
    check_pass("Production API base is correct")
  else
    check_fail("Expected https://axiam.io/api for production, got: #{api_base}")
  end
  
  if cable_url&.start_with?('wss://')
    check_pass("Production cable URL uses WSS (secure)")
  else
    check_fail("Production MUST use wss:// not ws://")
  end
  
  if domain == 'veritrustai.net'
    check_pass("Production domain is correct")
  else
    check_fail("Expected 'veritrustai.net' for production domain, got: #{domain}")
  end
end

# Check database configuration
puts "\n4. Database Configuration:"
puts "-" * 80

db_config = {
  'DB_HOST' => ENV['DB_HOST'],
  'DB_PORT' => ENV['DB_PORT'],
  'DB_NAME' => ENV['DB_NAME'],
  'DB_USERNAME' => ENV['DB_USERNAME']
}

db_config.each do |key, value|
  if value.nil? || value.empty?
    check_warn("#{key} not set (may be using database.yml)")
  else
    display_value = key == 'DB_PASSWORD' ? '***' : value
    check_pass("#{key}: #{display_value}")
  end
end

# Check Redis
puts "\n5. Redis Configuration:"
puts "-" * 80

redis_url = ENV['REDIS_URL']
if redis_url.nil? || redis_url.empty?
  check_warn("REDIS_URL not set (may be using default)")
else
  check_pass("REDIS_URL: #{redis_url}")
end

# Check email configuration
puts "\n6. Email Configuration (Optional):"
puts "-" * 80

email_vars = {
  'SENDGRID_SMTP_USERNAME' => ENV['SENDGRID_SMTP_USERNAME'],
  'SENDGRID_SMTP_PASSWORD' => ENV['SENDGRID_SMTP_PASSWORD'],
  'SMTP_USERNAME' => ENV['SMTP_USERNAME'],
  'SMTP_PASSWORD' => ENV['SMTP_PASSWORD'],
  'EMAIL_FROM' => ENV['EMAIL_FROM']
}

email_configured = email_vars.values.any? { |v| !v.nil? && !v.empty? }

if email_configured
  email_vars.each do |key, value|
    next if value.nil? || value.empty?
    display_value = key.include?('PASSWORD') ? '***' : value
    check_pass("#{key}: #{display_value}")
  end
else
  check_warn("Email not configured (emails will not be sent)")
end

# Summary
puts "\n" + "="*80
puts "Summary:"
puts "="*80

if all_present
  check_pass("All required environment variables are set")
  puts "\n#{GREEN}Environment is ready!#{RESET}"
  
  if rails_env == 'development'
    puts "\nNext steps:"
    puts "1. Ensure Axiam Docker container is running: docker ps | grep axiamai"
    puts "2. Test authentication: rails console"
    puts "   > AxiamApi.authenticated_token"
    puts "3. Access application: http://localhost:3030"
  elsif rails_env == 'production'
    puts "\nNext steps:"
    puts "1. Verify Axiam production credentials with Axiam support"
    puts "2. Test authentication: RAILS_ENV=production rails console"
    puts "   > AxiamApi.authenticated_token"
    puts "3. Check SSL certificate: https://veritrustai.net"
  end
else
  check_fail("Some required environment variables are missing")
  puts "\n#{RED}Please update your .env file or config/application.yml#{RESET}"
  puts "Reference: .env.example or SETUP_GUIDE.md"
  exit 1
end

puts "\n"
