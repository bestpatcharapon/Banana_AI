# frozen_string_literal: true

module AzureDevops
  # Projects and Team Members related actions
  module Projects
    include AzureDevops::Base

    def list_projects
      url = "https://dev.azure.com/#{AzureDevops::Base::ORGANIZATION}/_apis/projects?api-version=7.0"
      result = api_request(:get, url)
      projects = result["value"].map { |p| "- **#{p['name']}**: #{p['description'] || 'No description'}" }.join("\n")
      success_response("Projects in #{AzureDevops::Base::ORGANIZATION}:\n\n#{projects}")
    end

    def list_team_members(project)
      return error_response("Project is required") unless project
      encoded_project = encode_path(project)
      teams_url = "https://dev.azure.com/#{AzureDevops::Base::ORGANIZATION}/_apis/projects/#{encoded_project}/teams?api-version=7.0"
      teams = api_request(:get, teams_url)

      all_members = []
      teams["value"].each do |team|
        members_url = "https://dev.azure.com/#{AzureDevops::Base::ORGANIZATION}/_apis/projects/#{encoded_project}/teams/#{team['id']}/members?api-version=7.0"
        members = api_request(:get, members_url)
        members["value"].each do |m|
          identity = m["identity"]
          all_members << "- **#{identity['displayName']}** (#{identity['uniqueName'] || 'N/A'}) - Team: #{team['name']}"
        end
      end
      success_response("Team Members in #{project}:\n\n#{all_members.uniq.join("\n")}")
    end
  end
end
