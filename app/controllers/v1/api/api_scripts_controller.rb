class V1::Api::ApiScriptsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    @script = Script.new(script_upload_params).merge!(user_id: 4, status: 'uploaded', history: {})

    respond_to do |format|
      if @script.save
        RunScriptWorker.perform_in(50.seconds, @script)
        puts "Script was successfully created"
        format.html { }
        format.json { }
      else
        puts "Uprocessable Entity"
        format.html {}
        format.json {}
      end
    end
  end

  def check
    if !params[:id].nil?
      @script = Script.find_by_id(params[:id])
    elsif !params[:name].nil?
      @script = Script.find("name": params[:name])
    else
      @script = nil
    end

    respond_to do |format|
      if !@script.nil?
        format.json { render :json => @script.status }
      else
        format.json { render :json => "Not found" }
      end
    end
  end

  private
    def script_upload_params
      params.permit(:name, :description, :language, :text)
    end
    def script_check_params
      params.permit(:id, :name)
    end
end
