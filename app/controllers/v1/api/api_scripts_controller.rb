class V1::Api::ApiScriptsController < ApiController
  before_action :authenticate_user!
  skip_before_action :verify_authenticity_token
  DEFAULT_ITERATIONS = 1000

  def create_script
    if script_upload_params
      @script = Script.new(:name => params[:name], :summary => params[:summary], :language => params[:language], :textfile => params[:textfile], :user_id => 3, :description => 'Successfully Uploaded')
    else
      render_404 and return
    end

    user_result = params[:result] || nil
    # add validations for user results, ie, integer, boolean, string only
    user_iterations = params[:iters] || DEFAULT_ITERATIONS

    if @script.save
      jid = SanitizeScriptWorker.perform_in(30.seconds, @script.id, user_iterations, user_result)
      @script.last_jid = jid
      @script.save
      puts "Script was successfully created"
      render_200("Uploaded Successfully", { :script_id => @script.id.to_s }) and return
    else
      puts "Uprocessable Entity"
      render_500("Upload Failed") and return
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
  def resubmit_script
    @script = Script.find_by_id(params[:id])

    if @script.nil?
      render_404 and return
    end

    status = @script.status
    if status == "error"
      # save the new script, launch the sanitization worker
      @script.textfile = params[:textfile]
      user_result = params[:result] || nil
      # add validations for user results, ie, integer, boolean, string only
      user_iterations = params[:iters] || DEFAULT_ITERATIONS
      @script.resubmitted! "Uploaded New File Successfully"
      if @script.save
	jid = SanitizeScriptWorker.perform_in(30.seconds, @script.id, user_iterations, user_result)
        @script.update_sidekiq_job_id(jid)
        render_200("Uploaded Successfully") and return
      else
        render_500("Upload Failed") and return
      end
    else
      # don't allow resubmitting the script if it worked successfully - 
      render_403("This Script Has Either Executed Successfully Or Is Being Validated And Can't Be Modified, Please Check Status") and return
    end
  end

  # this reruns the most recent successfully executed version of the script
  def rerun_script
    @script = Script.find_by_id(params[:id])

    if @script.nil?
      render_404 and return
    end

    if @script.status != 'executed'
      render_403("Can't Execute This Script, Please Rerun") and return
    end

    iterations = params[:iters] || DEFAULT_ITERATIONS
    @metric = Metric.new(:code_id => @script.latest_code_id, :script_id => @script.id, :execute_from => "attached_file", :iterations => iterations, :status => 'enqueued')
    @metric.save
    jid = ExecuteScriptWorker.perform_in(60.seconds, @metric.id)
    @metric.update_job_id(jid)
    @script.rerun! "Enqueued For Rerun"
    @script.update_latest_metric(@metric.id, jid)
    render_200("Submitted For Execution") and return
  end

  def revalidate_script
    @script = Script.find_by_id(params[:id])

    if @script.nil? || params[:result].nil?
      render_404("Script Not Found, Or Result Not Provided") and return
    end

    if (@script.status != 'error' || @script.latest_code_id.nil?)
      render_403("Can't Submit This Script For Validation, Please Check Status") and return
    end

    @code = Code.find_by_id(@script.latest_code_id)

    if @code.nil?
      render_404("No Code Found Associated With The Script, Please Check Status") and return
    end

    if @code.status != 'sanitized'
      render_403("The Code Associated With The Script Isn't Sanitized, Or Validated Already, Please Check Status Or Resubmit") and return
    end

    user_result = params[:result]
    user_iterations = params[:iters] || DEFAULT_ITERATIONS

    jid = SanitizeScriptWorker.perform_in(30.seconds, @script.id, user_iterations, user_result, true)
    @script.update_sidekiq_job_id(jid)
    @script.revalidating! "Script Is Being Revalidated"

    render_200("Submitted For Revalidation") and return
  end

  # this allows rerunning a specific executed version of the script - later
  def rerun_code
    @code = Code.find_by_id(params[:id])
    if @code.nil?
      render_404 and return
    elsif @code.status != "validated"
      render_403("This Code Is Not Suitable For Execution") and return
    end

    iterations = params[:iters] || DEFAULT_ITERATIONS
    @metric = Metric.new(:code_id => @code.id, :script_id => 1, :execute_from => "stored_code", :iterations => iterations, :status => "enqueued")
    @metric.save
    jid = ExecuteScriptWorker.perform_in(60.seconds, @metric.id)
    @metric.update_job_id(jid)
    render_200("Submitted For Execution", { :metric_id => @metric.id.to_s }) and return
  end

  def get_metric
    @metric = Metric.find_by_id(params[:id])
    response_message = nil
    if @metric.nil?
      response_message = "Not Found"
      render_404 and return
    elsif @metric.status != "success"
      response_message = "Execution Failed"
      render_500("Execution Failed") and return
    else
      response_message = @metric.get_execution_values
      render_200("Success", { :results => @metric.get_execution_value }) and return
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

    render_200("Success", { :jobs => jobs }) and return
  end

  private
    def script_upload_params
      params.permit(:name, :details, :language, :textfile, :iters, :result)
    end
    def script_check_params
      params.permit(:id, :name)
    end
end
