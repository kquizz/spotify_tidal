class TidalAuthController < ApplicationController
  def request_authorization
    # Generate PKCE code_verifier (43-128 characters, URL-safe)
    code_verifier = SecureRandom.urlsafe_base64(64)
    
    # Create code_challenge by SHA256 hashing and base64url encoding
    code_challenge = Base64.urlsafe_encode64(
      Digest::SHA256.digest(code_verifier),
      padding: false
    )
    
    # Store code_verifier in session for token exchange
    session[:tidal_code_verifier] = code_verifier
    
    query_params = {
      client_id: ENV["TIDAL_CLIENT_ID"],
      redirect_uri: tidal_callback_url,
      response_type: "code",
      scope: "user.read collection.read search.read playlists.read playlists.write collection.write",
      code_challenge: code_challenge,
      code_challenge_method: "S256"
    }
    redirect_to "https://login.tidal.com/authorize?#{query_params.to_query}", allow_other_host: true
  end

  def callback
    if params[:code]
      # Retrieve code_verifier from session
      code_verifier = session[:tidal_code_verifier]
      
      unless code_verifier
        redirect_to root_path, alert: "Tidal authentication failed: missing code verifier."
        return
      end
      
      service = TidalService.new
      tokens = service.exchange_code_for_token(params[:code], tidal_callback_url, code_verifier)

      # Clear code_verifier from session
      session.delete(:tidal_code_verifier)

      if tokens
        Current.user.update!(
          tidal_access_token: tokens["access_token"],
          tidal_refresh_token: tokens["refresh_token"],
          tidal_expires_at: Time.current + tokens["expires_in"].to_i.seconds
        )
        redirect_to root_path, notice: "Successfully connected to Tidal!"
      else
        redirect_to root_path, alert: "Failed to connect to Tidal."
      end
    else
      redirect_to root_path, alert: "Tidal authentication failed."
    end
  end

  private

  def tidal_callback_url
    "#{request.base_url}/auth/tidal/callback"
  end
end
