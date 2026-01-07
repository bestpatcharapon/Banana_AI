# frozen_string_literal: true

module AzureDevops
  # Work Items CRUD and Comments
  module WorkItems
    include AzureDevops::Base

    def list_work_items(project, query = nil, count = 20)
      return error_response("Project is required") unless project

      # 1. Try to get Sprint Info first (Context)
      sprint_info = ""
      begin
        sprint_result = get_current_sprint_data(project)
        if sprint_result
          dates = sprint_result["attributes"]
          sprint_info = "📌 **Context:** Current Sprint: #{sprint_result['name']} (#{dates['startDate']&.slice(0, 10)} to #{dates['finishDate']&.slice(0, 10)})\n\n"
        end
      rescue => e
        # Ignore sprint error, just list items
      end

      # 2. Get Work Items
      wiql = query || "SELECT [System.Id], [System.Title], [System.State], [System.AssignedTo] FROM WorkItems WHERE [System.TeamProject] = '#{project}' ORDER BY [System.ChangedDate] DESC"

      encoded_project = encode_path(project)
      url = "https://dev.azure.com/#{AzureDevops::Base::ORGANIZATION}/#{encoded_project}/_apis/wit/wiql?api-version=7.0"
      result = api_request(:post, url, { query: wiql })

      return success_response("#{sprint_info}No work items found") if result["workItems"].nil? || result["workItems"].empty?

      ids = result["workItems"].take(count).map { |wi| wi["id"] }.join(",")
      details_url = "https://dev.azure.com/#{AzureDevops::Base::ORGANIZATION}/_apis/wit/workitems?ids=#{ids}&api-version=7.0"
      details = api_request(:get, details_url)

      work_items = details["value"].map do |wi|
        fields = wi["fields"]
        assigned = fields["System.AssignedTo"]&.dig("displayName") || "Unassigned"
        "- **##{wi['id']}** [#{fields['System.WorkItemType']}] #{fields['System.Title']}\n  State: #{fields['System.State']} | Assigned: #{assigned}"
      end.join("\n\n")

      success_response("#{sprint_info}Work Items in #{project}:\n\n#{work_items}")
    end

    def get_work_item(id)
      return error_response("Work item ID is required") unless id
      url = "https://dev.azure.com/#{AzureDevops::Base::ORGANIZATION}/_apis/wit/workitems/#{id}?api-version=7.0&$expand=all"
      result = api_request(:get, url)

      fields = result["fields"]
      assigned = fields["System.AssignedTo"]&.dig("displayName") || "Unassigned"
      desc = (fields["System.Description"] || "No description").gsub(/<[^>]*>/, "")

      info = [
        "**Work Item ##{result['id']}**", "",
        "- **Type:** #{fields['System.WorkItemType']}",
        "- **Title:** #{fields['System.Title']}",
        "- **State:** #{fields['System.State']}",
        "- **Assigned To:** #{assigned}",
        "- **Iteration:** #{fields['System.IterationPath']}",
        "- **Area:** #{fields['System.AreaPath']}",
        "- **Created:** #{fields['System.CreatedDate']}",
        "", "**Description:**", desc
      ].join("\n")

      success_response(info)
    end

    def create_work_item(project, type, title, description, assigned_to, sprint)
      return error_response("Project, type, and title are required") unless project && type && title

      encoded_project = encode_path(project)
      encoded_type = encode_path(type)
      url = "https://dev.azure.com/#{AzureDevops::Base::ORGANIZATION}/#{encoded_project}/_apis/wit/workitems/$#{encoded_type}?api-version=7.0"

      operations = [{ op: "add", path: "/fields/System.Title", value: title }]
      operations << { op: "add", path: "/fields/System.Description", value: description } if description
      operations << { op: "add", path: "/fields/System.AssignedTo", value: assigned_to } if assigned_to
      operations << { op: "add", path: "/fields/System.IterationPath", value: sprint } if sprint

      result = api_request(:post, url, operations.to_json, "application/json-patch+json")
      success_response("✅ Created work item ##{result['id']}: #{title}")
    end

    def update_work_item(id, title, description, state, assigned_to, sprint)
      return error_response("Work item ID is required") unless id

      url = "https://dev.azure.com/#{AzureDevops::Base::ORGANIZATION}/_apis/wit/workitems/#{id}?api-version=7.0"

      operations = []
      operations << { op: "add", path: "/fields/System.Title", value: title } if title
      operations << { op: "add", path: "/fields/System.Description", value: description } if description
      operations << { op: "add", path: "/fields/System.State", value: state } if state
      operations << { op: "add", path: "/fields/System.AssignedTo", value: assigned_to } if assigned_to
      operations << { op: "add", path: "/fields/System.IterationPath", value: sprint } if sprint

      return error_response("No fields to update") if operations.empty?

      result = api_request(:patch, url, operations.to_json, "application/json-patch+json")
      success_response("✅ Updated work item ##{result['id']}")
    end

    def delete_work_item(id)
      return error_response("Work item ID is required") unless id
      url = "https://dev.azure.com/#{AzureDevops::Base::ORGANIZATION}/_apis/wit/workitems/#{id}?api-version=7.0"
      api_request(:delete, url)
      success_response("✅ Deleted work item ##{id}")
    end

    def add_comment(project, work_item_id, comment)
      return error_response("Project, work item ID, and comment are required") unless project && work_item_id && comment
      encoded_project = encode_path(project)
      url = "https://dev.azure.com/#{AzureDevops::Base::ORGANIZATION}/#{encoded_project}/_apis/wit/workItems/#{work_item_id}/comments?api-version=7.0-preview.3"
      api_request(:post, url, { text: comment })
      success_response("✅ Added comment to work item ##{work_item_id}")
    end

    def list_comments(project, work_item_id)
      return error_response("Project and work item ID are required") unless project && work_item_id
      encoded_project = encode_path(project)
      url = "https://dev.azure.com/#{AzureDevops::Base::ORGANIZATION}/#{encoded_project}/_apis/wit/workItems/#{work_item_id}/comments?api-version=7.0-preview.3"
      result = api_request(:get, url)

      comments = result["comments"]&.map do |c|
        "- **#{c['createdBy']['displayName']}** (#{c['createdDate'][0..9]}):\n  #{c['text'].gsub(/<[^>]*>/, '')}"
      end&.join("\n\n") || "No comments"

      success_response("Comments on work item ##{work_item_id}:\n\n#{comments}")
    end

    # ดึงงาน Active เฉพาะของ user ที่ระบุ จากทุกโปรเจค
    def list_my_active_work_items(user_email_or_name, count = 10)
      return error_response("กรุณาระบุ email หรือชื่อผู้ใช้") unless user_email_or_name

      # 1. Get all projects
      projects_url = "https://dev.azure.com/#{AzureDevops::Base::ORGANIZATION}/_apis/projects?api-version=7.0"
      projects_result = api_request(:get, projects_url)

      return error_response("No projects found") if projects_result["value"].nil? || projects_result["value"].empty?

      all_work_items = []
      project_summaries = []

      # 2. Loop through each project and get MY active work items
      projects_result["value"].each do |project|
        project_name = project["name"]

        begin
          # Query for Active work items assigned to specific user
          # ใช้ CONTAINS เพื่อให้ match ได้ทั้ง email และ displayName
          wiql = "SELECT [System.Id], [System.Title], [System.State], [System.AssignedTo], [System.WorkItemType], [System.IterationPath] FROM WorkItems WHERE [System.TeamProject] = '#{project_name}' AND [System.State] = 'Active' AND [System.AssignedTo] CONTAINS '#{user_email_or_name}' ORDER BY [System.ChangedDate] DESC"

          encoded_project = encode_path(project_name)
          url = "https://dev.azure.com/#{AzureDevops::Base::ORGANIZATION}/#{encoded_project}/_apis/wit/wiql?api-version=7.0"
          result = api_request(:post, url, { query: wiql })

          if result["workItems"] && !result["workItems"].empty?
            ids = result["workItems"].take(count).map { |wi| wi["id"] }.join(",")
            details_url = "https://dev.azure.com/#{AzureDevops::Base::ORGANIZATION}/_apis/wit/workitems?ids=#{ids}&api-version=7.0"
            details = api_request(:get, details_url)

            project_items = details["value"].map do |wi|
              fields = wi["fields"]
              assigned = fields["System.AssignedTo"]&.dig("displayName") || "Unassigned"
              iteration = fields["System.IterationPath"] || "No Sprint"
              sprint_name = iteration.split("\\").last
              {
                project: project_name,
                id: wi["id"],
                type: fields["System.WorkItemType"],
                title: fields["System.Title"],
                state: fields["System.State"],
                assigned: assigned,
                sprint: sprint_name
              }
            end

            all_work_items.concat(project_items)
            project_summaries << "- **#{project_name}**: #{project_items.count} งาน Active"
          end
        rescue => e
          # Skip errors silently for projects without items
        end
      end

      # 3. Format output
      user_display = user_email_or_name.split("@").first.capitalize rescue user_email_or_name
      output = ["## 📊 งาน Active ของ **#{user_display}**", ""]
      
      if all_work_items.any?
        total_count = all_work_items.count
        projects_with_items = all_work_items.map { |wi| wi[:project] }.uniq.count
        
        output << "มี **#{total_count} งาน** Active จาก **#{projects_with_items} โปรเจค**:"
        output << ""

        # Group by project
        all_work_items.group_by { |wi| wi[:project] }.each_with_index do |(project, items), index|
          output << "### #{index + 1}. #{project} - มีงาน Active #{items.count} งาน"
          items.each do |wi|
            # แสดงทุกอย่างในบรรทัดเดียว
            output << "• **##{wi[:id]}** [#{wi[:type]}] #{wi[:title]} | Sprint: #{wi[:sprint]}"
          end
          output << ""
        end

        output << "---"
        output << ""
        output << "## 🔥 งานสำคัญ (Critical Tasks)"
        # Show top 3-5 as critical
        all_work_items.take(5).each do |wi|
          output << "• **##{wi[:id]}** [#{wi[:type]}] #{wi[:title]} | Sprint: #{wi[:sprint]}"
        end
      else
        output << "ไม่พบงาน Active ที่ Assigned ให้คุณในขณะนี้ 🎉"
      end

      success_response(output.join("\n"))
    end

    def list_all_active_work_items(count = 10)
      # 1. Get all projects
      projects_url = "https://dev.azure.com/#{AzureDevops::Base::ORGANIZATION}/_apis/projects?api-version=7.0"
      projects_result = api_request(:get, projects_url)

      return error_response("No projects found") if projects_result["value"].nil? || projects_result["value"].empty?

      all_work_items = []
      project_summaries = []

      # 2. Loop through each project and get active work items
      projects_result["value"].each do |project|
        project_name = project["name"]

        begin
          # Query for ONLY "Active" state work items (including Sprint info)
          wiql = "SELECT [System.Id], [System.Title], [System.State], [System.AssignedTo], [System.WorkItemType], [System.IterationPath] FROM WorkItems WHERE [System.TeamProject] = '#{project_name}' AND [System.State] = 'Active' ORDER BY [System.ChangedDate] DESC"

          encoded_project = encode_path(project_name)
          url = "https://dev.azure.com/#{AzureDevops::Base::ORGANIZATION}/#{encoded_project}/_apis/wit/wiql?api-version=7.0"
          result = api_request(:post, url, { query: wiql })

          if result["workItems"] && !result["workItems"].empty?
            ids = result["workItems"].take(count).map { |wi| wi["id"] }.join(",")
            details_url = "https://dev.azure.com/#{AzureDevops::Base::ORGANIZATION}/_apis/wit/workitems?ids=#{ids}&api-version=7.0"
            details = api_request(:get, details_url)

            project_items = details["value"].map do |wi|
              fields = wi["fields"]
              assigned = fields["System.AssignedTo"]&.dig("displayName") || "Unassigned"
              iteration = fields["System.IterationPath"] || "No Sprint"
              # Extract sprint name from path (e.g., "Project\\Sprint 1" -> "Sprint 1")
              sprint_name = iteration.split("\\").last
              {
                project: project_name,
                id: wi["id"],
                type: fields["System.WorkItemType"],
                title: fields["System.Title"],
                state: fields["System.State"],
                assigned: assigned,
                sprint: sprint_name
              }
            end

            all_work_items.concat(project_items)
            project_summaries << "- **#{project_name}**: #{project_items.count} งาน Active"
          else
            project_summaries << "- **#{project_name}**: ไม่มีงาน Active"
          end
        rescue => e
          project_summaries << "- **#{project_name}**: Error - #{e.message[0..50]}"
        end
      end

      # 3. Format output
      output = ["## 📊 สรุปงาน Active จากทุกโปรเจค", ""]
      output << "### โปรเจคทั้งหมด #{projects_result['value'].count} โปรเจค"
      output.concat(project_summaries)
      output << ""

      if all_work_items.any?
        output << "### 📋 รายการงาน Active ทั้งหมด (#{all_work_items.count} งาน)"
        output << ""

        # Group by project
        all_work_items.group_by { |wi| wi[:project] }.each do |project, items|
          output << "#### 📁 #{project}"
          items.each do |wi|
            output << "- **##{wi[:id]}** [#{wi[:type]}] #{wi[:title]}"
            output << "  สถานะ: #{wi[:state]} | Sprint: #{wi[:sprint]} | ผู้รับผิดชอบ: #{wi[:assigned]}"
          end
          output << ""
        end
      else
        output << "### ❌ ไม่พบงาน Active ในทุกโปรเจค"
      end

      success_response(output.join("\n"))
    end
  end
end
