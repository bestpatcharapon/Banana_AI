class HealthCheckTool < MCP::Tool
  tool_name "health-check-tool"
  description "Check the health of the server."

  def self.call(server_context:)
    health_data = {
      "status" => "healthy",
      "version" => "1.0.0",
      "timestamp" => Time.now.utc.iso8601,
    }
    MCP::Tool::Response.new([{ 
      type: "text", 
      text: health_data.to_json 
    }])
  end
end