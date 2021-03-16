class RunScriptWorker
  include Sidekiq::Worker
  sidekiq_options :queue => :high
  sidekiq_options :retry => true, :retries => 3

  def perform(id)
    @script = Script.find_by_id(id)
    @script["status"] = "enqueued"
    if @script.save
      load "#{@script.has_one_attached}"
      @script["history"][Time.now] = 0
      @script["status"] = "executed"
      @script.save
    else
      raise RuntimeError
    end
  end
end
