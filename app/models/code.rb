class Code < ApplicationRecord
  has_many :metrics

  RESTRICTED_KEYWORDS = []
  VALID_STATUSES = ['stored', 'sanitized', 'validated', 'invalid']

  def sanitize_snippet
    return false unless self.status == 'stored'
    RESTRICTED_KEYWORDS.each { |word|
      return false if self.snippet.includes(word)
    }
    self.status = 'sanitized'
    self.save
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

  def validate_snippet(result)
    return false unless self.status == 'sanitized'
    ex = instance_eval self.snippet
    puts "**VALIDATION STARTS **"
    puts ex
    puts result
    puts "** VALIDATION END **"
    return false if ex != result
    self.status = 'validated'
    self.save
    return true
  end

end
