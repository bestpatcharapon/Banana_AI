# frozen_string_literal: true

module AzureDevops
  # Sprints and Boards related actions
  module Sprints
    include AzureDevops::Base

    NO_CURRENT_SPRINT = "No current sprint found"

    def list_sprints(project)
      return error_response("Project is required") unless project

      team_id = get_default_team_id(project)
      sprints = fetch_all_sprints(project, team_id)

      success_response("Sprints in #{project}:\n\n#{sprints}")
    end

    def get_current_sprint(project)
      result = get_current_sprint_data(project)
      return success_response(NO_CURRENT_SPRINT) if result.nil?

      format_sprint_info(result)
    end

    def get_current_sprint_data(project)
      return nil unless project

      team_id = get_default_team_id(project)
      return nil unless team_id

      fetch_current_sprint(project, team_id)
    rescue StandardError
      nil
    end

    def list_boards(project)
      return error_response("Project is required") unless project

      team_id = get_default_team_id(project)
      boards = fetch_boards(project, team_id)

      success_response("Boards in #{project}:\n\n#{boards}")
    end

    def get_board_columns(project)
      return error_response("Project is required") unless project

      team_id = get_default_team_id(project)
      board_id = get_default_board_id(project, team_id)
      columns = fetch_board_columns(project, team_id, board_id)

      success_response("Board Columns:\n\n#{columns}")
    end

    private

    def get_default_team_id(project)
      encoded_project = encode_path(project)
      url = "https://dev.azure.com/#{ORGANIZATION}/_apis/projects/#{encoded_project}/teams?api-version=7.0"
      teams = api_request(:get, url)

      return nil if teams["value"].empty?

      teams["value"].first["id"]
    end

    def fetch_all_sprints(project, team_id)
      encoded_project = encode_path(project)
      url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/#{team_id}/_apis/work/teamsettings/iterations?api-version=7.0"
      result = api_request(:get, url)

      result["value"].map do |sprint|
        format_sprint_line(sprint)
      end.join("\n")
    end

    def format_sprint_line(sprint)
      dates = sprint["attributes"]
      start_date = dates["startDate"]&.slice(0, 10) || "Not set"
      end_date = dates["finishDate"]&.slice(0, 10) || "Not set"
      "- **#{sprint['name']}**: #{start_date} → #{end_date} (#{dates['timeFrame']})"
    end

    def fetch_current_sprint(project, team_id)
      encoded_project = encode_path(project)
      url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/#{team_id}/_apis/work/teamsettings/iterations?$timeframe=current&api-version=7.0"
      result = api_request(:get, url)
      result["value"]&.first
    end

    def format_sprint_info(sprint)
      dates = sprint["attributes"]
      start_date = dates["startDate"]&.slice(0, 10)
      end_date = dates["finishDate"]&.slice(0, 10)

      info = [
        "**Current Sprint: #{sprint['name']}**", "",
        "- **Start:** #{start_date}",
        "- **End:** #{end_date}",
        "- **Path:** #{sprint['path']}"
      ].join("\n")

      success_response(info)
    end

    def fetch_boards(project, team_id)
      encoded_project = encode_path(project)
      url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/#{team_id}/_apis/work/boards?api-version=7.0"
      result = api_request(:get, url)

      result["value"].map { |board| "- **#{board['name']}**" }.join("\n")
    end

    def get_default_board_id(project, team_id)
      encoded_project = encode_path(project)
      url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/#{team_id}/_apis/work/boards?api-version=7.0"
      boards = api_request(:get, url)
      boards["value"].first["id"]
    end

    def fetch_board_columns(project, team_id, board_id)
      encoded_project = encode_path(project)
      url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/#{team_id}/_apis/work/boards/#{board_id}/columns?api-version=7.0"
      result = api_request(:get, url)

      result["value"].map do |column|
        "- **#{column['name']}** (#{column['columnType']})"
      end.join("\n")
    end
  end
end
