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
  def initialize(game, group, unit_serial, ratios)
    super(game,group)
    @unit_serial = unit_serial
    @role_ratios = ratios
    @agents = Hash.new
  end
  def update (resources, new_resources, trainers)
    @agents.each do |k,v|
      i = []
      v.each do |j|
        j.update(resources, new_resources,
          trainers)
        if not j.remove and j.role.proficiency > 0 and
            j.motivation <= Organization.preferences["motivation"]
          $FRAME.log(8, "Retraining #{j.to_s}")
          j.retrained = @game.scene.retrain(j)
          if j.retrained
            $FRAME.log(8, "Retrained #{j.to_s}")
            i.push(j)
          end
        end
      end
      #$FRAME.log(7, "#{@unit_serial} retraining #{i.size}")
      i.each do |t|
        t.retrained = false
        @game.scene.retrainees.push(v.delete(t))
      end
      #Find agents that have low motivation and
      # tag to retrain them.
      #options = organization decides, agent decides, both try to agree
      # how do I get the agent to talk to the org?
      v.delete_if do |j|
        if j.remove
          @game.scene.current_agents -= 1
          $FRAME.log(6,"#{j.serial_number} died at #{j.months}/#{j.months_total}.")
          #$FRAME.log(7, "Deleted agent: #{@game.scene.current_agents}")
          true
        end
      end
    end
    @agents.delete_if {|k,v| v.size == 0}
    @remove = true if @agents.size == 0
  end
  def has?(role)
    if @agents[role]
      return @agents[role].size >= @role_ratios[role]
    end
    false
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