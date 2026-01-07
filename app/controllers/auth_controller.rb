# frozen_string_literal: true

class AuthController < ActionController::Base
  # GET /auth/microsoft/callback
  # OmniAuth callback after successful Azure AD login
  def callback
    auth = request.env['omniauth.auth']
    
    # Store user info in session
    session[:user_email] = auth.info.email
    session[:user_name] = auth.info.name
    session[:user_id] = auth.uid
    
    # Note: ไม่เก็บ OAuth token ใน session เพราะใหญ่เกิน 4KB (CookieOverflow)
    # ใช้ PAT จาก ENV แทนสำหรับ Azure DevOps API
    
    # Redirect to root (Rails view)
    redirect_to "/?logged_in=true&name=#{CGI.escape(auth.info.name || '')}"
  end
  
  # GET /auth/failure
  # Handle authentication failures
  def failure
    error_message = params[:message] || 'Unknown error'
    redirect_to "/?error=#{CGI.escape(error_message)}"
  end
  
  # DELETE /auth/logout
  # Clear session and logout
  def logout
    reset_session
    redirect_to "/?logged_out=true"
  end
  
  # GET /auth/user
  # Return current user info as JSON
  def user
    if session[:user_email]
      render json: {
        logged_in: true,
        email: session[:user_email],
        name: session[:user_name]
      }
    else
      render json: { logged_in: false }
    end
  end
end
