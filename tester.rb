#!/usr/bin/env ruby

class MClass
  def initialize
    super
  end
  def ch (a)
    a[:food] -= 50
  end
end

a = {
    "food":         200,
    "shelter":      200,
    "health":       20,
    "acquisition":  40,
    "role":         70,
    "audit":        20,
    "equipment":    180,
    "security":     30,
    "data":         160,
    "ojt":          140,
    "professional": 80,
    "formal":       40
  }

m = MClass.new
puts a
m.ch (a)
puts a