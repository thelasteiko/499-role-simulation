#!/usr/bin/env ruby
require_relative 'weightedrand'

for i in 0...20
  puts WeightedRandom.rand(0.3,1.0,0.5,0.9,0.75)
end
