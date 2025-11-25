require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Ensures that a master key has been made available in ENV["RAILS_MASTER_KEY"], config/master.key, or an environment
  # key such as config/credentials/production.key. This key is used to decrypt credentials (and other encrypted files).
  # config.require_master_key = true

  # Disable serving static files from `public/`, relying on NGINX/Apache to do so instead.
  # config.public_file_server.enabled = false

  # Compress CSS using a preprocessor.
  # config.assets.css_compressor = :sass

  # Do not fall back to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for Apache
  # config.action_dispatch.x_sendfile_header = "X-Accel-Redirect" # for NGINX

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Mount Action Cable outside main process or domain.
  # config.action_cable.mount_path = nil
  # config.action_cable.url = "wss://example.com/cable"
  # config.action_cable.allowed_request_origins = [ "http://example.com", /http:\/\/example.*/ ]

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # Can be used together with config.force_ssl for Strict-Transport-Security and secure cookies.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Log to file in production (traditional approach)
  # If you prefer logging to STDOUT for Docker, change this back to:
  # config.logger = ActiveSupport::Logger.new(STDOUT)
  config.logger = ActiveSupport::Logger.new("log/#{Rails.env}.log")
    .tap  { |logger| logger.formatter = ::Logger::Formatter.new }
    .then { |logger| ActiveSupport::TaggedLogging.new(logger) }

  # Prepend all log lines with the following tags.
  config.log_tags = [ :request_id ]

  # "info" includes generic and useful information about system operation, but avoids logging too much
  # information to avoid inadvertent exposure of personally identifiable information (PII). If you
  # want to log everything, set the level to "debug".
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Use a different cache store in production.
  # For production, use Redis to ensure cache is shared across processes/servers
  # and persists across restarts (important for Axiam authenticated_token caching)
  if ENV["REDIS_URL"].present?
    config.cache_store = :redis_cache_store, {
      url: ENV["REDIS_URL"],
      namespace: "veritrustai_cache",
      expires_in: 90.minutes,
      pool: { size: 5, timeout: 5 },
      reconnect_attempts: 3,
      error_handler: -> (method:, returning:, exception:) {
        # Log to STDERR since Rails.logger not available yet during initialization
        $stderr.puts "[Redis Cache] Error in #{method}: #{exception.message}"
      }
    }
  else
    # Fallback to memory store if Redis not available
    # Use $stderr since Rails.logger not initialized yet
    $stderr.puts "[WARNING] REDIS_URL not set, using memory store (not recommended for production with multiple processes)"
    config.cache_store = :memory_store, { size: 64.megabytes }
  end

  # Use a real queuing backend for Active Job (and separate queues per environment).
  # config.active_job.queue_adapter = :resque
  # config.active_job.queue_name_prefix = "app_production"

  config.action_mailer.perform_caching = false

  # Amazon SES SMTP Configuration
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: ENV.fetch('SMTP_ADDRESS', 'email-smtp.us-east-1.amazonaws.com'),
    port: ENV.fetch('SMTP_PORT', 587).to_i,
    domain: ENV.fetch('SMTP_DOMAIN', 'axiam.io'),
    user_name: ENV['SMTP_USERNAME'],
    password: ENV['SMTP_PASSWORD'],
    authentication: :login,
    enable_starttls_auto: true
  }
  config.action_mailer.raise_delivery_errors = true
  # Update default_url_options based on your production domain
  config.action_mailer.default_url_options = { 
    host: ENV.fetch('APP_HOST', 'veritrustai.net'), 
    protocol: 'https' 
  }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Enable DNS rebinding protection and other `Host` header attacks.
  # Allow the public production host so Rails HostAuthorization doesn't block requests
  config.hosts << "webclient.axiam.io"
  config.hosts << "teranet.axiam.io"
  config.hosts << "veritrustai.net"  # VeriTrust production domain
  config.hosts << "www.veritrustai.net"  # VeriTrust with www
  config.hosts << "167.71.206.103"
  # Allow localhost and loopback for reverse-proxy/healthchecks on this host
  config.hosts << "127.0.0.1"
  config.hosts << "localhost"
  # If you need to allow multiple hosts or patterns, you can set an array or regexes, e.g.:
  # config.hosts = ["example.com", /.*\.example\.com/]
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
