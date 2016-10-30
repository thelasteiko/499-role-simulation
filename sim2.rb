#!/usr/bin/env ruby
=begin
An Agent-based simulation using FXRuby to run the simulation loop.

=end

require_relative 'littleengine'
require_relative 'weightedrand'
require_relative 'groups'
require 'json'

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
  attr_reader :preferences
  attr_accessor :trainers
  def initialize (game,param)
    super
    #read file things
    @preferences = JSON.parse(File.read('pref.json'))
    @role_data = JSON.parse(File.read('roles.json'))
    @default_data = JSON.parse(File.read('start.json'))
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
      sn = @total_agents
      r = @role_data["roles"][i] #name of the role
      o = @role_data["offices"][(i/3).to_i] #name of the office
      d = @role_data[o][r] #data for the role
      t = 2 #proficiency level
      params = parse_default
      a = Agent.new(@game,:units,sn,o,r,d,params)
      @groups[:units][0].add_agent(a)
      @total_agents += 1
      @current_agents += 1
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
  
  # Creates and adds an agent to the simulation by determining
  # the greatest resource need.
  def add_agent
    sn = @total_agents
    r = priority_need
    o = @role_data["offices"][(@role_data.index(r)/3).to_i]
    d = @role_data[o][r]
    params = parse_default(r)
    agent = Agent.new(@game,:units,sn,o,r,d,params)
    n = 0 #unit to access
    u = @groups[:units][-1] #get last unit
    n = @groups[:units].size-2
    while n >= 0 and not u.add_agent(agent)
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
  
  # Get the resource that is in need.
  def priority_need
    #search through resources
    minv = 10000
    mink = nil
    @resources.each do |k,v|
      if v < minv
        minv = v
        mink = k
      end
    end
    return mink
  end
  
  # Get the resource that is in excess.
  def least_need
    maxv = -100
    maxk = nil
    @resources.each do |k,v|
      if v > maxv
        maxv = v
        maxk = k
      end
    end
    return maxk
  end
  
  # Uses default data to create parameters for a new agent.
  # @param role [String] is the role to create for; default is "default".
  def parse_default(role="default")
    agent_data = @default_data["#{role}_agent"]
    params = {}
    agent_data.each do |k,v|
      if k != "consumption"
        if v[0] < 0
          params[k] = WeightedRandom.rand(
              v[1],v[2],v[3],v[4],v[5])
        else
          params[k] = v[0]
        end
      else
        params[k] = {}
        v.each do |k2,v2|
          if v2[0] < 0
            params[k][k2] = WeightedRandom.rand(
                v2[1],v2[2],v2[3],v2[4],v2[5])
          else
            params[k][k2] = v2[0]
          end
        end
      end
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
