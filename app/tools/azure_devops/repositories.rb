# frozen_string_literal: true

module AzureDevops
  # Repositories, Branches, Commits, and Pull Requests
  module Repositories
    include AzureDevops::Base

    def list_repositories(project)
      return error_response("Project is required") unless project
      encoded_project = encode_path(project)
      url = "https://dev.azure.com/#{AzureDevops::Base::ORGANIZATION}/#{encoded_project}/_apis/git/repositories?api-version=7.0"
      result = api_request(:get, url)

      repos = result["value"].map { |r| "- **#{r['name']}** (#{r['defaultBranch'] || 'No default branch'})" }.join("\n")
      success_response("Repositories in #{project}:\n\n#{repos}")
    end

    def list_branches(project, repo_name)
      return error_response("Project and repository name are required") unless project && repo_name
      encoded_project = encode_path(project)
      encoded_repo = encode_path(repo_name)
      url = "https://dev.azure.com/#{AzureDevops::Base::ORGANIZATION}/#{encoded_project}/_apis/git/repositories/#{encoded_repo}/refs?filter=heads/&api-version=7.0"
      result = api_request(:get, url)

      branches = result["value"].map { |b| "- **#{b['name'].gsub('refs/heads/', '')}**" }.join("\n")
      success_response("Branches in #{repo_name}:\n\n#{branches}")
    end

    def list_commits(project, repo_name, branch = nil, count = 100)
      return error_response("Project and repository name are required") unless project && repo_name
      encoded_project = encode_path(project)
      encoded_repo = encode_path(repo_name)

      url = "https://dev.azure.com/#{AzureDevops::Base::ORGANIZATION}/#{encoded_project}/_apis/git/repositories/#{encoded_repo}/commits?$top=#{count}&api-version=7.0"
      url += "&searchCriteria.itemVersion.version=#{encode_path(branch)}" if branch

      result = api_request(:get, url)

      commits = result["value"].map do |c|
        "- **#{c['commitId'][0..7]}**: #{c['comment'].lines.first&.strip} (#{c['author']['name']})"
      end.join("\n")

      success_response("Recent Commits in #{repo_name}:\n\n#{commits}")
    end

    def list_pull_requests(project, repo_name = nil)
      return error_response("Project is required") unless project
      encoded_project = encode_path(project)

      if repo_name
        encoded_repo = encode_path(repo_name)
        url = "https://dev.azure.com/#{AzureDevops::Base::ORGANIZATION}/#{encoded_project}/_apis/git/repositories/#{encoded_repo}/pullrequests?api-version=7.0"
      else
        url = "https://dev.azure.com/#{AzureDevops::Base::ORGANIZATION}/#{encoded_project}/_apis/git/pullrequests?api-version=7.0"
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

    def get_pull_request(project, repo_name, pr_id)
      return error_response("Project, repository, and PR ID are required") unless project && repo_name && pr_id
      encoded_project = encode_path(project)
      encoded_repo = encode_path(repo_name)
      url = "https://dev.azure.com/#{AzureDevops::Base::ORGANIZATION}/#{encoded_project}/_apis/git/repositories/#{encoded_repo}/pullrequests/#{pr_id}?api-version=7.0"
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
  end
end
