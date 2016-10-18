#!/usr/bin/env ruby

require_relative 'sim2'

resources = Organization.create_resource_list(
    2,2,1,1,1,1,1,1,1,1,1,1)

motivation = 1.0
trainers = 3
consumption = 1.0
output_level = 2.0
proficiency = 0.0

ret = Equations.consume(resources, proficiency, consumption)
puts resources
puts ret

t = Equations.train(ret, trainers, motivation)
o = Equations.output(ret, motivation, proficiency)
puts t
puts o