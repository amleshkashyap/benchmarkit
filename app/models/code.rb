class Code < ApplicationRecord
  has_many :metrics

  def sanitize_snippet
  end

  def display_snippet
  end

  def display_description
  end

  def validate_snippet(result)
    ex = instance_eval self.snippet
  end

end
