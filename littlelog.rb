=begin
The LittleLog module has several log classes that can track
and save a record of debug comments, runtime performance and
other statistical data.
=end

module LittleLog
  LOG_FOLDER = "log/"
  # Standard log class. This class is meant to be extended.
  class Log
    # @!attribute [r] str_date
    #   @return [String]
    attr_reader   :str_date
    # @!attribute [r] str_time
    #   @return [String]
    attr_reader   :str_time
    # @!attribute [r] start_time
    #   @return [Time]
    attr_reader   :start_time
    # @!attribute [r] filename
    #   @return [String]
    attr_reader   :filename
    
    # Creates a log instance with a starting time and date.
    def initialize
      time = Time.now
      @str_date = "#{time.year}#{time.month}#{time.day}"
      hour = time.hour < 10 ? "0"+time.hour.to_s : time.hour
      min = time.min < 10 ? "0"+time.min.to_s : time.min
      sec = time.sec < 10 ? "0"+time.sec.to_s : time.sec
      @str_time = "#{hour}#{min}#{sec}"
      @start_time = time
    end
  end
  # Tracks statistical data through a csv file.
  class Statistical < LittleLog::Log
    EXT = ".csv"
    # @!attribute [r] stat_list
    #   @return [Hash]
    attr_reader   :stat_list
    
    # Creates a log instance that tracks statistics
    # via a csv file.
    # @param qualifier [String] will be part of the file name.
    # @param stat_list [Hash] is the list of statistics to track
    #                         with starting data.
    def initialize(qualifier="statistical",stat_list={})
      @stat_list = stat_list
      super()
      #@filename = "#{LittleLog::LOG_FOLDER}#{qualifier}_#{@str_date}#{EXT}"
      @filename = "#{LittleLog::LOG_FOLDER}#{qualifier}_20161128#{EXT}"
      if not File.file?(@filename)
        File.new(@filename, 'w')
        File.open(@filename, 'w') do |f|
          @stat_list.each do |k,v|
            f.write(k.to_s)
            f.write(",")
          end
          f.puts ""
        end
      end
    end
    
    # Initializes or overwrites the data for a statistic.
    # @param stat [String] is the statistic to set.
    # @param value [Object] is the value to set.
    # @return Statistical is this object.
    def set(stat, value=0)
      @stat_list[stat] = value
      self
    end
    
    # Increments a statistic by 1. This assumes that
    # the statistic is numerical.
    # @param stat [String] is the statistic to increment.
    # @return Statistical is this object.
    def inc(stat)
      set(stat) if not @stat_list[stat]
      @stat_list[stat] += 1
      self
    end
    
    def dec(stat)
      set(stat) if not @stat_list[stat]
      @stat_list[stat] -= 1
      self
    end
    
    def add(stat, value)
      set(stat) if not @stat_list[stat]
      @stat_list[stat] += value
      self
    end
    
    def save
      #puts @stat_list
      File.open(@filename, 'a') do |f|
        @stat_list.each_pair do |k,v|
          f.write(v)
          f.write(',')
        end
        f.puts ""
      end
      self
    end
    def get(stat)
      return @stat_list[stat]
    end
    def reset(exceptions, default=0)
      @stat_list.each do |k,v|
        if not exceptions.include?(k)
          @stat_list[k] = default
        end
      end
      self
    end
  end
  
  # Tracks statistical data about the performance of 
  # a program.
  class Performance < LittleLog::Statistical
  
    def initialize
      super("performance",date: 0,runs: 0,
          totaltime: 0,time_per_run: 0)
      set(:date, @str_date)
    end
    
    def save
      @stat_list[:runtime] = (Time.now - @start_time).to_f
      @stat_list[:time_per_run] = @stat_list[:runtime] / @stat_list[:runs]
      super
    end
    
  end
  
  # Saves comments to a file for debugging.
  class Debug < LittleLog::Log
    EXT = ".txt"
    def initialize(qualifier="log")
      super()
      @filename = 
          "#{LittleLog::LOG_FOLDER}#{qualifier}_#{@str_date}#{@str_time}#{EXT}"
    end
    def log(sender, method, note)
      time = Time.now
      hour = time.hour < 10 ? "0"+time.hour.to_s : time.hour
      min = time.min < 10 ? "0"+time.min.to_s : time.min
      sec = time.sec < 10 ? "0"+time.sec.to_s : time.sec
      run = time-@start_time
      line = "#{hour}:#{min}:#{sec}:"+
        "#{run}: #{sender.class.name}.#{method}: "+
        "#{note}"
      open(@filename, 'a') do |f|
        f.puts line
      end
    end
  end
end
