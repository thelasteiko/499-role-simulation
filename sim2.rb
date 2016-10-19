#!/usr/bin/env ruby
=begin
An Agent-based simulation using FXRuby to run the simulation loop.

=end

require_relative 'littleengine'
require 'json'

=begin
The equations used in the simulation.
=end
module Equations
  # Determines how much each resource affects the simulation.
  WEIGHT = {
    "food" =>         1.0,
    "shelter" =>      1.0,
    "health" =>       1.1,
    "acquisition" =>  1.0,
    "role" =>         1.0,
    "audit" =>        0.8,
    "equipment" =>    1.1,
    "security" =>     1.0,
    "data" =>         1.1,
    "ojt" =>          1.0,
    "professional" => 0.8,
    "formal" =>       1.0
  }
  # The minimum requirement for training and output.
  TOLERANCE = 1
  # Compares tolerance to the available resources.
  def Equations.basic_tolerance(resources)
    return (resources["food"] >= TOLERANCE and
        resources["shelter"] >= TOLERANCE)
  end
  # Compares tolerance to the available resources.
  def Equations.train_tolerance(resources)
    return resources["ojt"] >= TOLERANCE
  end
  # Compares tolerance to the available resources.
  def Equations.output_tolerance(resources)
    return (resources["equipment"] >= TOLERANCE and
        resources["data"] >= TOLERANCE)
  end
  # Consumes resources and produces a ratio for training.
  # @param resources [Hash] a listing of available resources.
  # @param trainers [FixNum] the number of trainers available.
  # @param motivation [Float] percentage modifier specific to an agent.
  # @param consumption [FixNum] the rate of resource reduction.
  def Equations.train (resources, trainers, motivation)
    return 0.0 if not train_tolerance(resources)
    ratio = (resources["food"]  * WEIGHT["food"] +
        resources["shelter"]  * WEIGHT["shelter"] +
        resources["ojt"]      * WEIGHT["ojt"])/100.0
    return ratio + (motivation + (trainers/100.0))
  end
  # Produces a ratio for output.
  # @param resources [Hash] a listing of available resources.
  # @param motivation [Float] percentage modifier specific to an agent.
  # @param proficiency [Float] the level of proficiency an agent has.
  # @param consumption [Float] the rate of resource reduction.
  # @return [Float] a percentage of the output.
  def Equations.output (resources, motivation, proficiency)
    #return 0.0 if not output_tolerance(resources)
    ratio = (resources["food"]     * WEIGHT["food"] +
        resources["shelter"]    * WEIGHT["shelter"] +
        resources["health"]     * WEIGHT["health"] +
        resources["equipment"]  * WEIGHT["equipment"] +
        resources["data"]       * WEIGHT["data"] +
        resources["security"]   * WEIGHT["security"]) * proficiency
    return ratio + motivation + (resources["audit"]  * WEIGHT["audit"])/10.0
  end
  
  def Equations.cross_train
    #TODO
  end
  
  def Equations.acquire_agent
    #TODO
  end
  # Consumes resources.
  # @param resources [Hash] the overall resources available.
  # @param consumption [Hash] the rate of consumption based
  #   on agent need.
  def Equations.consume(resources, consumption, proficiency)
    #$FRAME.log(99,"#{consumption}")
    p = proficiency
    if not basic_tolerance(resources) and p > 0
      p -= 1
    end
    ret = {}
    resources.each_pair do |k,v|
      x = consumption[k] + p
      if k == "ojt" and (proficiency == 0 or proficiency == 3)
        x = 0.0
      elsif k == "role" or k == "formal" or k == "acquisition"
        x = 0.0
      end
      if v - x >= 0.0
        resources[k] -= x
        ret[k] = x
      else
        ret[k] = v
        resources[k] = 0.0
      end
    end
    return ret
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
    @progress = 0.0
  end
  # Updates the training progress.
  # @param ration [Number] percentage determined by the agent of how much
  #  progress they make.
  def update(ratio)
    if @proficiency > 0 && @proficiency < 3
      if ratio > 0.0
        @progress += (@role_data[@proficiency] * ratio)
      else
        @progress += 1
      end
    end
    @months_current += 1
  end
  # Determines if the agent is ready for upgrade to the next proficiency level.
  # @return [Boolean] true if they upgrade, false otherwise.
  def upgrade?
    if @proficiency == 0 
      if @months_current >= @role_data[@proficiency]
        @proficiency += 1
        @months_current = 0
        @progress = 0
        return true
      end
    elsif @proficiency < 3
      if (@progress >= @role_data[@proficiency] and
          @months_current >= MIN_MONTH[@proficiency])
        @proficiency += 1
        @months_current = 0
        @progress = 0
        return true
      end
    end
    false
  end
  
  def to_s
    "{#{@office}:#{@role_name}:#{@role_data}," +
      "P:#{@proficiency},MOS:#{@months_current},T:#{@progress}}"
  end
end
# Agents are the backbone of the simulation. They intake resources and
# produce output.
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
  attr_accessor :retrain
  def initialize(game, group, serial_number,
      office, role_name, role_data, params={})
    super(game, group)
    @serial_number = serial_number
    @roles = [RoleProgress.new(office,role_name,role_data)]
    @tolerance = params[:tolerance] ? params[:tolerance] : 1.0
    @motivation = params[:motivation] ? params[:motivation] : 1.0
    @months_total = params[:months_total] ? params[:months_total] : 240
    @output_level = params[:output_level] ? params[:output_level] : 2.0
    if params[:consumption]
      @consumption = params[:consumption]
    else
      @consumption = Organization.create_resource_list(
          1,1,1,1,1,1,1,1,1,1,1,1
      )
    end
    @months = 0
  end
  def change_role(role)
    #TODO...not used yet
  end
  def role
    #TODO i need the latest...do this when doing cross-training stuff
    @roles[-1]
  end
  # Updates the agent, consumes resources and produces output.
  # @param resources [Hash] a list of resources the agent needs.
  # @param new_resources [Hash] a list of resources for the next iteration.
  # @param trainers [Hash] a list of trainers for each role.
  def update (resources, new_resources, trainers)
    #signifies death
    if @months >= @months_total
      @remove = true
      if trainers[role.office][role.proficiency-1] > 0 and
          role.proficiency > 0
        trainers[role.office][role.proficiency-1] -= 1
      end
      return nil
    end
    (ret = Equations.consume(resources, @consumption, role.proficiency))
    #$FRAME.log(3, "#{@serial_number}:#{ret}")
    o = Equations.output(ret, @motivation, role.proficiency)
    #$FRAME.log(3, "#{@serial_number}:#{o}")
    new_resources[role.role_name] += @output_level * o
    #$FRAME.log(3, "#{new_resources}")
    @months += 1
    if role.proficiency < 3
      t = Equations.train(ret, trainers[role.office][role.proficiency], @motivation)
      role.update(t)
    else
      t = 0.0
    end
    b = role.upgrade?
    if b
      $FRAME.log(3, "#{@serial_number} upgraded to #{role.proficiency}")
    end
    if b and role.proficiency > 0
      trainers[role.office][role.proficiency-1] += 1
      if role.proficiency-2 >= 0 and
          trainers[role.office][role.proficiency-2] > 0
        trainers[role.office][role.proficiency-2] -= 1
        
      end
      @consumption["ojt"] = 0.0
    end
  end
  def to_s
    text = "#{@serial_number}:#{@motivation}:#{@months}/#{@months_total}{"
    @roles.each do |i|
      text += "\n\t#{i.to_s}"
    end
    text += "}"
    return text
  end
end

=begin
The best way to distribute resources is by making each
group a unit with 1 agent per role.
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
  def update (resources, new_resources, trainers)
    @agents.each do |k,v|
      v.each {|j| j.update(resources, new_resources,
          trainers)}
      v.delete_if do |j|
        if j.remove
          @game.scene.current_agents -= 1
        end
      end
    end
    @agents.delete_if {|k,v| v.size == 0}
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
    if has?(rn)
      #$FRAME.log(5, "Could not add #{@agents[rn][0].to_s}")
      return false
    end
    @agents[rn] = [] if not @agents[rn]
    @agents[rn].push(agent)
    true
  end
  def to_s
    text = "#{@unit_serial}{"
    @agents.each_pair do |k,v|
      text += "\n\t#{k}:#{v}"
    end
    text += "\n}"
    return text
  end
  def brief
    text = "#{@unit_serial}:#{@agents.size}"
  end
end

class UnitGroup < Group
  def update(resources, new_resources, trainers)
      @entities.each {|i| i.update(resources,
          new_resources, trainers)}
      @entities.delete_if {|i| i.remove}
  end
end

=begin
Manages distribution of resources to various units.
  "roles":["food","shelter","health",
    "acquisition","role","audit",
    "equipment","security","data",
    "ojt","professional","formal"]
=end
class Organization < Scene
  # @return [FixNum] the total or max amount of agents.
  attr_accessor :total_agents
  # @return [FixNum] the current number of agents.
  attr_accessor :current_agents
  # @return [FixNum] the total number of units created.
  attr_accessor :total_units
  # @return [Hash] the resources available.
  attr_accessor :resources
  attr_reader :role_data
  attr_reader :start_data
  attr_reader :preferences
  attr_accessor :trainers
  def initialize (game,param)
    super
    #read file things
    @preferences = JSON.parse(File.read('pref.json'))
    @role_data = JSON.parse(File.read('roles.json'))
    @start_data = JSON.parse(File.read('start.json'))
    @total_agents = 0
    @current_agents = 0
    @trainers = {
      "service"         =>  [0,0,0],
      "administration"  =>  [0,0,0],
      "technical"       =>  [0,0,0],
      "training"        =>  [0,0,0]
    }
    @groups[:units] = UnitGroup.new(game, self)
    @total_units = 1;
    push(:units, Unit.new(game,:units,"U0"))
  end
  # Creates the offices from the starting data and adds agents.
  # @see Scene::load
  def load (app)
    #$FRAME.log(0,"Organization::load::Loading objects.")
    #create an office for each role
    roles = @start_data["roles"] #integer array
    q = [0,1,0]
    for i in 0...roles.length
      if roles[i] > 0 #number of agents in role
        #TODO so this is wonky...
        r = @role_data["roles"][i] #name of the role
        o = @role_data["offices"][(i/3).to_i] #name of the office
        d = @role_data[o][r] #data for the role
        t = 1 #proficiency level
        params = {role: r, office: o, role_data: d, proficiency: t}
        a = create_agent(params)
        #add agent to unit
        #$FRAME.log(4, a.to_s)
        add_agent(a)
      end
    end
    @resources = @start_data["resources"]
    super
  end
  
  # Creates an agent.
  # @param role_name [String] the name of the role.
  # @param role_data [Array] a list of information about the role.
  # @param proficiency [FixNum] represents the proficiency level of the agent.
  # @return [Agent] the created agent.
  def create_agent(param={})
    #$FRAME.log(4, param.to_s)
    if param[:office]
      #game, group, serial_number,
      #office, role_name, role_data, params={}
      a = Agent.new(@game, :units,
          param[:office]+@total_agents.to_s,
          param[:office],
          param[:role],
          param[:role_data])
      #$FRAME.log(4, a.to_s)
    else
      num = Random.rand(12)
      r = @role_data["roles"][num]
      o = @role_data["offices"][(num/3).to_i]
      d = @role_data[o][r] #data for the role
      #$FRAME.log(4,"{R:#{r},O:#{o},D:#{d}}")
      a = Agent.new(@game, :units, o+@total_agents.to_s,o,r,d)
    end
    a.role.proficiency = param[:proficiency] ? param[:proficiency] : 0
    return a
  end
  # Adds an agent to the simulation, creating a unit if there
  # is none for them.
  # @param agent [Agent] the agent to add.
  def add_agent(agent)
    n = 0 #unit to access
    u = @groups[:units][-1] #get last unit
    n = -1
    while u and not u.add_agent(agent)
      u = @groups[:units][n]
      n -= 1
    end
    if not u
      u = Unit.new(@game, :units,"U#{@total_units}")
      push(:units,u)
      @total_units += 1
      u.add_agent(agent)
    end
    @total_agents += 1
    @current_agents += 1
    if agent.role.proficiency > 0
      @trainers[agent.role.office][agent.role.proficiency-1] += 1
    end
  end
  
  # This is where we need to distribute resources.
  def update
    return nil if @game.end_game
    if @preferences["iterations"] == 0 || @current_agents < 5
      @game.end_game = true
      $FRAME.log(0, to_s)
      return nil
    end
    $FRAME.log(0, brief)
    $FRAME.log(0, "IN:#{@resources}")
    add_agent(create_agent)
    nr = Organization.create_resource_list
    @groups.each do |k,v|
      if k == :units
        v.update(@resources, nr, @trainers)
      else
        v.update
      end
    end
    $FRAME.log(0, "R:#{@resources}")
    #TODO determine which resources ran out and go through
    # to retrain agents that could not produce output, unless
    # they are already in that resource band
    @resources = nr
    @preferences["iterations"] -= 1
  end
  # Draws if draw is on.
  # @see LittleGame::draw
  def draw (graphics, tick)
    super if @preferences[:draw] == 1
  end
  def to_s
    text = "Agents:#{@current_agents}/#{@total_agents}," +
        "Units:#{@total_units}\nResource{"
    @resources.each_pair do |k,v|
      text += "\n\t#{k}:#{v}"
    end
    text += "\n}\nTrainers{#{@trainers}"
    text += "\n}\nUnits{"
    g = @groups[:units]
    for i in 0...g.size
      text += "\n\t#{g[i].brief}"
    end
    text += "\n}"
    return text
  end
  def brief
    "I:#{@preferences["iterations"]}" +
        "{A:#{@current_agents}/#{@total_agents}," +
        "U:#{@groups[:units].size}/#{@total_units}}"
  end
  # Creates a resource list with the listed values, defaulting to zero.
  # @param a [Number] how much of whatever.
  def self.create_resource_list (a=0,b=0,c=0,d=0,e=0,f=0,g=0,h=0,i=0,j=0,k=0,l=0)
    return {
    "food" =>         a.to_f,
    "shelter" =>      b.to_f,
    "health" =>       c.to_f,
    "acquisition" =>  d.to_f,
    "role" =>         e.to_f,
    "audit" =>        f.to_f,
    "equipment" =>    g.to_f,
    "security" =>     h.to_f,
    "data" =>         i.to_f,
    "ojt" =>          j.to_f,
    "professional" => k.to_f,
    "formal" =>       l.to_f
    }
  end
end

=begin

=end
