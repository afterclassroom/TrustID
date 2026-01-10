module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_site, :connection_id, :jwt_payload

    def connect
      self.connection_id = SecureRandom.uuid
      
      # ✨ NEW: JWT authentication (preferred method)
      jwt_token = request.params[:token]
      
      if jwt_token.present?
        begin
          self.jwt_payload = verify_jwt_token(jwt_token)
          self.current_site = find_site_from_jwt
          Rails.logger.info("[ActionCable] ✅ JWT authentication successful for site_id=#{current_site&.id}, connection_id=#{connection_id}")
        rescue JWT::DecodeError => e
          Rails.logger.error("[ActionCable] ❌ JWT authentication failed: #{e.message}")
          reject_unauthorized_connection
        end
      else
        # LEGACY: channel_prefix fallback (deprecated)
        channel_prefix = request.params[:channel_prefix]
        
        if channel_prefix.present?
          self.current_site = find_verified_site_legacy(channel_prefix)
          self.jwt_payload = nil
          Rails.logger.warn("[ActionCable] ⚠️ Using deprecated channel_prefix authentication for site_id=#{current_site&.id}")
        else
          Rails.logger.error("[ActionCable] ❌ No authentication provided (token or channel_prefix)")
          reject_unauthorized_connection
        end
      end
    rescue => e
      Rails.logger.error("[ActionCable] ❌ Connection error: #{e.message}")
      reject_unauthorized_connection
    end

    private

    # ✨ NEW: Strong JWT validation
    def verify_jwt_token(token)
      # 1. Decode JWT with signature verification
      payload = JWT.decode(
        token, 
        jwt_secret, 
        true, 
        { algorithm: 'HS256' }
      )[0]
      
      # 2. Check revocation status (if JwtRevocationService exists)
      if defined?(JwtRevocationService) && JwtRevocationService.revoked?(token)
        raise JWT::DecodeError.new('Token has been revoked')
      end
      
      # 3. Validate token expiration
      if payload['exp'].present?
        exp_time = Time.at(payload['exp'])
        if Time.current > exp_time
          raise JWT::DecodeError.new('Token has expired')
        end
      end
      
      # 4. IP binding validation (optional - disabled for application tokens per docs)
      # Note: IP binding removed for application JWT tokens to support backend-to-frontend flow
      # Uncomment if needed for other JWT implementations:
      # if payload['ip_address'].present? && ENV['JWT_IP_BINDING_ENABLED'] == 'true'
      #   unless validate_ip_match(payload['ip_address'], request.remote_ip)
      #     raise JWT::DecodeError.new('IP address mismatch')
      #   end
      # end
      
      payload
    end

    def find_site_from_jwt
      site_id = jwt_payload['site_id']
      
      unless site_id.present?
        raise JWT::DecodeError.new('Missing site_id in token payload')
      end
      
      # Try to find Site model (if exists in VeriTrust)
      # If VeriTrust doesn't have Site model, we can store site_id in jwt_payload for validation
      if defined?(Site)
        Site.find(site_id)
      else
        # For applications without Site model, just validate site_id exists
        # You can add custom validation here
        OpenStruct.new(id: site_id) # Temporary placeholder
      end
    rescue ActiveRecord::RecordNotFound
      raise JWT::DecodeError.new('Invalid site_id in token')
    end

    def jwt_secret
      # Use Axiam's SECRET_KEY for JWT verification (must match Axiam's signing key)
      ENV['AXIAM_SECRET_KEY'] || ENV['JWT_SECRET_KEY'] || Rails.application.secret_key_base
    end

    def validate_ip_match(token_ip, request_ip)
      # Exact match
      return true if token_ip == request_ip
      
      # /24 subnet tolerance (e.g., 192.168.1.x matches 192.168.1.y)
      token_subnet = token_ip.split('.')[0..2].join('.')
      request_subnet = request_ip.split('.')[0..2].join('.')
      token_subnet == request_subnet
    end

    # DEPRECATED: Legacy channel_prefix authentication
    def find_verified_site_legacy(channel_prefix)
      # For VeriTrust without Site model, we just log the channel_prefix
      # Axiam will handle the validation on their side
      Rails.logger.info("[ActionCable] Legacy auth with channel_prefix=#{channel_prefix}")
      
      # If you have Site model:
      # Site.find_by(channel_prefix: channel_prefix) || reject_unauthorized_connection
      
      # Placeholder for apps without Site model
      OpenStruct.new(id: 0, channel_prefix: channel_prefix)
    end
  end
end
