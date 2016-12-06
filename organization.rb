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
    @cap = SimControl.preferences["start_agents"]
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
=begin
    @percents_stat = LittleLog::Statistical.new("percents_use",
        type: @type,
        run:  0,
        "food_s" =>  0,
        "shelter_s" => 0,
        "health_s" =>  0,
        "acquisition_s" => 0,
        "role_s" =>  0,
        "audit_s" => 0,
        "equipment_s" => 0,
        "security_s" =>  0,
        "data_s" =>  0,
        "ojt_s" => 0,
        "professional_s" =>  0,
        "formal_s" =>  0)
    @percente_stat = LittleLog::Statistical.new("percente_use",
        type: @type,
        run:  0,
        "food_e" =>  0,
        "shelter_e" => 0,
        "health_e" =>  0,
        "acquisition_e" => 0,
        "role_e" =>  0,
        "audit_e" => 0,
        "equipment_e" => 0,
        "security_e" =>  0,
        "data_e" =>  0,
        "ojt_e" => 0,
        "professional_e" =>  0,
        "formal_e" =>  0)
    @percentd_stat = LittleLog::Statistical.new("percentd_use",
        type: @type,
        run:  0,
        "food_d" =>  0,
        "shelter_d" => 0,
        "health_d" =>  0,
        "acquisition_d" => 0,
        "role_d" =>  0,
        "audit_d" => 0,
        "equipment_d" => 0,
        "security_d" =>  0,
        "data_d" =>  0,
        "ojt_d" => 0,
        "professional_d" =>  0,
        "formal_d" =>  0)
=end
    @resource_stat = LittleLog::Statistical.new("resource",
        type: @type,
        run: 0,
        "food_start" =>  0,
        "shelter_start" => 0,
        "health_start" =>  0,
        "acquisition_start" => 0,
        "role_start" =>  0,
        "audit_start" => 0,
        "equipment_start" => 0,
        "security_start" =>  0,
        "data_start" =>  0,
        "ojt_start" => 0,
        "professional_start" =>  0,
        "formal_start" =>  0,
        "food_end" =>  0,
        "shelter_end" => 0,
        "health_end" =>  0,
        "acquisition_end" => 0,
        "role_end" =>  0,
        "audit_end" => 0,
        "equipment_end" => 0,
        "security_end" =>  0,
        "data_end" =>  0,
        "ojt_end" => 0,
        "professional_end" =>  0,
        "formal_end" =>  0)
    @retrain_stat = LittleLog::Statistical.new("retrain",
        type: @type,
        run:  0,
        attempts: 0,
        "food_f" =>  0,
        "shelter_f" => 0,
        "health_f" =>  0,
        "acquisition_f" => 0,
        "role_f" =>  0,
        "audit_f" => 0,
        "equipment_f" => 0,
        "security_f" =>  0,
        "data_f" =>  0,
        "ojt_f" => 0,
        "professional_f" =>  0,
        "formal_f" =>  0,
        "food_t" =>  0,
        "shelter_t" => 0,
        "health_t" =>  0,
        "acquisition_t" => 0,
        "role_t" =>  0,
        "audit_t" => 0,
        "equipment_t" => 0,
        "security_t" =>  0,
        "data_t" =>  0,
        "ojt_t" => 0,
        "professional_t" =>  0,
        "formal_t" =>  0)
    @total_stat = LittleLog::Statistical.new("total",
        type: @type,
        run: 0,
        cap: @cap,
        "food_new" => 0,
        "shelter_new" =>  0,
        "health_new" =>   0,
        "acquisition_new" =>  0,
        "role_new" => 0,
        "audit_new" =>  0,
        "equipment_new" =>  0,
        "security_new" => 0,
        "data_new" => 0,
        "ojt_new" =>  0,
        "professional_new" => 0,
        "formal_new" => 0,
        "food_dead" => 0,
        "shelter_dead" =>  0,
        "health_dead" =>   0,
        "acquisition_dead" =>  0,
        "role_dead" => 0,
        "audit_dead" =>  0,
        "equipment_dead" =>  0,
        "security_dead" => 0,
        "data_dead" => 0,
        "ojt_dead" =>  0,
        "professional_dead" => 0,
        "formal_dead" => 0,
        "food_total" => 0,
        "shelter_total" =>  0,
        "health_total" =>   0,
        "acquisition_total" =>  0,
        "role_total" => 0,
        "audit_total" =>  0,
        "equipment_total" =>  0,
        "security_total" => 0,
        "data_total" => 0,
        "ojt_total" =>  0,
        "professional_total" => 0,
        "formal_total" => 0)
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
      @total_stat.inc("#{r}_new")
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
      @total_stat.inc("#{r}_new")
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
  
  def reassign_need(role)
    #check if role is in excess
    if @old_resources[role] >= SimControl.default_data["max_resources"][role]
      mink = priority_need
      if mink and @old_resources[priority_need] <=  SimControl.default_data["min_resources"][role]
        #priority need is really needed
        return true
      end
    end
    return false
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
    #total_s = 0
    @resources.each do |k,v|
      @resource_stat.set("#{k}_start", v)
      #@percents_stat.set("#{k}_s",v)
      #total_s += v
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
    @total_stat.set(:cap, @cap)
    $FRAME.log(self,"update", "R:#{@resources}")
    @old_resources = @resources
    @resources = nr
    @resources.each do |k,v|
      need = v - @old_resources[k] == 0 ? 0.0 : v / (v - @old_resources[k])
      @resources[k] += Equations.consume_audit(
          @old_resources, @consumption, need) * v
    end
    #track resource use
    #total_e = 0
    @old_resources.each do |k,v|
      @resource_stat.set("#{k}_end", v)
      #x = @resource_stat["#{k}_start"]-@resource_stat["#{k}_end"]
      #@percentd_stat.set("#{k}_d", x)
      #total_e += v
      #@percente_stat.set("#{k}_e", v)
    end
=begin
    @resources.each_key do |k|
      @percents_stat.div("#{k}_s", total_s)
      #@percent_stat.div("#{k}_e", total_e)
      @percentd_stat.div("#{k}_d", total_s-total_e)
    end
    @percents_stat.save.inc(:run).reset([:run, :type])
    @percentd_stat.save.inc(:run).reset([:run, :type])
=end
    @resource_stat.save.inc(:run).reset([:run,:type])
    @retrain_stat.save.inc(:run).reset([:run, :type])
    @total_stat.save.inc(:run).reset([:run, :type])
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
      r0 = agent.role.role_name #current
      r1 = agent.desired_role #want
      #$FRAME.log(self, "retrain", "Retrain to #{r1}?")
      r2 = priority_need #org
      #desired + needed
      if @old_resources[r1] < SimControl.default_data["min_resources"][r1]
        #desired + needed + not needed
        if @old_resources[r0] >= SimControl.default_data["max_resources"][r0]
          #agent role change
          r = r1
        else #desired + needed + needed
          r = r0
        end
      #desired + not needed
      else
        #desired + not needed + not needed
        if @old_resources[r0] >= SimControl.default_data["max_resources"][r0]
          r = r1
        end
      end
      if r == nil #has not chosen
        #not desired + needed
        if @old_resources[r2] < SimControl.default_data["min_resources"][r2]
          #not desired + needed + not needed
          if @old_resources[r0] >= SimControl.default_data["max_resources"][r0]
            r = r2
          end #not desired + needed + needed
        #not desired + not needed
        end
      end
    end
    return false if r == nil or not SimControl.role_data["roles"].include? r
    o = SimControl.role_data["offices"][(SimControl.role_data["roles"].index(r)/3).to_i]
    d = SimControl.role_data[o][r]
    ratio = Equations.consume_retrain(@resources, @consumption, d[0])
    if Random.rand < ratio
      role = RoleProgress.new(o,r,d)
      oldrole = agent.role.role_name
      b = agent.change_role(role)
      if b
        @retrain_stat.inc("#{oldrole}_f")
        @retrain_stat.inc("#{r}_t")
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
    unit_log = LittleLog::Debug.new("units")
    unit_log.log(self,"on_close",@type.to_s)
    unit_log.log(self,"on_close",@groups[:units].brief)
    unit_log.log(self,"on_close","\n")
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
