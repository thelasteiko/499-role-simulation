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
        if Organization.preferences["reassignment_start"] <= @game.scene.num_runs and
            not j.remove and j.role.proficiency > 0 and
            j.motivation <= Organization.preferences["motivation"]
          $FRAME.log(self,"update", "Retraining #{j.to_s}")
          j.retrained = @game.scene.retrain(j)
          if j.retrained
            $FRAME.log(self,"update", "Retrained #{j.to_s}")
            i.push(j)
          end
        end
      end
      #$FRAME.log(7, "#{@unit_serial} retraining #{i.size}")
      i.each do |t|
        t.retrained = false
        @game.scene.retrainees.push(v.delete(t))
      end
      v.delete_if do |j|
        if j.remove
          @game.scene.current_agents -= 1
          @game.scene.total_stat.dec("#{j.role.role_name}_from")
          j.remove_trainer(trainers)
          $FRAME.log(self,"update",
              "#{j.serial_number} died at #{j.months}/#{j.months_total}.")
          true
        else
          false
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
  
  def remove_agent(role)
    if has?(role)
      @agents[role][0].remove = true
      true
    end
    false
  end
  
  def to_s
    text = "#{@unit_serial}{"
    @agents.each_pair do |k,v|
      v.each do |i|
        text += "\n\t#{k}:#{i.to_s}"
      end
    end
    text += "\n}"
    return text
  end
  def brief
    n = 0
    @agents.each do |k,v|
      n += v.size
    end
    text = "#{@unit_serial}:#{n}"
  end
end

class UnitGroup < Group
  def update(resources, new_resources, trainers)
      @entities.each {|i| i.update(resources, new_resources, trainers)}
      @entities.delete_if do |i|
        if i.remove
          $FRAME.log(self,"update", "Unit #{i.unit_serial} died with #{i.to_s}")
          true
        end
      end
  end
end