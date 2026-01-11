# frozen_string_literal: true

module AzureDevops
  # Pipelines related actions
  module Pipelines
    include AzureDevops::Base

    NO_PIPELINES = "No pipelines found"
    DEFAULT_RUN_COUNT = 100

    def list_pipelines(project)
      return error_response("Project is required") unless project

      encoded_project = encode_path(project)
      url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/pipelines?api-version=7.0"
      result = api_request(:get, url)

      return success_response(NO_PIPELINES) if result["value"].nil? || result["value"].empty?

      pipelines = format_pipelines_list(result["value"])
      success_response("Pipelines in #{project}:\n\n#{pipelines}")
    end

    def get_pipeline_runs(project, pipeline_id, count = DEFAULT_RUN_COUNT)
      return error_response("Project and pipeline ID are required") unless project && pipeline_id

      encoded_project = encode_path(project)
      url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/pipelines/#{pipeline_id}/runs?api-version=7.0"
      result = api_request(:get, url)

      runs = format_pipeline_runs(result["value"].take(count))
      success_response("Pipeline Runs:\n\n#{runs}")
    end

    def run_pipeline(project, pipeline_id, branch = nil)
      return error_response("Project and pipeline ID are required") unless project && pipeline_id

      encoded_project = encode_path(project)
      url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/pipelines/#{pipeline_id}/runs?api-version=7.0"

      body = build_run_pipeline_body(branch)
      result = api_request(:post, url, body)

      success_response("✅ Started pipeline run ##{result['id']}")
    end

    private

    def format_pipelines_list(pipelines)
      pipelines.map { |p| "- **#{p['name']}** (ID: #{p['id']})" }.join("\n")
    end

    def format_pipeline_runs(runs)
      runs.map do |run|
        status = run["result"] || "In progress"
        date = run["createdDate"][0..9]
        "- **Run ##{run['id']}**: #{run['state']} - #{status} (#{date})"
      end.join("\n")
    end

    def build_run_pipeline_body(branch)
      return {} unless branch

      {
        "resources" => {
          "repositories" => {
            "self" => { "refName" => "refs/heads/#{branch}" }
          }
        }
      }
    end
  end
end
