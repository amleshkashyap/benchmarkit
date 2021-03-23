class Script < ApplicationRecord

  VALID_STATUSES = ['uploaded', 'validating', 'enqueued', 'executed', 'resubmit_uploaded', 'rerun_enqueued', 'error', 'invalid']

  has_one_attached :textfile
  has_many :metrics
  has_many :codes

  validates :status, inclusion: { in: VALID_STATUSES }

  def extract_code
    snippet = ""
    snippet_array = []
    self.textfile.open do |file|
      File.readlines(file).each do |line|
        next if line.chomp.nil? or line.strip[0].nil?
        next if line.split("#")[0].strip[0].nil?
        snippet += line.chomp + ";"
        snippet_array.push(line.chomp)
      end
    end
    return snippet
  end

  def update_status
  end

  def get_latest_execution_values
    @metric = Metric.find_by_id(self.latest_metric_id)
    return @metric.get_execution_values
  end

end
