class Metric < ApplicationRecord

  VALID_STATUSES = ['error', 'success']
  VALID_SOURCES = ['attached_file', 'snippet']

  has_one :code

  validates :status, inclusion: { in: VALID_STATUSES }
  validates :execute_from, inclusion: { in: VALID_SOURCES }

  def update_after_execution
  end

  def execute_from_script
  end

  def execute_from_string
  end

end
