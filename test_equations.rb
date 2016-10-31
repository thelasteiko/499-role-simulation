#!/usr/bin/env ruby

require_relative 'sim2'

resources = Organization.create_resource_list(
    2,2,1,1,1,1,1,7,1,7,1,1)

motivation = 0.9
trainers = 3
consumption = Organization.create_resource_list(
    4,2,8,0,0,0,6,2,5,1,4,0)
output_level = 2.0
proficiency = 2
ret = Equations.consume(resources, consumption, proficiency)
puts resources
puts ret

t = Equations.train(ret, consumption, trainers, motivation)
o = Equations.output(ret, consumption, motivation, proficiency)
puts t
puts o
puts motivation - ret[:shortfall] * 0.01