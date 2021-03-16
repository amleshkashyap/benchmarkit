class V1::Api::ApiScriptsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    @script = Script.new(script_upload_params)

    respond_to do |format|
      if @script.save
        RunScriptWorker.perform_in(5.seconds, @script.id)
        puts "Script was successfully created"
        format.json { render :json => "Uploaded successfully" }
      else
        puts "Uprocessable Entity"
        format.json { render :json => "Upload failed" }
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

    if !@script.nil?
      @script.textfile.open do |file|
        File.readlines(file).each do |line|
          puts line
        end
      end
    end
#    File.readlines(@script.textfile).each do |line|
#      puts line
#    end
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
      params.permit(:name, :description, :language, :textfile).merge!(user_id: 3).merge!(status: 'uploaded').merge!(history: "")
    end
    def script_check_params
      params.permit(:id, :name)
    end
end
