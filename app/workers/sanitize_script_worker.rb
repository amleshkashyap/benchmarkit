class SanitizeScriptWorker
  include Sidekiq::Worker
  sidekiq_options :queue => :high
  sidekiq_options :retries => 3

  def perform(id, result)
    script = Script.find_by_id(id)
    script["status"] = "validating"
    if script.save
      snippet = script.extract_code
      code = Code.new(:snippet => snippet, :status => "stored")
      if code.save
        if code.sanitize_snippet
          code["status"] = "sanitized" if code.sanitize_snippet
          if code.save
            if code.validate_snippet(result)
              code["status"] = "validated"
              code.save
              script["status"] = "validated"
              if script.save
                ExecuteScriptWorker.perform_in(10.seconds, script.id)
              else
                raise RuntimeError
              end
            else
              code["status"] = "error"
              code["description"] = "Validation failed"
              code.save
              script["status"] = "error"
              script["description"] = "Validation failed"
              script.save
            end
          else
            raise RuntimeError
          end
        else
          code["status"] = "error"
          code["description"] = "Sanitization failed"
          code.save
          script["status"] = "error"
          script["description"] = "Sanitization failed, fix and upload the script again"
          script.save
        end
      else
        raise RuntimeError
      end
    else
      raise RuntimeError
    end
  end
end
