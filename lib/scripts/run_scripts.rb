require 'benchmark'
# puts Benchmark.measure {
#  10000.times do
#    load "moreclasses.rb";
#  end
# }

puts Benchmark.measure {
  10000.times do
    z = Time.new(2020, 8, 4, 10, 10, 10, "UTC")
  end
}

puts Benchmark.measure {
  10000.times do
    cur = Time.now.utc
    s = "#{cur.year},#{cur.month},#{cur.day},#{cur.hour},#{cur.min},#{cur.sec}"
    list = s.split(",")
    z = Time.new(list[0], list[1], list[2], list[3], list[4], list[5], "UTC")
  end
}

puts Benchmark.measure {
  10000.times do
    z = Time.now.utc.to_i
  end
}
