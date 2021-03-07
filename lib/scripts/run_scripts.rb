require 'benchmark'

$script_in_string = ""
$script_in_array = []

def measure_given_script(filename)
  return false if !File.file?(filename)
  time = Benchmark.measure {
    100.times do
      load filename
    end
  }
  puts "Measuring script: " + filename + ", results: ", time
end

def measure_time_snippets
  puts "Time.new", Benchmark.measure {
    10000.times do
      z = Time.new(2020, 8, 4, 10, 10, 10, "UTC")
    end
  }

  puts "Time.new from string", Benchmark.measure {
    10000.times do
      cur = Time.now.utc
      s = "#{cur.year},#{cur.month},#{cur.day},#{cur.hour},#{cur.min},#{cur.sec}"
      list = s.split(",")
      z = Time.new(list[0], list[1], list[2], list[3], list[4], list[5], "UTC")
    end
  }

  puts "Time.now.utc.to_i", Benchmark.measure {
    10000.times do
      z = Time.now.utc.to_i
    end
  }
end

def measure_given_snippet(snippet)
  time = Benchmark.measure {
    10000.times do
      z = instance_eval snippet
    end
  }
  puts "Measuring snippet: " + snippet, time
end

def execute_given_snippet(snippet)
  ex = instance_eval snippet
  p ex
end

def sanitize_this_line(snippet)
end

def read_and_store_script(filename)
  $script_in_string = ""
  $script_in_array = []
  File.readlines(filename).each do |line|
    next if line.chomp.nil? or line.strip[0].nil?
    next if line.split("#")[0].strip[0].nil?
    $script_in_string += line.chomp + ";"
    $script_in_array.push(line.chomp)
  end
  p $script_in_string
  p $script_in_array
#  execute_given_snippet($script_in_string)
  write_snippet_to_file($script_in_array)
end

def write_snippet_to_file(snippet_array)
  File.open("test.rb", "w+") do |f|
    f.puts(snippet_array)
  end
end

# measure_time_snippets
# measure_given_script("moreclasses.rb")
# measure_given_script("/home/amlesh/projects/explore-rubyonrails/benchmarkit/lib/scripts/moreclasses.rb")
# measure_given_snippet("Time.now.utc.to_i")
# measure_given_snippet("100.times do; Time.now.utc; end; 100.times do; Time.now.utc.to_i; end;")
read_and_store_script("/home/amlesh/projects/explore-rubyonrails/benchmarkit/lib/scripts/moreclasses.rb")
read_and_store_script("moreclasses.rb")
