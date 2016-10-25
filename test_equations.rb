#!/usr/bin/env ruby

require_relative 'sim2'

resources = Organization.create_resource_list(
    0,0,1,1,1,1,0,0,1,0,1,1)

motivation = 0.9
trainers = 3
consumption = Organization.create_resource_list(
    1,1,1,1,1,1,1,1,1,1,1,1)
output_level = 2.0
proficiency = 3
ret = Equations.consume(resources, consumption, proficiency)
puts resources
puts ret

t = Equations.train(ret, consumption, trainers, motivation)
o = Equations.output(ret, consumption, motivation, proficiency)
puts t
puts o

puts (76*(1.0-motivation))