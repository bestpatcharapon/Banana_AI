# frozen_string_literal: true
# encoding: UTF-8

# Controller for fetching user's tasks from Azure DevOps
class Api::MyTasksController < ActionController::Base
  skip_before_action :verify_authenticity_token
  before_action :set_cors_headers

  EMPTY_PROJECT = "ไม่พบโปรเจค"
  NO_PULL_REQUESTED = "ไม่มีงานที่อยู่ใน Pull Requested 🎉"
  FETCH_ERROR = "ไม่สามารถดึงงาน Pull Requested ได้"

  # GET /api/my_tasks - Main endpoint for fetching user tasks
  def index
    user_data = get_current_user

    unless user_data
      render json: {
        error: "Please login with Microsoft 365 first",
        login_url: "/auth/microsoft"
      }, status: :unauthorized
      return
    end

    user_identifier = user_data[:name] || user_data[:email]
    sections = fetch_all_sections(user_identifier, user_data[:ado_token])

    render json: {
      user: { email: user_data[:email], name: user_data[:name] },
      sections: sections,
      content: build_content_string(sections),
      timestamp: Time.now.iso8601
    }
  end

  # GET/POST /api/my_tasks/demo - Demo endpoint
  def demo
    user_name = params[:user_name] || "Patcharapon Yoriya"
    sections = fetch_all_sections(user_name, nil)

    render json: {
      user: { name: user_name },
      sections: sections,
      content: build_content_string(sections),
      timestamp: Time.now.iso8601
    }
  rescue StandardError => e
    Rails.logger.error "Demo error: #{e.message}"
    render json: { error: e.message, user: { name: user_name } }, status: :internal_server_error
  end

  # Handle CORS preflight
  def options
    head :ok
  end

  private

  # === Data Aggregation ===

  def fetch_all_sections(user_identifier, access_token)
    {
      active: fetch_active_tasks(user_identifier, access_token),
      pull_requested: fetch_pull_requested_tasks(user_identifier),
      state_changes: fetch_state_changes(user_identifier)
    }
  end

  def build_content_string(sections)
    [sections[:active], "---", sections[:pull_requested], "---", sections[:state_changes]].join("\n\n")
  end

  # === UTF-8 Helper ===

  def safe_utf8(str)
    return "" if str.nil?

    s = str.to_s
    return s if s.encoding == Encoding::UTF_8 && s.valid_encoding?

    s.force_encoding("UTF-8")
    return s if s.valid_encoding?

    s.encode("UTF-8", "binary", invalid: :replace, undef: :replace, replace: "")
  rescue StandardError
    str.to_s
  end

  # === CORS ===

  def set_cors_headers
    headers["Access-Control-Allow-Origin"] = request.headers["Origin"] || "*"
    headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    headers["Access-Control-Allow-Headers"] = "Content-Type, Accept, Authorization"
    headers["Access-Control-Allow-Credentials"] = "true"
  end

  # === Authentication ===

  def extract_token
    auth_header = request.headers["Authorization"]
    return auth_header.sub("Bearer ", "") if auth_header&.start_with?("Bearer ")

    params[:token]
  end

  def get_current_user
    token = extract_token
    return nil unless token

    Rails.cache.read("auth_token_#{token}")
  end

  # === Azure DevOps Data Fetching ===

  def fetch_active_tasks(user_identifier, access_token)
    result = AzureDevopsTool.call(
      action: "list_my_active_work_items",
      assigned_to: user_identifier,
      access_token: access_token,
      server_context: nil
    )
    safe_utf8(result.content.first[:text])
  end

  def fetch_state_changes(user_identifier)
    result = AzureDevopsTool.call(
      action: "list_my_state_changes_today",
      assigned_to: user_identifier,
      server_context: nil
    )
    safe_utf8(result.content.first[:text])
  end

  def fetch_pull_requested_tasks(user_name)
    projects = fetch_project_names
    return EMPTY_PROJECT if projects.empty?

    project_items = collect_pull_requested_items(projects, user_name)
    return NO_PULL_REQUESTED if project_items.empty?

    format_pull_requested_output(project_items, user_name)
  rescue StandardError => e
    Rails.logger.error "Error fetching Pull Requested: #{e.message}"
    FETCH_ERROR
  end

  def fetch_project_names
    result = AzureDevopsTool.call(action: "list_projects", server_context: nil)
    text = safe_utf8(result.content.first[:text])
    text.scan(/\*\*(.+?)\*\*/).flatten.map { |p| safe_utf8(p).strip }
  end

  def collect_pull_requested_items(projects, user_name)
    project_items = {}

    projects.each do |project|
      items = fetch_pull_requested_for_project(project, user_name)
      project_items[project] = items if items.any?
    end

    project_items
  end

  def fetch_pull_requested_for_project(project, user_name)
    query = build_pull_requested_query(project, user_name)

    result = AzureDevopsTool.call(
      action: "list_work_items",
      project: project,
      query: query,
      server_context: nil
    )

    parse_work_items_from_response(result)
  rescue StandardError
    []
  end

  def build_pull_requested_query(project, user_name)
    <<~WIQL.gsub("\n", " ")
      SELECT [System.Id], [System.Title], [System.WorkItemType]
      FROM WorkItems
      WHERE [System.TeamProject] = '#{project}'
        AND [System.State] = 'Pull Requested'
        AND [System.AssignedTo] CONTAINS '#{user_name}'
      ORDER BY [System.ChangedDate] DESC
    WIQL
  end

  def parse_work_items_from_response(result)
    text = safe_utf8(result.content.first[:text])
    return [] if text.include?("No work items") || text.include?("Error")

    text.scan(/\*\*#(\d+)\*\* \[(\w+)\] (.+)/)
  end

  # === Output Formatting ===

  def format_pull_requested_output(project_items, user_name)
    total = project_items.values.flatten(1).count
    first_name = user_name.split.first

    output = [
      "## 🔀 งาน Pull Requested ของ **#{first_name}**",
      "",
      "มี **#{total} งาน** Pull Requested จาก **#{project_items.count} โปรเจค**:",
      ""
    ]

    project_items.each_with_index do |(project, items), index|
      output << "### #{index + 1}. #{project} - มี #{items.count} งาน"
      items.each { |id, type, title| output << "• **##{id}** [#{type}] #{title}" }
      output << ""
    end

    output.join("\n")
  end
end
