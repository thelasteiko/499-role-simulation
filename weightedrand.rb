#!/usr/bin/env ruby

=begin
I need a class that gives me a random number within a range
that prioritizes a range within the range.
Example:
  a random number between 0 and 1, prioritizing 0.5 to 0.9
=end
class WeightedRandom
  def self.rand(b,e,r1,r2,p)
    return -1 if r1 < b or r2 > e
    a = Random.rand
    if a < p
      return Random.rand((r2-r1).to_f)+r1
    else
      a = Random.rand
      if a < 0.5
        if r1 < b
          return Random.rand((r1-b).to_f)+b
        else
          return b
        end
      else
        if r2 < e
          return Random.rand((e-r2).to_f)+r2
        else
          return e
        end
      end
    end
    return Random.rand((e-b).to_f)+b
  end
end
