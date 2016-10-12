#!/usr/bin/env ruby

resources = {
    "food" =>         1,
    "shelter" =>      1,
    "health" =>       1,
    "acquisition" =>  1,
    "role" =>         1,
    "audit" =>        1,
    "equipment" =>    1,
    "security" =>     1,
    "data" =>         1,
    "ojt" =>          1,
    "professional" => 1,
    "formal" =>       1
}

puts(resources)

resources.each_pair do |k,v|
  resources[k] += 1
end

puts(resources)
