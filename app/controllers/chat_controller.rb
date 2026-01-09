class ChatController < ActionController::Base
  MAX_RETRIES = 3

  def index
  end

  def send_message
    user_message = params[:message]
    
    # SYSTEM PROMPT: Instruct Groq to act as an agent that can uses tools via JSON
    system_prompt = <<~PROMPT
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

    # Retry logic for LLM tool call
    tool_call = nil
    retries = 0
    last_error = nil
    
    while retries < MAX_RETRIES && tool_call.nil?
      begin
        # 1. First Call: Ask Groq
        response = GroqInferenceTool.call(
          model: "llama-3.1-8b-instant",
          prompt: retries > 0 ? "#{user_message} (กรุณาตอบเป็น JSON format เท่านั้น)" : user_message,
          system_prompt: system_prompt,
          server_context: nil
        )
        
        initial_content = response.content.find { |c| c[:type] == "text" }&.dig(:text)
        
        # 2. Check if Groq wants to use a tool (flexible JSON extraction)
        json_match = initial_content.match(/\{.*\}/m)
        
        if json_match
          parsed = JSON.parse(json_match[0])
          
          # Validate that it's a proper tool call
          if parsed["tool"] == "azure-devops-tool" && parsed["action"]
            tool_call = parsed
          else
            last_error = "Invalid tool format"
            retries += 1
            Rails.logger.debug "Retry #{retries}/#{MAX_RETRIES} - #{last_error}"
          end
        else
          # No JSON found - might be a greeting or normal response
          # Return as-is without retry
          render json: { role: "assistant", content: initial_content }
          return
        end
      rescue JSON::ParserError => e
        last_error = "JSON parse error: #{e.message}"
        retries += 1
        Rails.logger.debug "Retry #{retries}/#{MAX_RETRIES} - #{last_error}"
      rescue => e
        last_error = e.message
        retries += 1
        Rails.logger.debug "Retry #{retries}/#{MAX_RETRIES} - #{last_error}"
      end
    end
    
    # If still no valid tool call after retries
    if tool_call.nil?
      render json: { role: "assistant", content: "ขออภัยครับ ไม่สามารถประมวลผลคำขอได้ กรุณาลองใหม่อีกครั้ง (Error: #{last_error})" }
      return
    end
    
    # 3. Execute the real tool
    project_arg = tool_call["project"] || "Banana AI Assistant" # Default project if missing
    
    tool_result = AzureDevopsTool.call(
      action: tool_call["action"],
      project: project_arg,
      query: tool_call["query"],
      server_context: nil
    )
    
    result_text = tool_result.content.first[:text]
    
    # 4. Feed result back to Groq for summarization (with retry)
    final_content = nil
    summarize_retries = 0
    
    while summarize_retries < MAX_RETRIES && final_content.nil?
      begin
        final_response = GroqInferenceTool.call(
          model: "llama-3.1-8b-instant",
          prompt: "User asked: #{user_message}. Tool Result: #{result_text}. สรุปเป็นภาษาไทยตาม format ที่กำหนด",
          system_prompt: <<~SYS_PROMPT
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
          SYS_PROMPT
          .strip,
          server_context: nil
        )
        
        final_content = final_response.content.first[:text]
      rescue => e
        summarize_retries += 1
        Rails.logger.debug "Summarize Retry #{summarize_retries}/#{MAX_RETRIES} - #{e.message}"
        sleep(1) # Wait 1 second before retry
      end
    end
    
    if final_content
      render json: { role: "assistant", content: final_content }
    else
      # Fallback: return raw tool result
      render json: { role: "assistant", content: "📋 ข้อมูลดิบจาก Azure DevOps:\n\n#{result_text}" }
    end

  rescue => e
    Rails.logger.error "Controller Error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { role: "assistant", content: "System Error: #{e.message}" }
  end
end
