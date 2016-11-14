#!/usr/bin/env ruby

require_relative 'organization'

class SimControl < LittleGame
  def initialize
    #for each priority do ...
    @run_param = JSON.parse(File.read('run_param.json'))
    @priority = 0
    @reassign = 0
    @test_num = 0
    super(Organization, get_next_run)
  end
  
  def get_next_run
    return nil if @priority >= @run_param["priority"].size
    if @test_num >= @run_param["limit"]
      if @priority == 0
        @priority += 1
        @reassign = 0
      else
        @reassign += 1
        if @reassign >= @run_param["reassignment_level"].size
          @priority += 1
          @reassign = 0
        end
      end
      @test_num = 0
    end
    if @priority == 0
      r = [0,0,0,0]
    else
      r = @run_param["reassignment_level"][@reassign]
    end
    return {"priority" => @run_param["priority"][@priority],
        "reassignment_level" => r}
  end
  
  def run
    if @scene and @scene.end_run
      @test_num += 1
      param = get_next_run
      if param == nil
        @end_game = true
      else
        changescene(Organization.new(self, param))
      end
    end
    super
    
  end
end

if __FILE__ == $0
  $FRAME = LittleFrame.new(400, 300)
  game = SimControl.new
  $FRAME.start(game)
end