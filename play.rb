#!/usr/bin/env ruby

require_relative 'organization'

if __FILE__ == $0
  $FRAME = LittleFrame.new(400, 300)
  game = LittleGame.new(Organization)
  $FRAME.start(game)
end