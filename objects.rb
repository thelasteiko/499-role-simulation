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