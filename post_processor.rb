=begin
I want to create a class that does post processing on the data
by reading in the files and averaging out each data set according
to type.

There is a type and run in each.
Types should be consolidated and averaged per run.

x => run #
y => whatever...
=end

class PostProcessor
  def self.parse(filename)
    i = 0
    types = []
    headers = []
    current = []
    tests = 0
    start = false
    CSV.foreach(filename) do |csv|
      if i == 0 #get headers
        headers = csv
      else #not header? process line
        if types.includes?(csv[0]) #i have seen this run before
          start = true
          for j in 2...csv.size #look at each line starting at run #
            #csv[1] is the run number
            current[csv[1]] = [] if current[csv[1]] == nil
            # j is the address of the number to average
            # subtract 2 to account for type and run
            csv[csv[1]][j-2] =  0 if current[csv[1]][j-2] == nil
            current[csv[1]][j-2] += csv[j]
            tests += 1
          end #keep doing this until the next type is found
        elsif start #we have at least one current filled in
          #average all the current according to number of tests
          current.each do |j|
            for k in 0...j.size
              j[k] /= tests
            end
          end
          #after averaging we need to save the results in a csv
          #type_filename
          if not File.file?("#{types[-1]}_#{filename}")
            File.new("#{types[-1]}_#{filename}", 'w')
            File.open("#{types[-1]}_#{filename}","a") do |f|
              for j in 0...current.length
                f.write("#{j},") #the run number
                f.write(current[j].to_csv) #the data
                f.puts ""
              end
            end
          end
          tests = 0
          types.push(csv[0])
        else #no types have been added
        end
      end
      i +=1
    end
  end
end

