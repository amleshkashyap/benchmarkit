class V1::Api::ApiScriptsController < ApplicationController
  skip_before_action :verify_authenticity_token
  DEFAULT_ITERATIONS = 1000

  def create_script
    @script = Script.new(script_upload_params)

    user_result = params[:result] || nil
    # add validations for user results, ie, integer, boolean, string only
    user_iterations = params[:iters] || DEFAULT_ITERATIONS
    respond_to do |format|
      if @script.save
        RunScriptWorker.perform_in(5.seconds, @script.id, user_iterations, user_result)
        puts "Script was successfully created"
        format.json { render :json => "Uploaded successfully" }
      else
        puts "Uprocessable Entity"
        format.json { render :json => "Upload failed" }
      end
    end
  end

  def check_script
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

    respond_to do |format|
      if !@script.nil?
        format.json { render :json => @script.status }
      else
        format.json { render :json => "Not found" }
      end
    end
  end

  # this is in case of sanitization, validation and execution errors - will identify the last executed version if exists (both success/error)
  # priority order for identification is sanitization error, validation error, execution error, execution success
  def resubmit_script
    @script = Script.find_by_id(params[:id])
    if @script.nil?
      respond_to do |format|
        format.json { render :json => "Not found" }
      end
    end

    status = @script.status
    if status == "error"
      # save the new script, launch the sanitization worker
      @script.textfile = params[:textfile]
      user_result = params[:result] || nil
      # add validations for user results, ie, integer, boolean, string only
      user_iterations = params[:iters] || DEFAULT_ITERATIONS
      if @script.save
	RunScriptWorker.perform_in(5.seconds, @script.id, user_iterations, user_result)
        respond_to
      else
        respond_to
      end
    else
      # don't allow resubmitting the script if it worked successfully - 
      respond_to
    end
  end

  # this reruns the most recent successfully executed version of the script
  # simply use the currently attached file
  def rerun_script
    @script = Script.find_by_id(params[:id])
    @metric = Metric.new(:code_id => @script.latest_code_id, :execute_from => "attached_file")
    @metric.save
    user_iterations = params[:iters] || DEFAULT_ITERATIONS
    ExecuteScriptWorker.perform_in(10.seconds, @metric.id, user_iterations)
    @script["status"] = "rerun"
    @script.save
    respond_to do |format|
      format.json = { }
    end
  end

  # this allows rerunning a specific executed version of the script - later
  def rerun_code
  end

  private
    def script_upload_params
      params.permit(:name, :description, :language, :textfile).merge!(user_id: 3).merge!(status: 'uploaded')
    end
    def script_check_params
      params.permit(:id, :name)
    end
end
