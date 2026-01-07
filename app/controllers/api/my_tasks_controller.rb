# frozen_string_literal: true

class Api::MyTasksController < ActionController::Base
  skip_before_action :verify_authenticity_token
  before_action :set_cors_headers
  
  # Handle CORS preflight OPTIONS request
  def options
    head :ok
  end
  
  private
  
  def set_cors_headers
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
    headers['Access-Control-Allow-Headers'] = 'Content-Type, Accept'
  end
  
  public
  
  # GET /api/my_tasks
  # ดึงงาน Active ของ user ที่ login อยู่
  def index
    # ดึง user จาก session (จาก Microsoft 365 OAuth)
    current_user_email = session[:user_email]
    current_user_name = session[:user_name]
    
    # ถ้ายังไม่ได้ login ให้ redirect ไป login
    unless current_user_email || current_user_name
      render json: { 
        error: "กรุณา Login ด้วย Microsoft 365 ก่อน",
        login_url: "/auth/microsoft"
      }, status: :unauthorized
      return
    end
    
    # เรียก tool ดึงงานของ user
    user_identifier = current_user_name || current_user_email
    
    # ส่ง Access Token ไปด้วย (ถ้ามี)
    result = AzureDevopsTool.call(
      action: "list_my_active_work_items",
      assigned_to: user_identifier,
      access_token: session[:ado_token], # ส่ง token ของ user
      server_context: nil
    )
    
    # ส่ง result กลับ
    content = result.content.first[:text]
    
    render json: {
      user: {
        email: current_user_email,
        name: current_user_name
      },
      content: content,
      timestamp: Time.now.iso8601
    }
  end
  
  # GET/POST /api/my_tasks/demo
  # สำหรับ demo/test โดยไม่ต้อง login จริง
  def demo
    # รองรับทั้ง query params (?user_name=xxx) และ body params
    user_name = params[:user_name] || "Patcharapon Yoriya"
    
    result = AzureDevopsTool.call(
      action: "list_my_active_work_items",
      assigned_to: user_name,
      server_context: nil
    )
    
    content = result.content.first[:text]
    
    render json: {
      user: { name: user_name },
      content: content,
      timestamp: Time.now.iso8601
    }
  rescue => e
    render json: {
      error: e.message,
      user: { name: user_name }
    }, status: :internal_server_error
  end
end
