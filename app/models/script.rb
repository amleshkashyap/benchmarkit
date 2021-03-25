class Script < ApplicationRecord
  include AASM

  VALID_STATUSES = ['uploaded', 'validating', 'revalidating', 'enqueued', 'executed', 'resubmit_uploaded', 'rerun_enqueued', 'error', 'invalid']

  has_one_attached :textfile
  has_many :metrics
  has_many :codes

  validates :status, inclusion: { in: VALID_STATUSES }

  aasm column: 'status', whiny_transitions: false do
    state :uploaded, initial: true
    state :validating
    state :revalidating
    state :enqueued
    state :executed
    state :resubmit_uploaded
    state :rerun_enqueued
    state :error
    state :invalid

    after_all_transitions :update_description

    event :validating do
      transitions from: [:uploaded, :resubmit_uploaded, :revalidating], to: :validating
    end

    event :validated do
      transitions from: [:validating], to: :enqueued
    end

    event :executed do
      transitions from: [:enqueued, :rerun_enqueued], to: :executed
    end

    event :resubmitted do
      transitions from: [:error], to: :resubmit_uploaded
    end

    event :revalidating do
      transitions from: [:error], to: :revalidating
    end

    event :rerun do
      transitions from: [:executed], to: :rerun_enqueued
    end

    event :failed_validation do
      transitions from: [:validating], to: :error
    end

    event :failed_execution do
      transitions from: [:enqueued, :rerun_enqueued], to: :error
    end

    event :invalidate do
      transitions from: [:error], to: :invalid
    end
  end

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

  def update_description(message)
    self.description = message
    self.save
  end

  def update_latest_code(code_id, job_id)
    self.latest_code_id = code_id
    self.update_sidekiq_job_id(job_id)
  end

  def update_latest_metric(metric_id, job_id)
    self.latest_metric_id = metric_id
    self.update_sidekiq_job_id(job_id)
  end

  def update_sidekiq_job_id(job_id)
    self.last_jid = job_id
    self.save
  end

  def get_latest_execution_values
    @metric = Metric.find_by_id(self.latest_metric_id)
    return @metric.get_execution_values
  end

end
