#!/usr/bin/env ruby

require_relative 'sim2'

if __FILE__ == $0
  $FRAME = LittleFrame.new(400, 300)
  game = LittleGame.new(Organization)
  $FRAME.start(game)
end