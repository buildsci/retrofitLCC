#start the measure
class SetCOPforTwoSpeedDXCoolingUnitsAndAutosize < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "Set COP for Two Speed DX Cooling Units"
  end

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #populate choice argument for constructions that are applied to surfaces in the model
    air_loop_handles = OpenStudio::StringVector.new
    air_loop_display_names = OpenStudio::StringVector.new

    #putting space types and names into hash
    air_loop_args = model.getAirLoopHVACs
    air_loop_args_hash = {}
    air_loop_args.each do |air_loop_arg|
      air_loop_args_hash[air_loop_arg.name.to_s] = air_loop_arg
    end

    #looping through sorted hash of air loops
    air_loop_args_hash.sort.map do |key,value|
      show_loop = false
      components = value.supplyComponents
      components.each do |component|
        if not component.to_CoilCoolingDXTwoSpeed.is_initialized  #instead of if not component.to_CoilCoolingDXTwoSpeed.empty?
          show_loop = true
        end
      end
      if show_loop == true
        air_loop_handles << value.handle.to_s
        air_loop_display_names << key
      end
    end

    #add building to string vector with air loops
    building = model.getBuilding
    air_loop_handles << building.handle.to_s
    air_loop_display_names << "*All Air Loops*"

    #make an argument for air loops
    object = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("object", air_loop_handles, air_loop_display_names,true)
    object.setDisplayName("Choose an Air Loop with a two speed DX Cooling Unit to Alter.")
    object.setDefaultValue("*All Air Loops*") #if no air loop is chosen this will run on all air loops
    args << object

    #make an argument to add new space true/false
    cop_high = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("cop_high",true)
    cop_high.setDisplayName("Rated High Speed COP")
    cop_high.setDefaultValue(4.0)
    args << cop_high

    #make an argument to add new space true/false
    cop_low = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("cop_low",true)
    cop_low.setDisplayName("Rated Low Speed COP")
    cop_low.setDefaultValue(4.0)
    args << cop_low

    #bool argument to remove existing costs
    remove_costs = OpenStudio::Ruleset::OSArgument::makeBoolArgument("remove_costs",true)
    remove_costs.setDisplayName("Remove Baseline Costs From Effected Cooling Coil DX Two Speed Units?")
    remove_costs.setDefaultValue(true)
    args << remove_costs

    #make an argument for material and installation cost
    material_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("material_cost",true)
    material_cost.setDisplayName("Material and Installation Costs per Cooling Coil DX Two Speed Unit ($).")
    material_cost.setDefaultValue(0.0)
    args << material_cost

    #make an argument for demolition cost
    demolition_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("demolition_cost",true)
    demolition_cost.setDisplayName("Demolition Costs per Cooling Coil DX Two Speed Unit ($).")
    demolition_cost.setDefaultValue(0.0)
    args << demolition_cost

    #make an argument for duration in years until costs start
    years_until_costs_start = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("years_until_costs_start",true)
    years_until_costs_start.setDisplayName("Years Until Costs Start (whole years).")
    years_until_costs_start.setDefaultValue(0)
    args << years_until_costs_start

    #make an argument to determine if demolition costs should be included in initial construction
    demo_cost_initial_const = OpenStudio::Ruleset::OSArgument::makeBoolArgument("demo_cost_initial_const",true)
    demo_cost_initial_const.setDisplayName("Demolition Costs Occur During Initial Construction?")
    demo_cost_initial_const.setDefaultValue(false)
    args << demo_cost_initial_const

    #make an argument for expected life
    expected_life = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("expected_life",true)
    expected_life.setDisplayName("Expected Life (whole years).")
    expected_life.setDefaultValue(20)
    args << expected_life

    #make an argument for o&m cost
    om_cost = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("om_cost",true)
    om_cost.setDisplayName("O & M Costs per Cooling Coil DX Two Speed Unit ($).")
    om_cost.setDefaultValue(0.0)
    args << om_cost

    #make an argument for o&m frequency
    om_frequency = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("om_frequency",true)
    om_frequency.setDisplayName("O & M Frequency (whole years).")
    om_frequency.setDefaultValue(1)
    args << om_frequency

    return args
  end #end the arguments method

  #define what happens when the measure is cop
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    #use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    #assign the user inputs to variables
    object = runner.getOptionalWorkspaceObjectChoiceValue("object",user_arguments,model) #model is passed in because of argument type
    cop_high = runner.getDoubleArgumentValue("cop_high",user_arguments)
    cop_low = runner.getDoubleArgumentValue("cop_low",user_arguments)
    remove_costs = runner.getBoolArgumentValue("remove_costs",user_arguments)
    material_cost = runner.getDoubleArgumentValue("material_cost",user_arguments)
    demolition_cost = runner.getDoubleArgumentValue("demolition_cost",user_arguments)
    years_until_costs_start = runner.getIntegerArgumentValue("years_until_costs_start",user_arguments)
    demo_cost_initial_const = runner.getBoolArgumentValue("demo_cost_initial_const",user_arguments)
    expected_life = runner.getIntegerArgumentValue("expected_life",user_arguments)
    om_cost = runner.getDoubleArgumentValue("om_cost",user_arguments)
    om_frequency = runner.getIntegerArgumentValue("om_frequency",user_arguments)

    #check the air_loop for reasonableness
    apply_to_all_air_loops = false
    air_loop = nil
    if object.empty?
      handle = runner.getStringArgumentValue("air_loop",user_arguments)
      if handle.empty?
        runner.registerError("No air loop was chosen.")
      else
        runner.registerError("The selected air_loop with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if not object.get.to_AirLoopHVAC.empty?
        air_loop = object.get.to_AirLoopHVAC.get
      elsif not object.get.to_Building.empty?
        apply_to_all_air_loops = true
      else
        runner.registerError("Script Error - argument not showing up as air loop.")
        return false
      end
    end  #end of if air_loop.empty?

    #check the user_name for reasonableness
    if cop_high <= 0
      runner.registerError("Please enter a positive value for Rated High Speed COP.")
      return false
    end
    if cop_high > 10
      runner.registerWarning("The requested Rated High Speed COP of #{cop_high} seems unusually high")
    end
    if cop_low <= 0
      runner.registerError("Please enter a positive value for Rated Low Speed COP.")
      return false
    end
    if cop_low > 10
      runner.registerWarning("The requested Rated Low Speed COP of #{cop_low} seems unusually high")
    end

    #set flags to use later
    costs_requested = false

    #set values to use later
    yr0_capital_totalCosts_baseline = 0
    yr0_capital_totalCosts_proposed = 0

    #If demo_cost_initial_const is true then will be applied once in the lifecycle. Future replacements use the demo cost of the new construction.
    demo_costs_of_baseline_objects = 0

    #check costs for reasonableness
    if material_cost.abs + demolition_cost.abs + om_cost.abs == 0
      runner.registerInfo("No costs were requested for Coil Cooling DX Two Speed units.")
    else
      costs_requested = true
    end

    #check lifecycle arguments for reasonableness
    if not years_until_costs_start >= 0 and not years_until_costs_start <= expected_life
      runner.registerError("Years until costs start should be a non-negative integer less than Expected Life.")
    end
    if not expected_life >= 1 and not expected_life <= 100
      runner.registerError("Choose an integer greater than 0 and less than or equal to 100 for Expected Life.")
    end
    if not om_frequency >= 1
      runner.registerError("Choose an integer greater than 0 for O & M Frequency.")
    end

    #short def to make numbers pretty (converts 4125001.25641 to 4,125,001.26 or 4,125,001). The definition be called through this measure
    def neat_numbers(number, roundto = 2) #round to 0 or 2)
      if roundto == 2
        number = sprintf "%.2f", number
      else
        number = number.round
      end
      #regex to add commas
      number.to_s.reverse.gsub(%r{([0-9]{3}(?=([0-9])))}, "\\1,").reverse
    end #end def neat_numbers

    #helper that loops through lifecycle costs getting total costs under "Construction" or "Salvage" category and add to counter if occurs during year 0
    def get_total_costs_for_objects(objects)
      counter = 0
      objects.each do |object|
        object_LCCs = object.lifeCycleCosts
        object_LCCs.each do |object_LCC|
          if object_LCC.category == "Construction" or object_LCC.category == "Salvage"
            if object_LCC.yearsFromStart == 0
              counter += object_LCC.totalCost
            end
          end
        end
      end
      return counter
    end #end of def get_total_costs_for_objects(objects)

    #get air loops for measure
    if apply_to_all_air_loops
      air_loops = model.getAirLoopHVACs
    else
      air_loops = []
      air_loops << air_loop #only run on a single space type
    end

    # get cop values
    initial_high_cop_values = []
    initial_low_cop_values = []
    missing_initial_high_cop = 0
    missing_initial_low_cop = 0

    #loop through air loops
    air_loops.each do |air_loop|
      supply_components = air_loop.supplyComponents

      #find two speed dx units on loop
      supply_components.each do |supply_component|
        hVACComponent = supply_component.to_CoilCoolingDXTwoSpeed
        if not hVACComponent.empty?
          hVACComponent = hVACComponent.get

          #change and report high speed cop
          initial_high_cop = hVACComponent.ratedHighSpeedCOP
          if not initial_high_cop.empty?
            runner.registerInfo("Changing the Rated High Speed COP from #{initial_high_cop.get} to #{cop_high} for two speed dx unit '#{hVACComponent.name}' on air loop '#{air_loop.name}'")
            initial_high_cop_values << initial_high_cop.get
            hVACComponent.setRatedHighSpeedCOP(cop_high)
			# The following setRated methods in object CoilCoolingDXTwoSpeed 
			# give an error "...Expected argument 1 of type boost:optional, but got Float 8000 (TypeError) in SWIG method..."
			# In the c++ source code, these methods require an argument of ( OptionalDouble value) instead of the ( double value ) found in the setRatedHighSpeedCOP method
			# The methods are unable to take floats, and pass (false), (nil), ("Autosize") does not work either. 		
			value_autosize = OpenStudio::OptionalDouble.new
			hVACComponent.setRatedHighSpeedTotalCoolingCapacity(OpenStudio::OptionalDouble.new) 
			hVACComponent.setRatedHighSpeedSensibleHeatRatio(OpenStudio::OptionalDouble.new) 
			hVACComponent.setRatedHighSpeedAirFlowRate(OpenStudio::OptionalDouble.new) 
          else
            runner.registerInfo("Setting the Rated High Speed COP to #{cop_high} for two speed dx unit '#{hVACComponent.name}' on air loop '#{air_loop.name}. The original object did not have a Rated High Speed COP value'")
            missing_initial_high_cop = missing_initial_high_cop + 1
            hVACComponent.setRatedHighSpeedCOP(cop_high)
			hVACComponent.setRatedHighSpeedTotalCoolingCapacity(OpenStudio::OptionalDouble.new)
			hVACComponent.setRatedHighSpeedSensibleHeatRatio(OpenStudio::OptionalDouble.new)
			hVACComponent.setRatedHighSpeedAirFlowRate(OpenStudio::OptionalDouble.new)
          end

          #change and report low speed cop
          initial_low_cop = hVACComponent.ratedLowSpeedCOP
          if not initial_low_cop.empty?
            runner.registerInfo("Changing the Rated Low Speed COP from #{initial_low_cop.get} to #{cop_low} for two speed dx unit '#{hVACComponent.name}' on air loop '#{air_loop.name}'")
            initial_low_cop_values << initial_low_cop.get
            hVACComponent.setRatedLowSpeedCOP(cop_low)
			hVACComponent.setRatedLowSpeedTotalCoolingCapacity(OpenStudio::OptionalDouble.new)
			hVACComponent.setRatedLowSpeedSensibleHeatRatio(OpenStudio::OptionalDouble.new)
			hVACComponent.setRatedLowSpeedAirFlowRate(OpenStudio::OptionalDouble.new)
          else
            runner.registerInfo("Setting the Rated Low Speed COP to #{cop_low} for two speed dx unit '#{hVACComponent.name}' on air loop '#{air_loop.name}. The original object did not have a Rated Low Speed COP COP value'")
            missing_initial_low_cop = missing_initial_low_cop + 1
            hVACComponent.setRatedLowSpeedCOP(cop_low)
			hVACComponent.setRatedLowSpeedTotalCoolingCapacity(OpenStudio::OptionalDouble.new)
			hVACComponent.setRatedLowSpeedSensibleHeatRatio(OpenStudio::OptionalDouble.new)
			hVACComponent.setRatedLowSpeedAirFlowRate(OpenStudio::OptionalDouble.new)
          end		  
		  
          #get initial year 0 cost
          yr0_capital_totalCosts_baseline += get_total_costs_for_objects([hVACComponent])

          #demo value of baseline costs associated with unit
          demo_LCCs = hVACComponent.lifeCycleCosts
          demo_LCCs.each do |demo_LCC|
            if demo_LCC.category == "Salvage"
              demo_costs_of_baseline_objects += demo_LCC.totalCost
            end
          end

          #remove all old costs to mimic replacement of component vs. an upgrade
          if hVACComponent.lifeCycleCosts.size > 0 and remove_costs == true
            runner.registerInfo("Removing existing lifecycle cost objects associated with #{hVACComponent.name}")
            removed_costs = hVACComponent.removeLifeCycleCosts()
            costs_removed = true
          end

          #add new costs
          if costs_requested == true

            #adding new cost items
            lcc_mat = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_Mat - #{hVACComponent.name}", hVACComponent, material_cost, "CostPerEach", "Construction", expected_life, years_until_costs_start)
            # cost for if demo_initial_Construction == true is added at the end of the measure
            lcc_demo = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_Demo - #{hVACComponent.name}", hVACComponent, demolition_cost, "CostPerEach", "Salvage", expected_life, years_until_costs_start+expected_life)
            lcc_om = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_OM - #{hVACComponent.name}", hVACComponent, om_cost, "CostPerEach", "Maintenance", om_frequency, 0)

            #get final year 0 cost
            yr0_capital_totalCosts_proposed += get_total_costs_for_objects([hVACComponent])

          end #end of costs_requested == true

        end #end if not hVACComponent.empty?

      end #end supply_components.each do

    end #end air_loops.each do

    #add one time demo cost of removed object
    if demo_cost_initial_const == true
      building = model.getBuilding
      lcc_baseline_demo = OpenStudio::Model::LifeCycleCost.createLifeCycleCost("LCC_baseline_demo", building, demo_costs_of_baseline_objects, "CostPerEach", "Salvage", 0, years_until_costs_start).get #using 0 for repeat period since one time cost.
      runner.registerInfo("Adding one time cost of $#{neat_numbers(lcc_baseline_demo.totalCost,0)} related to demolition of baseline objects.")

      #if demo occurs on year 0 then add to initial capital cost counter
      if lcc_baseline_demo.yearsFromStart == 0
        yr0_capital_totalCosts_proposed += lcc_baseline_demo.totalCost
      end
    end

    #reporting initial condition of model
    runner.registerInitialCondition("The starting Rated High Speed COP values in affected loop(s) range from #{initial_high_cop_values.min} to #{initial_high_cop_values.max}. The starting Rated Low Speed COP values range from #{initial_low_cop_values.min} to #{initial_low_cop_values.max}. Initial year 0 capital costs for affected Coil Cooling DX Two Speed units is $#{neat_numbers(yr0_capital_totalCosts_baseline,0)}.")

    #warning if two counts of cop's are not the same
    if not initial_high_cop_values.size + missing_initial_high_cop == initial_low_cop_values.size + missing_initial_low_cop
      runner.registerWarning("Something went wrong with the measure, not clear on count of two speed dx objects")
    end

    if initial_high_cop_values.size + missing_initial_high_cop == 0
      runner.registerAsNotApplicable("The affected loop(s) does not contain any two speed DX cooling units, the model will not be altered.")
      return true
    end

    #reporting final condition of model
    runner.registerFinalCondition("#{initial_high_cop_values.size + missing_initial_high_cop} two speed dx units had their High and Low speed COP values set to #{cop_high} for high, and #{cop_low} for low. Final year 0 capital costs for affected Coil Cooling DX Two Speed units is $#{neat_numbers(yr0_capital_totalCosts_proposed,0)}.")

    return true

  end #end the cop method

end #end the measure

#this allows the measure to be used by the application
SetCOPforTwoSpeedDXCoolingUnitsAndAutosize.new.registerWithApplication