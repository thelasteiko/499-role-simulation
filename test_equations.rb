#!/usr/bin/env ruby

require_relative 'organization'

resources = Organization.create_resource_list(
    10,10,10,10,10,10,10,10,10,10,10,10)

motivation = 0.8
trainers = 0
consumption = Organization.create_resource_list(
    2,2,1,1,1,1,3,1,3,2,1,1)
output_level = 5.0
proficiency = 2

rp = RoleProgress.new('a','b',[3,34,56])
rp.proficiency = 2

ret = Equations.consume(resources, consumption, proficiency)
puts resources
puts ret

t = Equations.train(ret, consumption, trainers, motivation)
o = Equations.output(ret, consumption, motivation, rp)
puts (t * 2.5) / proficiency
puts o
puts motivation - ret[:shortfall] * 0.01

p = 0
for i in 0...30
  m = motivation #WeightedRandom.rand(0.3,1.0,0.6,0.9,0.85)
  if i % 10 == 0
    p += 1
  end
  t = Equations.train(ret, consumption, trainers, m)
  rp.update(t)
  rp.upgrade?(p)
  o = Equations.output(ret, consumption, m,rp)
  puts "M:#{m},P:#{p},O:#{o}"
  puts "#{rp.to_s}"
end

=begin
puts resources
cr = Equations.consume_retrain(resources, consumption, 3)
puts resources
puts cr


puts resources
ca = Equations.consume_acquire(resources, consumption, 3)
puts resources
puts ca


p = 3.0
n = 5.0
puts p/n
cau = Equations.consume_audit(resources, consumption, p/n)

for i in 0...10
  r = Organization.create_resource_list(
    10,10,10,10,10,10,10,10,10,10,10,10)
  p = Random.rand(5).to_f
  n = Random.rand(5).to_f
  puts "#{p},#{n}"
  need = n == 0 ? 0.0 : p/n
  puts Equations.consume_audit(r, consumption, need)
end
=end