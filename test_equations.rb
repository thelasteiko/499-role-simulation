#!/usr/bin/env ruby

require_relative 'organization'

resources = Organization.create_resource_list(
    1,1,1,1,1,1,1,1,1,1,1,1)

motivation = 0.9
trainers = 3
consumption = Organization.create_resource_list(
    1,1,1,2,1,1,1,1,1,1,1,1)
output_level = 2.0
proficiency = 2

=begin
ret = Equations.consume(resources, consumption, proficiency)
puts resources
puts ret

t = Equations.train(ret, consumption, trainers, motivation)
o = Equations.output(ret, consumption, motivation, proficiency)
puts t
puts o
puts motivation - ret[:shortfall] * 0.01
=end

puts resources
cr = Equations.consume_retrain(resources, consumption, 3)
puts resources
puts cr


puts resources
ca = Equations.consume_acquire(resources, consumption, 3)
puts resources
puts ca