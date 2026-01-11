# frozen_string_literal: true

class ChatController < ActionController::Base
  MAX_RETRIES = 3
  RETRY_DELAY_SECONDS = 1
  DEFAULT_PROJECT = "Banana AI Assistant"
  DEFAULT_MODEL = "llama-3.1-8b-instant"

  def index
  end

  def send_message
    user_message = params[:message]
    tool_call = parse_tool_call(user_message)

    if tool_call.nil?
      return
    end

    tool_result = execute_tool(tool_call)
    final_content = summarize_result(user_message, tool_result)

    if final_content
      render json: { role: "assistant", content: final_content }
    else
      render json: { role: "assistant", content: "📋 ข้อมูลดิบจาก Azure DevOps:\n\n#{tool_result}" }
    end
  rescue StandardError => e
    Rails.logger.error "Controller Error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { role: "assistant", content: "System Error: #{e.message}" }
  end

  private

  def parse_tool_call(user_message)
    tool_call = nil
    retries = 0
    last_error = nil

    while retries < MAX_RETRIES && tool_call.nil?
      begin
        prompt = retries.positive? ? "#{user_message} (กรุณาตอบเป็น JSON format เท่านั้น)" : user_message

        response = GroqInferenceTool.call(
          model: DEFAULT_MODEL,
          prompt: prompt,
          system_prompt: system_prompt,
          server_context: nil
        )

        initial_content = response.content.find { |c| c[:type] == "text" }&.dig(:text)
        json_match = initial_content&.match(/\{.*\}/m)

        if json_match
          parsed = JSON.parse(json_match[0])
          if valid_tool_call?(parsed)
            tool_call = parsed
          else
            last_error = "Invalid tool format"
            retries += 1
            Rails.logger.debug "Retry #{retries}/#{MAX_RETRIES} - #{last_error}"
          end
        else
          render json: { role: "assistant", content: initial_content }
          return nil
        end
      rescue JSON::ParserError => e
        last_error = "JSON parse error: #{e.message}"
        retries += 1
        Rails.logger.debug "Retry #{retries}/#{MAX_RETRIES} - #{last_error}"
      rescue StandardError => e
        last_error = e.message
        retries += 1
        Rails.logger.debug "Retry #{retries}/#{MAX_RETRIES} - #{last_error}"
      end
    end

    if tool_call.nil?
      render json: { role: "assistant", content: "ขออภัยครับ ไม่สามารถประมวลผลคำขอได้ กรุณาลองใหม่อีกครั้ง (Error: #{last_error})" }
      return nil
    end

    tool_call
  end

  def valid_tool_call?(parsed)
    parsed["tool"] == "azure-devops-tool" && parsed["action"]
  end

  def execute_tool(tool_call)
    project = tool_call["project"] || DEFAULT_PROJECT

    result = AzureDevopsTool.call(
      action: tool_call["action"],
      project: project,
      query: tool_call["query"],
      server_context: nil
    )

    result.content.first[:text]
  end

  def summarize_result(user_message, result_text)
    final_content = nil
    retries = 0

    while retries < MAX_RETRIES && final_content.nil?
      begin
        response = GroqInferenceTool.call(
          model: DEFAULT_MODEL,
          prompt: "User asked: #{user_message}. Tool Result: #{result_text}. สรุปเป็นภาษาไทยตาม format ที่กำหนด",
          system_prompt: summarize_system_prompt,
          server_context: nil
        )

        final_content = response.content.first[:text]
      rescue StandardError => e
        retries += 1
        Rails.logger.debug "Summarize Retry #{retries}/#{MAX_RETRIES} - #{e.message}"
        sleep(RETRY_DELAY_SECONDS)
      end
    end

    final_content
  end

  def system_prompt
    <<~PROMPT
      You are Banana AI, a helpful assistant for Azure DevOps.
      You have access to the following tool:

      Tool: "azure-devops-tool"
      Actions:
      - "list_projects": Get list of all projects.
      - "list_work_items": Get work items (tasks, bugs) in a specific project. REQUIRES 'project' argument.
      - "list_all_active_work_items": Get ALL active work items from ALL projects at once. NO project argument needed.
      - "list_my_active_work_items": Get active work items assigned to a SPECIFIC USER. REQUIRES 'assigned_to' argument (email or name).
      - "get_current_sprint": Get current sprint info. REQUIRES 'project' argument.

      IMPORTANT RULES:
      1. If user asks for work items from "all projects" or "ทุกโปรเจค" or "ทั้งหมด", use "list_all_active_work_items" action.
      2. If user asks for THEIR OWN work or mentions a specific person's name/email, use "list_my_active_work_items" with "assigned_to".
      3. If parsing information, return ONLY a JSON object. Do not speak.
      4. ALWAYS call the tool first, do NOT just tell the user the command format.
      5. You MUST respond with valid JSON like: { "tool": "azure-devops-tool", "action": "..." }

      EXAMPLES:
      User: "มีโปรเจกต์อะไรบ้าง", "ใน bananacoding มีโปรเจกต์ไรบ้าง"
      Output: { "tool": "azure-devops-tool", "action": "list_projects" }

      User: "ใน Banana Test Engineer มีงานอะไรบ้าง", "ใครทำอะไรในโปรเจกต์ Banana Test Engineer"
      Output: { "tool": "azure-devops-tool", "action": "list_work_items", "project": "Banana Test Engineer" }

      User: "ดึงงาน Active จากทุกโปรเจค", "มีงานอะไรต้องทำบ้างจากทุกโปรเจค", "งานที่ยังไม่เสร็จทั้งหมด"
      Output: { "tool": "azure-devops-tool", "action": "list_all_active_work_items" }

      User: "งานของ Patcharapon มีอะไรบ้าง", "ดึงงานของฉัน (patcharapon@banana.com)"
      Output: { "tool": "azure-devops-tool", "action": "list_my_active_work_items", "assigned_to": "Patcharapon" }

      User: "งานของ Jessada Boonta", "jessada.b@bananacoding.com มีงานอะไร"
      Output: { "tool": "azure-devops-tool", "action": "list_my_active_work_items", "assigned_to": "Jessada Boonta" }

      User: "งานใน Banana AI Assistant เป็นยังไง"
      Output: { "tool": "azure-devops-tool", "action": "list_work_items", "project": "Banana AI Assistant" }

      If you have the information or just greeting, answer in polite Thai.
    PROMPT
  end

  def summarize_system_prompt
    <<~PROMPT.strip
      คุณคือ Senior Project Manager มืออาชีพชาวไทย เชี่ยวชาญ Agile และ Azure DevOps

      ## รูปแบบการตอบ (ต้องทำตาม 100%)

      **ตัวอย่าง Output ที่ถูกต้อง:**
      ```
      ## 📊 สรุปงาน Active จาก Azure DevOps

      มีทั้งหมด 3 โปรเจค:

      ### 1. Banana Bootcamp - มีงาน Active 2 งาน
      • **#21154** [Task] ชื่องาน 1
      • **#21155** [Task] ชื่องาน 2

      ### 2. Banana Test Engineer - มีงาน Active 3 งาน
      • **#22155** [Task] R&D - how to test AI
      • **#22156** [Task] Bootcamp-Wiki-TE
      • **#22157** [Task] prepare foundation

      ### 3. Banana AI Assistant - มีงาน Active 1 งาน
      • **#23155** [Task] Design Test Case for prompt AI

      ---

      ## 🔥 งานสำคัญ (Critical Tasks)
      • **#23155** [Task] Design Test Case for prompt AI
      • **#22157** [Task] prepare foundation
      ```

      ## กฎสำคัญ
      1. ต้องแสดง **#WorkItemID** เสมอ (เช่น #21154)
      2. ต้องแสดง **[Type]** เช่น [Task], [Bug], [User Story]
      3. จัดกลุ่มตามโปรเจค และแสดงจำนวนงานในแต่ละโปรเจค
      4. ใช้ emoji 📊 🔥 ให้ดูสวยงาม
      5. ห้ามใช้ภาษาจีน ญี่ปุ่น - ใช้เฉพาะไทย/อังกฤษ
      6. ห้ามสรุปรวมๆ ต้องแสดงรายละเอียดทุกงาน Active
      7. Critical Tasks = เลือก 3-5 งานที่สำคัญที่สุด
    PROMPT
  end
end
