class SanitizeScriptWorker
  include Sidekiq::Worker
  sidekiq_options :queue => :high
  sidekiq_options :retry => 5

  def perform(id, iterations, result, skip_validation=false)
    @script = Script.find_by_id(id)
    @script.validating! "Performing Checks On The Submitted Code, Please Check After Sometime"
    snippet = @script.extract_code
    if !skip_validation
      @code = Code.new(:snippet => snippet, :script_id => @script.id)
      @code.save
      @script.update_latest_code(@code.id, self.jid)
      if !(@code.sanitization! "Code Is Safe For Evaluation, Sanitization Check Passed")
        @script.failed_validation! "Sanitization Failed, Resubmit After Modifying"
        return
      end
    end
    @code = Code.find_by_id(@script.latest_code_id)
    result = Util.cleanup_arguments(result)
    if @code.validation!(result)
      @code.update_description("Code Is Safe For Benchmarking, Validation Successful")
      @metric = Metric.new(:code_id => @code.id, :script_id => @script.id, :execute_from => "attached_file", :iterations => iterations, :status => 'enqueued')
      @metric.save
      jid = ExecuteScriptWorker.perform_in(60.seconds, @metric.id)
      @metric.update_job_id(jid)
      @script.update_latest_metric(@metric.id, jid)
      @script.validated! "Successfully Enqueued For Execution, Check Metrics After Sometime"
    else
      @script.failed_validation! "Validation Failed, Resubmit After Modifying, Or Validate With A New Result"
    end
  end
end
