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

class PostProcessor
  def self.parse(filename)
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
          save_parsed(current, types[-1], filename, tests)
          tests = 0
          types.push(csv[0]) #next type added
          current.clear
        end
      end
      i += 1
    end
    
    if not current.empty?
      save_parsed(current, types[-1], filename, tests)
    end
  end
  
  def self.save_parsed (current, type, filename, tests)
    current.each do |j|
      if j != nil
        for k in 0...j.size
          j[k] /= tests
        end
      end
    end
    if not File.file?("parsed_#{filename}")
      File.new("parsed_#{filename}", 'w')
    end
    File.open("parsed_#{filename}","a") do |f|
        for j in 0...current.length
          f.write("#{type},#{j},") #the run number
          f.write(current[j].to_csv) if current[j] != nil #the data
        end #did it for each run
    end #end of file
  end
end

#PostProcessor.parse("test.csv")
#PostProcessor.parse("retrain_20161127.csv")
#PostProcessor.parse("total_20161128.csv")
PostProcessor.parse("resource_20161128.csv")