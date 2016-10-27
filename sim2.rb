#!/usr/bin/env ruby
=begin
An Agent-based simulation using FXRuby to run the simulation loop.

=end

require_relative 'littleengine'
require_relative 'weightedrand'
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
  # Consumes resources and produces a ratio for training.
  # @param resources [Hash] a listing of available resources.
  # @param trainers [FixNum] the number of trainers available.
  # @param motivation [Float] percentage modifier specific to an agent.
  # @param consumption [FixNum] the rate of resource reduction.
  def Equations.train (resources, consumption, trainers, motivation)
    return 0.0 if consumption["ojt"] <= 0.0
    ratio = (resources["food"]/consumption["food"])  * WEIGHT["food"] +
        (resources["shelter"]/consumption["shelter"])  * WEIGHT["shelter"] +
        (resources["ojt"]/consumption["ojt"]) * WEIGHT["ojt"] +
        trainers
    ratio *= motivation
  end
  # Produces a ratio for output.
  # @param resources [Hash] a listing of available resources.
  # @param motivation [Float] percentage modifier specific to an agent.
  # @param proficiency [Float] the level of proficiency an agent has.
  # @param consumption [Float] the rate of resource reduction.
  # @return [Float] a percentage of the output.
  def Equations.output (resources, consumption, motivation, proficiency)
    return 0.0 if proficiency == 0
    ratio = (resources["food"]/consumption["food"]) * WEIGHT["food"] +
        (resources["shelter"]/consumption["shelter"]) * WEIGHT["shelter"] +
        (resources["health"]/consumption["health"]) * WEIGHT["health"] +
        (resources["equipment"]/consumption["equipment"]) * WEIGHT["equipment"] +
        (resources["data"]/consumption["data"]) * WEIGHT["data"] +
        (resources["security"]/consumption["security"]) * WEIGHT["security"]
    ratio *= (motivation + proficiency + (resources["audit"]  * WEIGHT["audit"]))
    ratio *= 0.1
  end
  
  def Equations.cross_train
    #TODO
  end
  
  def Equations.acquire_agent(resources)
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
        v > 0.0 ? a = v : a = 0.0
        resources[k] -= x
        ret[k] = a
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
        @progress += ratio
      else
        @progress += 1
      end
    end
    #$FRAME.log(5, to_s)
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
  attr_accessor :in_queue
  def initialize(game, group, serial_number,
      office, role_name, role_data, params={})
    super(game, group)
    @serial_number = serial_number
    @roles = [RoleProgress.new(office,role_name,role_data)]
    @tolerance = params[:tolerance] ? params[:tolerance] : 0.8
    @motivation = params[:motivation] ? params[:motivation] : 0.7
    @months_total = params[:months_total] ? params[:months_total] : 240
    @output_level = params[:output_level] ? params[:output_level] : 5.0
    if params[:consumption]
      @consumption = params[:consumption]
    else
      @consumption = Organization.create_resource_list(
          1,1,1,1,1,1,1,1,1,1,1,1
      )
    end
    @months = 0
    @retrain = 0
  end
  # Changes the role of an agent. If the agent has previously
  # held the role, it reverts to the previously held role.
  # This also resets retraining, motivation and sets the
  # months back by 36.
  # @param role [RoleProgress] is the role to switch to.
  def change_role(r)
    #if there is a role with the same office
    a = []
    p = r
    o = role.role_name
    @roles.delete_if do |i|
      if i.office == r.office
        a.push(i)
        p.proficiency = 1
        true
      end
    end
    #if there is a role with the same name
    if a
      a.each do |i|
        if i.role_name == r.role_name
          p = i
          break
        end
      end
      a.delete(p)
      a.each do |i|
        @roles.push(i)
      end
    end
    if p.role_name == o
      return false
    end
    @retrain = 0
    @months -= 36
    @roles.push(p)
    @motivation = WeightedRandom.rand(0,1,0.5,0.9,0.75)
    return true
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
    #$FRAME.log(6, "#{@serial_number}")
    #signifies death
    if @months >= @months_total
      @remove = true
      if trainers[role.office][role.proficiency-1] > 0 and
          role.proficiency > 0
        trainers[role.office][role.proficiency-1] -= 1
      end
      $FRAME.log(6,"#{@serial_number} died at #{@months}/#{@months_total}.")
      return nil
    end
    (ret = Equations.consume(resources, @consumption, role.proficiency))
    #$FRAME.log(3, "#{@serial_number}:#{ret}")
    o = Equations.output(ret, @consumption, @motivation, role.proficiency)
    if role.proficiency > 0 and o < @tolerance
      #TODO it needs to start dying...
      @months += (@months_total*(1.0-@motivation))
      @retrain += 1
      $FRAME.log(3, "#{@serial_number}:#{o}:#{@months}/#{@months_total}")
    end
    if @motivation < 0.5
      @retrain += 1
    end
    #$FRAME.log(3, "#{@serial_number}:#{o}")
    new_resources[role.role_name] += @output_level * o
    #$FRAME.log(3, "#{new_resources}")
    if role.proficiency < 3
      t = Equations.train(ret, @consumption,
          trainers[role.office][role.proficiency], @motivation)
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
    @months += 1
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
      v.each do |j|
        j.update(resources, new_resources,
          trainers)
        if j.retrain > 0 and not j.in_queue
          @game.scene.push(:retrain, j)
        end
      end
      v.delete_if do |j|
        if j.remove
          @game.scene.current_agents -= 1
          true
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
    agent.group = self
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
      @entities.each {|i| i.update(resources, new_resources, trainers)}
      @entities.delete_if {|i| i.remove}
  end
end

class RetrainGroup < Group
  MAX_RETRAINEES = 10
  def update (resources)
    if size > MAX_RETRAINEES
      #find a resource that is needed
      minv = 10000
      mink = nil
      resources.each do |k,v|
        if v < minv
          minv = v
          mink = k
        end
      end
    end
  end
  def draw(graphics, tick)
    #don't do anything
  end
  def load(app)
    #don't do anything
  end
  def get_top
    @entries.sort!{|a,b| a.retrain <=> b.retrain}
    return @entries[-1]
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
    @groups[:retrain] = RetrainGroup.new(game, self)
    @total_units = 1;
    push(:units, Unit.new(game,:units,"U0"))
  end
  # Loads base data to start the simulation with.
  # @see Scene::load
  def load (app)
    #$FRAME.log(0,"Organization::load::Loading objects.")
    #create an office for each role
    for i in 0...12
      r = @role_data["roles"][i] #name of the role
      o = @role_data["offices"][(i/3).to_i] #name of the office
      d = @role_data[o][r] #data for the role
      t = 2 #proficiency level
      params = {role: r, office: o, role_data: d, proficiency: t}
      a = create_agent(params)
      #add agent to unit
      #$FRAME.log(4, a.to_s)
      add_agent(a)
    end
    @resources = Organization.create_resource_list(
        50,50,50,50,50,50,50,50,50,50,50,50
    )
    #set statistics
    if $LOG
      $FRAME.logger.set(:agents_created, @total_agents)
      $FRAME.logger.set(:units_created, @total_units)
    end
    super
  end
  
  # Creates an agent.
  # @param role_name [String] the name of the role.
  # @param role_data [Array] a list of information about the role.
  # @param proficiency [FixNum] represents the proficiency level of the agent.
  # @return [Agent] the created agent.
  def create_agent(param={})
    #$FRAME.log(4, param.to_s)
    if param[:role]
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
      a = Agent.new(@game, :units, o+@total_agents.to_s,o,r,d,
        months_total: (Random.rand(360-36)+36),
        motivation: (Random.rand(100)+2).to_f/100.0)
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
      $FRAME.logger.inc(:units_created)
      u.add_agent(agent)
    end
    @total_agents += 1
    @current_agents += 1
    $FRAME.logger.inc(:agents_created)
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
    if $LOG
      old = {} #for updating the log
      @resources.each do |k,v|
        old[k] = v
      end
    end
    #determine need for basic things: food, shelter, equipment, data
    #and what role needs to be created or retrained from/to
    nr = Organization.create_resource_list
    @groups.each do |k,v|
      if k == :units
        v.update(@resources, nr, @trainers)
      elsif k == :retrain
        v.update(@resources)
      else
        v.update
      end
    end
    $FRAME.log(0, "R:#{@resources}")
    if $LOG #track resource use
      @resources.each do |k,v|
        #difference b/t used and needed
        $FRAME.logger.add("#{k}_needed", old[k] - v) #needed
        v < 0 ? n = old[k] : n = old[k] - v
        $FRAME.logger.add("#{k}_used", n) #actual use
      end
    end
    #TODO determine which resources ran out and go through
    # to retrain agents that could not produce output, unless
    # they are already in that resource band
    #determine whether to add an agent based on
    # acquisition and formal schools resources
    #if there are agents to retrain then retrain them
    if @current_agents < @preferences["max_agents"]
      add_agent(create_agent)
    end
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
  def on_close
    if $LOG
      $FRAME.logger.set(:agents_current, @current_agents)
      $FRAME.logger.set(:units_current, @groups[:units].size)
      #track resource use as well, average resource use per run
      #avg = resources used / runs
      @resources.each do |k,v|
        $FRAME.logger.avg("#{k}_needed")
        $FRAME.logger.avg("#{k}_used")
      end
    end
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
