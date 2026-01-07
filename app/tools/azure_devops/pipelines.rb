# frozen_string_literal: true

module AzureDevops
  # Pipelines related actions
  module Pipelines
    include AzureDevops::Base

    def list_pipelines(project)
      return error_response("Project is required") unless project
      encoded_project = encode_path(project)
      url = "https://dev.azure.com/#{AzureDevops::Base::ORGANIZATION}/#{encoded_project}/_apis/pipelines?api-version=7.0"
      result = api_request(:get, url)

      if result["value"].nil? || result["value"].empty?
        return success_response("No pipelines found")
      end

      pipelines = result["value"].map { |p| "- **#{p['name']}** (ID: #{p['id']})" }.join("\n")
      success_response("Pipelines in #{project}:\n\n#{pipelines}")
    end

    def get_pipeline_runs(project, pipeline_id, count = 100)
      return error_response("Project and pipeline ID are required") unless project && pipeline_id
      encoded_project = encode_path(project)
      url = "https://dev.azure.com/#{AzureDevops::Base::ORGANIZATION}/#{encoded_project}/_apis/pipelines/#{pipeline_id}/runs?api-version=7.0"
      result = api_request(:get, url)

      runs = result["value"].take(count).map do |r|
        "- **Run ##{r['id']}**: #{r['state']} - #{r['result'] || 'In progress'} (#{r['createdDate'][0..9]})"
      end.join("\n")

      success_response("Pipeline Runs:\n\n#{runs}")
    end

    def run_pipeline(project, pipeline_id, branch = nil)
      return error_response("Project and pipeline ID are required") unless project && pipeline_id
      encoded_project = encode_path(project)
      url = "https://dev.azure.com/#{AzureDevops::Base::ORGANIZATION}/#{encoded_project}/_apis/pipelines/#{pipeline_id}/runs?api-version=7.0"

      body = {}
      body["resources"] = { "repositories" => { "self" => { "refName" => "refs/heads/#{branch}" } } } if branch

      result = api_request(:post, url, body)
      success_response("✅ Started pipeline run ##{result['id']}")
    end
  end
end
