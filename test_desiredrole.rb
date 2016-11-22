#!/usr/bin/env ruby

require_relative 'littleengine'
require_relative 'objects'
#require 'json'

r1 = RoleProgress.new("a","b",[0,0,0])
r2 = RoleProgress.new("a","c",[0,0,0])

puts (r1 == r2)

array = [r1,r2]

puts array.include? "c"

a = Agent.new(nil,nil,"0","a","food",[0,0,0], "desired_role" => "role",
    "consumption" => {"food" => 1})

puts a.desired_role
puts a.desired_role


#role_data = JSON.parse(File.read('roles.json'))

#puts role_data["roles"].length
