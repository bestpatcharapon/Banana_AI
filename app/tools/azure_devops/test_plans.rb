# frozen_string_literal: true

module AzureDevops
  # Test Plans, Suites, and Cases
  module TestPlans
    include AzureDevops::Base

    NO_TEST_PLANS = "No test plans found"
    NO_TEST_CASES = "No test cases found"

    def list_test_plans(project)
      return error_response("Project is required") unless project

      encoded_project = encode_path(project)
      url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/testplan/plans?api-version=7.0"
      result = api_request(:get, url)

      return success_response(NO_TEST_PLANS) if result["value"].nil? || result["value"].empty?

      plans = format_test_plans(result["value"])
      success_response("Test Plans in #{project}:\n\n#{plans}")
    end

    def list_test_suites(project, test_plan_id)
      return error_response("Project and test plan ID are required") unless project && test_plan_id

      encoded_project = encode_path(project)
      url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/testplan/Plans/#{test_plan_id}/suites?api-version=7.0"
      result = api_request(:get, url)

      suites = format_test_suites(result["value"])
      success_response("Test Suites in Plan ##{test_plan_id}:\n\n#{suites}")
    end

    def list_test_cases(project, test_plan_id, test_suite_id)
      return error_response("Project, test plan ID, and test suite ID are required") unless project && test_plan_id && test_suite_id

      encoded_project = encode_path(project)
      url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/testplan/Plans/#{test_plan_id}/Suites/#{test_suite_id}/TestCase?api-version=7.0"
      result = api_request(:get, url)

      return success_response(NO_TEST_CASES) if result["value"].nil? || result["value"].empty?

      cases = format_test_cases(result["value"])
      success_response("Test Cases in Suite ##{test_suite_id}:\n\n#{cases}")
    end

    private

    def format_test_plans(plans)
      plans.map do |plan|
        "- **#{plan['name']}** (ID: #{plan['id']}) - State: #{plan['state']}"
      end.join("\n")
    end

    def format_test_suites(suites)
      suites.map do |suite|
        "- **#{suite['name']}** (ID: #{suite['id']}) - Type: #{suite['suiteType']}"
      end.join("\n")
    end

    def format_test_cases(cases)
      cases.map do |tc|
        work_item = tc["workItem"]
        "- **##{work_item['id']}**: #{work_item['name']}"
      end.join("\n")
    end
  end
end
