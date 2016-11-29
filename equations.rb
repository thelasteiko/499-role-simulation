=begin
The equations used in the simulation.
=end
module Equations
  # Determines how much each resource affects the simulation.
  WEIGHT = {
    "food" =>         1.2,
    "shelter" =>      1.2,
    "health" =>       1.1,
    "acquisition" =>  1.0,
    "role" =>         1.0,
    "audit" =>        0.8,
    "equipment" =>    1.2,
    "security" =>     1.0,
    "data" =>         1.2,
    "ojt" =>          1.1,
    "professional" => 0.8,
    "formal" =>       1.0
  }
  # Consumes resources and produces a ratio for training.
  # @param r [Hash] a listing of available resources.
  # @param trainers [FixNum] the number of trainers available.
  # @param motivation [Float] percentage modifier specific to an agent.
  # @param c [FixNum] the rate of resource reduction.
  def Equations.train (r, c, trainers, motivation)
    return 0.0 if c["ojt"] <= 0.0
    ratio = c["food"] == 0 ? 0.0 : (r["food"]/c["food"])  * WEIGHT["food"]
    ratio += c["shelter"] == 0 ? 0.0 : (r["shelter"]/c["shelter"])  * WEIGHT["shelter"]
    ratio += c["ojt"] == 0 ? 0.0 : (r["ojt"]/c["ojt"]) * WEIGHT["ojt"] +
        trainers
    ratio *= motivation
  end
  # Produces a ratio for output.
  # @param r [Hash] a listing of available resources.
  # @param motivation [Float] percentage modifier specific to an agent.
  # @param proficiency [Float] the level of proficiency an agent has.
  # @param c [Float] the rate of resource reduction.
  # @return [Float] a percentage of the output.
  def Equations.output (r, c, motivation, proficiency)
    return 0.0 if proficiency == 0
    ratio = c["food"] == 0 ? 0.0 : (r["food"]/c["food"]) * WEIGHT["food"] * motivation
    ratio += c["shelter"] == 0 ? 0.0 : (r["shelter"]/c["shelter"]) * WEIGHT["shelter"] * motivation
    re = c["equipment"] == 0 ? 0.0 : (r["equipment"]/c["equipment"]) * WEIGHT["equipment"]
    re *= (motivation + proficiency)
    rd = c["data"] == 0 ? 0.0 : (r["data"]/c["data"]) * WEIGHT["data"]
    rd *= (motivation + proficiency)
    rh = c["health"] == 0 ? 0.0 : (r["health"]/c["health"]) * WEIGHT["health"] * motivation
    rs = c["security"] == 0 ? 0.0 : (r["security"]/c["security"]) * WEIGHT["security"] * motivation
    return ratio + re + rd + rh + rs
  end
  # Consumes resources.
  # @param r [Hash] the overall resources available.
  # @param c [Hash] the rate of consumption based
  #   on agent need.
  # @param proficiency [Fixnum] the proficiency of the agent.
  def Equations.consume(r, c, proficiency)
    #$FRAME.log(99,"#{c}")
    ret = {shortfall: 0}
    r.each_pair do |k,v|
      x = c[k]
      if proficiency == 0
        x = 0.0
      elsif k == "ojt" 
        if proficiency == 3
          x = 0.0
        elsif proficiency > 0
          x = (x*2.5) / proficiency
        end
      elsif k == "role" or k == "formal" or k == "acquisition" or k == "audit"
        x = 0.0
      end
      if v - x >= 0.0
        r[k] -= x
        ret[k] = x
      else
        v > 0.0 ? a = v : a = 0.0
        r[k] -= x
        ret[k] = a
        if k == "food" or k == "shelter" or k == "equipment" or k == "data"
          ret[:shortfall] += x-a
        end
      end
    end
    return ret
  end
  # Consumes resources when retraining.
  # @param r [Hash] is the list of resources.
  # @param c [Hash] is the list of consumption rates for the organization.
  # @param cost [FixNum] is the number associated with level 0 training.
  def Equations.consume_retrain(r, c, cost)
    #using formal and role
    x = c["role"]
    n = {}
    if r["role"] - x < 0.0
      r["role"] > 0 ? a = r["role"] : a = 0.0
      n["role"] = a
    else
      n["role"] = x
    end
    r["role"] -= x
    ratio = c["role"] == 0 ? 0.0 : (n["role"]/c["role"]) * WEIGHT["role"]
    x = c["formal"]
    if cost > 0
      if r["formal"] - x < 0.0
        r["formal"] > 0 ? a = r["formal"] : a = 0.0
        n["formal"] = a
      else
        n["formal"] = x
      end
      r["formal"] -= x
      ratio += c["formal"] == 0 ? 0.0 : (n["formal"]/c["formal"]) * WEIGHT["formal"]
      ratio /= cost
    end
    return ratio * 1.5
  end
  # Consumes resources when acquiring agents.
  # @param r [Hash] is the list of resources.
  # @param c [Hash] is the list of consumption rates for the organization.
  # @param cost [FixNum] is the number associated with level 0 training.
  def Equations.consume_acquire (r, c, cost)
    #using formal and acquisition
    x = c["acquisition"]
    n = {}
    if r["acquisition"] - x < 0.0
      r["acquisition"] > 0 ? a = r["acquisition"] : a = 0.0
      n["acquisition"] = a
    else
      n["acquisition"] = x
    end
    r["acquisition"] -= x
    ratio = c["acquisition"] == 0 ? 0.0 : (n["acquisition"]/c["acquisition"]) * WEIGHT["acquisition"]
    x = c["formal"]
    if cost > 0
      if r["formal"] - x < 0.0
        r["formal"] > 0 ? a = r["formal"] : a = 0.0
        n["formal"] = a
      else
        n["formal"] = x
      end
      r["formal"] -= x
      ratio += c["formal"] == 0 ? 0.0 : (n["formal"]/c["formal"]) * WEIGHT["formal"]
      ratio *= cost
    end
    return ratio * 0.19
  end
  
  def Equations.consume_audit(r, c, need)
    x = c["audit"]
    n ={}
    if r["audit"] - x < 0.0
      r["audit"] > 0 ? a = r["audit"] : a = 0.0
      n["audit"] = a
    else
      n["audit"] = x
    end
    r["audit"] -= x
    ratio = c["audit"] == 0 ? 0.0 : (n["audit"]/c["audit"]) * WEIGHT["audit"]
    # need = provided / demand
    ratio *= (need <= 1.0 and need > 0.0) ? (1.0 - need) : 0.0
  end
end