=begin
The equations used in the simulation.
=end
module Equations
  # Determines how much each resource affects the simulation.
  WEIGHT = {
    "food" =>         1.0,
    "shelter" =>      1.0,
    "health" =>       1.1,
    "acquisition" =>  1.0,
    "role" =>         1.0,
    "audit" =>        0.8,
    "equipment" =>    1.1,
    "security" =>     1.0,
    "data" =>         1.1,
    "ojt" =>          1.0,
    "professional" => 0.8,
    "formal" =>       1.0
  }
  # The minimum requirement for training and output.
  TOLERANCE = 1
  # Compares tolerance to the available resources.
  def Equations.basic_tolerance(resources)
    return (resources["food"] >= TOLERANCE and
        resources["shelter"] >= TOLERANCE)
  end
  # Consumes resources and produces a ratio for training.
  # @param resources [Hash] a listing of available resources.
  # @param trainers [FixNum] the number of trainers available.
  # @param motivation [Float] percentage modifier specific to an agent.
  # @param consumption [FixNum] the rate of resource reduction.
  def Equations.train (resources, consumption, trainers, motivation)
    return 0.0 if consumption["ojt"] <= 0.0
    ratio = (resources["food"]/consumption["food"])  * WEIGHT["food"] +
        (resources["shelter"]/consumption["shelter"])  * WEIGHT["shelter"] +
        (resources["ojt"]/consumption["ojt"]) * WEIGHT["ojt"] +
        trainers
    ratio *= motivation
  end
  # Produces a ratio for output.
  # @param resources [Hash] a listing of available resources.
  # @param motivation [Float] percentage modifier specific to an agent.
  # @param proficiency [Float] the level of proficiency an agent has.
  # @param consumption [Float] the rate of resource reduction.
  # @return [Float] a percentage of the output.
  def Equations.output (resources, consumption, motivation, proficiency)
    return 0.0 if proficiency == 0
    ratio = (resources["food"]/consumption["food"]) * WEIGHT["food"] +
        (resources["shelter"]/consumption["shelter"]) * WEIGHT["shelter"] +
        (resources["health"]/consumption["health"]) * WEIGHT["health"] +
        (resources["equipment"]/consumption["equipment"]) * WEIGHT["equipment"] +
        (resources["data"]/consumption["data"]) * WEIGHT["data"] +
        (resources["security"]/consumption["security"]) * WEIGHT["security"]
    ratio *= (motivation + proficiency + (resources["audit"]  * WEIGHT["audit"]))
    ratio *= 0.1
  end
  
  def Equations.cross_train
    #TODO
  end
  
  def Equations.acquire_agent(resources)
    #TODO
  end
  # Consumes resources.
  # @param resources [Hash] the overall resources available.
  # @param consumption [Hash] the rate of consumption based
  #   on agent need.
  def Equations.consume(resources, consumption, proficiency)
    #$FRAME.log(99,"#{consumption}")
    p = proficiency
    if not basic_tolerance(resources) and p > 0
      p -= 1
    end
    ret = {}
    resources.each_pair do |k,v|
      x = consumption[k] + p
      if k == "ojt" and (proficiency == 0 or proficiency == 3)
        x = 0.0
      elsif k == "role" or k == "formal" or k == "acquisition"
        x = 0.0
      end
      if v - x >= 0.0
        resources[k] -= x
        ret[k] = x
      else
        v > 0.0 ? a = v : a = 0.0
        resources[k] -= x
        ret[k] = a
      end
    end
    return ret
  end
end