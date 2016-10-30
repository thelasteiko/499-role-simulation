require_relative 'objects'

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