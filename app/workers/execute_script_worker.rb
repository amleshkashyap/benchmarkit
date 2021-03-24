class ExecuteScriptWorker
  include Sidekiq::Worker
  sidekiq_options :queue => :high
  sidekiq_options :retries => 3

  def perform(id)
    @metric = Metric.find_by_id(id)
    # what happens if metric is null? shouldn't happen
    @script = Script.find_by_id(@metric.script_id)
    result = @metric.execute_metric
    if result.real > 0
      @script.executed do
        @script.update_description("Executed Successfully")
      end
    else
      @script.failed_execution do
        @script.update_description("Execution Failed")
      end
    end
  end
end
