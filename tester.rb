#!/usr/bin/env ruby

class LogThing
  def initialize
    @list = {}
  end
  def set(k,v)
    @list[k] = v
  end
  def +(k, v)
    if not @list[k]
      set(k,v)
    else
      @list[k] += v
    end
  end
  def to_s
    @list.to_s
  end
end


lt = LogThing.new

lt.set(:run, 0)
lt+:run 5

puts lt.to_s
