class V1::Api::ApiScriptsController < ApplicationController
  before_action :authenticate_user!
  skip_before_action :verify_authenticity_token
  DEFAULT_ITERATIONS = 1000

  def create_script
    if script_upload_params
      @script = Script.new(:name => params[:name], :description => params[:description], :language => params[:language], :textfile => params[:textfile], :user_id => 3, :status => 'uploaded')
    else
      respond_to do |format|
        format.json { render :json => "Invalid Parameters" }
      end
    end

    user_result = params[:result] || nil
    # add validations for user results, ie, integer, boolean, string only
    user_iterations = params[:iters] || DEFAULT_ITERATIONS
    respond_to do |format|
      if @script.save
        jid = SanitizeScriptWorker.perform_in(30.seconds, @script.id, user_iterations, user_result)
        @script.last_jid = jid
        @script.save
        puts "Script was successfully created"
	format.json { render :json => "Uploaded successfully: " + @script.id.to_s }
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
      if @script.nil?
        format.json { render :json => "Not found" }
      elsif @script.status != "executed"
        new_obj = Util.find_in_retry_set(@script.last_jid)
        new_obj = Util.find_in_dead_set(@script.last_jid) if new_obj.nil?
        if new_obj.nil?
          format.json { render :json => "status: " + @script.status + "\ndetails: " + @script.description }
        else
          format.json { render :json => new_obj }
        end
      else
	new_obj = @script.get_latest_execution_values
        format.json { render :json =>  new_obj }
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
      @script.status = "resubmit_uploaded"
      @script.description = "Uploaded New File Successfully"
      if @script.save
	jid = SanitizeScriptWorker.perform_in(30.seconds, @script.id, user_iterations, user_result)
        @script.last_jid = jid
        @script.save
        respond_to do |format|
	  format.json { render :json => "Uploaded Successfully" }
        end
      else
        respond_to do |format|
          format.json { render :json => "Upload Failed" }
        end
      end
    else
      # don't allow resubmitting the script if it worked successfully - 
      respond_to do |format|
        format.json { render :json => "This Script Has Executed Successfully And Can't Be Modified, Try Rerunning" }
      end
    end
  end

  # this reruns the most recent successfully executed version of the script
  # simply use the currently attached file
  def rerun_script
    @script = Script.find_by_id(params[:id])

    if @script.nil?
      respond_to do |format|
        format.json { render :json => "Script Not Found" }
      end
    end

    if @script.status != 'executed'
      respond_to do |format|
        format.json { render :json => "Can't Execute This Script, Please Resubmit" }
      end
    end

    iterations = params[:iters] || DEFAULT_ITERATIONS
    @metric = Metric.new(:code_id => @script.latest_code_id, :script_id => @script.id, :execute_from => "attached_file", :iterations => iterations, :status => 'enqueued')
    @metric.save
    jid = ExecuteScriptWorker.perform_in(60.seconds, @metric.id)
    @metric.jid = jid
    @metric.save
    @script.status = "rerun_enqueued"
    @script.latest_metric_id = @metric.id
    @script.last_jid = jid
    if @script.save
      respond_to do |format|
        format.json { render :json => "Submitted For Execution" }
      end
    else
      respond_to do |format|
        format.json { render :json => "Submitted for Execution, Error in Updating Status" }
      end
    end
  end

  # this allows rerunning a specific executed version of the script - later
  def rerun_code
	  @code = Code.find_by_id(params[:id])
    if @code.nil?
      respond_to do |format|
        format.json { render :json => "Code Not Found" }
      end
    elsif @code.status != "validated"
      respond_to do |format|
        format.json { render :json => "This Code Is Not Suitable For Execution" }
      end
    end

    iterations = params[:iters] || DEFAULT_ITERATIONS
    @metric = Metric.new(:code_id => @code.id, :script_id => 1, :execute_from => "stored_code", :iterations => iterations, :status => "enqueued")
    @metric.save
    jid = ExecuteScriptWorker.perform_in(60.seconds, @metric.id)
    @metric.jid = jid
    @metric.save
    respond_to do |format|
      format.json { render :json => "Submitted For Execution, Metric ID: " + @metric.id.to_s }
    end
  end

  def get_metric
    @metric = Metric.find_by_id(params[:id])
    response_message = nil
    if @metric.nil?
      response_message = "Not Found"
    elsif @metric.status != "success"
      response_message = "Execution Failed"
    else
      response_message = @metric.get_execution_values
    end
    respond_to do |format|
      format.json { render :json => response_message }
    end
  end

  def get_sidekiq_jobs
    set = params[:set] || 'scheduled'
    if set == 'scheduled'
      jobs = Util.all_sidekiq_jobs_in_scheduled_set
    elsif set == 'retry'
      jobs = Util.all_sidekiq_jobs_in_retry_set
    elsif set == 'dead'
      jobs = Util.all_sidekiq_jobs_in_dead_set
    else
      jobs = [{:message => "Invalid Set Provided, Possible Values - scheduled, retry and dead"}]
    end

    respond_to do |format|
      format.json { render :json => jobs }
    end
  end

  private
    def script_upload_params
      params.permit(:name, :description, :language, :textfile, :iters, :result)
    end
    def script_check_params
      params.permit(:id, :name)
    end
end
