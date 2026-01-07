# frozen_string_literal: true

module AzureDevops
  # Test Plans, Suites, and Cases
  module TestPlans
    include AzureDevops::Base

    def list_test_plans(project)
      return error_response("Project is required") unless project
      encoded_project = encode_path(project)
      url = "https://dev.azure.com/#{AzureDevops::Base::ORGANIZATION}/#{encoded_project}/_apis/testplan/plans?api-version=7.0"
      result = api_request(:get, url)

      if result["value"].nil? || result["value"].empty?
        return success_response("No test plans found")
      end

      plans = result["value"].map { |p| "- **#{p['name']}** (ID: #{p['id']}) - State: #{p['state']}" }.join("\n")
      success_response("Test Plans in #{project}:\n\n#{plans}")
    end

    def list_test_suites(project, test_plan_id)
      return error_response("Project and test plan ID are required") unless project && test_plan_id
      encoded_project = encode_path(project)
      url = "https://dev.azure.com/#{AzureDevops::Base::ORGANIZATION}/#{encoded_project}/_apis/testplan/Plans/#{test_plan_id}/suites?api-version=7.0"
      result = api_request(:get, url)

      suites = result["value"].map { |s| "- **#{s['name']}** (ID: #{s['id']}) - Type: #{s['suiteType']}" }.join("\n")
      success_response("Test Suites in Plan ##{test_plan_id}:\n\n#{suites}")
    end

    def list_test_cases(project, test_plan_id, test_suite_id)
      return error_response("Project, test plan ID, and test suite ID are required") unless project && test_plan_id && test_suite_id
      encoded_project = encode_path(project)
      url = "https://dev.azure.com/#{AzureDevops::Base::ORGANIZATION}/#{encoded_project}/_apis/testplan/Plans/#{test_plan_id}/Suites/#{test_suite_id}/TestCase?api-version=7.0"
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
  end
end
