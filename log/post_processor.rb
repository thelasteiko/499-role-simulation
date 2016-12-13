=begin
I want to create a class that does post processing on the data
by reading in the files and averaging out each data set according
to type.

There is a type and run in each.
Types should be consolidated and averaged per run.

x => run #
y => whatever...
=end

require 'csv'
require 'json'

class PostProcessor
  def self.average(filename)
    i = 0
    types = []
    headers = []
    current = []
    tests = 0
    start = false
    CSV.foreach(filename) do |csv|
      #puts csv
      if i == 0 #get headers
        headers = csv.to_s
        puts "headers: #{headers}"
      elsif i > 0 and csv[0] == 'type'
        next
      else #not header? process line
        if types.empty?
          types.push(csv[0]) #next type added
        end
        #i have seen this run before or no types have been added
        if types.include?(csv[0])
          #puts "We have started 1"
          r = csv[1].to_i
          for j in 2...csv.size #look at each line starting at run #
            #csv[1] is the run number
            current[r] = [] if current[r] == nil
            # j is the address of the number to average
            # subtract 2 to account for type and run
            current[r][j-2] = 0 if current[r][j-2] == nil
            current[r][j-2] += csv[j].to_f
          end #keep doing this until the next type is found
          if r == 0
            tests += 1
          end
          #puts "#{current}"
        elsif not current.empty? #we have at least one current filled in
          #puts "We have started 2"
          #average all the current according to number of tests
          #after averaging we need to save the results in a csv
          #type_filename
          save_average(current, types[-1], filename, tests)
          tests = 0
          types.push(csv[0]) #next type added
          current.clear
        end
      end
      i += 1
    end
    
    if not current.empty?
      save_average(current, types[-1], filename, tests)
    end
  end
  
  def self.survival_rates(filename, benchmarks)
    i = 0
    csvheaders = []
    headers = ["type","survive", "success","start>0", "end>0"]
    oldtype = nil
    rates = [nil,0,0,0,0]
    puts benchmarks.to_s
    CSV.foreach(filename) do |csv|
      #puts csv.to_s
      if i == 0
        csvheaders = csv
        puts csvheaders.to_s
        i = 1
        next
      end
      #I need to record the number that pass the benchmark for each type
      #this should just be for the end game, so separate the file first
      #puts oldtype
      if oldtype != csv[0]
        #puts oldtype
        append(nil,"survival.csv", headers, rates) if oldtype != nil
        oldtype = csv[0]
        rates = [csv[0],0,0,0,0]
      end
      #survive if exists
      rates[1] += 1
      success = true
      st = true
      en = true
      for j in 2...csv.length-1
        #go through each resource
        x = csv[j].to_f
        if x < 0 and j >=2 and j <= 13
          st = false
        end
        if j > 13 and j < csv.length-1
          #success if it meets benchmark
          if x < benchmarks[csvheaders[j]]
            success = false
          end
          if x < 0
            en = false
          end
        end
        if not (st or en)
          break
        end
      end
      rates[2] += 1 if success
      rates[3] += 1 if st
      rates[4] += 1 if en
      i+=1
    end
  end
  
  def self.group_run(filename)
    i = 0
    headers = []
    b1 = 0
    b2 = 9
    CSV.foreach(filename) do |csv|
      if i == 0
        headers = csv
      else
        #ft = csv[0]
        fn = csv[1].to_i #just group numbers
        if fn % 10 != 0
          b1 = fn - (fn % 10)
          b2 = b1 + 9
        else
          b1 = fn
          b2 = fn+9
        end
        data = []
        for j in 0...csv.length
          data.push(csv[j])
        end
        #I would like to put this in buckets...
        #append("run_#{b1}-#{b2}", "#{fn}#{ft}_#{filename}", headers,data)
        append("run_#{b1}-#{b2}", "#{fn}_#{filename}", headers,data)
      end
      i += 1
    end
  end
  
  #I need the mean across means.
  def self.means(filename) #the one I'm trying to get the means from
    #start with the averages? no I need to pull the originals.
    #i = 1
    headers = ["run", "start_mean", "start_stdev", "end_mean", "end_stdev"]
    fn = 0
    b1 = 0
    b2 = 9
    #i = 6
    for i in 0...1000 #each file
      if i != 0 and (i) % 10 == 0
        b1 += 10
        b2 += 10
      end
      f = "run_#{b1}-#{b2}/#{i}_#{filename}" #next file
      h = false
      sta = 0.0
      ena = 0.0
      stsum = []
      ensum = []
      CSV.foreach(f) do |csv| #read the file
        if not h or csv[0].include?("organization")
          h = true
          next
        end
        st = 0.0
        en = 0.0
        #sum the items across start and end for each line
        for k in 2..13
          x = csv[k].to_f
          st += x
          sta += x
        end
        for t in 13...csv.length-1
          x = csv[t].to_f
          en += x
          ena += x
        end
        #store sums for each possible combination
        stsum.push(st)
        ensum.push(en)
      end
      #puts "{#{sta},#{ena},#{stsum.length},#{ensum.length}}"
      #calculate the average for this run
      #m = sum(x)/n
      stm = sta / stsum.length.to_f
      enm = ena / ensum.length.to_f
      #puts "{#{stm},#{enm}}"
      #calculate the standard deviation
      #sigma = sum((x-(sum(x)/n))^2)/(n-1)
      stsd = 0.0
      ensd = 0.0
      stsum.each do |v|
        stsd += ((v - stm) ** 2)
        #puts stsd
      end
      ensum.each do |v|
        ensd += ((v - enm) ** 2)
      end
      stsd = Math.sqrt(stsd / (stsum.length-1))
      ensd = Math.sqrt(ensd / (ensum.length-1))
      #puts "{#{stsd},#{ensd}}"
      append(nil, "stdev2_#{filename}", headers, [i,stm,stsd,enm,ensd])
    end
  end
  
  def self.append(directory, filename, headers, data)
    f = filename
    if directory
      f = "#{directory}/#{filename}"
      if not File.exists?(directory)
        Dir.mkdir(directory)
      end
    end
    if not File.file?(f)
      File.new(f,'w')
      File.open(f, 'w') do |f|
        f.write(headers.to_csv)
        f.write(data.to_csv)
      end
    else
      File.open(f, 'a') do |f|
        f.write(data.to_csv)
      end
    end
  end
  
  def self.save_average (current, type, filename, tests)
    current.each do |j|
      if j != nil
        for k in 0...j.size
          j[k] /= tests
        end
      end
    end
    if not File.file?("average_#{filename}")
      File.new("average_#{filename}", 'w')
    end
    File.open("average_#{filename}","a") do |f|
        for j in 0...current.length
          f.write("#{type},#{j},") #the run number
          f.write(current[j].to_csv) if current[j] != nil #the data
        end #did it for each run
    end #end of file
  end
end

#PostProcessor.average("resource_20161204.csv")
#PostProcessor.average("retrain_20161204.csv")
#PostProcessor.average("total_20161204.csv")
#PostProcessor.group_run("resource_20161204.csv")
#PostProcessor.group_run("total_20161204.csv")
#PostProcessor.survival_rates("run_990-999/999_resource_20161204.csv", JSON.parse(File.read("benchmarks.json")))
PostProcessor.means("resource_20161204.csv")