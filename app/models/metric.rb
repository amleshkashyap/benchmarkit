class Metric < ApplicationRecord

  VALID_STATUSES = ['enqueued', 'success', 'error']
  VALID_SOURCES = ['attached_file', 'stored_code']

  has_one :code

  validates :status, inclusion: { in: VALID_STATUSES }
  validates :execute_from, inclusion: { in: VALID_SOURCES }

  def update_description
  end

  def update_job_id(job_id)
    self.jid = job_id
    self.save
  end

  def execute_metric
    return self.execute_from_script if self.execute_from == "attached_file"
    return self.execute_from_snippet if self.execute_from == "stored_code"
  end

  def execute_from_script
    @script = Script.find_by_id(self.script_id)
    time = nil
    @script.textfile.open do |file|
      time = Benchmark.measure {
	self.iterations.times do
          load file
        end
      }
    end
    self.store_execution_times(time)
    return time
  end

  def execute_from_snippet
    @code = Code.find_by_id(self.code_id)
    time = @code.execute_snippet(self.iterations)
    self.store_execution_times(time)
    return time
  end

  def store_execution_times(time)
    self.user_time = time.utime
    self.system_time = time.stime
    self.total_time = time.total
    self.real_time = time.real
    self.status = 'success'
    self.save
  end

  def get_execution_values
    @code = Code.find_by_id(self.code_id)
    return { :status => "executed", :user_time => self.user_time, :system_time => self.system_time, :total_time => self.total_time, :real_time => self.real_time, :snippet => @code.snippet }
  end

end
