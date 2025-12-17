class HealthCheckTool < MCP::Tool
  tool_name "health-check-tool"
  description "Check the health of the server."

  def self.call(server_context:)
    MCP::Tool::Response.new([{ type: "text", text: "Server is healthy." }])
  end
end