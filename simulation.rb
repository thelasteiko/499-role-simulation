#!/usr/bin/env ruby
=begin
An Agent-based simulation using FXRuby to run the simulation loop.

=end

require_relative 'littleengine'
require 'json'
$DRAW = false

module Equations
  WEIGHT = {
    "food" =>         1.0,
    "shelter" =>      1.0,
    "health" =>       1.0,
    "acquisition" =>  1.0,
    "role" =>         1.0,
    "audit" =>        1.0,
    "equipment" =>    1.0,
    "security" =>     1.0,
    "data" =>         1.0,
    "ojt" =>          1.0,
    "professional" => 1.0,
    "formal" =>       1.0
    }
  def Equations.train (resources, trainers, motivation)
    ratio = (resources["food"] * WEIGHT["food"]
        + resources["shelter"] * WEIGHT["shelter"]
        + resources["ojt"] * WEIGHT["ojt"])/100
    return ratio * (motivation + (trainers/100))
  end
  
  def Equations.output (resources, motivation, proficiency)
    ratio = resources["food"]     * WEIGHT["food"]
        + resources["shelter"]    * WEIGHT["shelter"]
        + resources["health"]     * WEIGHT["health"]
        + resources["equipment"]  * WEIGHT["equipment"]
        + resources["data"]       * WEIGHT["data"]
        + resources["security"]   * WEIGHT["security"]
    return ratio * (motivation + (proficiency + resources["audit"])/100)
  end
  
  def Equations.cross_train
  end
  
  def Equations.acquire_agent
  end
end

class RoleProgress
  MIN_MONTH = [0,12,12]
  # @return [String] the name of the role.
  attr_accessor :role_name
  # @return [Array] reference to the base data for a role.
  attr_accessor :role_data
  # @return [FixNum] 0 to 3 according to the level of proficieny in the job.
  attr_accessor :proficiency
  # @return [FixNum] how many months in the current proficiency level.
  attr_accessor :months_current
  # @return [FixNum] number of tasks completed.
  attr_accessor :progress
  # Creates an object to track the training progress of an agent.
  # @param role_data [Array] holds the requirements for upgrade.
  def initialize (name, role_data)
    @role_name = name
    @role_data = role_data
    @proficiency = 0
    @months_current = 0
    @progress = 0
  end
  # Updates the training progress.
  # @param ration [Number] percentage determined by the agent of how much progress they make.
  def update(ratio)
    if @proficiency > 0
      @progress += (@role_data[@proficiency] * ratio)
    end
    @months_current += 1
  end
  # Determines if the agent is ready for upgrade to the next proficiency level.
  # @return [Boolean] true if they upgrade, false otherwise.
  def upgrade?
    if @proficiency == 0 
      if @months_current >= role_data[@proficiency]
        @proficiency += 1
        @months_current = 0
        @progress = 0
        return true
      end
    else if @proficiency < 3
      if (@progress >= @role_data[@proficiency]
          and @months_current >= MIN_MONTH[@proficiency])
        @proficiency += 1
        @months_current = 0
        @progress = 0
        return true
      end
    end
    false
  end
end
# Agents are the backbone of the simulation. They intake resources and produce output.
class Agent < GameObject
  # @return [String] uniquely identifies agent.
  attr_reader   :serial_number
  # @return [Array] list of the progress the agent has made in training.
  attr_accessor :roles
  # @return [FixNum] base resources needed to produce output.
  attr_accessor :tolerance
  # @return [Float] determines how much output the agent produces.
  attr_accessor :motivation
  # @return [FixNum] how many months the agent has been active.
  attr_accessor :months
  # @return [FixNum] agent life-span.
  attr_accessor :months_total
  def initialize(game, group, serial_number, role_name, role_data, params={})
    super(game, group)
    @serial_number = serial_number
    @roles = [RoleProgress.new(role_name,role_data)]
    @tolerance = params[:tolerance] ? params[:tolerance] : 1
    @motivation = params[:motivation] ? params[:motivation] : 1
    @months_total = params[:months_total] ? params[:months_total] : 24
    @output_level = params[:output_level] ? params[:output_level] : 5
    @months = 0
  end
  # TODO need to make the resource requirements flexible
  def check_tolerance (resources)
    if resources["food"] >= @tolerance
        and resources["shelter"] >= @tolerance
      return true
    end
    false
  end
  def retrain(role)
    #TODO...not used yet
  end
  def role
    #TODO i need the latest...do this when doing cross-training stuff
    @roles.value_at(-1)
  end
  def update (resources, new_resources, trainers)
    #signifies death
    if @months >= @months_total
      @remove = true
      trainers[role.proficience-1] -= 1 if role.proficiency > 0
      return nil
    end
    return nil if not check_tolerance(resources)
    o = Equations.output(resources, @motivation, role.proficiency)
    new_resources[role.role_name] += @output_level * o
    t = Equations.train(resources, trainers[role.proficiency], motivation)
    role.update(t)
    if role.upgrade? and role.proficiency > 0
      trainers[role.proficiency-1] += 1
    end
    @months += 1
  end
end

=begin
do I need a separate office for each role?
what does every office need?
  a way to change roles within the office -> no need to go to school
  distribute resources evenly for agents
  gather resources and report them to organization
  request resources from organization
  
  TODO how do i determine which role is the primary one?
=end
class Office < Group
  attr_accessor :office
  # @return [FixNum] the total amount of agents ever created in this office.
  attr_accessor :total_all
  # @return [FixNum] the current amount of agents.
  attr_accessor :total_curr
  # @return [Array] how many trainers there are for each proficiency level.
  attr_accessor :trainers
  def initialize (game, scene, office, params={})
    super(game,scene)
    @office = office
    @total_all = 0
    @total_curr = 0
    @trainers = [0,0,0,0]
    add_role(params) if params[:role]
  end
  # Adds a role to this office object and initializes agents for it.
  # @param params [Hash] a list of parameters. The hash is for ease of programming.
  def add_role(params={}) #TODO this doesn't really need to be a hash
    return nil if params[:office] != @office
    data = @scene.role_data[@office][params[:role]]
    q = params[:qualified]
    for i in 0...params[:num]
      #TODO on the next iteration have an optional JSON list of agents to load
      a = Agent.new(@game,@office,params[:role]+@total_all.to_s,params[:role],data)
      for j in 0...q.length #so for the beginning add some trainers
        if q[j] > 0
          a.role.proficiency = j+1
          q[j] -= 1
          @trainers[j] += 1
          break
        end
      end
      push(a)
      @total_all += 1
      @total_curr += 1
    end
  end
  
  def update (resources, new_resources)
    @entities.each {|i| i.update(resources, new_resources, @trainers)}
    @entities.delete_if{|i| i.remove}
  end
end

=begin
Manages distribution of resources to various offices.
  "roles":["food","shelter","health",
    "acquisition","role","audit",
    "equipment","security","data",
    "ojt","professional","formal"]
=end
class Organization < Scene
  attr_accessor :total_agents
  attr_accessor :resources
  attr_reader :role_data
  attr_reader :start_data
  def initialize (game)
    super
    #read file things
    #@preferences = JSON.parse(File.read('pref.json'))
    @role_data = JSON.parse(File.read('roles.json'))
    @start_data = JSON.parse(File.read('start.json'))
    @total_agents = 0
  end
  # Creates the offices from the starting data and adds agents.
  # @see Scene::load
  def load (app)
    $FRAME.log(0,"Organization::load::Loading objects.")
    #create an office for each role
    roles = @start_data["roles"] #integer array
    for i in 0...roles.length
      if roles[i] > 0
        r = @role_data["roles"][i] #name of the role
        #TODO so this is wonky...
        q = [@start_data["qualified"][0][i],
              @start_data["qualified"][1][i],
              @start_data["qualified"][2][i]]
        o = @role_data["offices"][(i/4).to_i] #name of the office
        if @groups[o]
          #updates an office that already exists
          @groups[o].add_role(o,r,roles[i])
        else
          #adds a new office with the role data and how many agents
          push(@role_data["roles"],Office.new(@game,this,o,
            role: r,initial_agents: roles[i],qualified: q))
        end
        @total_agents += @groups[o].total_curr
      end
    end
    @resources = @start_data["resources"]
    super
  end
  
  # This is where we need to distribute resources.
  def update
    new_resources = create_resource_list
    @groups.each do |k,v|
      resources = create_distributed (v.total_curr)
      v.update(resources, new_resources)
    end
    $FRAME.log(1,"Organization::update::Replacing resources : "
        + @resources.to_s)
    @resources = new_resources
  end
  # Draws if draw is on.
  # @see LittleGame::draw
  def draw (graphics, tick)
    super if $DRAW
  end
  # Creates a resource list depending on the number of agents
  # to provide for from the total resource list. Then it subtracts
  # any distributed resources from the current list.
  def create_distributed (num)
    #create a resource list that has distributed resources
    # according to how many people total and how many to provide for
    new_list = Organization.create_resource_list
    @resources.each_pair do |k,v|
      # v / total = how much each * num = how much
      nv = (v / @total_agents) * num
      new_list[k] = nv
      @resources[k] -= nv
    end
    return new_list
  end
  def self.create_resource_list (a=0,b=0,c=0,d=0,e=0,f=0,g=0,h=0,i=0)
    return {
    "food" =>         a,
    "shelter" =>      b,
    "health" =>       c,
    "acquisition" =>  d,
    "role" =>         e,
    "audit" =>        f,
    "equipment" =>    g,
    "security" =>     h,
    "data" =>         i,
    "ojt" =>          j,
    "professional" => k,
    "formal" =>       l
    }
  end
  
end

