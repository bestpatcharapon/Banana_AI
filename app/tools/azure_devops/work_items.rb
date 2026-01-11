# frozen_string_literal: true

module AzureDevops
  # Work Items CRUD and Comments
  module WorkItems
    include AzureDevops::Base

    THAILAND_UTC_OFFSET = 7 * 60 * 60
    DEFAULT_COUNT = 20
    NO_STATE_CHANGES_TODAY = "ไม่มีการเปลี่ยน State วันนี้ 🎉"
    NO_ACTIVE_ITEMS = "ไม่พบงาน Active ที่ Assigned ให้คุณในขณะนี้ 🎉"

    # === List Work Items ===

    def list_work_items(project, query = nil, count = DEFAULT_COUNT)
      return error_response("Project is required") unless project

      sprint_info = fetch_sprint_context(project)
      work_items = fetch_work_items_by_query(project, query, count)

      return success_response("#{sprint_info}No work items found") if work_items.empty?

      formatted = format_work_items_list(work_items)
      success_response("#{sprint_info}Work Items in #{project}:\n\n#{formatted}")
    end

    def list_all_active_work_items(count = 10)
      projects = fetch_all_projects
      return error_response("No projects found") if projects.empty?

      all_items, summaries = collect_active_items_from_projects(projects, count)
      format_all_active_output(projects, all_items, summaries)
    end

    def list_my_active_work_items(user_email_or_name, count = 10)
      return error_response("กรุณาระบุ email หรือชื่อผู้ใช้") unless user_email_or_name

      projects = fetch_all_projects
      return error_response("No projects found") if projects.empty?

      all_items, summaries = collect_user_active_items(projects, user_email_or_name, count)
      format_my_active_output(user_email_or_name, all_items)
    end

    def list_my_state_changes_today(user_name, count = DEFAULT_COUNT)
      return error_response("User name is required") unless user_name

      today_thai = thailand_today
      projects = fetch_all_projects
      return error_response("No projects found") if projects.empty?

      changes = collect_state_changes(projects, user_name, today_thai, count)
      format_state_changes_output(changes, today_thai)
    end

    # === Single Work Item Operations ===

    def get_work_item(id)
      return error_response("Work item ID is required") unless id

      url = "https://dev.azure.com/#{ORGANIZATION}/_apis/wit/workitems/#{id}?api-version=7.0&$expand=all"
      result = api_request(:get, url)
      format_work_item_details(result)
    end

    def create_work_item(project, type, title, description, assigned_to, sprint)
      return error_response("Project, type, and title are required") unless project && type && title

      url = build_create_work_item_url(project, type)
      operations = build_create_operations(title, description, assigned_to, sprint)
      result = api_request(:post, url, operations.to_json, "application/json-patch+json")

      success_response("✅ Created work item ##{result['id']}: #{title}")
    end

    def update_work_item(id, title, description, state, assigned_to, sprint)
      return error_response("Work item ID is required") unless id

      operations = build_update_operations(title, description, state, assigned_to, sprint)
      return error_response("No fields to update") if operations.empty?

      url = "https://dev.azure.com/#{ORGANIZATION}/_apis/wit/workitems/#{id}?api-version=7.0"
      result = api_request(:patch, url, operations.to_json, "application/json-patch+json")

      success_response("✅ Updated work item ##{result['id']}")
    end

    def delete_work_item(id)
      return error_response("Work item ID is required") unless id

      url = "https://dev.azure.com/#{ORGANIZATION}/_apis/wit/workitems/#{id}?api-version=7.0"
      api_request(:delete, url)

      success_response("✅ Deleted work item ##{id}")
    end

    # === Comments ===

    def add_comment(project, work_item_id, comment)
      return error_response("Project, work item ID, and comment are required") unless project && work_item_id && comment

      encoded_project = encode_path(project)
      url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/wit/workItems/#{work_item_id}/comments?api-version=7.0-preview.3"
      api_request(:post, url, { text: comment })

      success_response("✅ Added comment to work item ##{work_item_id}")
    end

    def list_comments(project, work_item_id)
      return error_response("Project and work item ID are required") unless project && work_item_id

      encoded_project = encode_path(project)
      url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/wit/workItems/#{work_item_id}/comments?api-version=7.0-preview.3"
      result = api_request(:get, url)

      comments = format_comments(result["comments"])
      success_response("Comments on work item ##{work_item_id}:\n\n#{comments}")
    end

    private

    # === Helper Methods ===

    def thailand_today
      thailand_now = Time.now.utc + THAILAND_UTC_OFFSET
      thailand_now.strftime("%Y-%m-%d")
    end

    def fetch_all_projects
      url = "https://dev.azure.com/#{ORGANIZATION}/_apis/projects?api-version=7.0"
      result = api_request(:get, url)
      result["value"] || []
    end

    def fetch_sprint_context(project)
      sprint_result = get_current_sprint_data(project)
      return "" unless sprint_result

      dates = sprint_result["attributes"]
      start_date = dates["startDate"]&.slice(0, 10)
      finish_date = dates["finishDate"]&.slice(0, 10)
      "📌 **Context:** Current Sprint: #{sprint_result['name']} (#{start_date} to #{finish_date})\n\n"
    rescue StandardError
      ""
    end

    def fetch_work_items_by_query(project, query, count)
      wiql = query || default_work_items_query(project)
      encoded_project = encode_path(project)
      url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/wit/wiql?api-version=7.0"

      result = api_request(:post, url, { query: wiql })
      return [] if result["workItems"].nil? || result["workItems"].empty?

      fetch_work_item_details(result["workItems"].take(count))
    end

    def default_work_items_query(project)
      "SELECT [System.Id], [System.Title], [System.State], [System.AssignedTo] FROM WorkItems WHERE [System.TeamProject] = '#{project}' ORDER BY [System.ChangedDate] DESC"
    end

    def fetch_work_item_details(work_items)
      ids = work_items.map { |wi| wi["id"] }.join(",")
      url = "https://dev.azure.com/#{ORGANIZATION}/_apis/wit/workitems?ids=#{ids}&api-version=7.0"
      result = api_request(:get, url)
      result["value"] || []
    end

    def format_work_items_list(work_items)
      work_items.map do |wi|
        fields = wi["fields"]
        assigned = fields["System.AssignedTo"]&.dig("displayName") || "Unassigned"
        "- **##{wi['id']}** [#{fields['System.WorkItemType']}] #{fields['System.Title']}\n  State: #{fields['System.State']} | Assigned: #{assigned}"
      end.join("\n\n")
    end

    def format_work_item_details(result)
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

    def format_comments(comments)
      return "No comments" if comments.nil? || comments.empty?

      comments.map do |c|
        text = c["text"].gsub(/<[^>]*>/, "")
        "- **#{c['createdBy']['displayName']}** (#{c['createdDate'][0..9]}):\n  #{text}"
      end.join("\n\n")
    end

    # === CRUD Operations Builders ===

    def build_create_work_item_url(project, type)
      encoded_project = encode_path(project)
      encoded_type = encode_path(type)
      "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/wit/workitems/$#{encoded_type}?api-version=7.0"
    end

    def build_create_operations(title, description, assigned_to, sprint)
      operations = [{ op: "add", path: "/fields/System.Title", value: title }]
      operations << { op: "add", path: "/fields/System.Description", value: description } if description
      operations << { op: "add", path: "/fields/System.AssignedTo", value: assigned_to } if assigned_to
      operations << { op: "add", path: "/fields/System.IterationPath", value: sprint } if sprint
      operations
    end

    def build_update_operations(title, description, state, assigned_to, sprint)
      operations = []
      operations << { op: "add", path: "/fields/System.Title", value: title } if title
      operations << { op: "add", path: "/fields/System.Description", value: description } if description
      operations << { op: "add", path: "/fields/System.State", value: state } if state
      operations << { op: "add", path: "/fields/System.AssignedTo", value: assigned_to } if assigned_to
      operations << { op: "add", path: "/fields/System.IterationPath", value: sprint } if sprint
      operations
    end

    # === Active Items Collection ===

    def collect_active_items_from_projects(projects, count)
      all_items = []
      summaries = []

      projects.each do |project|
        items, summary = fetch_active_items_for_project(project["name"], nil, count)
        all_items.concat(items)
        summaries << summary
      end

      [all_items, summaries]
    end

    def collect_user_active_items(projects, user, count)
      all_items = []
      summaries = []

      projects.each do |project|
        items, summary = fetch_active_items_for_project(project["name"], user, count)
        all_items.concat(items)
        summaries << summary if items.any?
      end

      [all_items, summaries]
    end

    def fetch_active_items_for_project(project_name, user, count)
      wiql = build_active_items_query(project_name, user)
      encoded_project = encode_path(project_name)
      url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/wit/wiql?api-version=7.0"

      result = api_request(:post, url, { query: wiql })

      if result["workItems"] && !result["workItems"].empty?
        items = fetch_and_parse_active_items(result["workItems"], project_name, count)
        summary = "- **#{project_name}**: #{items.count} งาน Active"
        [items, summary]
      else
        [[], "- **#{project_name}**: ไม่มีงาน Active"]
      end
    rescue StandardError => e
      [[], "- **#{project_name}**: Error - #{e.message[0..50]}"]
    end

    def build_active_items_query(project_name, user)
      base = "SELECT [System.Id], [System.Title], [System.State], [System.AssignedTo], [System.WorkItemType], [System.IterationPath] FROM WorkItems WHERE [System.TeamProject] = '#{project_name}' AND [System.State] = 'Active'"
      base += " AND [System.AssignedTo] CONTAINS '#{user}'" if user
      base + " ORDER BY [System.ChangedDate] DESC"
    end

    def fetch_and_parse_active_items(work_items, project_name, count)
      ids = work_items.take(count).map { |wi| wi["id"] }.join(",")
      url = "https://dev.azure.com/#{ORGANIZATION}/_apis/wit/workitems?ids=#{ids}&api-version=7.0"
      details = api_request(:get, url)

      details["value"].map do |wi|
        fields = wi["fields"]
        iteration = fields["System.IterationPath"] || "No Sprint"
        {
          project: project_name,
          id: wi["id"],
          type: fields["System.WorkItemType"],
          title: fields["System.Title"],
          state: fields["System.State"],
          assigned: fields["System.AssignedTo"]&.dig("displayName") || "Unassigned",
          sprint: iteration.split("\\").last
        }
      end
    end

    # === Output Formatting ===

    def format_all_active_output(projects, all_items, summaries)
      output = ["## 📊 สรุปงาน Active จากทุกโปรเจค", ""]
      output << "### โปรเจคทั้งหมด #{projects.count} โปรเจค"
      output.concat(summaries)
      output << ""

      if all_items.any?
        output << "### 📋 รายการงาน Active ทั้งหมด (#{all_items.count} งาน)"
        output << ""
        output.concat(format_items_grouped_by_project(all_items, :full))
      else
        output << "### ❌ ไม่พบงาน Active ในทุกโปรเจค"
      end

      success_response(output.join("\n"))
    end

    def format_my_active_output(user, all_items)
      user_display = user.split("@").first.capitalize rescue user
      output = ["## 📊 งาน Active ของ **#{user_display}**", ""]

      if all_items.any?
        projects_count = all_items.map { |wi| wi[:project] }.uniq.count
        output << "มี **#{all_items.count} งาน** Active จาก **#{projects_count} โปรเจค**:"
        output << ""
        output.concat(format_items_grouped_by_project(all_items, :compact))
        output << "---"
        output << ""
        output << "## 🔥 งานสำคัญ (Critical Tasks)"
        all_items.take(5).each do |wi|
          output << "• **##{wi[:id]}** [#{wi[:type]}] #{wi[:title]} | Sprint: #{wi[:sprint]}"
        end
      else
        output << NO_ACTIVE_ITEMS
      end

      success_response(output.join("\n"))
    end

    def format_items_grouped_by_project(items, style)
      output = []
      items.group_by { |wi| wi[:project] }.each_with_index do |(project, project_items), index|
        if style == :full
          output << "#### 📁 #{project}"
          project_items.each do |wi|
            output << "- **##{wi[:id]}** [#{wi[:type]}] #{wi[:title]}"
            output << "  สถานะ: #{wi[:state]} | Sprint: #{wi[:sprint]} | ผู้รับผิดชอบ: #{wi[:assigned]}"
          end
        else
          output << "### #{index + 1}. #{project} - มีงาน Active #{project_items.count} งาน"
          project_items.each do |wi|
            output << "• **##{wi[:id]}** [#{wi[:type]}] #{wi[:title]} | Sprint: #{wi[:sprint]}"
          end
        end
        output << ""
      end
      output
    end

    # === State Changes ===

    def collect_state_changes(projects, user_name, today_thai, count)
      all_changes = []

      projects.each do |project|
        changes = fetch_state_changes_for_project(project["name"], user_name, today_thai, count)
        all_changes.concat(changes)
      end

      deduplicate_and_sort_changes(all_changes)
    end

    def fetch_state_changes_for_project(project_name, user_name, today_thai, count)
      wiql = "SELECT [System.Id] FROM WorkItems WHERE [System.AssignedTo] CONTAINS '#{user_name}' AND [System.ChangedDate] >= @Today-1 ORDER BY [System.ChangedDate] DESC"
      encoded_project = encode_path(project_name)
      url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/wit/wiql?api-version=7.0"

      result = api_request(:post, url, { query: wiql })
      return [] if result["workItems"].nil? || result["workItems"].empty?

      collect_changes_from_work_items(result["workItems"].take(count), project_name, today_thai, encoded_project)
    rescue StandardError
      []
    end

    def collect_changes_from_work_items(work_items, project_name, today_thai, encoded_project)
      changes = []

      work_items.each do |wi|
        wi_changes = fetch_work_item_state_changes(wi["id"], project_name, today_thai, encoded_project)
        changes.concat(wi_changes)
      end

      changes
    end

    def fetch_work_item_state_changes(wi_id, project_name, today_thai, encoded_project)
      updates_url = "https://dev.azure.com/#{ORGANIZATION}/#{encoded_project}/_apis/wit/workitems/#{wi_id}/updates?api-version=7.0"
      updates = api_request(:get, updates_url)
      return [] if updates["value"].nil?

      parse_state_changes(updates["value"], wi_id, project_name, today_thai)
    end

    def parse_state_changes(updates, wi_id, project_name, today_thai)
      changes = []

      updates.reverse_each do |update|
        change = extract_state_change(update, wi_id, project_name, today_thai)
        changes << change if change
      end

      changes
    end

    def extract_state_change(update, wi_id, project_name, today_thai)
      changed_date_str = update.dig("revisedDate") || ""
      return nil if changed_date_str.start_with?("9999")

      thai_date, thai_time = parse_to_thailand_time(changed_date_str)
      return nil unless thai_date == today_thai

      old_state = update.dig("fields", "System.State", "oldValue")
      new_state = update.dig("fields", "System.State", "newValue")
      return nil unless old_state && new_state && old_state != new_state

      title = fetch_work_item_title(wi_id)

      {
        time: thai_time,
        id: wi_id,
        title: title,
        project: project_name,
        old_state: old_state,
        new_state: new_state
      }
    rescue StandardError
      nil
    end

    def parse_to_thailand_time(date_str)
      utc_time = Time.parse(date_str)
      thai_time = utc_time + THAILAND_UTC_OFFSET
      [thai_time.strftime("%Y-%m-%d"), thai_time.strftime("%H:%M")]
    end

    def fetch_work_item_title(wi_id)
      url = "https://dev.azure.com/#{ORGANIZATION}/_apis/wit/workitems/#{wi_id}?api-version=7.0"
      result = api_request(:get, url)
      result.dig("fields", "System.Title") || "Unknown"
    end

    def deduplicate_and_sort_changes(changes)
      changes
        .uniq { |c| "#{c[:id]}-#{c[:time]}-#{c[:old_state]}-#{c[:new_state]}" }
        .sort_by { |c| c[:time] }
        .reverse
    end

    def format_state_changes_output(changes, today_thai)
      return success_response(NO_STATE_CHANGES_TODAY) if changes.empty?

      output = ["## 📊 State Changes วันนี้ (#{today_thai})", ""]
      output << "มี **#{changes.count}** การเปลี่ยน State:"
      output << ""

      changes.each do |change|
        truncated_title = change[:title][0..40]
        output << "• **#{change[:time]}** | ##{change[:id]} #{truncated_title}"
        output << "  #{change[:old_state]} → #{change[:new_state]}"
        output << ""
      end

      success_response(output.join("\n"))
    end
  end
end
