class RunScriptWorker
  include Sidekiq::Worker
  sidekiq_options :queue => :high
  sidekiq_options :retries => 3

  def perform(id)
    @script = Script.find_by_id(id)
    @script["status"] = "enqueued"
    if @script.save
#      puts "File is " + @script.textfile
      @script.textfile.open do |file|
        load file
      end
#      @script["history"][Time.now.utc.to_i] = 0
      @script["status"] = "executed"
      @script.save
    else
      raise RuntimeError
    end
  end
end
