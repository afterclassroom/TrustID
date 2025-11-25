require 'net/http'
require 'uri'
require 'json'

class AxiamApi
  # API URLs - Environment-specific configuration
  # Development: http://localhost:3000 (Axiam Docker)
  # Production: https://axiam.io/api
  API_BASE = ENV.fetch('AXIAM_API_BASE', 'http://localhost:3000')
  AUTH_URL = "#{API_BASE}/api/v1/facial_sign_on/application_auth"
  
  # Credentials - Must be obtained from Axiam Admin
  # Development: Request dev credentials for localhost
  # Production: Request production credentials for veritrustai.net
  API_KEY = ENV.fetch('AXIAM_API_KEY', '')
  SECRET_KEY = ENV.fetch('AXIAM_SECRET_KEY', '')
  
  # Domain - Must match Site.domain in Axiam database
  # Development: localhost
  # Production: veritrustai.net
  DOMAIN = ENV.fetch('AXIAM_DOMAIN', 'localhost')

  # Cache authenticated_token với expires_in từ API response (default 720 hours = 30 days)
  def self.authenticated_token(force_refresh: false)
    cache_key = "axiam_authenticated_token_#{DOMAIN}"
    
    if force_refresh
      Rails.cache.delete(cache_key)
    end
    
    Rails.cache.fetch(cache_key, expires_in: 29.days) do
      uri = URI(AUTH_URL)
      headers = { "Content-Type" => "application/json" }
      
      request_body = { 
        api_key: API_KEY, 
        secret_key: SECRET_KEY, 
        domain: DOMAIN
      }
      
      res = Net::HTTP.post(uri, request_body.to_json, headers)

      if res.code.to_i >= 400
        Rails.logger.error "[AxiamApi] Auth failed. Response: #{res.body}"
        raise "Axiam authentication failed: HTTP #{res.code}"
      end
      
      json = JSON.parse(res.body) rescue nil
      
      if json && json['success'] && json['data'] && json['data']['authenticated_token']
        token = json['data']['authenticated_token']
        expires_in = json['data']['expires_in'] || 2592000 # Default 30 days
        
        # Re-cache with correct expiration from API
        Rails.cache.write(cache_key, token, expires_in: expires_in.seconds)
        
        Rails.logger.info "[AxiamApi] Authenticated successfully. Token expires in #{expires_in}s"
        token
      else
        error_msg = json && json['message'] ? json['message'] : 'Unknown error'
        Rails.logger.error "[AxiamApi] Failed to get authenticated_token: #{error_msg}"
        raise "Failed to authenticate with Axiam API: #{error_msg}"
      end
    end
  end

  # Step 2: Lookup client by email
  def self.lookup_client(email:)
    path = '/api/v1/facial_sign_on/login/lookup_client'
    response = api_post(path, { email: email })
    
    if response['success']
      Rails.logger.info "[AxiamApi] Client found: #{email}"
      response
    else
      Rails.logger.warn "[AxiamApi] Client lookup failed: #{response['message']}"
      response
    end
  end

  # Step 3: Push notification to mobile app
  def self.push_notification(client_id:)
    path = '/api/v1/facial_sign_on/login/push_notification'
    response = api_post(path, { id: client_id })
    
    if response['success']
      verification_token = response.dig('data', 'verification_token')
      Rails.logger.info "[AxiamApi] Push notification sent. Token: #{verification_token}"
      response
    else
      Rails.logger.error "[AxiamApi] Push notification failed: #{response['message']}"
      response
    end
  end


  # Gọi API với Bearer token
  def self.api_post(path, body = {}, retry_auth: true)
    uri = URI.join(API_BASE, path)
    req = Net::HTTP::Post.new(uri)
    req['Authorization'] = "Bearer #{authenticated_token}"
    req['Content-Type'] = 'application/json'
    req.body = body.to_json
    
    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request(req)
    end
    
    parsed = JSON.parse(res.body)
    
    # If token invalid (401/403), retry once with fresh token
    if retry_auth && [401, 403].include?(res.code.to_i)
      Rails.logger.warn "[AxiamApi] Token may be expired, refreshing..."
      authenticated_token(force_refresh: true)
      return api_post(path, body, retry_auth: false) # Retry once
    end
    
    parsed
  rescue JSON::ParserError => e
    Rails.logger.error "[AxiamApi] JSON parse error: #{e.message}, body: #{res.body}"
    { 'success' => false, 'message' => 'Invalid API response', 'user_message' => 'Server error. Please try again.' }
  end

  def self.api_get(path, retry_auth: true)
    uri = URI.join(API_BASE, path)
    req = Net::HTTP::Get.new(uri)
    req['Authorization'] = "Bearer #{authenticated_token}"
    
    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request(req)
    end
    
    parsed = JSON.parse(res.body)
    
    # If token invalid, retry once with fresh token
    if retry_auth && [401, 403].include?(res.code.to_i)
      Rails.logger.warn "[AxiamApi] Token may be expired, refreshing..."
      authenticated_token(force_refresh: true)
      return api_get(path, retry_auth: false)
    end
    
    parsed
  rescue JSON::ParserError => e
    Rails.logger.error "[AxiamApi] JSON parse error: #{e.message}"
    { 'success' => false, 'message' => 'Invalid API response' }
  end


  # Upload file facial (multipart/form-data) - Legacy method for facial signup
  def self.upload_facial(path, axiam_uid, avatar)
    uri = URI.join(API_BASE, path)
    req = Net::HTTP::Post.new(uri)
    req['Authorization'] = "Bearer #{authenticated_token}"
    form_data = [['id', axiam_uid]]
    
    # Lấy file từ ActiveStorage::Attached::One
    if avatar.attached?
      file = avatar.download
      filename = avatar.filename.to_s
      content_type = avatar.content_type
      form_data << ['facial', file, { filename: filename, content_type: content_type }]
    end
    
    req.set_form(form_data, 'multipart/form-data')
    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") { |http| http.request(req) }
    JSON.parse(res.body)
  end

  # Create client for facial signup - Legacy method
  def self.create_client(email:, full_name:)
    api_post('/api/v1/facial_sign_on/client/create', {
      email: email,
      full_name: full_name
    })
  end

  # Generate QR code - Legacy method
  def self.generate_qrcode(client_id:, action: 'login')
    api_post('/api/v1/facial_sign_on/client/qrcode', {
      id: client_id,
      flow_type: action
    })
  end
end