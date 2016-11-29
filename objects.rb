require_relative 'equations'

class RoleProgress
  MIN_MONTH = [0,12,12]
  RET_MONTH = [0,9,6]
  attr_accessor :office
  # @return [String] the name of the role.
  attr_accessor :role_name
  # @return [Array] reference to the base data for a role.
  attr_accessor :role_data
  # @return [FixNum] 0 to 3 according to the level of proficieny in the job.
  attr_accessor :proficiency
  # @return [FixNum] how many months in the current proficiency level.
  attr_accessor :months_current
  attr_accessor :months
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
    @months = 0
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
    @months += 1
  end
  # Determines if the agent is ready for upgrade to the next proficiency level.
  # @return [Boolean] true if they upgrade, false otherwise.
  def upgrade?(max_prof)
    if @proficiency == 0
      if @months_current >= @role_data[@proficiency]
        @proficiency += 1
        @months_current = 0
        @progress = 0
        return true
      end
    elsif @proficiency < 3
      if @progress >= @role_data[@proficiency] and
          (@months_current >= MIN_MONTH[@proficiency] or
          (max_prof >= @proficiency and
          @months_current >= RET_MONTH[@proficiency]))          
        @proficiency += 1
        @months_current = 0
        @progress = 0
        return true
      end
    end
    false
  end
  def ==(o)
    if o.instance_of? self.class
      return @role_name == o.role_name
    elsif o.instance_of? String
      return @role_name == o
    end
    return false
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
  #attr_accessor :desired_role
  attr_accessor :remove
  attr_accessor :retrained
  attr_accessor :desired_role_probability
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
    #@desired_role = params["desired_role"] ? params["desired_role"] :
    #    SimControl.role_data["roles"][params["desired_role"].to_i]
    @desired_role = SimControl.role_data["roles"][params["desired_role"].to_i]
    #$FRAME.log(self, "initialize", "#{@desired_role}")
    @months = 0
    @retrained = false
    @remove = false
    @desired_role_probability = params["d_prob"] ? params["d_prob"] : 0.0
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
    a = []
    p = nil
    o = role.role_name
    t = role.months
    @roles.each do |i|
      if i.office == r.office
        #$FRAME.log(7, "#{i.office}==#{r.office}")
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
      if @motivation < SimControl.preferences["motivation"] and
          o == @desired_role
        @remove = true
      end
      return false
    end
    #quickly changing roles increases stress
    @months -= 36
    a = SimControl.default_data["default_agent"]["motivation"]
    @motivation = WeightedRandom.rand(0.5,a[2],a[3],a[4],a[5])
    a = SimControl.default_data["default_agent"]["consumption"]["ojt"]
    @consumption["ojt"] = WeightedRandom.rand(a[1],a[2],a[3],a[4],a[5])
    if role.role_name == @desired_role
      @motivation *= 1.5
    elsif t <= 3
      @motivation *= 0.5
    end
    return true
  end
  # Returns the most current role assigned.
  # @return [RoleProgress] is the most recent role.
  def role
    #$FRAME.log(2, "#{@serial_number}:#{@roles}")
    @roles[-1]
  end
  def max_prof
    max = 0
    @roles.each {|i| max = max < i.proficiency ? i.proficiency : max}
    return max
  end
  # Updates the agent, consumes resources and produces output.
  # @param resources [Hash] a list of resources the agent needs.
  # @param new_resources [Hash] a list of resources for the next iteration.
  # @param trainers [Hash] a list of trainers for each role.
  def update (resources, new_resources, trainers)
    #$FRAME.log(6, "#{to_s}")
    #signifies death
    if @months >= @months_total or @motivation <= 0.05
      @remove = true
      return nil
    end
    (ret = Equations.consume(resources, @consumption, role.proficiency))
    #$FRAME.log(3, "#{@serial_number}:#{ret}")
    # Reduce motivation if there isn't enough resources.
    if ret[:shortfall] >= @tolerance
      #$FRAME.log(6, "Shortfall: #{ret[:shortfall]} : #{@motivation}")
      @motivation -= (ret[:shortfall] *
          SimControl.preferences["motivation_multiplier"])
      $FRAME.log(self,"update", "Shortfall: #{ret[:shortfall]} : #{@motivation}")
    elsif ret[:shortfall] <= 0
      @motivation += SimControl.preferences["motivation_multiplier"]
    elsif role.role_name != @desired_role and ret[:shortfall] > 0
      @motivation -= (ret[:shortfall] *
          SimControl.preferences["motivation_multiplier"])
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
    b = role.upgrade?(max_prof)
    if b
      $FRAME.log(self,"update", "#{@serial_number} upgraded to #{role.proficiency}")
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
  def remove_trainer(trainers)
    @roles.each do |i|
      if trainers[i.office][i.proficiency-1] > 0 and
          i.proficiency > 0
        trainers[i.office][i.proficiency-1] -= 1
      end
    end
  end
  # Returns a role that the agent has not been assigned yet.
  # This does not necessarily equal the one they will be
  # most proficient in.
  # @return [String] the name of a role.
  def desired_role (test_data = ["food","shelter","health",
    "equipment","security","data",
    "acquisition","role","audit",
    "ojt","professional","formal"])
    #determine if the desired role will be chosen
    if Random.rand < @desired_role_probability
      #$FRAME.log(self, "desired_role", "Request #{@desired_role}")
      return @desired_role
    end
    min = 0
    max = SimControl.role_data["roles"].length
    if Random.rand < @desired_role_probability + 0.5
      #get the location of the office
      min = (SimControl.role_data["roles"].index(@desired_role)/3).to_i * 3
      max = min+3
    end
    #randomly choose a role from the list of roles
    #where the role chosen is not in the role list
    #r = Random.rand(12)
    r = Random.rand(max-min)+min
    $FRAME.log(self, "desired_role", "#Trying #{r}")
    n = 0
    while @roles.include?(SimControl.role_data["roles"][r]) and
        n < 12
    #while @roles.include?(test_data[r])
      #puts test_data[r]
      #r = Random.rand(12)
      r = Random.rand(max-min)+min
      #$FRAME.log(self, "desired_role", "Trying #{r}")
      n += 1
    end
    @desired_role_probability += Random.rand
    ret = SimControl.role_data["roles"][r]
    if ret == nil
      return role.role_name
    end
    return ret
    #return test_data[r]
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
