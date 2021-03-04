class ExecuteScriptsController < ApplicationController

  require 'benchmark'

  def result_script
    @ex_res = Benchmark.measure {
      100.times do
         load "lib/scripts/moreclasses.rb";
      end
    }
    p @ex_res
  end

  def result_time
    @ex_res = Benchmark.measure {
      10000.times do
        z = Time.new(2020, 8, 4, 10, 10, 10, "UTC")
      end
    }
    p @ex_res
  end

end
