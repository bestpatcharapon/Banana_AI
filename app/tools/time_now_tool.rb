class TimeNowTool < MCP::Tool
  tool_name "time-now-tool"
  description "Get the current time."

  def self.call(server_context:)
    MCP::Tool::Response.new([{ type: "text", text: Time.now.strftime("%Y-%m-%d %H:%M:%S") }])
  end
end