class V1::Api::ScriptController < ApiController
  skip_before_action :verify_authenticity_token
  DEFAULT_ITERATIONS = 1000

  resource_description do
    resource_id 'Script'
    short 'All APIs for Script Operations'
    api_base_url '/v1/api/script'
    description <<-EOS
      APIs for uploading, listing, checking the status of, revalidating and rerunning a script.
      EOS
    error 400, "Request has missing mandatory parameter/s"
    error 401, "Unauthorized to perform this request"
    error 403, "Forbidden from accessing this resource"
    error 404, "Requested resource not found"
    error 500, "Internal server error"
  end

  api :POST, '/', "Add a script for execution"
  param :name, String, desc: 'name of the script', required: true
  param :summary, String, desc: 'summary of the script', required: true
  param :language, String, desc: 'language of the script being submitted', required: true
  param :textfile, File, desc: 'the script', required: true
  param :result, [Integer, String], desc: 'expected output from the script', required: true
  param :iters, Integer, desc: 'number of iterations the script should be run while benchmarking, defaults to 1000 when not supplied', required: false
  description <<-EOS
    This API takes a script with some other information and submits it for sanitization.
    EOS
  returns :code => 200, :desc => "Script has been successfully uploaded and enqueued for sanitization" do
    property :script_id, String, :desc => "Script ID for future references"
    property :message, String, :desc => "Message related to response status"
  end
  example '
    POST /v1/api/script

    {
        "script_id": "1",
        "message": "Uploaded Successfully"
    }
  '
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

  api :GET, '/', "Get details for a submitted script"
  param :id, Integer, desc: 'id of the script', required: false
  param :name, String, desc: "name of the script - if ID isn't supplied, then this is required", required: false
  description <<-EOS
    This API takes a script id/name and returns its current progress/state.
    EOS
  returns :code => 200, :desc => "Script is found in the system" do
    property :script_status, String, :desc => "If the script hasn't executed successfully, then this will be present, otherwise it won't be present"
    property :details, String, :desc => "Present only if script_status is present, provides details about the script status"
    property :result, Hash, :desc => "Present if script has executed successfully" do
      property :status, String, :desc => "Same as script_status"
      property :user_time, Float, :desc => "User time returned by the benchmark after executing the script"
      property :system_time, Float, :desc => "System time returned by the benchmark after executing the script"
      property :total_time, Float, :desc => "Total time returned by the benchmark after executing the script"
      property :real_time, Float, :desc => "Real time returned by the benchmark after executing the script"
      property :snippet, String, :desc => "The executed code snippet"
    end
    property :message, String, :desc => "Message about the response"
  end
  
  example '
    GET /v1/api/script?name=MoreClasses

    {
        "script_status": "error",
        "details": "Validation Failed, Resubmit After Modifying, Or Validate With A New Result",
        "message": "Success"
    }
  '
  example '
    GET /v1/api/script?name=MoreClasses

    {
        "script_status": "resubmit_uploaded",
        "details": "Uploaded New File Successfully",
        "message": "Success"
    }
  '
  example '
    GET /v1/api/script?name=MoreClasses

    {
        "script_status": "enqueued",
        "details": "Successfully Enqueued For Execution, Check Metrics After Sometime",
        "message": "Success"
    }
  '
  example '
    GET /v1/api/script?name=MoreClasses

    {
        "result": {
            "status": "executed",
            "user_time": 0.09513600000000011,
            "system_time": 0.019856000000000096,
            "total_time": 0.1149920000000002,
            "real_time": 0.11521641496801749,
            "snippet": "class Item;  attr_reader :item_name, :quantity, :supplier_name, :price;  def initialize(item_name, quantity, supplier_name, price);    @item_name = item_name;    @quantity = quantity;    @supplier_name = supplier_name;    @price = price;  end ;  def compare_others(other_item);    @item_name == other_item.item_name && @quantity == other_item.quantity && @supplier_name == other_item.supplier_name && @price == other_item.price;  end;  def ==(other_item);    @item_name == other_item.item_name && @quantity == other_item.quantity && @supplier_name == other_item.supplier_name && @price == other_item.price;  end;  def eql?(other_item);    compare_others(other_item);  end;  def hash;    @item_name.hash ^ @quantity.hash ^ @supplier_name.hash ^ + @price.hash;  end;end;items = [Item.new(\"a\", 1, \"b\", 2), Item.new(\"a\", 1, \"b\", 2), Item.new(\"c\", 2, \"b\", 2), Item.new(\"a\", 1, \"b\", 2)];items.uniq;true;"
        },
        "message": "Success"
    }
  '
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

  api :PUT, '/', "Resubmit an existing script which failed validation/execution"
  param :id, Integer, desc: 'id of the existing script', required: true
  param :textfile, File, desc: 'the script', required: true
  param :result, [Integer, String], desc: 'expected output from the script', required: true
  param :iters, Integer, desc: 'number of iterations the script should be run while benchmarking, defaults to 1000 when not supplied', required: false
  description <<-EOS
    This API takes a new textfile and validation output for an existing script and resubmits it for sanitization.
    EOS
  returns :code => 200, :desc => "Script has been successfully uploaded and re-enqueued for sanitization" do
    property :message, String, :desc => "Uploaded Successfully"
  end
  example '
    PUT /v1/api/script

    {
        "message": "Uploaded Successfully"
    }
  '
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
