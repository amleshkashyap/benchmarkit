class SanitizeScriptWorker
  include Sidekiq::Worker
  sidekiq_options :queue => :high
  sidekiq_options :retries => 3

  def perform(id, result)
    @script = Script.find_by_id(id)
    script_status = "validating"
    script_description = "Successfully Updated The Status"
    snippet = script.extract_code
    @code = Code.new(:snippet => snippet, :status => "stored")
    if @code.save
      code_status = "stored"
      code_description = "Successfully Updated The Status"
      if @code.sanitize_snippet
        code_status = "sanitized"
        if @code.validate_snippet
          code_status = "validated"
          ExecuteScriptWorker.perform_in(10.seconds, @script.id)
        else
          code_status = "error"
          code_description = "Snippet Validation Failed"
        end
      else
        code_status = "error"
        code_description = "Snippet Sanitization Failed"
      end
      @code["status"] = code_status
      @code["description"] = code_description
      @code.save
    else
      script_status = "error"
      script_description = "Failed to store the given code"
    end
    @script["status"] = script_status
    @script["description"] = script_description
    @script.save
  end
end
