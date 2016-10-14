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
  TOLERANCE = 1
  def Equations.basic_tolerance(resources)
    return resources["food"] >= TOLERANCE
        and resources["shelter"] >= TOLERANCE
  end
  def Equations.train_tolerance(resources)
    return resources["ojt"] >= TOLERANCE
  end
  def Equations.output_tolerance(resources)
    return resources["equipment"] >= TOLERANCE
        and resources["data"] >= TOLERANCE
  end
  def Equations.train (resources, trainers, motivation, consumption)
    ratio = (resources["food"]  * WEIGHT["food"]
        + resources["shelter"]  * WEIGHT["shelter"]
        + resources["ojt"]      * WEIGHT["ojt"])/100
    resources["ojt"] -= consumption * ratio
    return 0 if not train_tolerance(resources)
    return ratio * (motivation + (trainers/100))
  end
  def Equations.output (resources, motivation, proficiency, consumption)
    return 0 if not output_tolerance(resources)
    ratio = resources["food"]     * WEIGHT["food"]
        + resources["shelter"]    * WEIGHT["shelter"]
        + resources["health"]     * WEIGHT["health"]
        + resources["equipment"]  * WEIGHT["equipment"]
        + resources["data"]       * WEIGHT["data"]
        + resources["security"]   * WEIGHT["security"]
    return ratio * (motivation 
        + (proficiency 
        + resources["audit"]  * WEIGHT["audit"])/100)
  end
  
  def Equations.cross_train
    #TODO
  end
  
  def Equations.acquire_agent
    #TODO
  end
end

class RoleProgress
  MIN_MONTH = [0,12,12]
  attr_accessor :office
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
  def initialize (office, name, role_data)
    @office = office
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
  #attr_accessor :tolerance
  # @return [Float] determines how much output the agent produces.
  attr_accessor :motivation
  # @return [FixNum] how many months the agent has been active.
  attr_accessor :months
  # @return [FixNum] agent life-span.
  attr_accessor :months_total
  def initialize(game, group, serial_number, office, role_name, role_data, params={})
    super(game, group)
    @serial_number = serial_number
    @roles = [RoleProgress.new(office,role_name,role_data)]
    @tolerance = params[:tolerance] ? params[:tolerance] : 1
    @motivation = params[:motivation] ? params[:motivation] : 1
    @months_total = params[:months_total] ? params[:months_total] : 24
    @output_level = params[:output_level] ? params[:output_level] : 5
    @consumption = params[:consumption] ? params[:consumption] : 2
    @months = 0
  end
  # TODO need to make the resource requirements flexible

  def retrain(role)
    #TODO...not used yet
  end
  def role
    #TODO i need the latest...do this when doing cross-training stuff
    @roles.value_at(-1)
  end
  # Updates the agent, consumes resources and produces output.
  # @param resources [Hash] a list of resources the agent needs.
  # @param new_resources [Hash] a list of resources for the next iteration.
  # @param trainers [Hash] a list of trainers for each role.
  def update (resources, new_resources, trainers)
    #signifies death
    if @months >= @months_total 
        or not Equations.basic_tolerance(resources)
      @remove = true
      trainers[role.office][role.proficiency-1] -= 1 if role.proficiency > 0
      return nil
    end
    o = Equations.output(resources, @motivation, role.proficiency, @consumption)
    new_resources[role.role_name] += @output_level * o
    @months += 1
    t = Equations.train(resources, trainers[role.proficiency], motivation, @consumption)
    role.update(t)
    if role.upgrade? and role.proficiency > 0
      trainers[role.office][role.proficiency-1] += 1
    end
  end
end

=begin
The best way to distribute resources is by making each
group a unit with 1 agent per role but this could create
problems when changing roles.
What might work better is having the 3 offices within a unit
then have 3 agents per office. Services and Tech first.
=end

class Unit < GameObject
  # @return [Hash] a hash map of agents in the unit.
  attr_accessor :agents
  attr_accessor :unit_serial
  # Creates an object that holds a certain number of agents.
  def initialize(game, group, unit_serial)
    super(game,group)
    @unit_serial = unit_serial
    @agents = Hash.new
  end
  def update (params={})
    @agents.each do |k,v| 
      v.update(params[:resources],
          params[:new_resources],
          params[:trainers])
    end
    @agents.delete_if {|k,v| v.remove}
    @remove = true if @agents.size == 0
  end
  def has?(role)
    #TODO I can modify this so that it checks if
    # the role is full, that is to have multiple
    # agents in some roles
    @agents[role]
  end
  def add_agent(agent)
    rn = agent.role.role_name
    return false if has?(rn)
    @agent[rn] = [] if not @agent[rn]
    @agent[rn].push(agent)
    true
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
  attr_accessor :current_agents
  attr_accessor :total_units
  attr_accessor :resources
  attr_reader :role_data
  attr_reader :start_data
  attr_accessor :trainers
  def initialize (game)
    super
    #read file things
    #@preferences = JSON.parse(File.read('pref.json'))
    @role_data = JSON.parse(File.read('roles.json'))
    @start_data = JSON.parse(File.read('start.json'))
    @total_agents = 0
    @current_agents = 0
    @total_units = 0;
    @trainers = {
      "service"         =>  [0,0,0],
      "administration"  =>  [0,0,0],
      "technical"       =>  [0,0,0],
      "training"        =>  [0,0,0]
    }
    push(:units,Unit.new(game,:units,"U"+@total_units.to_s))
    @total_units += 1
  end
  # Creates the offices from the starting data and adds agents.
  # @see Scene::load
  def load (app)
    $FRAME.log(0,"Organization::load::Loading objects.")
    #create an office for each role
    roles = @start_data["roles"] #integer array
    for i in 0...roles.length
      if roles[i] > 0 #number of agents in role
        #TODO so this is wonky...
        q = [@start_data["qualified"][0][i],
              @start_data["qualified"][1][i],
              @start_data["qualified"][2][i]]
        r = @role_data["roles"][i] #name of the role
        o = @role_data["offices"][(i/4).to_i] #name of the office
        d = @role_data[o][r] #data for the role
        t = 0 #proficiency level
        for j = 0...roles[i] #for the number of agents to be added
          #create agent
          a = nil
          if t > q.length #got past all the proficiency levels
            a = create_agent(o,r,d)
          else if q[t] == 0 #the current level has been satisfied
            t += 1
          else #the current level needs agents
            a = create_agent(o,r,d,t)
            q[t] -= 1
          end
          a = create_agent(o,r,d) if not a
          #add agent to unit
          add_agent(a)
        end
      end
    end
    @resources = @start_data["resources"]
    super
  end
  
  # Creates an agent.
  # @param role_name [String] the name of the role.
  # @param role_data [Array] a list of information about the role.
  # @param proficiency [FixNum] represents the proficiency level of the agent.
  def create_agent(office,role_name,role_data, proficiency=0)
    a = Agent.new(@game, :unit, office+@total_agents.to_s,
          office,role_name,role_data)
    a.role.proficiency = proficiency
    return a
  end
  # Adds an agent to the simulation, creating a unit if there
  # is none for them.
  # @param agent [Agent] the agent to add.
  def add_agent(agent)
    n = 0 #unit to access
    u = @groups[:units][n] #get first unit
    n += 1
    while u and not u.add_agent(agent)
      u = @groups[:units][n]
      n += 1
    end
    if not u
      u = Unit.new(@game, :units,"U"+@total_units.to_s)
      push(:units,u)
      @total_units += 1
      u.add_agent(agent)
    end
    @total_agents += 1
    @current_agents += 1
    if a.role.proficiency > 0
      @trainers[o][a.role.proficiency-1] += 1
    end
  end
  
  # This is where we need to distribute resources.
  def update
    nr = create_resource_list
    @groups.each do |k,v|
      v.update(resources: @resources,
          new_resources:  nr,
          trainers: @trainers)
    end
    $FRAME.log(1,"Organization::update::Replacing resources : "
        + @resources.to_s)
    @resources = nr
  end
  # Draws if draw is on.
  # @see LittleGame::draw
  def draw (graphics, tick)
    super if $DRAW
  end
  # Creates a resource list with the listed values, defaulting to zero.
  # @param a [Number] how much of whatever.
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

