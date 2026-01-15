# frozen_string_literal: true

require "securerandom"

class AuthController < ActionController::Base
  FRONTEND_URL = ENV.fetch("FRONTEND_URL", "http://localhost:4200")
  ELECTRON_URL = "banana-ai://callback"

  # GET /auth/login
  # Entry point to set session state before OAuth redirect
  def login
    # Store electron state in session since OAuth callback query params might be lost
    if params[:electron] == "true"
      session[:is_electron] = true
    end
    
    # Needs to be a POST request to /auth/microsoft due to OmniAuth security settings
    # So we render a simple form that auto-submits
    render inline: <<-HTML
      <html>
        <head><title>Redirecting...</title></head>
        <body onload="document.getElementById('login-form').submit();">
          <form id="login-form" action="/auth/microsoft" method="post">
            <input type="hidden" name="authenticity_token" value="#{form_authenticity_token}">
          </form>
          <p>Redirecting to Microsoft Login...</p>
        </body>
      </html>
    HTML
  end

  # GET /auth/microsoft/callback
  # OmniAuth callback after successful Azure AD login
  def callback
    auth = request.env["omniauth.auth"]
    auth_token = SecureRandom.hex(32)

    user_data = {
      email: auth.info.email,
      name: auth.info.name,
      user_id: auth.uid,
      ado_token: auth.credentials&.token
    }

    Rails.cache.write("auth_token_#{auth_token}", user_data)
    Rails.logger.info "✅ Auth token generated for user: #{auth.info.email}"

    # Check if request came from Electron (via session or params)
    is_electron = session[:is_electron] == true || params[:electron] == "true"
    
    # Clear session flag
    session.delete(:is_electron)

    if is_electron
      redirect_to build_electron_redirect_url(auth_token, auth.info), allow_other_host: true
    else
      redirect_to build_success_redirect_url(auth_token, auth.info), allow_other_host: true
    end
  end

  # GET /auth/failure
  # Handle authentication failures
  def failure
    error_message = params[:message] || "Unknown error"
    redirect_to "#{FRONTEND_URL}?error=#{CGI.escape(error_message)}", allow_other_host: true
  end

  # DELETE /auth/logout
  # Clear session and logout
  def logout
    token = extract_token
    Rails.cache.delete("auth_token_#{token}") if token
    
    if params[:electron] == "true"
      redirect_to "#{ELECTRON_URL}?logged_out=true", allow_other_host: true
    else
      redirect_to "#{FRONTEND_URL}?logged_out=true", allow_other_host: true
    end
  end

  # GET /auth/user
  # Return current user info as JSON (accepts token via header)
  def user
    user_data = get_current_user_from_token

    if user_data
      render json: {
        logged_in: true,
        email: user_data[:email],
        name: user_data[:name]
      }
    else
      render json: { logged_in: false }
    end
  end

  private

  def build_success_redirect_url(auth_token, info)
    name = CGI.escape(info.name || "")
    email = CGI.escape(info.email || "")
    "#{FRONTEND_URL}?token=#{auth_token}&name=#{name}&email=#{email}"
  end

  def build_electron_redirect_url(auth_token, info)
    name = CGI.escape(info.name || "")
    email = CGI.escape(info.email || "")
    "#{ELECTRON_URL}?token=#{auth_token}&name=#{name}&email=#{email}"
  end

  def extract_token
    auth_header = request.headers["Authorization"]
    return auth_header.sub("Bearer ", "") if auth_header&.start_with?("Bearer ")

    params[:token]
  end

  def get_current_user_from_token
    token = extract_token
    return nil unless token

    Rails.cache.read("auth_token_#{token}")
  end
end
