# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Angular development server
    origins 'http://localhost:4200', 'http://127.0.0.1:4200',
            # Production frontend (add your domain here)
            'https://banana-ai-frontend.netlify.app',
            # Rails itself (for embedded views)
            'http://localhost:3000', 'http://127.0.0.1:3000'

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true,  # Allow cookies for session
      max_age: 86400
  end
end
