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
  # @!attribute [rw] total_agents
  #   @return [FixNum] the total or max amount of agents.
  attr_accessor :total_agents
  # @!attribute [rw] current_agents
  #   @return [FixNum] the current number of agents.
  attr_accessor :current_agents
  # @!attribute [rw] total_units
  #   @return [FixNum] the total number of units created.
  attr_accessor :total_units
  # @return [Hash] the resources available.
  attr_accessor :resources
  attr_accessor :old_resources
  attr_accessor :trainers
  attr_accessor :retrainees
  attr_accessor :consumption
  attr_accessor :total_stat
  attr_accessor :num_runs
  attr_accessor :end_run
  def initialize (game,param)
    super
    #read file things
    @@control_data = param
    @total_agents = 0
    @current_agents = 0
    @cap = 70
    @end_run = false
    @trainers = {
      "service"         =>  [0,0,0],
      "administration"  =>  [0,0,0],
      "technical"       =>  [0,0,0],
      "training"        =>  [0,0,0]
    }
    @groups[:units] = UnitGroup.new(game, self)
    @total_units = 1
    push(:units, Unit.new(game,:units,"U0",
        SimControl.default_data["role_ratios"]))
    @retrainees = []
    @consumption = Hash.new
    @type = "#{@@control_data["priority"]}"
    a = @@control_data["reassignment_level"]
    @type += "#{a[0]}#{a[1]}#{a[2]}#{a[3]}"
    @resource_stat = LittleLog::Statistical.new("resource",
        type: @type,
        run: 0,
        "food_needed" =>  0,
        "food_used" =>    0,
        "shelter_needed" => 0,
        "shelter_used" =>   0,
        "health_needed" =>  0,
        "health_used" =>    0,
        "acquisition_needed" => 0,
        "acquisition_used" =>   0,
        "role_needed" =>  0,
        "role_used" =>    0,
        "audit_needed" => 0,
        "audit_used" =>   0,
        "equipment_needed" => 0,
        "equipment_used" =>   0,
        "security_needed" =>  0,
        "security_used" =>    0,
        "data_needed" =>  0,
        "data_used" =>    0,
        "ojt_needed" => 0,
        "ojt_used" =>   0,
        "professional_needed" =>  0,
        "professional_used" =>    0,
        "formal_needed" =>  0,
        "formal_used" =>    0)
    @retrain_stat = LittleLog::Statistical.new("retrain",
        type: @type,
        run:  0,
        attempts: 0,
        successes:  0)
    @total_stat = LittleLog::Statistical.new("total",
        type: @type,
        run: 0,
        "food_orig" => 0,"food_from" => 0,"food_to" => 0,
        "shelter_orig" =>  0,
        "shelter_from" =>  0,"shelter_to" =>  0,
        "health_orig" =>   0,
        "health_from" =>   0,"health_to" =>   0,
        "acquisition_orig" =>  0,
        "acquisition_from" =>  0,
        "acquisition_to" =>  0,
        "role_orig" => 0,"role_from" => 0,"role_to" => 0,
        "audit_orig" =>  0,"audit_from" =>  0,"audit_to" =>  0,
        "equipment_orig" =>  0,
        "equipment_from" =>  0,
        "equipment_to" =>  0,
        "security_orig" => 0,
        "security_from" => 0,
        "security_to" => 0,
        "data_orig" => 0,"data_from" => 0,"data_to" => 0,
        "ojt_orig" =>  0,"ojt_from" =>  0,"ojt_to" =>  0,
        "professional_orig" => 0,
        "professional_from" => 0,
        "professional_to" => 0,
        "formal_orig" => 0,"formal_from" => 0,"formal_to" => 0)
    #puts "Created Org"
  end
  # Loads base data to start the simulation with.
  # @see Scene::load
  def load (app)
    #puts "Loading..."
    $FRAME.log(self,"load","Starting run #{@type}")
    #create an office for each role
    @resources = Organization.create_resource_list(
        150,150,150,150,150,150,150,150,150,150,150,150
    )
    @old_resources = @resources
    SimControl.default_data["org_consumption"].each do |k,v|
      if v[0] < 0
        a = WeightedRandom.rand(v[1],v[2],v[3],v[4],v[5])
      else
        a = v[0]
      end
      @consumption[k] = a
    end
    for i in 0...SimControl.preferences["start_agents"]
      sn = @total_agents
      r = SimControl.role_data["roles"][i % 12] #name of the role
      params = parse_default
      n = Random.rand
      if n < SimControl.preferences["satisfaction"]
        r = SimControl.role_data["roles"][params["desired_role"]]
      end
      o = SimControl.role_data["offices"][(SimControl.role_data["roles"].index(r)/3).to_i]
      d = SimControl.role_data[o][r] #data for the role
      a = Agent.new(@game,:units,sn,o,r,d,params)
      a.months = a.months_total * Random.rand
      a.role.proficiency = Random.rand(4)
      add_agent(a)
      @total_agents += 1
      @current_agents += 1
      @total_stat.inc("#{r}_orig")
      @total_stat.inc(:total_agents)
    end
    #set statistics
    $FRAME.log(self,"load","Loaded agents #{@current_agents}")
    @num_runs = 0
    super
  end
  
  # Creates and adds an agent to the simulation by determining
  # the greatest resource need.
  def add_agent (agent=nil)
    if not agent
      sn = @total_agents
      params = parse_default#(r)
      if Random.rand < SimControl.preferences["pcs"]
        r = SimControl.role_data["roles"][params["desired_role"]]
        months = Random.rand * params["months_total"]
        proficiency = Random.rand(4)
        school = 0
      else
        r = priority_need
        months = 0
        proficiency = 0
      end
      o = SimControl.role_data["offices"][(SimControl.role_data["roles"].index(r)/3).to_i]
      d = SimControl.role_data[o][r]
      agent = Agent.new(@game,:units,sn,o,r,d,params)
      agent.months = months
      agent.role.proficiency = proficiency
      ratio = Equations.consume_acquire(@resources,
          @consumption, proficiency == 0 ? d[0] : 0)
      if Random.rand > ratio
        $FRAME.log(self,"add_agent", "Failed to add #{sn}.")
        return nil
      end
      @total_agents += 1
      @current_agents += 1
      @total_stat.inc("#{r}_orig")
      #@total_stat.inc(:total_agents)
      #$FRAME.log(self,"add_agent", "Created #{sn}")
    end
    u = nil #get last unit
    n = @groups[:units].size-1
    u = @groups[:units][n]
    b = u ? u.add_agent(agent) : false
    while n >= 0 and not b
      u = @groups[:units][n]
      n -= 1
      b = u.add_agent(agent)
    end
    if n < 0 and not b
      u = Unit.new(@game, :units,"U#{@total_units}",
          SimControl.default_data["role_ratios"])
      push(:units,u)
      @total_units += 1
      #@total_stat.inc(:total_units)
      b = u.add_agent(agent)
    end
    if b
      $FRAME.log(self,"add_agent","Added #{agent.serial_number} to #{u.unit_serial}")
    end
    if agent.role.proficiency > 0
      @trainers[agent.role.office][agent.role.proficiency-1] += 1
    end
  end
  
  def remove_agent
    role = least_need
    u = nil #get last unit
    n = 0
    u = @groups[:units][n]
    b = u ? u.remove_agent(role) : false
    while n < @groups[:units].size and not b
      u = @groups[:units][n]
      n += 1
      b = u.remove_agent(role)
    end
  end
  
  # Get the resource that is in need.
  def priority_need
    #search through resources
    minv = 10000
    mink = nil
    @old_resources.each do |k,v|
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
    @old_resources.each do |k,v|
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
    agent_data = SimControl.default_data["#{role}_agent"]
    #$FRAME.log(9, "Creating defaults...#{agent_data}")
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
    #$FRAME.log(9, "#{params}")
    return params
  end
  
  # This is where we need to distribute resources.
  def update
    return nil if @end_run
    $FRAME.log(self,"update", brief)
    $FRAME.log(self,"update", "IN:#{@resources}")
    if SimControl.preferences["iterations"] == @num_runs || @current_agents < 5
      @end_run = true
      $FRAME.log(self,"EOG", to_s)
      return nil
    end
    old = {} #for updating the log
    @resources.each do |k,v|
      old[k] = v
    end
    while not @retrainees.empty?
      add_agent(@retrainees.pop)
    end
    nr = Organization.create_resource_list
    @groups.each do |k,v|
      if k == :units
        v.update(@resources, nr, @trainers)
      else
        v.update
      end
    end
    if @current_agents < @cap
      add_agent
    else
      remove_agent
    end
    rand = Random.rand(SimControl.preferences["cap_modifier"])
    @cap += (rand * Random.rand < 0.5 ? 1 : -1)
    $FRAME.log(self,"update", "R:#{@resources}")
    #track resource use
    @resources.each do |k,v|
      #difference b/t used and needed
      @resource_stat.add("#{k}_needed", old[k] - v)
      v < 0 ? n = old[k] : n = old[k] - v
      @resource_stat.add("#{k}_used", n) #actual use
    end
    @resource_stat.save.inc(:run).reset([:run,:type])
    @retrain_stat.save.inc(:run).reset([:run, :type])
    @total_stat.save.inc(:run).reset([:run, :type])
    @old_resources = @resources
    @resources = nr
    @num_runs += 1
  end
  
  # Changes the role of an agent based on the set parameters,
  # agent desire and organization needs.
  # @param agent [Agent] is the agent to change the role of.
  def retrain(agent)
    @retrain_stat.inc(:attempts)
    #check preferences for what proficiency level
    #they can change roles at
    if @@control_data["reassignment_level"][agent.role.proficiency] == 0
      return false
    end
    #$FRAME.log(9, "Retraining #{agent.serial_number}")
    if @@control_data["priority"] == "organization"
      #the organization decides where they go
      r = priority_need
    elsif @@control_data["priority"] == "agent"
      #the agent decides
      r = agent.desired_role
    else
      #both try to compromise
      #to           agent         from
      #needed +     desired +     not needed  = yes X
      #needed +     desired +     needed      = yes X
      #needed +     not desired + not needed  = yes 
      #needed +     not desired + needed      = no  X
      #not needed + desired +     not needed  = yes X
      #not needed + desired +     needed      = no  X
      #not needed + not desired + not needed  = no
      #not needed + not desired + needed      = no  X
      r0 = agent.role.role_name
      r1 = agent.desired_role
      r2 = priority_need
      #desired + needed
      if @old_resources[r1] < SimControl.default_data["resources"][r1]
        #desired + needed + not needed
        if @old_resources[r0] >= SimControl.default_data["resources"][r0]
          #agent role change
          r = r1
        else #desired + needed + needed
          r = r0
        end
      #desired + not needed
      else
        #desired + not needed + not needed
        if @old_resources[r0] >= SimControl.default_data["resources"][r0]
          r = r1
        end
      end
      if r == nil #has not chosen
        #not desired + needed
        if @old_resources[r2] < SimControl.default_data["resources"][r2]
          #not desired + needed + not needed
          if @old_resources[r0] >= SimControl.default_data["resources"][r0]
            r = r2
          end #not desired + needed + needed
        #not desired + not needed
        end
      end
    end
    return false if r == nil
    o = SimControl.role_data["offices"][(SimControl.role_data["roles"].index(r)/3).to_i]
    d = SimControl.role_data[o][r]
    ratio = Equations.consume_retrain(@resources, @consumption, d[0])
    if Random.rand < ratio
      role = RoleProgress.new(o,r,d)
      oldrole = agent.role.role_name
      b = agent.change_role(role)
      if b
        @total_stat.inc("#{oldrole}_from")
        @retrain_stat.inc(:successes)
        @total_stat.inc("#{r}_to")
        return b
      end
    end
    false
  end
  
  # Draws if draw is on.
  # @see LittleGame::draw
  def draw (graphics, tick)
    #$FRAME.log(self,"draw","#{tick}")
    #@retrain_stat.set(:runtime, tick)
    super if SimControl.preferences[:draw] == 1
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
      text += "\n\t#{g[i].to_s}"
    end
    text += "\n}"
    return text
  end
  def brief
    "I:#{@num_runs}/#{SimControl.preferences["iterations"]}" +
        "{A:#{@current_agents}/#{@total_agents}," +
        "R:#{@retrainees.size}," +
        "U:#{@groups[:units].size}/#{@total_units}}"
  end
  def on_close
    #@total_stat.set(:agents_current, @current_agents)
    #@total_stat.set(:units_current, @groups[:units].size)
    #@total_stat.save
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
  def self.control_data
    @@control_data
  end
end

=begin

=end
