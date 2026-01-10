class JwtRevocationService
  # Redis-based JWT token revocation
  # Allows immediate invalidation of compromised tokens
  
  class << self
    # Revoke a JWT token
    # @param token [String] JWT token to revoke
    # @param reason [String] Reason for revocation (security_incident, user_logout, etc.)
    # @return [Boolean] true if successfully revoked
    def revoke_token(token, reason: 'manual_revocation')
      return false if token.blank?
      
      begin
        # Decode token to get expiration time
        payload = JWT.decode(token, nil, false)[0] rescue nil
        
        if payload.nil?
          Rails.logger.warn("[JwtRevocation] Cannot decode token for revocation")
          return false
        end
        
        # Get token expiration (ttl)
        exp_time = payload['exp']
        ttl = exp_time.present? ? (exp_time - Time.current.to_i) : 7200 # Default 2 hours
        
        # Only revoke if token hasn't expired yet
        if ttl > 0
          redis_key = redis_key_for_token(token)
          
          # Store revocation info
          redis.setex(
            redis_key,
            ttl, # TTL matches token expiration
            {
              site_id: payload['site_id'],
              revoked_at: Time.current.to_i,
              reason: reason
            }.to_json
          )
          
          Rails.logger.info("[JwtRevocation] ✅ Token revoked: site_id=#{payload['site_id']}, reason=#{reason}, ttl=#{ttl}s")
          true
        else
          Rails.logger.info("[JwtRevocation] Token already expired, no need to revoke")
          false
        end
      rescue Redis::BaseError => e
        Rails.logger.error("[JwtRevocation] Redis error during revocation: #{e.message}")
        false
      end
    end
    
    # Check if token is revoked
    # @param token [String] JWT token to check
    # @return [Boolean] true if token is revoked
    def revoked?(token)
      return false if token.blank?
      
      begin
        redis_key = redis_key_for_token(token)
        # ✅ FIX: redis.exists returns Integer (1 or 0), not Boolean
        redis.exists(redis_key) > 0
      rescue Redis::BaseError => e
        Rails.logger.error("[JwtRevocation] Redis error checking revocation: #{e.message}")
        # Fail-open: Don't block if Redis is down
        false
      end
    end
    
    # Get revocation details
    # @param token [String] JWT token
    # @return [Hash, nil] Revocation details or nil if not revoked
    def revocation_details(token)
      return nil if token.blank?
      
      begin
        redis_key = redis_key_for_token(token)
        data = redis.get(redis_key)
        
        if data.present?
          JSON.parse(data)
        else
          nil
        end
      rescue Redis::BaseError, JSON::ParserError => e
        Rails.logger.error("[JwtRevocation] Error getting revocation details: #{e.message}")
        nil
      end
    end
    
    # Revoke all tokens for a site
    # @param site_id [Integer] Site ID
    # @param reason [String] Reason for mass revocation
    # @return [Integer] Number of tokens revoked
    def revoke_all_for_site(site_id, reason: 'site_compromised')
      # This requires scanning Redis for all tokens with matching site_id
      # For production, consider storing site-specific revocation flags
      Rails.logger.warn("[JwtRevocation] ⚠️ Mass revocation for site_id=#{site_id}, reason=#{reason}")
      
      # Store site-level revocation flag
      redis_key = "jwt_revocation:site:#{site_id}"
      redis.setex(redis_key, 7200, { revoked_at: Time.current.to_i, reason: reason }.to_json)
      
      Rails.logger.info("[JwtRevocation] ✅ All tokens for site_id=#{site_id} marked as revoked")
      1 # Return count (simplified)
    rescue Redis::BaseError => e
      Rails.logger.error("[JwtRevocation] Redis error during mass revocation: #{e.message}")
      0
    end
    
    # Check if entire site is revoked
    # @param site_id [Integer] Site ID
    # @return [Boolean] true if all tokens for site are revoked
    def site_revoked?(site_id)
      return false if site_id.blank?
      
      begin
        redis_key = "jwt_revocation:site:#{site_id}"
        redis.exists(redis_key) > 0
      rescue Redis::BaseError => e
        Rails.logger.error("[JwtRevocation] Redis error checking site revocation: #{e.message}")
        false
      end
    end
    
    private
    
    # Generate Redis key for token
    # Uses SHA256 hash of token to save space
    def redis_key_for_token(token)
      token_hash = Digest::SHA256.hexdigest(token)
      "jwt_revocation:token:#{token_hash}"
    end
    
    # Get Redis connection
    def redis
      @redis ||= begin
        if defined?(Redis)
          Redis.new(
            url: ENV['REDIS_URL'] || 'redis://localhost:6379/0',
            timeout: 1,
            reconnect_attempts: 3
          )
        else
          raise "Redis gem not available. Add 'gem redis' to Gemfile"
        end
      end
    end
  end
end
