#!/usr/bin/env ruby

require_relative 'sim2'

resources = Organization.create_resource_list(
    1,1,1,1,1,1,1,1,1,1,1,1)

motivation = 0.7
trainers = 3
consumption = Organization.create_resource_list(
    1,1,1,1,1,1,1,1,1,1,1,1)
output_level = 2.0
proficiency = 3
ret = Equations.consume(resources, consumption, proficiency)
puts resources
puts ret

t = Equations.train(ret, trainers, motivation)
o = Equations.output(ret, motivation, proficiency)
puts t
puts o