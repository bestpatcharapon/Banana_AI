class ChatController < ActionController::Base
  def index
    @messages = []
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
      - "get_current_sprint": Get current sprint info. REQUIRES 'project' argument.
      
      IMPORTANT:
      If parsing information, return ONLY a JSON object. Do not speak.
      
      EXAMPLES:
      User: "มีโปรเจกต์อะไรบ้าง", "ใน bananacoding มีโปรเจกต์ไรบ้าง"
      Output: { "tool": "azure-devops-tool", "action": "list_projects" }

      User: "ใน Banana Test Engineer มีงานอะไรบ้าง", "ใครทำอะไรในโปรเจกต์ Banana Test Engineer"
      Output: { "tool": "azure-devops-tool", "action": "list_work_items", "project": "Banana Test Engineer" }

      User: "งานใน Banana AI Assistant เป็นยังไง"
      Output: { "tool": "azure-devops-tool", "action": "list_work_items", "project": "Banana AI Assistant" }

      If you have the information or just greeting, answer in polite Thai.
    PROMPT

    # 1. First Call: Ask Groq
    response = GroqInferenceTool.call(
      model: "llama-3.3-70b-versatile",
      prompt: user_message,
      system_prompt: system_prompt,
      server_context: nil
    )
    
    initial_content = response.content.find { |c| c[:type] == "text" }&.dig(:text)
    
    # 2. Check if Groq wants to use a tool (flexible JSON extraction)
    # Regex to find the first JSON object block { ... }
    json_match = initial_content.match(/\{.*\}/m)
    
    if json_match
      begin
        tool_call = JSON.parse(json_match[0])
        
        # 3. Execute the real tool
        if tool_call["tool"] == "azure-devops-tool"
           project_arg = tool_call["project"] || "Banana AI Assistant" # Default project if missing
           
           tool_result = AzureDevopsTool.call(
             action: tool_call["action"],
             project: project_arg, 
             query: tool_call["query"],
             server_context: nil
           )
           
           result_text = tool_result.content.first[:text]
           
           # 4. Feed result back to Groq for summarization
           final_response = GroqInferenceTool.call(
             model: "llama-3.3-70b-versatile",
             prompt: "User asked: #{user_message}. Tool Result: #{result_text}. ช่วยวิเคราะห์และสรุปเป็นภาษาไทยให้หน่อยครับ ขอแบบละเอียดแต่กระชับ เน้นจุดสำคัญ",
             system_prompt: <<~SYS_PROMPT
               คุณคือ Senior Project Manager มืออาชีพชาวไทย เชี่ยวชาญ Agile และ Azure DevOps
               
               หน้าที่ของคุณ:
               1. สรุปสถานะงาน (Task Status) และภาพรวมจากข้อมูลที่ได้รับ
               2. วิเคราะห์โหลดงานของทีม (ใครถือเยอะสุด, งานกระจุกตัวที่ไหน)
               3. ถ้ามีข้อมูล Sprint/Context ให้ระบุชื่อ Sprint และวันที่เสมอด้านบนสุด
               
               กฎการใช้ภาษา:
               - ใช้ภาษาไทยแบบมืออาชีพ ผสมศัพท์เทคนิคภาษาอังกฤษได้เลย (เช่น Task, Bug, Sprint, Version, Deploy, Production)
               - ห้ามใช้ภาษาจีน ญี่ปุ่น หรือภาษาอื่นที่ไม่ใช่ ไทย/อังกฤษ เด็ดขาด
               - ห้ามแปลคำศัพท์เทคนิคเป็นไทยแบบแปลกๆ (เช่น ไม่ใช้ "รุ่น" หรือ "ฉบับ" ให้ใช้ "Version" ไปเลย)
               
               Format:
               - ใช้ Markdown (Bold, Bullet points) ให้สวยงาม อ่านง่าย
               - แยกหัวข้อให้ชัดเจน (Overview, Team Workload, Critical Tasks)
             SYS_PROMPT
             .strip,
             server_context: nil
           )
           
           final_content = final_response.content.first[:text]
           render json: { role: "assistant", content: final_content }
        else
           render json: { role: "assistant", content: "Unknown tool requested." }
        end
      rescue JSON::ParserError
        # Fallback if JSON is weird
        render json: { role: "assistant", content: initial_content }
      end
    else
      # Normal conversation
      render json: { role: "assistant", content: initial_content }
    end

  rescue => e
    puts "DEBUG: Controller Error: #{e.message}"
    puts e.backtrace
    render json: { role: "assistant", content: "System Error: #{e.message}" }
  end
end
