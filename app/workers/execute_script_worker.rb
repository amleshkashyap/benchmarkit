class ExecuteScriptWorker
  include Sidekiq::Worker
  sidekiq_options :queue => :high
  sidekiq_options :retries => 3

  def perform(id)
    @metric = Metric.find_by_id(id)
    # what happens if metric is null? shouldn't happen
    @script = Script.find_by_id(@metric.script_id)
    @script["status"] = "enqueued"
    result = nil
    if @metric.execute_from == "stored_code"
      @code = Code.find_by_id(@metric.code_id)
      result = run_benchmark_from_code(@code, @metric.iterations)
    elsif @metric.execute_from == "attached_file"
      result = run_benchmark_from_file(@script, @metric.iterations)
    end
    @script["status"] = "executed"
    if @script.save
    else
    end
  end

  def run_benchmark_from_file(script, iterations)
    time = nil
    @script.textfile.open do |file|
      time = Benchmark.measure {
        iterations.times do
          load file
        end
      }  
    end
    return time
  end

  def run_benchmark_from_code(code, iterations)
    time = Benchmark.measure {
      iterations.times do
        instance_eval code.snippet
      end
    }
    return time
  end

end
