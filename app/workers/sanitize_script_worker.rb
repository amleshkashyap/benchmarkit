class SanitizeScriptWorker
  include Sidekiq::Worker
  sidekiq_options :queue => :high
  sidekiq_options :retry => 5

  def perform(id, iterations, result)
    @script = Script.find_by_id(id)
    @script.validating do
      @script.update_description("Performing Checks On The Submitted Code, Please Check After Sometime")
    end
    snippet = @script.extract_code
    @code = Code.new(:snippet => snippet, :script_id => @script.id)
    @code.save
    if @code.sanitization
      result = true if result == 'true'
      result = false if result == 'false'
      if @code.validation(result)
        @metric = Metric.new(:code_id => @code.id, :script_id => @script.id, :execute_from => "attached_file", :iterations => iterations, :status => 'enqueued')
        @metric.save
        jid = ExecuteScriptWorker.perform_in(60.seconds, @metric.id)
        @metric.jid = jid
        @metric.save
        @script.update_execution_details(@code.id, @metric.id, jid)
        @script.validated do
          @script.update_description("Successfully Enqueued For Execution, Check Metrics After Sometime")
        end
      else
        @script.failed_validation do
          @script.update_description("Validation Failed, Resubmit After Modifying")
        end
      end
    else
      @script.failed_validation do
        @script.update_description("Sanitization Failed, Resubmit After Modifying")
      end
    end
  end
end
