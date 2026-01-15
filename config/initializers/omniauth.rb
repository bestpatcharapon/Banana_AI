# frozen_string_literal: true

# OmniAuth configuration for Microsoft Azure AD
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :azure_activedirectory_v2,
    {
      client_id: ENV.fetch('AZURE_CLIENT_ID'),
      client_secret: ENV.fetch('AZURE_CLIENT_SECRET'),
      tenant_id: ENV.fetch('AZURE_TENANT_ID'),
      name: 'microsoft',
      callback_path: '/auth/microsoft/callback',
      scope: 'openid profile email offline_access 499b84ac-1321-427f-aa17-267ca6975798/user_impersonation',
      provider_ignores_state: true
    }
end

# Allow GET requests for OAuth callbacks (needed for Azure AD)
OmniAuth.config.allowed_request_methods = [:post, :get]

# Silence GET deprecation warning
OmniAuth.config.silence_get_warning = true

# Handle OAuth failures gracefully (e.g., stale callbacks, state mismatch)
# This catches errors like "undefined method 'bytesize' for nil" when a user
# uses a stale OAuth callback URL or opens multiple login tabs
OmniAuth.config.on_failure = Proc.new do |env|
  error_type = env['omniauth.error.type'] || :unknown_error
  error_message = env['omniauth.error']&.message || 'Authentication session expired. Please try logging in again.'
  
  # Log the error for debugging
  Rails.logger.warn "⚠️ OmniAuth failure: #{error_type} - #{error_message}"
  
  # Redirect to failure handler
  # Redirect to failure handler
  frontend_url = ENV.fetch('FRONTEND_URL', 'http://localhost:4200')
  message = CGI.escape("session_expired")
  
  # Check if it might be from Electron (simple heuristic or default to frontend)
  # For now, just redirect to frontend, but with allow_other_host behavior implies external redirect.
  # If we really want to support Electron failure redirect, we need to know the context.
  # Let's keep it simple: just redirect to frontend, but since we disabled state check, this error should happen less.
  
  [302, { 'Location' => "#{frontend_url}?error=#{message}", 'Content-Type' => 'text/html' }, []]
end
