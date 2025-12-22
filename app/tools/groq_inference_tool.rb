# frozen_string_literal: true
require "net/http"
require "json"

class GroqInferenceTool < MCP::Tool
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

  def self.call(model: nil, prompt: nil, system_prompt: nil, temperature: 0.7, server_context:)
    api_key = ENV['GROQ_API_KEY']
    
    unless api_key
      return MCP::Tool::Response.new([{ 
        type: "text", 
        text: "Error: GROQ_API_KEY environment variable is not set. Please set it to use this tool." 
      }])
    end

    uri = URI("https://api.groq.com/openai/v1/chat/completions")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    messages = []
    messages << { role: "system", content: system_prompt } if system_prompt && !system_prompt.empty?
    messages << { role: "user", content: prompt }

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{api_key}"
    request["Content-Type"] = "application/json"
    
    payload = {
      model: model,
      messages: messages,
      temperature: temperature.to_f
    }

    request.body = payload.to_json

    response = http.request(request)
    
    if response.is_a?(Net::HTTPSuccess)
      parsed = JSON.parse(response.body)
      content = parsed.dig("choices", 0, "message", "content")
      
      MCP::Tool::Response.new([{ type: "text", text: content }])
    else
      error_msg = "Groq API Error: #{response.code} #{response.message} - #{response.body}"
      MCP::Tool::Response.new([{ type: "text", text: error_msg }])
    end
  rescue StandardError => e
    MCP::Tool::Response.new([{ type: "text", text: "Internal Error: #{e.message}" }])
  end
end
