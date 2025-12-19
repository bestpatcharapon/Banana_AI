class TimeNowTool < MCP::Tool
  tool_name "time-now-tool"
  description "Get the current time."

  def self.call(server_context:)
    time_data = {
      "time" => Time.now.strftime("%Y-%m-%d %H:%M:%S")
    }
    MCP::Tool::Response.new([{ type: "text", text: time_data.to_json }])
  end
end