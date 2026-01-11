# frozen_string_literal: true

module AzureDevops
  # Repositories, Branches, Commits, and Pull Requests
  module Repositories
    include AzureDevops::Base

    NO_PRS = "No pull requests found"
    DEFAULT_COMMIT_COUNT = 100

    def list_repositories(project)
      return error_response("Project is required") unless project

      encoded_project = encode_path(project)
      url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/git/repositories?api-version=7.0"
      result = api_request(:get, url)

      repos = format_repositories(result["value"])
      success_response("Repositories in #{project}:\n\n#{repos}")
    end

    def list_branches(project, repo_name)
      return error_response("Project and repository name are required") unless project && repo_name

      encoded_project = encode_path(project)
      encoded_repo = encode_path(repo_name)
      url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/git/repositories/#{encoded_repo}/refs?filter=heads/&api-version=7.0"
      result = api_request(:get, url)

      branches = format_branches(result["value"])
      success_response("Branches in #{repo_name}:\n\n#{branches}")
    end

    def list_commits(project, repo_name, branch = nil, count = DEFAULT_COMMIT_COUNT)
      return error_response("Project and repository name are required") unless project && repo_name

      url = build_commits_url(project, repo_name, branch, count)
      result = api_request(:get, url)

      commits = format_commits(result["value"])
      success_response("Recent Commits in #{repo_name}:\n\n#{commits}")
    end

    def list_pull_requests(project, repo_name = nil)
      return error_response("Project is required") unless project

      url = build_pull_requests_url(project, repo_name)
      result = api_request(:get, url)

      return success_response(NO_PRS) if result["value"].nil? || result["value"].empty?

      prs = format_pull_requests(result["value"])
      success_response("Pull Requests:\n\n#{prs}")
    end

    def list_my_pull_requests(project, user_name)
      return error_response("Project is required") unless project
      return error_response("User name is required") unless user_name

      result = fetch_all_prs(project)
      return success_response(NO_PRS) if result["value"].nil? || result["value"].empty?

      my_prs = filter_prs_by_user(result["value"], user_name)
      return success_response("No pull requests created by #{user_name}") if my_prs.empty?

      prs_text = format_my_pull_requests(my_prs)
      success_response("My Pull Requests:\n\n#{prs_text}")
    end

    def get_pull_request(project, repo_name, pr_id)
      return error_response("Project, repository, and PR ID are required") unless project && repo_name && pr_id

      url = build_single_pr_url(project, repo_name, pr_id)
      result = api_request(:get, url)

      format_pull_request_details(result)
    end

    private

    # === URL Builders ===

    def build_commits_url(project, repo_name, branch, count)
      encoded_project = encode_path(project)
      encoded_repo = encode_path(repo_name)
      url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/git/repositories/#{encoded_repo}/commits?$top=#{count}&api-version=7.0"
      url += "&searchCriteria.itemVersion.version=#{encode_path(branch)}" if branch
      url
    end

    def build_pull_requests_url(project, repo_name)
      encoded_project = encode_path(project)
      if repo_name
        encoded_repo = encode_path(repo_name)
        "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/git/repositories/#{encoded_repo}/pullrequests?api-version=7.0"
      else
        "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/git/pullrequests?api-version=7.0"
      end
    end

    def build_single_pr_url(project, repo_name, pr_id)
      encoded_project = encode_path(project)
      encoded_repo = encode_path(repo_name)
      "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/git/repositories/#{encoded_repo}/pullrequests/#{pr_id}?api-version=7.0"
    end

    # === Formatters ===

    def format_repositories(repos)
      repos.map do |repo|
        branch = repo["defaultBranch"] || "No default branch"
        "- **#{repo['name']}** (#{branch})"
      end.join("\n")
    end

    def format_branches(branches)
      branches.map do |branch|
        name = branch["name"].gsub("refs/heads/", "")
        "- **#{name}**"
      end.join("\n")
    end

    def format_commits(commits)
      commits.map do |commit|
        short_id = commit["commitId"][0..7]
        message = commit["comment"].lines.first&.strip
        author = commit["author"]["name"]
        "- **#{short_id}**: #{message} (#{author})"
      end.join("\n")
    end

    def format_pull_requests(prs)
      prs.map do |pr|
        source = pr["sourceRefName"].gsub("refs/heads/", "")
        target = pr["targetRefName"].gsub("refs/heads/", "")
        "- **PR ##{pr['pullRequestId']}**: #{pr['title']}\n  #{source} → #{target} | Status: #{pr['status']}"
      end.join("\n\n")
    end

    def format_my_pull_requests(prs)
      prs.map do |pr|
        source = pr["sourceRefName"].gsub("refs/heads/", "")
        target = pr["targetRefName"].gsub("refs/heads/", "")
        creator = pr.dig("createdBy", "displayName")
        "- **PR ##{pr['pullRequestId']}**: #{pr['title']}\n  #{source} → #{target} | Status: #{pr['status']} | Created by: #{creator}"
      end.join("\n\n")
    end

    def format_pull_request_details(pr)
      source = pr["sourceRefName"].gsub("refs/heads/", "")
      target = pr["targetRefName"].gsub("refs/heads/", "")
      description = pr["description"] || "No description"

      info = [
        "**Pull Request ##{pr['pullRequestId']}**", "",
        "- **Title:** #{pr['title']}",
        "- **Status:** #{pr['status']}",
        "- **Created By:** #{pr['createdBy']['displayName']}",
        "- **Source:** #{source}",
        "- **Target:** #{target}",
        "- **Created:** #{pr['creationDate'][0..9]}",
        "", "**Description:**", description
      ].join("\n")

      success_response(info)
    end

    # === Helpers ===

    def fetch_all_prs(project)
      encoded_project = encode_path(project)
      url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/git/pullrequests?api-version=7.0"
      api_request(:get, url)
    end

    def filter_prs_by_user(prs, user_name)
      user_name_parts = user_name.to_s.downcase.split(/\s+/)

      prs.select do |pr|
        creator = pr.dig("createdBy", "displayName").to_s.downcase
        user_name_parts.any? { |part| creator.include?(part) && part.length > 2 }
      end
    end
  end
end
