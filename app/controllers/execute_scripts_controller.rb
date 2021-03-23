class ExecuteScriptsController < ApplicationController

  before_action :authenticate_user!
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

  def result_redis
    Util.redis_add_to_hash("redis_key", "fruit", "apple")
    Util.redis_add_to_hash("redis_key", "better_fruit", "banana")
    @ex_res = Util.redis_get_all_from_hash("redis_key") ? Util.redis_get_all_from_hash("redis_key") : {}
  end

end
