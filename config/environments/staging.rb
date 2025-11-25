require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Inherit most settings from production
  config.cache_classes = true
  config.eager_load = true

  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?

  config.log_level = :info
  config.log_tags  = [ :request_id ]

  # SendGrid SMTP Configuration (port 2525 - bypasses DigitalOcean blocking)
  # Alternative to Gmail which is blocked on DigitalOcean
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: 'smtp.sendgrid.net',
    port: 2525,  # Alternative port that bypasses ISP blocking
    domain: 'axiam.io',
    user_name: ENV['SENDGRID_SMTP_USERNAME'],  # Always 'apikey'
    password: ENV['SENDGRID_SMTP_PASSWORD'],   # Your SendGrid API key
    authentication: :plain,
    enable_starttls_auto: true
  }
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.perform_caching = false
  config.action_mailer.default_url_options = { host: 'webclientstaging.axiam.io', protocol: 'https' }

  config.i18n.fallbacks = true

  config.active_support.deprecation = :notify

  config.log_formatter = ::Logger::Formatter.new

  # Show full error reports only if ENV is set
  config.consider_all_requests_local = ENV["STAGING_SHOW_ERRORS"].present?

  # Set host for staging
  config.hosts << "webclientstaging.axiam.io"
  config.hosts << "68.183.195.248"
  # staging-specific hosts only; keep production hosts in production.rb
  
  config.active_storage.service = :local

  # Add any other staging-specific configs here
end