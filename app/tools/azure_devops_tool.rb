# frozen_string_literal: true

require "net/http"
require "json"
require "base64"
require "uri"

class AzureDevopsTool < MCP::Tool
  tool_name "azure-devops-tool"
  description "Complete Azure DevOps integration: Projects, Work Items, Sprints, Boards, Pipelines, Repos, Pull Requests, Test Plans, and Team Members."

  input_schema(
    properties: {
      action: {
        type: "string",
        enum: [
          "list_projects", "list_work_items", "get_work_item", "create_work_item", 
          "update_work_item", "delete_work_item", "list_team_members",
          "list_sprints", "get_current_sprint", "list_boards", "get_board_columns",
          "list_pipelines", "get_pipeline_runs", "run_pipeline",
          "list_repositories", "list_pull_requests", "get_pull_request",
          "list_branches", "list_commits",
          "list_test_plans", "list_test_suites", "list_test_cases",
          "add_comment", "list_comments"
        ],
        description: "The action to perform"
      },
      project: { type: "string", description: "Project name" },
      work_item_id: { type: "integer", description: "Work item ID" },
      work_item_type: { 
        type: "string", 
        enum: ["Bug", "Task", "User Story", "Feature", "Epic", "Issue"],
        description: "Type of work item" 
      },
      title: { type: "string", description: "Title (for create/update)" },
      description: { type: "string", description: "Description (for create/update)" },
      state: { type: "string", description: "State (New, Active, Closed, etc.)" },
      assigned_to: { type: "string", description: "Email to assign" },
      query: { type: "string", description: "WIQL query for filtering" },
      sprint: { type: "string", description: "Sprint/Iteration path" },
      pipeline_id: { type: "integer", description: "Pipeline ID" },
      repo_name: { type: "string", description: "Repository name" },
      pull_request_id: { type: "integer", description: "Pull request ID" },
      branch: { type: "string", description: "Branch name" },
      test_plan_id: { type: "integer", description: "Test plan ID" },
      test_suite_id: { type: "integer", description: "Test suite ID" },
      comment: { type: "string", description: "Comment text" },
      count: { type: "integer", description: "Number of items to return (default 100)" }
    },
    required: ["action"]
  )

  ORGANIZATION = ENV.fetch("AZURE_DEVOPS_ORGANIZATION", "bananacoding")
  PAT = ENV.fetch("AZURE_DEVOPS_PAT", "")

  def self.call(action:, project: nil, work_item_id: nil, work_item_type: nil,
                title: nil, description: nil, state: nil, assigned_to: nil, 
                query: nil, sprint: nil, pipeline_id: nil, repo_name: nil,
                pull_request_id: nil, branch: nil, test_plan_id: nil, 
                test_suite_id: nil, comment: nil, count: 100, server_context:)
    case action
    # Projects & Teams
    when "list_projects" then list_projects # Ignore project argument intentionally
    when "list_team_members" then list_team_members(project)
    
    # Work Items
    when "list_work_items" then list_work_items(project, query, count)
    when "get_work_item" then get_work_item(work_item_id)
    when "create_work_item" then create_work_item(project, work_item_type, title, description, assigned_to, sprint)
    when "update_work_item" then update_work_item(work_item_id, title, description, state, assigned_to, sprint)
    when "delete_work_item" then delete_work_item(work_item_id)
    when "add_comment" then add_comment(project, work_item_id, comment)
    when "list_comments" then list_comments(project, work_item_id)
    
    # Sprints & Boards
    when "list_sprints" then list_sprints(project)
    when "get_current_sprint" then get_current_sprint(project)
    when "list_boards" then list_boards(project)
    when "get_board_columns" then get_board_columns(project)
    
    # Pipelines
    when "list_pipelines" then list_pipelines(project)
    when "get_pipeline_runs" then get_pipeline_runs(project, pipeline_id, count)
    when "run_pipeline" then run_pipeline(project, pipeline_id, branch)
    
    # Repositories & Pull Requests
    when "list_repositories" then list_repositories(project)
    when "list_branches" then list_branches(project, repo_name)
    when "list_commits" then list_commits(project, repo_name, branch, count)
    when "list_pull_requests" then list_pull_requests(project, repo_name)
    when "get_pull_request" then get_pull_request(project, repo_name, pull_request_id)
    
    # Test Plans
    when "list_test_plans" then list_test_plans(project)
    when "list_test_suites" then list_test_suites(project, test_plan_id)
    when "list_test_cases" then list_test_cases(project, test_plan_id, test_suite_id)
    
    else
      error_response("Unknown action: #{action}")
    end
  rescue StandardError => e
    error_response("Error: #{e.message}")
  end

  private

  def self.encode_path(str)
    URI.encode_www_form_component(str).gsub("+", "%20")
  end

  def self.api_request(method, url, body = nil, content_type = "application/json")
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = case method
              when :get then Net::HTTP::Get.new(uri)
              when :post then Net::HTTP::Post.new(uri)
              when :patch then Net::HTTP::Patch.new(uri)
              when :delete then Net::HTTP::Delete.new(uri)
              end

    credentials = Base64.strict_encode64(":#{PAT}")
    request["Authorization"] = "Basic #{credentials}"
    request["Content-Type"] = content_type

    request.body = body.is_a?(String) ? body : body.to_json if body

    response = http.request(request)

    if response.code.to_i >= 200 && response.code.to_i < 300
      JSON.parse(response.body) rescue {}
    else
      raise "API Error (#{response.code}): #{response.body[0..200]}"
    end
  end

  # ==================== Projects & Teams ====================
  
  def self.list_projects
    url = "https://dev.azure.com/#{ORGANIZATION}/_apis/projects?api-version=7.0"
    result = api_request(:get, url)
    projects = result["value"].map { |p| "- **#{p['name']}**: #{p['description'] || 'No description'}" }.join("\n")
    success_response("Projects in #{ORGANIZATION}:\n\n#{projects}")
  end

  def self.list_team_members(project)
    return error_response("Project is required") unless project
    encoded_project = encode_path(project)
    teams_url = "https://dev.azure.com/#{ORGANIZATION}/_apis/projects/#{encoded_project}/teams?api-version=7.0"
    teams = api_request(:get, teams_url)
    
    all_members = []
    teams["value"].each do |team|
      members_url = "https://dev.azure.com/#{ORGANIZATION}/_apis/projects/#{encoded_project}/teams/#{team['id']}/members?api-version=7.0"
      members = api_request(:get, members_url)
      members["value"].each do |m|
        identity = m["identity"]
        all_members << "- **#{identity['displayName']}** (#{identity['uniqueName'] || 'N/A'}) - Team: #{team['name']}"
      end
    end
    success_response("Team Members in #{project}:\n\n#{all_members.uniq.join("\n")}")
  end

  # ==================== Work Items ====================

  def self.list_work_items(project, query = nil, count = 20)
    return error_response("Project is required") unless project
    
    # 1. Try to get Sprint Info first (Context)
    sprint_info = ""
    begin
      sprint_result = get_current_sprint_data(project) # Use helper method
      if sprint_result
         dates = sprint_result["attributes"]
         sprint_info = "📌 **Context:** Current Sprint: #{sprint_result['name']} (#{dates['startDate']&.slice(0, 10)} to #{dates['finishDate']&.slice(0, 10)})\n\n"
      end
    rescue => e
      # Ignore sprint error, just list items
    end

    # 2. Get Work Items
    wiql = query || "SELECT [System.Id], [System.Title], [System.State], [System.AssignedTo] FROM WorkItems WHERE [System.TeamProject] = '#{project}' ORDER BY [System.ChangedDate] DESC"
    
    encoded_project = encode_path(project)
    url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/wit/wiql?api-version=7.0"
    result = api_request(:post, url, { query: wiql })
    
    return success_response("#{sprint_info}No work items found") if result["workItems"].nil? || result["workItems"].empty?
    
    ids = result["workItems"].take(count).map { |wi| wi["id"] }.join(",")
    details_url = "https://dev.azure.com/#{ORGANIZATION}/_apis/wit/workitems?ids=#{ids}&api-version=7.0"
    details = api_request(:get, details_url)
    
    work_items = details["value"].map do |wi|
      fields = wi["fields"]
      assigned = fields["System.AssignedTo"]&.dig("displayName") || "Unassigned"
      "- **##{wi['id']}** [#{fields['System.WorkItemType']}] #{fields['System.Title']}\n  State: #{fields['System.State']} | Assigned: #{assigned}"
    end.join("\n\n")
    
    success_response("#{sprint_info}Work Items in #{project}:\n\n#{work_items}")
  end

  def self.get_work_item(id)
    return error_response("Work item ID is required") unless id
    url = "https://dev.azure.com/#{ORGANIZATION}/_apis/wit/workitems/#{id}?api-version=7.0&$expand=all"
    result = api_request(:get, url)
    
    fields = result["fields"]
    assigned = fields["System.AssignedTo"]&.dig("displayName") || "Unassigned"
    desc = (fields["System.Description"] || "No description").gsub(/<[^>]*>/, "")
    
    info = [
      "**Work Item ##{result['id']}**", "",
      "- **Type:** #{fields['System.WorkItemType']}",
      "- **Title:** #{fields['System.Title']}",
      "- **State:** #{fields['System.State']}",
      "- **Assigned To:** #{assigned}",
      "- **Iteration:** #{fields['System.IterationPath']}",
      "- **Area:** #{fields['System.AreaPath']}",
      "- **Created:** #{fields['System.CreatedDate']}",
      "", "**Description:**", desc
    ].join("\n")
    
    success_response(info)
  end

  def self.create_work_item(project, type, title, description, assigned_to, sprint)
    return error_response("Project, type, and title are required") unless project && type && title
    
    encoded_project = encode_path(project)
    encoded_type = encode_path(type)
    url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/wit/workitems/$#{encoded_type}?api-version=7.0"
    
    operations = [{ op: "add", path: "/fields/System.Title", value: title }]
    operations << { op: "add", path: "/fields/System.Description", value: description } if description
    operations << { op: "add", path: "/fields/System.AssignedTo", value: assigned_to } if assigned_to
    operations << { op: "add", path: "/fields/System.IterationPath", value: sprint } if sprint
    
    result = api_request(:post, url, operations.to_json, "application/json-patch+json")
    success_response("✅ Created work item ##{result['id']}: #{title}")
  end

  def self.update_work_item(id, title, description, state, assigned_to, sprint)
    return error_response("Work item ID is required") unless id
    
    url = "https://dev.azure.com/#{ORGANIZATION}/_apis/wit/workitems/#{id}?api-version=7.0"
    
    operations = []
    operations << { op: "add", path: "/fields/System.Title", value: title } if title
    operations << { op: "add", path: "/fields/System.Description", value: description } if description
    operations << { op: "add", path: "/fields/System.State", value: state } if state
    operations << { op: "add", path: "/fields/System.AssignedTo", value: assigned_to } if assigned_to
    operations << { op: "add", path: "/fields/System.IterationPath", value: sprint } if sprint
    
    return error_response("No fields to update") if operations.empty?
    
    result = api_request(:patch, url, operations.to_json, "application/json-patch+json")
    success_response("✅ Updated work item ##{result['id']}")
  end

  def self.delete_work_item(id)
    return error_response("Work item ID is required") unless id
    url = "https://dev.azure.com/#{ORGANIZATION}/_apis/wit/workitems/#{id}?api-version=7.0"
    api_request(:delete, url)
    success_response("✅ Deleted work item ##{id}")
  end

  def self.add_comment(project, work_item_id, comment)
    return error_response("Project, work item ID, and comment are required") unless project && work_item_id && comment
    encoded_project = encode_path(project)
    url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/wit/workItems/#{work_item_id}/comments?api-version=7.0-preview.3"
    result = api_request(:post, url, { text: comment })
    success_response("✅ Added comment to work item ##{work_item_id}")
  end

  def self.list_comments(project, work_item_id)
    return error_response("Project and work item ID are required") unless project && work_item_id
    encoded_project = encode_path(project)
    url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/wit/workItems/#{work_item_id}/comments?api-version=7.0-preview.3"
    result = api_request(:get, url)
    
    comments = result["comments"]&.map do |c|
      "- **#{c['createdBy']['displayName']}** (#{c['createdDate'][0..9]}):\n  #{c['text'].gsub(/<[^>]*>/, '')}"
    end&.join("\n\n") || "No comments"
    
    success_response("Comments on work item ##{work_item_id}:\n\n#{comments}")
  end

  # ==================== Sprints & Boards ====================

  def self.list_sprints(project)
    return error_response("Project is required") unless project
    encoded_project = encode_path(project)
    
    # Get default team
    teams_url = "https://dev.azure.com/#{ORGANIZATION}/_apis/projects/#{encoded_project}/teams?api-version=7.0"
    teams = api_request(:get, teams_url)
    team_id = teams["value"].first["id"]
    
    url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/#{team_id}/_apis/work/teamsettings/iterations?api-version=7.0"
    result = api_request(:get, url)
    
    sprints = result["value"].map do |s|
      dates = s["attributes"]
      start_date = dates["startDate"]&.slice(0, 10) || "Not set"
      end_date = dates["finishDate"]&.slice(0, 10) || "Not set"
      "- **#{s['name']}**: #{start_date} → #{end_date} (#{dates['timeFrame']})"
    end.join("\n")
    
    success_response("Sprints in #{project}:\n\n#{sprints}")
  end

  def self.get_current_sprint(project)
    result = get_current_sprint_data(project)
    
    if result.nil?
      return success_response("No current sprint found")
    end
    
    dates = result["attributes"]
    info = [
      "**Current Sprint: #{result['name']}**", "",
      "- **Start:** #{dates['startDate']&.slice(0, 10)}",
      "- **End:** #{dates['finishDate']&.slice(0, 10)}",
      "- **Path:** #{result['path']}"
    ].join("\n")
    
    success_response(info)
  end

  def self.list_boards(project)
    return error_response("Project is required") unless project
    encoded_project = encode_path(project)
    
    teams_url = "https://dev.azure.com/#{ORGANIZATION}/_apis/projects/#{encoded_project}/teams?api-version=7.0"
    teams = api_request(:get, teams_url)
    team_id = teams["value"].first["id"]
    
    url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/#{team_id}/_apis/work/boards?api-version=7.0"
    result = api_request(:get, url)
    
    boards = result["value"].map { |b| "- **#{b['name']}**" }.join("\n")
    success_response("Boards in #{project}:\n\n#{boards}")
  end

  def self.get_board_columns(project)
    return error_response("Project is required") unless project
    encoded_project = encode_path(project)
    
    teams_url = "https://dev.azure.com/#{ORGANIZATION}/_apis/projects/#{encoded_project}/teams?api-version=7.0"
    teams = api_request(:get, teams_url)
    team_id = teams["value"].first["id"]
    
    boards_url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/#{team_id}/_apis/work/boards?api-version=7.0"
    boards = api_request(:get, boards_url)
    board_id = boards["value"].first["id"]
    
    url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/#{team_id}/_apis/work/boards/#{board_id}/columns?api-version=7.0"
    result = api_request(:get, url)
    
    columns = result["value"].map { |c| "- **#{c['name']}** (#{c['columnType']})" }.join("\n")
    success_response("Board Columns:\n\n#{columns}")
  end

  # ==================== Pipelines ====================

  def self.list_pipelines(project)
    return error_response("Project is required") unless project
    encoded_project = encode_path(project)
    url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/pipelines?api-version=7.0"
    result = api_request(:get, url)
    
    if result["value"].nil? || result["value"].empty?
      return success_response("No pipelines found")
    end
    
    pipelines = result["value"].map { |p| "- **#{p['name']}** (ID: #{p['id']})" }.join("\n")
    success_response("Pipelines in #{project}:\n\n#{pipelines}")
  end

  def self.get_pipeline_runs(project, pipeline_id, count = 100)
    return error_response("Project and pipeline ID are required") unless project && pipeline_id
    encoded_project = encode_path(project)
    url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/pipelines/#{pipeline_id}/runs?api-version=7.0"
    result = api_request(:get, url)
    
    runs = result["value"].take(count).map do |r|
      "- **Run ##{r['id']}**: #{r['state']} - #{r['result'] || 'In progress'} (#{r['createdDate'][0..9]})"
    end.join("\n")
    
    success_response("Pipeline Runs:\n\n#{runs}")
  end

  def self.run_pipeline(project, pipeline_id, branch = nil)
    return error_response("Project and pipeline ID are required") unless project && pipeline_id
    encoded_project = encode_path(project)
    url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/pipelines/#{pipeline_id}/runs?api-version=7.0"
    
    body = {}
    body["resources"] = { "repositories" => { "self" => { "refName" => "refs/heads/#{branch}" } } } if branch
    
    result = api_request(:post, url, body)
    success_response("✅ Started pipeline run ##{result['id']}")
  end

  # ==================== Repositories ====================

  def self.list_repositories(project)
    return error_response("Project is required") unless project
    encoded_project = encode_path(project)
    url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/git/repositories?api-version=7.0"
    result = api_request(:get, url)
    
    repos = result["value"].map { |r| "- **#{r['name']}** (#{r['defaultBranch'] || 'No default branch'})" }.join("\n")
    success_response("Repositories in #{project}:\n\n#{repos}")
  end

  def self.list_branches(project, repo_name)
    return error_response("Project and repository name are required") unless project && repo_name
    encoded_project = encode_path(project)
    encoded_repo = encode_path(repo_name)
    url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/git/repositories/#{encoded_repo}/refs?filter=heads/&api-version=7.0"
    result = api_request(:get, url)
    
    branches = result["value"].map { |b| "- **#{b['name'].gsub('refs/heads/', '')}**" }.join("\n")
    success_response("Branches in #{repo_name}:\n\n#{branches}")
  end

  def self.list_commits(project, repo_name, branch = nil, count = 100)
    return error_response("Project and repository name are required") unless project && repo_name
    encoded_project = encode_path(project)
    encoded_repo = encode_path(repo_name)
    
    url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/git/repositories/#{encoded_repo}/commits?$top=#{count}&api-version=7.0"
    url += "&searchCriteria.itemVersion.version=#{encode_path(branch)}" if branch
    
    result = api_request(:get, url)
    
    commits = result["value"].map do |c|
      "- **#{c['commitId'][0..7]}**: #{c['comment'].lines.first&.strip} (#{c['author']['name']})"
    end.join("\n")
    
    success_response("Recent Commits in #{repo_name}:\n\n#{commits}")
  end

  def self.list_pull_requests(project, repo_name = nil)
    return error_response("Project is required") unless project
    encoded_project = encode_path(project)
    
    if repo_name
      encoded_repo = encode_path(repo_name)
      url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/git/repositories/#{encoded_repo}/pullrequests?api-version=7.0"
    else
      url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/git/pullrequests?api-version=7.0"
    end
    
    result = api_request(:get, url)
    
    if result["value"].nil? || result["value"].empty?
      return success_response("No pull requests found")
    end
    
    prs = result["value"].map do |pr|
      "- **PR ##{pr['pullRequestId']}**: #{pr['title']}\n  #{pr['sourceRefName'].gsub('refs/heads/', '')} → #{pr['targetRefName'].gsub('refs/heads/', '')} | Status: #{pr['status']}"
    end.join("\n\n")
    
    success_response("Pull Requests:\n\n#{prs}")
  end

  def self.get_pull_request(project, repo_name, pr_id)
    return error_response("Project, repository, and PR ID are required") unless project && repo_name && pr_id
    encoded_project = encode_path(project)
    encoded_repo = encode_path(repo_name)
    url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/git/repositories/#{encoded_repo}/pullrequests/#{pr_id}?api-version=7.0"
    result = api_request(:get, url)
    
    info = [
      "**Pull Request ##{result['pullRequestId']}**", "",
      "- **Title:** #{result['title']}",
      "- **Status:** #{result['status']}",
      "- **Created By:** #{result['createdBy']['displayName']}",
      "- **Source:** #{result['sourceRefName'].gsub('refs/heads/', '')}",
      "- **Target:** #{result['targetRefName'].gsub('refs/heads/', '')}",
      "- **Created:** #{result['creationDate'][0..9]}",
      "", "**Description:**", result['description'] || "No description"
    ].join("\n")
    
    success_response(info)
  end

  # ==================== Test Plans ====================

  def self.list_test_plans(project)
    return error_response("Project is required") unless project
    encoded_project = encode_path(project)
    url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/testplan/plans?api-version=7.0"
    result = api_request(:get, url)
    
    if result["value"].nil? || result["value"].empty?
      return success_response("No test plans found")
    end
    
    plans = result["value"].map { |p| "- **#{p['name']}** (ID: #{p['id']}) - State: #{p['state']}" }.join("\n")
    success_response("Test Plans in #{project}:\n\n#{plans}")
  end

  def self.list_test_suites(project, test_plan_id)
    return error_response("Project and test plan ID are required") unless project && test_plan_id
    encoded_project = encode_path(project)
    url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/testplan/Plans/#{test_plan_id}/suites?api-version=7.0"
    result = api_request(:get, url)
    
    suites = result["value"].map { |s| "- **#{s['name']}** (ID: #{s['id']}) - Type: #{s['suiteType']}" }.join("\n")
    success_response("Test Suites in Plan ##{test_plan_id}:\n\n#{suites}")
  end

  def self.list_test_cases(project, test_plan_id, test_suite_id)
    return error_response("Project, test plan ID, and test suite ID are required") unless project && test_plan_id && test_suite_id
    encoded_project = encode_path(project)
    url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/testplan/Plans/#{test_plan_id}/Suites/#{test_suite_id}/TestCase?api-version=7.0"
    result = api_request(:get, url)
    
    if result["value"].nil? || result["value"].empty?
      return success_response("No test cases found")
    end
    
    cases = result["value"].map do |tc|
      wi = tc["workItem"]
      "- **##{wi['id']}**: #{wi['name']}"
    end.join("\n")
    
    success_response("Test Cases in Suite ##{test_suite_id}:\n\n#{cases}")
  end

  def self.get_current_sprint_data(project)
    return nil unless project
    encoded_project = encode_path(project)
    
    # Get default team
    teams_url = "https://dev.azure.com/#{ORGANIZATION}/_apis/projects/#{encoded_project}/teams?api-version=7.0"
    teams = api_request(:get, teams_url)
    return nil if teams["value"].empty?
    
    team_id = teams["value"].first["id"]
    
    url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/#{team_id}/_apis/work/teamsettings/iterations?$timeframe=current&api-version=7.0"
    result = api_request(:get, url)
    
    result["value"]&.first
  rescue
    nil
  end

  # ==================== Helpers ====================

  def self.success_response(text)
    MCP::Tool::Response.new([{ type: "text", text: text }])
  end

  def self.error_response(text)
    MCP::Tool::Response.new([{ type: "text", text: "❌ #{text}" }])
  end
end
