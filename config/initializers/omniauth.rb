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
      scope: 'openid profile email offline_access 499b84ac-1321-427f-aa17-267ca6975798/user_impersonation'
    }
end

# Allow GET requests for OAuth callbacks (needed for Azure AD)
OmniAuth.config.allowed_request_methods = [:post, :get]

# Silence GET deprecation warning
OmniAuth.config.silence_get_warning = true
