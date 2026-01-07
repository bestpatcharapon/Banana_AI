# frozen_string_literal: true

require_relative "azure_devops/base"
require_relative "azure_devops/projects"
require_relative "azure_devops/work_items"
require_relative "azure_devops/sprints"
require_relative "azure_devops/pipelines"
require_relative "azure_devops/repositories"
require_relative "azure_devops/test_plans"

class AzureDevopsTool < MCP::Tool
  # Include all modules
  include AzureDevops::Base
  include AzureDevops::Projects
  include AzureDevops::WorkItems
  include AzureDevops::Sprints
  include AzureDevops::Pipelines
  include AzureDevops::Repositories
  include AzureDevops::TestPlans

  tool_name "azure-devops-tool"
  description "Complete Azure DevOps integration: Projects, Work Items, Sprints, Boards, Pipelines, Repos, Pull Requests, Test Plans, and Team Members."

  input_schema(
    properties: {
      action: {
        type: "string",
        enum: [
          "list_projects", "list_work_items", "list_all_active_work_items", "list_my_active_work_items", "get_work_item", "create_work_item",
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

  def self.call(action:, project: nil, work_item_id: nil, work_item_type: nil,
                title: nil, description: nil, state: nil, assigned_to: nil,
                query: nil, sprint: nil, pipeline_id: nil, repo_name: nil,
                pull_request_id: nil, branch: nil, test_plan_id: nil,
                test_suite_id: nil, comment: nil, count: 100, access_token: nil, server_context:)
    
    instance = new
    instance.access_token = access_token if access_token # Set access token on instance
    
    case action
    # Projects & Teams
    when "list_projects" then instance.list_projects
    when "list_team_members" then instance.list_team_members(project)

    # Work Items
    when "list_work_items" then instance.list_work_items(project, query, count)
    when "list_all_active_work_items" then instance.list_all_active_work_items(count)
    when "list_my_active_work_items" then instance.list_my_active_work_items(assigned_to, count)
    when "get_work_item" then instance.get_work_item(work_item_id)
    when "create_work_item" then instance.create_work_item(project, work_item_type, title, description, assigned_to, sprint)
    when "update_work_item" then instance.update_work_item(work_item_id, title, description, state, assigned_to, sprint)
    when "delete_work_item" then instance.delete_work_item(work_item_id)
    when "add_comment" then instance.add_comment(project, work_item_id, comment)
    when "list_comments" then instance.list_comments(project, work_item_id)

    # Sprints & Boards
    when "list_sprints" then instance.list_sprints(project)
    when "get_current_sprint" then instance.get_current_sprint(project)
    when "list_boards" then instance.list_boards(project)
    when "get_board_columns" then instance.get_board_columns(project)

    # Pipelines
    when "list_pipelines" then instance.list_pipelines(project)
    when "get_pipeline_runs" then instance.get_pipeline_runs(project, pipeline_id, count)
    when "run_pipeline" then instance.run_pipeline(project, pipeline_id, branch)

    # Repositories & Pull Requests
    when "list_repositories" then instance.list_repositories(project)
    when "list_branches" then instance.list_branches(project, repo_name)
    when "list_commits" then instance.list_commits(project, repo_name, branch, count)
    when "list_pull_requests" then instance.list_pull_requests(project, repo_name)
    when "get_pull_request" then instance.get_pull_request(project, repo_name, pull_request_id)

    # Test Plans
    when "list_test_plans" then instance.list_test_plans(project)
    when "list_test_suites" then instance.list_test_suites(project, test_plan_id)
    when "list_test_cases" then instance.list_test_cases(project, test_plan_id, test_suite_id)

    else
      instance.error_response("Unknown action: #{action}")
    end
  rescue StandardError => e
    MCP::Tool::Response.new([{ type: "text", text: "❌ Error: #{e.message}" }])
  end
end
