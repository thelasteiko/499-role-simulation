=begin
I want to make agents.
Sometimes I'll know what kind of agent I'll want.
I will know some variable but not all.
Sometimes I don't know any.
The min things I need for an agent are:
  *game
  *group -> unit
  *ssn -> string
  *office -> string
  *role_name -> string
  *role_data -> array
=end

#do I need an agent?
#what kind of agent do I need?
#I need a function that will create random variables for the
#things that should be random and default values for things that
#should not be random.
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
=begin
get prefs   -> determine whether we are changing roles
            -> what variables will be defaulted
            -> what is the default
=end
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
