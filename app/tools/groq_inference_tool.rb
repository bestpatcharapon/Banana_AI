# frozen_string_literal: true

require "net/http"
require "json"

class GroqInferenceTool < MCP::Tool
  API_ENDPOINT = "https://api.groq.com/openai/v1/chat/completions"
  DEFAULT_TEMPERATURE = 0.7

  tool_name "groq-inference-tool"
  description "Perform LLM inference using Groq API. Supported models include 'llama-3.3-70b-versatile', 'llama-3.1-8b-instant', 'mixtral-8x7b-32768', etc."

  input_schema(
    properties: {
      model: {
        type: "string",
        description: "The model ID to use (e.g., 'llama-3.3-70b-versatile', 'llama-3.1-8b-instant')"
      },
      prompt: {
        type: "string",
        description: "The user prompt to send to the model"
      },
      system_prompt: {
        type: "string",
        description: "Optional system prompt to set context/behavior"
      },
      temperature: {
        type: "number",
        description: "Sampling temperature (0.0 to 1.0). Default is 0.7."
      }
    },
    required: [:model, :prompt]
  )

  def self.call(model: nil, prompt: nil, system_prompt: nil, temperature: DEFAULT_TEMPERATURE, server_context:)
    api_key = ENV["GROQ_API_KEY"]

    return missing_api_key_response unless api_key

    response = make_api_request(api_key, model, prompt, system_prompt, temperature)
    parse_response(response)
  rescue StandardError => e
    error_response("Internal Error: #{e.message}")
  end

  class << self
    private

    def missing_api_key_response
      error_response("GROQ_API_KEY environment variable is not set. Please set it to use this tool.")
    end

    def make_api_request(api_key, model, prompt, system_prompt, temperature)
      uri = URI(API_ENDPOINT)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = build_request(uri, api_key, model, prompt, system_prompt, temperature)
      http.request(request)
    end

    def build_request(uri, api_key, model, prompt, system_prompt, temperature)
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{api_key}"
      request["Content-Type"] = "application/json"
      request.body = build_payload(model, prompt, system_prompt, temperature).to_json
      request
    end

    def build_payload(model, prompt, system_prompt, temperature)
      messages = []
      messages << { role: "system", content: system_prompt } if system_prompt && !system_prompt.empty?
      messages << { role: "user", content: prompt }

      {
        model: model,
        messages: messages,
        temperature: temperature.to_f
      }
    end

    def parse_response(response)
      if response.is_a?(Net::HTTPSuccess)
        parsed = JSON.parse(response.body)
        content = parsed.dig("choices", 0, "message", "content")
        success_response(content)
      else
        error_response("Groq API Error: #{response.code} #{response.message} - #{response.body}")
      end
    end

    def success_response(text)
      MCP::Tool::Response.new([{ type: "text", text: text }])
    end

    def error_response(text)
      MCP::Tool::Response.new([{ type: "text", text: "Error: #{text}" }])
    end
  end
end
