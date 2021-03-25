class Code < ApplicationRecord
  include AASM

  has_many :metrics

  RESTRICTED_KEYWORDS = []
  VALID_STATUSES = ['stored', 'sanitized', 'validated', 'invalid']

  validates :status, inclusion: { in: VALID_STATUSES }

  aasm column: 'status', whiny_transitions: false do
    state :stored, initial: true
    state :sanitized
    state :validated
    state :invalid

    event :sanitization, :after => :update_description do
      transitions from: [:stored], to: :sanitized, guards: [:sanitize_it?, :is_sanitized_snippet?]
    end

    event :validation, :after => :update_valid_with_result do
      transitions from: [:sanitized], to: :validated, guards: [:validate_it?, :is_valid_snippet?]
    end

    event :invalidate do
      transitions from: [:sanitized], to: :invalid, guard: :validate_it?
    end
  end

  def sanitize_it?
    self.stored?
  end

  def is_sanitized_snippet?
    RESTRICTED_KEYWORDS.each { |word|
      return false if self.snippet.include?(word)
    }
    return true
  end

  def display_snippet
  end

  def execute_snippet(iterations)
    time = Benchmark.measure {
      iterations.times do
        instance_eval self.snippet
      end
    }
    return time
  end

  def update_description(message)
    self.description = message
    self.save
  end

  def update_valid_with_result(result)
    if result.class.to_s == 'String'
      self.valid_with_result = result
      self.result_type = result.class
    else
      self.valid_with_result = result.to_s
      self.result_type = result.class
    end
    self.save
  end

  def validate_it?
    self.sanitized?
  end

  def is_valid_snippet?(result)
    ex = instance_eval self.snippet
    return (ex == result)
  end

end
