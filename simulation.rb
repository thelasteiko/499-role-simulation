#!/usr/bin/env ruby
=begin
An Agent-based simulation using FXRuby to run the simulation loop.
=end

require_relative 'littleengine'

$DRAW = false

class FileReader
  def self.read_pref
  end
  def self.read_roles
  end
  # If a role is active, add to data list, else leave out.
  # If a variable is active, leave it out, else add the default.
  # Only resources from an active role should be included.
  def self.read_start
    #returns a Hash -> :roles, :variables, :resources
  end
end

class Agent < GameObject

end

class Office < Group

end

class Organization < Scene
  def initialize (game)
    super
    #read file things
    @preferences = FileReader.read_pref
    @role_data = FileReader.read_roles
    @start_data = FileReader.read_start
  end
  def load (app)
    $FRAME.log(0,"Organization::load::Loading objects.")
    #create an office for each role
    roles = @start_data[:roles]
    roles.each do |i|
      
    end
    super
  end
  def draw (graphics, tick)
    super if $DRAW
  end
end

