#!/usr/bin/env ruby

a = {"food" => 10, "shelter" => 8, "health" => 10}

minv = 10000
mink = nil

a.each {|k,v| v < minv ? minv = v; mink = k : nil}
puts a
