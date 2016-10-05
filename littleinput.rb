#!/usr/bin/env ruby

require 'fox16'
require 'fox16/keys'
include Fox

# Namespace for input functionality.
# Keyboard keys start at 0x0020 so custom codes
# can be created up to 20.
module LittleInput
  # Markers for the command.
  SCENE = 0
  CODE = 1
  ARGS = 2
  # Markers for mouse input.
  MOUSE_LEFT = 0
  MOUSE_RIGHT = 1
  MOUSE_MIDDLE = 4
  MOUSE_WHEEL = 2
  MOUSE_MOTION = 3
  # Markers for key type
  KEYSET_OTHER = 8
  KEYSET_NUMERICAL = 5
  KEYSET_ALPHA = 6
  KEYSET_FUNCTION = 7
  
  PRESS = 9
  RELEASE = 10
  
  #treat consequetive commands as being held down
  #if the time between them is less than the cutoff
  TIMER_CUTOFF = 600
  # Helper class for handling input. The scene should be
  # the current scene.
  class Input
    include LittleInput
    # Creates an input object.
    # @param game [LittleGame] is the game object just in case.
    def initialize(game)
      @queue = Array.new
      @game = game
      @last_command = nil
    end
    # Connect a differenct scene so that it's methods
    # get called during user input.
    # @param scene [Scene] is the current scene.
    # @param mapping [Array] is an array of symbols that relate back to
    #                         methods in the scene for various inputs.
    def connect(scene, mapping)
      @scene = scene
      @mapping = mapping
    end
    
    # Should be called when any type of input is received.
    # @param code [Numeric] is the key or mouse code. This should
    #                       have a related response in the mapping.
    # @param args [Object] whatever is needed for the event to execute.
    def add(code, args = [])
      @queue.push([@scene, code, args])
    end
    
    # Executes the next command in the input queue.
    # @return true if the command could be executed,
    #         false otherwise.
    def execute
      #TODO use generic markers for key sets, such as number, letter, function
      return false if @queue.empty?
      command = @queue.slice!(0)
      #check if the scene is active
      if @scene == command[LittleInput::SCENE]
        #access the appropriate method using call
        sym = @mapping[command[LittleInput::CODE]]
        if sym
          #as a note, all methods using this must take arguments
          #for this not to throw errors
          #@scene.send(sym, command[LittleInput::ARGS])
          @scene.method(sym).call(command[LittleInput::ARGS])
          return true
        end
        if command[LittleInput::CODE] > LittleInput::MOUSE_MIDDLE
          code = LittleInput::KEYSET_OTHER
          if (command[LittleInput::CODE] >= KEY_A and
              command[LittleInput::CODE] <= KEY_Z) or
              (command[LittleInput::CODE] >= KEY_a and
              command[LittleInput::CODE] <= KEY_z)
            code = LittleInput::KEYSET_ALPHA
          elsif (command[LittleInput::CODE] >= KEY_0 and
              command[LittleInput::CODE] <= KEY_1)
            code = LittleInput::KEYSET_NUMERICAL
          elsif command[LittleInput::CODE] >= KEY_F1 and
              command[LittleInput::CODE] <= KEY_R15
            code = LittleInput::KEYSET_FUNCTION
          end
          sym = @mapping[code]
          if sym
            #as a note, all methods using this must take arguments
            #for this not to throw errors
            @scene.method(sym).call(command[LittleInput::ARGS])
            return true
          end
        end
      end
      #if the scene is not active or does not have a
      #corresponding response, return false
      return false
    end
  end
end
