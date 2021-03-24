class Code < ApplicationRecord
  include AASM

  has_many :metrics

  RESTRICTED_KEYWORDS = []
  VALID_STATUSES = ['stored', 'sanitized', 'validated', 'invalid']

  aasm column: 'status', whiny_transitions: false do
    state :stored, initial: true
    state :sanitized
    state :validated
    state :invalid

    event :sanitization do
      transitions from: [:stored], to: :sanitized, guards: [:sanitize_it?, :sanitize_snippet]
    end

    event :validation do
      transitions from: [:sanitized], to: :validated, guards: [:validate_it?, :validate_snippet]
    end
  end

  def sanitize_it?
    p "Stored: " + self.stored?.to_s
    self.stored?
  end

  def sanitize_snippet
    RESTRICTED_KEYWORDS.each { |word|
      return false if self.snippet.includes(word)
    }
    p "Sanitization Done: " + true.to_s
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

  def display_description
  end

  def validate_it?
    p "Sanitized: " + self.sanitized?.to_s
    self.sanitized?
  end

  def validate_snippet(result)
    ex = instance_eval self.snippet
    puts "**VALIDATION STARTS **"
    puts ex
    puts result
    puts "** VALIDATION END **"
    puts "Validation Results: " + (ex == result).to_s
    return (ex == result)
  end

end
