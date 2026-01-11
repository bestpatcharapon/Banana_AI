# frozen_string_literal: true

module AzureDevops
  # Projects and Team Members related actions
  module Projects
    include AzureDevops::Base

    def list_projects
      url = "https://dev.azure.com/#{ORGANIZATION}/_apis/projects?api-version=7.0"
      result = api_request(:get, url)

      projects = result["value"].map do |project|
        description = project["description"] || "No description"
        "- **#{project['name']}**: #{description}"
      end

      success_response("Projects in #{ORGANIZATION}:\n\n#{projects.join("\n")}")
    end

    def list_team_members(project)
      return error_response("Project is required") unless project

      teams = fetch_project_teams(project)
      members = collect_team_members(project, teams)

      success_response("Team Members in #{project}:\n\n#{members.uniq.join("\n")}")
    end

    private

    def fetch_project_teams(project)
      encoded_project = encode_path(project)
      url = "https://dev.azure.com/#{ORGANIZATION}/_apis/projects/#{encoded_project}/teams?api-version=7.0"
      api_request(:get, url)
    end

    def collect_team_members(project, teams)
      encoded_project = encode_path(project)
      members = []

      teams["value"].each do |team|
        team_members = fetch_team_members(encoded_project, team)
        members.concat(team_members)
      end

      members
    end

    def fetch_team_members(encoded_project, team)
      url = "https://dev.azure.com/#{ORGANIZATION}/_apis/projects/#{encoded_project}/teams/#{team['id']}/members?api-version=7.0"
      result = api_request(:get, url)

      result["value"].map do |member|
        identity = member["identity"]
        unique_name = identity["uniqueName"] || "N/A"
        "- **#{identity['displayName']}** (#{unique_name}) - Team: #{team['name']}"
      end
    end
  end
end
