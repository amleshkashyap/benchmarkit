class SanitizeScriptWorker
  include Sidekiq::Worker
  sidekiq_options :queue => :high
  sidekiq_options :retry => 5

  def perform(id, iterations, result)
    @script = Script.find_by_id(id)
    @script.status = "validating"
    @script.description = "Performing Checks On The Submitted Code, Please Check After Sometime"
    @script.save
    snippet = @script.extract_code
    @code = Code.new(:snippet => snippet, :status => "stored", :script_id => @script.id)
    @code.save
    if @code.sanitize_snippet
      result = true if result == 'true'
      result = false if result == 'false'
      if @code.validate_snippet(result)
        @metric = Metric.new(:code_id => @code.id, :script_id => @script.id, :execute_from => "attached_file", :iterations => iterations, :status => 'enqueued')
        @metric.save
        jid = ExecuteScriptWorker.perform_in(60.seconds, @metric.id)
        @metric.jid = jid
        @metric.save
        @script.latest_code_id = @code.id
        @script.latest_metric_id = @metric.id
        @script.status = 'enqueued'
        @script.description = "Successfully Enqueued For Execution, Check Metrics After Sometime"
        @script.last_jid = jid
	@script.save
      else
        @script.status = "error"
	@script.description = "Validation Failed, Resubmit After Modifying"
        @script.save
      end
    else
      @script.status = "error"
      @script.description = "Sanitization Failed, Resubmit After Modifying"
      @script.save
    end
  end
end
