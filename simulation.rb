#!/usr/bin/env ruby
=begin
An Agent-based simulation using FXRuby to run the simulation loop.

    resources = {
      food: 0,
      shelter: 0,
      health: 0,
      acquisition: 0,
      role: 0,
      audit: 0,
      equipment: 0,
      security: 0,
      data: 0,
      ojt: 0,
      professional: 0,
      formal: 0
    }
=end

require_relative 'littleengine'
require 'json'
$DRAW = false

#Class that has utility functions for reading JSON files.
class FileReader
  # Reads a preference file.
  # @return [Hash] a list of preferences.
  def self.read_pref
  end
  # Reads a file of role definitions.
  def self.read_roles
  end
  # If a role is active, add to data list, else leave out.
  # If a variable is active, leave it out, else add the default.
  # Only resources from an active role should be included.
  def self.read_start
    #returns a Hash? -> :roles, :variables, :resources
    json = File.read('start.json')
    obj = JSON.parse(json)
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

