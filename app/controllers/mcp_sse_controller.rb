# frozen_string_literal: true

require "thread"

class McpSseController < ActionController::Base
  include ActionController::Live
  skip_before_action :verify_authenticity_token

  PING_INTERVAL_SECONDS = 15
  POLL_INTERVAL_SECONDS = 0.1
  CONNECTIONS = Concurrent::Hash.new rescue {}

  # GET /mcp/sse - SSE endpoint for MCP Inspector
  def sse
    setup_sse_headers
    connection_id = SecureRandom.uuid
    message_queue = Queue.new

    register_connection(connection_id, message_queue)
    Rails.logger.info "🔗 MCP SSE connected: #{connection_id}"

    send_endpoint_url(connection_id)
    run_event_loop(connection_id, message_queue)
  rescue IOError, ActionController::Live::ClientDisconnected, Errno::EPIPE
    Rails.logger.info "🔌 MCP SSE disconnected: #{connection_id}"
  ensure
    cleanup_connection(connection_id)
  end

  # POST /mcp/message - Handle MCP messages
  def message
    connection_id = params[:connectionId]
    conn = CONNECTIONS[connection_id]

    unless conn
      Rails.logger.warn "❌ Connection not found: #{connection_id}"
      Rails.logger.warn "Active connections: #{CONNECTIONS.keys}"
      render json: { error: "Connection not found" }, status: :not_found
      return
    end

    request_body = request.body.read
    Rails.logger.info "📥 MCP Request: #{request_body[0..200]}"

    result = mcp_server.handle_json(request_body)
    Rails.logger.info "📤 MCP Response: #{result[0..200]}"

    conn[:queue].push(result)
    head :accepted
  rescue StandardError => e
    Rails.logger.error "❌ MCP Error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    render json: { error: e.message }, status: :internal_server_error
  end

  private

  def setup_sse_headers
    response.headers["Content-Type"] = "text/event-stream"
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    response.headers["Connection"] = "keep-alive"
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["X-Accel-Buffering"] = "no"
  end

  def register_connection(connection_id, message_queue)
    CONNECTIONS[connection_id] = {
      stream: response.stream,
      queue: message_queue,
      created_at: Time.now
    }
  end

  def cleanup_connection(connection_id)
    CONNECTIONS.delete(connection_id)
    response.stream.close rescue nil
  end

  def send_endpoint_url(connection_id)
    endpoint_url = "#{request.base_url}/mcp/message?connectionId=#{connection_id}"
    write_sse("endpoint", endpoint_url)
  end

  def run_event_loop(connection_id, message_queue)
    last_ping = Time.now

    loop do
      process_queued_messages(message_queue)
      last_ping = send_ping_if_needed(last_ping)
      sleep POLL_INTERVAL_SECONDS
    end
  end

  def process_queued_messages(message_queue)
    while !message_queue.empty?
      msg = message_queue.pop(true) rescue nil
      write_sse("message", msg) if msg
    end
  rescue ThreadError
    # Queue empty, continue
  end

  def send_ping_if_needed(last_ping)
    if Time.now - last_ping > PING_INTERVAL_SECONDS
      write_sse("ping", Time.now.to_i.to_s)
      Time.now
    else
      last_ping
    end
  end

  def write_sse(event, data)
    response.stream.write("event: #{event}\n")
    response.stream.write("data: #{data}\n\n")
  end

  def mcp_server
    @mcp_server ||= MCP::Server.new(
      name: "rails_mcp_server",
      version: "1.0.0",
      tools: MCP::Tool.descendants
    )
  end
end
