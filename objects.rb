require_relative 'equations'

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
      if ratio > 1
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
  # @return [Float] a measure of how much the agent puts up with.
  attr_accessor :tolerance
  # @return [Float] determines how much output the agent produces.
  attr_accessor :motivation
  # @return [FixNum] how many months the agent has been active.
  attr_accessor :months
  # @return [FixNum] agent life-span.
  attr_accessor :months_total
  attr_accessor :desired_role
  attr_accessor :remove
  attr_accessor :retrained
  def initialize(game, group, serial_number,
      office, role_name, role_data, params={})
    super(game, group)
    @serial_number = serial_number
    @roles = [RoleProgress.new(office,role_name,role_data)]
    @tolerance = params["tolerance"] ? params["tolerance"] : 10
    @motivation = params["motivation"] ? params["motivation"] : 0.7
    @months_total = params["months_total"] ? params["months_total"] : 240
    @output = params["output"] ? params["output"] : 5.0
    if params["consumption"]
      @consumption = params["consumption"]
    else
      @consumption = Organization.create_resource_list(
          1,1,1,1,1,1,1,1,1,1,1,1)
    end
    @desired_role = Organization.role_data["roles"][params["desired_role"].to_i]
    #$FRAME.log(1, "#{@desired_role}")
    @months = 0
    @retrained = false
    @remove = false
  end
  # Changes the role of an agent. If the agent has previously
  # held the role, it reverts to the previously held role.
  # This also resets retraining, motivation and sets the
  # months back by 36.
  # @param role [RoleProgress] is the role to switch to.
  # @return [Boolean] true if the agent changed roles;
  #                   false if it did not.
  def change_role(r)
    #if there is a role with the same office
    return false if role.proficiency == 0
    a = []
    p = nil
    o = role.role_name
    @roles.each do |i|
      if i.office == r.office
        $FRAME.log(7, "#{i.office}==#{r.office}")
        a.push(i)
        r.proficiency = 1
      end
    end
    a.each do |j|
      if j.role_name == r.role_name
        p = @roles.delete(j)
        break
      end
    end
    if not p
      @roles.push(r)
    else
      @roles.push(p)
    end
    if role.role_name == o
      if @motivation < Organization.preferences["motivation"] and
          o == @desired_role
        @remove = true
      end
      return false
    end
    @months -= 36
    a = Organization.default_data["default_agent"]["motivation"]
    @motivation = WeightedRandom.rand(a[1],a[2],a[3],a[4],a[5])
    a = Organization.default_data["default_agent"]["consumption"]["ojt"]
    @consumption["ojt"] = WeightedRandom.rand(a[1],a[2],a[3],a[4],a[5])
    if role.role_name == @desired_role
      @motivation *= 1.5
    end
    return true
  end
  # Returns the most current role assigned.
  # @return [RoleProgress] is the most recent role.
  def role
    #$FRAME.log(2, "#{@serial_number}:#{@roles}")
    @roles[-1]
  end
  # Updates the agent, consumes resources and produces output.
  # @param resources [Hash] a list of resources the agent needs.
  # @param new_resources [Hash] a list of resources for the next iteration.
  # @param trainers [Hash] a list of trainers for each role.
  def update (resources, new_resources, trainers)
    #$FRAME.log(6, "#{to_s}")
    #signifies death
    if @months >= @months_total or @motivation <= 0
      @remove = true
      if trainers[role.office][role.proficiency-1] > 0 and
          role.proficiency > 0
        trainers[role.office][role.proficiency-1] -= 1
      end
      return nil
    end
    (ret = Equations.consume(resources, @consumption, role.proficiency))
    #$FRAME.log(3, "#{@serial_number}:#{ret}")
    # Reduce motivation if there isn't enough resources.
    if ret[:shortfall] >= @tolerance
      $FRAME.log(6, "Shortfall: #{ret[:shortfall]}")
      @motivation -= (ret[:shortfall] * 0.01)
    end
    o = Equations.output(ret, @consumption, @motivation, role.proficiency)
    #$FRAME.log(3, "#{@serial_number}:#{o}")
    new_resources[role.role_name] += @output * o
    #$FRAME.log(3, "#{new_resources}")
    if role.proficiency < 3
      t = Equations.train(ret, @consumption,
          trainers[role.office][role.proficiency], @motivation)
    else
      t = 0.0
    end
    role.update(t)
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
