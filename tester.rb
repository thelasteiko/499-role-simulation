#!/usr/bin/env ruby

#require_relative 'littleengine'
#require_relative 'objects'
require 'json'


role_data = JSON.parse(File.read('roles.json'))

puts role_data["roles"].length
for i in 0...12
  r = Random.rand(12)
  puts role_data["roles"][r]
end

puts role_data["roles"].index("role")

for i in 0...100
  puts Random.rand(12)
end
