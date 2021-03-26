class V1::Api::ApiScriptsController < ApiController
  skip_before_action :verify_authenticity_token
  DEFAULT_ITERATIONS = 1000

  def create_script
    render_400 and return if missing_required_params?(['name', 'summary', 'language', 'textfile', 'result'])

    @script = Script.new(:name => params[:name], :summary => params[:summary], :language => params[:language], :textfile => params[:textfile], :user_id => current_user.id, :description => 'Successfully Uploaded')
    @script.save

    user_result = params[:result]
    # add validations for user results, ie, integer, boolean, string only
    user_iterations = params[:iters] || DEFAULT_ITERATIONS
    jid = SanitizeScriptWorker.perform_in(30.seconds, @script.id, user_iterations, user_result)
    @script.update_sidekiq_job_id(jid)
    puts "Script was successfully created"
    render_200("Uploaded Successfully", { :script_id => @script.id.to_s }) and return
  end

  def check_script
    render_400 and return if missing_optional_params?(['id', 'name'])

    if !params[:id].nil?
      @script = Script.find_by(:id => params[:id], :user_id => current_user.id)
    elsif !params[:name].nil?
      @script = Script.find_by(:name => params[:name], :user_id => current_user.id)
    end

    render_404 and return if @script.nil?

    @script.textfile.open do |file|
      File.readlines(file).each do |line|
        puts line
      end
    end

    if @script.status != "executed"
      new_obj = Util.find_in_retry_set(@script.last_jid)
      new_obj = Util.find_in_dead_set(@script.last_jid) if new_obj.nil?
      render_200("Success", { :script_status => @script.status, :details => @script.description }) and return if new_obj.nil?
      render_200("Success", { :result => new_obj }) and return
    else
      new_obj = @script.get_latest_execution_values
      render_200("Success", { :result => new_obj }) and return
    end
  end

  def list_scripts
    status = params[:status] || 'all'
    render_400 and return if !Script::VALID_STATUSES.push('all').include?(status)
    statuses = (status == 'all' ? Script::VALID_STATUSES : [status])
    @scripts = Script.where({ :user_id => current_user.id, :status => statuses })
    render_404 and return if @scripts.nil?
    render_200("Success", { :count => @scripts.length, :scripts => @scripts }) and return
  end

  # this is in case of sanitization, validation and execution errors - will identify the last executed version if exists (both success/error)
  def resubmit_script
    render_400 and return if missing_required_params?(['id', 'textfile', 'result'])
    @script = Script.find_by(:id => params[:id], :user_id => current_user.id)
    render_404 and return if @script.nil?

    if @script.status == "error"
      @script.textfile = params[:textfile]
      @script.save
      user_result = params[:result]
      # add validations for user results, ie, integer, boolean, string only
      user_iterations = params[:iters] || DEFAULT_ITERATIONS
      @script.resubmitted! "Uploaded New File Successfully"
      jid = SanitizeScriptWorker.perform_in(30.seconds, @script.id, user_iterations, user_result)
      @script.update_sidekiq_job_id(jid)
      render_200("Uploaded Successfully") and return
    else
      # don't allow resubmitting the script if it worked successfully - 
      render_403("This Script Has Either Executed Successfully Or Is Being Validated And Can't Be Modified, Please Check Status") and return
    end
  end

  # this reruns the most recent successfully executed version of the script
  def rerun_script
    render_400 and return if missing_required_params?(['id'])
    @script = Script.find_by(:id => params[:id], :user_id => current_user.id)
    render_404 and return if @script.nil?
    render_403("Can't Execute This Script, Please Rerun") and return if @script.status != 'executed'

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
    render_400 and return if missing_required_params?(['id', 'result'])
    @script = Script.find_by(:id => params[:id], :user_id => current_user.id)
    render_404("Script Not Found") and return if @script.nil?
    render_403("Can't Submit This Script For Validation, Please Check Status") and return if (@script.status != 'error' || @script.latest_code_id.nil?)

    @code = Code.find_by_id(@script.latest_code_id)
    render_404("No Code Found Associated With The Script, Please Check Status") and return if @code.nil?
    render_403("The Code Associated With The Script Isn't Sanitized, Or Validated Already, Please Check Status Or Resubmit") and return if @code.status != 'sanitized'

    user_result = params[:result]
    user_iterations = params[:iters] || DEFAULT_ITERATIONS
    jid = SanitizeScriptWorker.perform_in(30.seconds, @script.id, user_iterations, user_result, true)
    @script.update_sidekiq_job_id(jid)
    @script.revalidating! "Script Is Being Revalidated"
    render_200("Submitted For Revalidation") and return
  end

  def get_metric
    render_400 and return if missing_required_params?(['id'])
    @metric = Metric.find_by_id(params[:id])
    render_404 and return if @metric.nil?
    @script = Metric.where({ :id => @metric.script_id, :user_id => current_user.id })
    render_403("You're Not Allowed To View Someone Else's Metrics") and return if @script.nil?
    render_500("Execution Failed") and return if @metric.status != "success"
    render_200("Success", { :results => @metric.get_execution_value }) and return
  end

  def list_metrics_for_script
    render_400 and return if missing_required_params?(['id'])
    @script = Script.find_by(:id => params[:id], :user_id => current_user.id)
    render_404 and return if @script.nil?
    @metrics = Metric.where({ :script_id => @script.id })
    render_200("Success", { :count => @metrics.length, :metrics => @metrics }) and return
  end

  def get_code
    render_500 and return
  end

  def list_metrics_for_private_code
    render_500 and return
  end

  # this allows rerunning a specific executed version of the script - later
  def rerun_script_code_and_share
    render_400 and return if missing_required_params?(['id'])
    @code = Code.find_by_id(params[:id])
    render_404 and return if @code.nil?
    @script = Script.find_by(:id => @code.script_id, :user_id => current_user.id)
    render_403("You're Not Allowed To Rerun Someone Else's Code") and return if @script.nil?
    render_403("This Code Is Not Suitable For Execution") and return if @code.status != "validated"

    user_iterations = params[:iters] || DEFAULT_ITERATIONS
    @metric = Metric.new(:code_id => @code.id, :script_id => 1, :execute_from => "stored_code", :iterations => user_iterations, :status => "enqueued")
    @metric.save
    jid = ExecuteScriptWorker.perform_in(60.seconds, @metric.id)
    @metric.update_job_id(jid)
    render_200("Submitted For Execution", { :metric_id => @metric.id.to_s }) and return
  end

  def list_codes_for_script
    render_500 and return
  end

  def get_public_code
    render_500 and return
  end

  def list_metrics_for_public_code
    render_500 and return
  end

  def rerun_public_code
    render_500 and return
  end
  
  def list_public_codes
    render_500 and return
  end

  def get_sidekiq_jobs
    render_400 and return if params[:set].nil?
    render_400 and return if invalid_param_values?('set', ['scheduled', 'retry', 'dead'])

    if params[:set] == 'scheduled'
      jobs = Util.all_sidekiq_jobs_in_scheduled_set
    elsif params[:set] == 'retry'
      jobs = Util.all_sidekiq_jobs_in_retry_set
    elsif params[:set] == 'dead'
      jobs = Util.all_sidekiq_jobs_in_dead_set
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
