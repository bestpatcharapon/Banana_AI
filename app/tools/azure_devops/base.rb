# frozen_string_literal: true

require "net/http"
require "json"
require "base64"
require "uri"

module AzureDevops
  # Shared configuration and helper methods for all Azure DevOps modules
  module Base
    ORGANIZATION = ENV.fetch("AZURE_DEVOPS_ORGANIZATION", "bananacoding")
    PAT = ENV.fetch("AZURE_DEVOPS_PAT", "")

    # Instance methods (available when module is included)
    attr_accessor :access_token
    
    def encode_path(str)
      URI.encode_www_form_component(str).gsub("+", "%20")
    end

    def api_request(method, url, body = nil, content_type = "application/json")
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = case method
                when :get then Net::HTTP::Get.new(uri)
                when :post then Net::HTTP::Post.new(uri)
                when :patch then Net::HTTP::Patch.new(uri)
                when :delete then Net::HTTP::Delete.new(uri)
                end

      if access_token
        # Use Bearer Token (On-Behalf-Of Flow)
        request["Authorization"] = "Bearer #{access_token}"
      else
        # Use PAT (Basic Auth)
        credentials = Base64.strict_encode64(":#{AzureDevops::Base::PAT}")
        request["Authorization"] = "Basic #{credentials}"
      end
      
      request["Content-Type"] = content_type

      request.body = body.is_a?(String) ? body : body.to_json if body

      response = http.request(request)

      if response.code.to_i >= 200 && response.code.to_i < 300
        JSON.parse(response.body) rescue {}
      else
        raise "API Error (#{response.code}): #{response.body[0..200]}"
      end
    end

    def success_response(text)
      MCP::Tool::Response.new([{ type: "text", text: text }])
    end

    def error_response(text)
      MCP::Tool::Response.new([{ type: "text", text: "❌ #{text}" }])
    end
  end
end
