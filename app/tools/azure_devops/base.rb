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
    API_VERSION = "7.0"

    attr_accessor :access_token

    def encode_path(str)
      URI.encode_www_form_component(str).gsub("+", "%20")
    end

    def api_request(method, url, body = nil, content_type = "application/json")
      uri = URI(url)
      http = build_http_client(uri)
      request = build_request(method, uri, body, content_type)

      response = http.request(request)
      parse_response(response)
    end

    def success_response(text)
      MCP::Tool::Response.new([{ type: "text", text: text }])
    end

    def error_response(text)
      MCP::Tool::Response.new([{ type: "text", text: "❌ #{text}" }])
    end

    private

    def build_http_client(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http
    end

    def build_request(method, uri, body, content_type)
      request = create_request_by_method(method, uri)
      set_authorization_header(request)
      request["Content-Type"] = content_type
      request.body = serialize_body(body) if body
      request
    end

    def create_request_by_method(method, uri)
      case method
      when :get then Net::HTTP::Get.new(uri)
      when :post then Net::HTTP::Post.new(uri)
      when :patch then Net::HTTP::Patch.new(uri)
      when :delete then Net::HTTP::Delete.new(uri)
      end
    end

    def set_authorization_header(request)
      if access_token
        request["Authorization"] = "Bearer #{access_token}"
      else
        credentials = Base64.strict_encode64(":#{PAT}")
        request["Authorization"] = "Basic #{credentials}"
      end
    end

    def serialize_body(body)
      body.is_a?(String) ? body : body.to_json
    end

    def parse_response(response)
      body_utf8 = ensure_utf8(response.body.to_s)

      if success_status?(response.code.to_i)
        JSON.parse(body_utf8) rescue {}
      else
        raise "API Error (#{response.code}): #{body_utf8[0..200]}"
      end
    end

    def ensure_utf8(str)
      str.force_encoding("UTF-8")
      return str if str.valid_encoding?

      str.encode("UTF-8", "binary", invalid: :replace, undef: :replace, replace: "")
    end

    def success_status?(code)
      code >= 200 && code < 300
    end
  end
end
