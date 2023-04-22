/*
* Name: ThesisModel
* The simulation code for my thesis
* 
* This code simulates vehicular evacuations from natural disasters. Specifically, this code looks at electric 
* vehicles and the charging infrastructure requirements necessary to evacuate them.
* 
* Author: Cayson Seipel
* Tags: Road, Vehicles, Electric, BEV, Evacuation, Charging-Infrastructure
*/


model ThesisModel

/* Model definition */

global {
	// Global variables
	date starting_date <- date("2019-09-01-00-00-00");
	// The graph (road and node) files used for the simulation
	geometry shape <- envelope(file("../includes/road.shp"));
	file shape_file_roads <- file("../includes/road.shp");
	file shape_file_nodes <- file("../includes/roads.shp");
	
	// Parameters used for the simulation
	// They can be changed in the simulation view
	float step <- 1 #mn;
	bool include_chargers_param <- false;
	float ev_saturation_param <- 0.1;
	float vehicle_length_param <- 3.0;
	float min_speed_param <- 40 #miles/#h;
	float max_speed_param <- 80 #miles/#h;
	float max_acceleration_param <- 0.5 + rnd(500) / 1000;
	float min_miles_remaining_param <- 500 #miles;
	float max_miles_remaining_param <- 700 #miles;
	float min_start_charge <- 0.75;
	float proba_lane_change_up_param <- rnd(500) / 500;
    float proba_lane_change_down_param <- 0.5 + (rnd(250) / 500);
    float security_distance_coeff_param <- 3 - (rnd(2000) / 1000);  
    float proba_respect_priorities_param <- 1.0 - rnd(200/1000);
    float odds_of_zone_target <- 0.38;
    int closest_loc <- 1;
    float percent_evacuated <- 1.0;
	int num_chargers_param <- 5;
	float charge_rate_param <- 50 #miles;
	float disaster_intensity_param <- 5.0;
	float node_scale <- 15.0;
	float vehicle_scale <- 15.0;
	
	// Lists containing all of the node information
	list<roadNode> fuel_locations;
	list<roadNode> start_zone;
	list<roadNode> end_zone;
	list<roadNode> closest_zone;
	
	// The road network
	graph road_network;
	
	init {
		// Create roads from the input file and bring in necessary features
		create road from: shape_file_roads with: [num_lanes::int(read("lanes")), oneway::string(read("oneway")), 
		maxspeed::float(read("maxspeed")) #mile/#h] {
			// Detect if the road is oneway
			switch oneway {
				match "no" {
					create road {
						num_lanes <- myself.num_lanes;
						shape <- polyline(reverse(myself.shape.points));
						maxspeed <- myself.maxspeed;
						linked_road <- myself;
						myself.linked_road <- self;
					}
				}
				match "-1" {
					shape <- polyline(reverse(shape.points));
				}
			}
		}
		
		// The nodes in the graph with their necessary features
		create roadNode from: shape_file_nodes with:[ref::(string(read("ref"))), type::(string(read("type"))), 
			evacuation_zone::int(read("evac_zone")), population::int(read("all_vhcl"))] {
				is_evacuating <- evacuation_zone <= disaster_intensity_param;
			}
		
		// Give nodes declared as charging stations some extra features
		ask roadNode where (each.type = "ev_charging") {
			include_chargers <- include_chargers_param;
			charge_rate <- charge_rate_param;	
			// Set up the charging queue
		 	loop times: num_chargers_param {
				add 0.0 to: chargers;
			}
		}
		
		// Add the roads to the map with speed limits as their weights (for driver preference)
		map general_speed_map <- road as_map (each::(each.shape.perimeter / (each.maxspeed)));
		road_network <- (as_driving_graph(road, roadNode)) with_weights general_speed_map;
		
		// Takes user input to use chargers in the simulation
		if include_chargers_param = true {
			fuel_locations <- roadNode where (each.type = "ev_charging");
		}
		
		// The start and ending zones for the vehicles
		start_zone <- roadNode where (each.type = "start_zone" and each.evacuation_zone <= disaster_intensity_param);
		end_zone <- roadNode where (each.type = "safe_zone"); //or (each.type = "start_zone" 
				//and each.evacuation_zone > disaster_intensity_param));
		
		// Uncommenting the above code would allow starting zones to be considered as safe zones if they are outside of the
		// disaster's reach
		// Something to be considered in the next iteration
		// The below code works in tandem with the above code
		// It is mostly used for coloration on the graph 
		
		/*
		ask roadNode where (each.type = "start_zone") {
			if self in end_zone {
				self.type <- "safe_zone";
			}
		}
		*/
		
		// For each starting zone, initialize vehicles based on the given parameters and the input data
		loop zone over: start_zone {				
			create ev number: zone.population * ev_saturation_param * percent_evacuated {
				fuel_stops <- fuel_locations;
				max_charge <- rnd(min_miles_remaining_param, max_miles_remaining_param);
				miles_remaining <- rnd(min_start_charge * max_charge, max_charge);
				
				if closest_loc > -1 and closest_loc < length(end_zone) {
					// The commented code removes the closest zone from the list of zones if the probability flip dos
					// not choose the 'closest' node
					// The current code has the probabilities a little messed up
					// Consider other options for the next iteration
					safe_zone <- flip(odds_of_zone_target) ? end_zone[closest_loc] : one_of(end_zone); //- 
						//end_zone closest_to(zone));
				} else  {
					safe_zone <- flip(odds_of_zone_target) ? end_zone closest_to(zone) : one_of(end_zone); //- 
						//end_zone closest_to(zone));
				}
				
				speed <- rnd(min_speed_param, max_speed_param);
				start_zone <- zone;
				location <- start_zone.location;
				vehicle_length <- vehicle_length_param;
				proba_lane_change_up <- proba_lane_change_up_param;
        		proba_lane_change_down <- proba_lane_change_down_param;
        		security_distance_coeff <- security_distance_coeff_param;  
        		proba_respect_priorities <- proba_respect_priorities_param;
				max_acceleration <- max_acceleration_param;
				right_side_driving <- true;
			}
		
			create vehicle number: zone.population * (1 - ev_saturation_param) * percent_evacuated {
				if closest_loc > -1 and closest_loc < length(end_zone) {
					safe_zone <- flip(odds_of_zone_target) ? end_zone[closest_loc] : one_of(end_zone); //- 
						//end_zone closest_to(zone));
				} else  {
					safe_zone <- flip(odds_of_zone_target) ? end_zone closest_to(zone) : one_of(end_zone); //- 
						//end_zone closest_to(zone));
				}
				
				speed <- rnd(min_speed_param, max_speed_param);
				start_zone <- zone;
				location <- start_zone.location;
				vehicle_length <- vehicle_length_param;
				proba_lane_change_up <- proba_lane_change_up_param;
        		proba_lane_change_down <- proba_lane_change_down_param;
        		security_distance_coeff <- security_distance_coeff_param;  
        		proba_respect_priorities <- proba_respect_priorities_param;
				max_acceleration <- max_acceleration_param;
				right_side_driving <- true;
			}
		}
		
		// These ask functions determine how many vehicles are travelling along each evacuation route
		ask ev {
			if self.safe_zone.evacuation_zone != nil {
				safe_zone.num_evacuees <- safe_zone.num_evacuees + 1;
			}
		}
		
		ask vehicle {
			if self.safe_zone.evacuation_zone != nil {
				safe_zone.num_evacuees <- safe_zone.num_evacuees + 1;
			}
		}
		
		// Write the counts from above into the console
		loop zone over: end_zone {
			if zone.num_evacuees > 0 {
				write '' + zone.num_evacuees + ' vehicles evacuated along ' + zone.ref;
			}
		}
	}
	
	// End the simulation once all of the vehicles have evacuated
	reflex end_simulation when: (length(ev) = 0) and (length(vehicle) = 0) {
		do pause;
	}
}

// The roads have the skill_road skill but no new reflexes
// This just draws them in the viewer
species road skills: [skill_road]{
	string oneway;
	float length;
	
	aspect base {
		draw shape color: #black;
	}
}

// The noads
//I found it worked better for all nodes to have reflexes from every type of node (start, charging, and end)
species roadNode skills: [skill_road_node, fipa] {
	string ref;
	float evacuation_zone;
	int num_evacuees <- 0;
	int population;
	bool is_evacuating;
	bool include_chargers;
	float charge_rate;
	string type;
	rgb color <- #grey; 
	float wait_time;
	list<float> chargers;
	list<ev> to_capture;
	
	// A subspecies for EVs that have been captured by the charging nodes
	species refuel_ev parent:ev {
		reflex recompute_path when: current_path = nil {
			current_path <- compute_path(graph: road_network, target: safe_zone);
			do start_conversation to: at_charging_station protocol: "no-protocol" performative: "inform" 
				contents: [max_charge - miles_remaining];
		}
		
		reflex accept_proposal when: !(empty(mailbox)) {
			message proposalFinishCharge <- mailbox at 0;
			time_to_finish_charge <- float(float(proposalFinishCharge.contents[0]) mod 24);
		}
	}
	
	// Captures EVs and adds them to the queue
	reflex start_refuel when: type = "ev_charging" and include_chargers = true {
		to_capture <- ev at_distance(1 #mile);
		loop ag over: to_capture{
			bool has_need <- false;
			list<roadNode> current_station;
			ask ag {
				if objective = "refuel" {
					has_need <- true;
					current_station <- at_charging_station;
				}
			}
			
			if has_need = true {
				capture ag as: refuel_ev;
			}
		}
	}
	
	// Another function for the charging nodes
	// Lets the EV know how long it will have to wait to be fully charged
	reflex get_wait_time when: !(empty(informs)) {
		loop m over: informs {
			float charge_time <- float(m.contents[0]) / charge_rate #miles;
		
			if float(current_date.hour) > min(chargers) {
				wait_time <- float(current_date.hour) + charge_time;
			} else {
				wait_time <- min(chargers) + charge_time;
			}
			
			chargers[chargers index_of(min(chargers))] <- wait_time;
			do end_conversation message: m contents: [wait_time];	
		}
	}
	
	// Releases the refueld vehicles from the charging station
	// A charging station exclusive function
	reflex release_refueled when: type = "ev_charging" and include_chargers = true {
		loop charging over: refuel_ev {
			bool to_release <- false;
			ask charging {
				if objective = "vacating" {
					to_release <- true;
				}
			}
			
			if to_release = true {
				release charging as: ev {
					current_path <- compute_path(graph: road_network, target: safe_zone);
				}
			}
		}
	}
	
	// Draw the start, charging, and end zones
	aspect base {
		switch type {
			match "ev_charging"{
				if include_chargers = true {
					draw circle(node_scale * 500) color: #yellow;
				}
			}
			match "start_zone" {
				if is_evacuating = true {
					draw circle(node_scale * 500) color: #orange;
				}
			}
			match "safe_zone" {
				draw circle(node_scale * 500) color: #green;
			}
		}
	}
}

// The vehicle species. This is the base class for vehicles with internal combustion engines.
// The ev species redefines some of the reflexes for this class.
species vehicle skills: [advanced_driving] {
	roadNode closest_zone;
	rgb color <- #blue;
	float speed;
	roadNode start_zone;
	roadNode safe_zone;
	int vacate <- 0;
	string objective <- "resting";
	
	reflex time_to_go when: current_date.hour = vacate and objective = "resting" {
		objective <- "vacating";
		current_path <- compute_path(graph: road_network, target: safe_zone);
	}
	
	// Kill the agent when they evacuate the area.
	reflex kill_evacuated when: final_target = nil and objective != "resting" {//and roadNode closest_to(self) != start_zone {
		do die;
	}
	
	// Drive to the safe zone
	reflex move when: final_target != nil {
		do drive;
	}
	
	aspect base {
		draw rectangle(vehicle_scale * 250, vehicle_scale * 300) color: color border: #black;
	}
}

// The electric vehicle species
species ev parent: vehicle skills: [fipa] {
	list<roadNode> fuel_stops;
	float time_to_finish_charge;
	float max_charge;
	list<roadNode> at_charging_station;
	float miles_remaining;
	rgb color <- #yellow;
		
	// Determines when the EV needs a charge
	reflex time_to_refuel when: objective = "vacating" and miles_remaining <  distance_to_current_target #miles {
		objective <- "going_to_pump";
	}
	
	// The EV is done refueling and is leaving the charging node
	reflex refuel when: objective = "refuel" and float(current_date.hour) = time_to_finish_charge 
		and fuel_stops != [] {
		objective <- "vacating";
		miles_remaining <- max_charge;
		// Do I need this?
		color <- #yellow;
	}
	
	// Updates the remaining charge in addition to moving to the exit
	// Overhauls the move function from the vehicle parent class
	reflex move when: final_target != nil and (miles_remaining - (speed #miles / 60)) > 0 #miles and 
		objective != "refueling" {
		do drive;
		
		miles_remaining <- miles_remaining - (speed #miles / 60);	
		
		if objective = "going_to_pump" {
			at_charging_station <- fuel_stops at_distance(1 #mile);
			if at_charging_station != [] {
				objective <- "refuel";
			}
		}
		
		// The vehicle ran out of charge
		if (miles_remaining - (speed #miles / 60)) <= 0 {
			color <- #red;
			do unregister;
			create fuelless_ev {
				location <- myself.location + {0.0, 0.0, 50.0};
			}
			do die;
		}
	}
}

// Display the EVs without charge
// This was made a seperate class because red vehicles of the EV class were messing with traffic
species fuelless_ev {
	point location;
	
	aspect base {
		draw rectangle(vehicle_scale * 250, vehicle_scale * 300) color: #red border: #black;
	}
}

experiment thesis_model type: gui {
	// Parameter levers
	parameter "The intensity of the disaster:" var: disaster_intensity_param category: "Disaster";
	parameter "Include fuel stations in the simulation:" var: include_chargers_param category: "Fuel Stations";
	parameter "Number of pumps at fuel stations:" var: num_chargers_param category: "Fuel Stations";
	parameter "Miles that the chargers can charge per hour (in meters):" var: charge_rate_param category: "Fuel Stations";
	parameter "Percent of the vehicles that are EVs:" var: ev_saturation_param category: "Vehicle";
	parameter "The minimum speed that can be randomly selected for vehicles (in meters per second):" var: min_speed_param
			  category: "Vehicle";
	parameter "The maximum speed that can be randomly selected for vehicles (in meters per second):" var: max_speed_param
			  category: "Vehicle";
	parameter "The odds that a vehicle will choose to evacuate to the closest evacuation zone" var: odds_of_zone_target 
			  category: "Vehicle";
	parameter "EV market saturation:" var: ev_saturation_param category: "Vehicle";
	parameter "Minumum miles remaining (in meters):" var: min_miles_remaining_param category: "Vehicle";
	parameter "Maximum miles remaining (in meters):" var: max_miles_remaining_param category: "Vehicle";
	parameter "Vehicle length (in meters):" var: vehicle_length_param category: "Vehicle"; 
	parameter "Maximum acceleration (in meters per second):" var: max_acceleration_param category: "Vehicle";
	parameter "Minimum percent of EV starting charge:" var: min_start_charge category: "Vehicle";
	parameter "Percent of vehicles that evacuated:" var: percent_evacuated category: "Vehicle";
	parameter "Scale of nodes:" var: node_scale category: "UI";
	parameter "Scale of vehicles:" var: vehicle_scale category: "UI";
	parameter "The index of the closest safe zone:" var: closest_loc category: "Safe Zones";
	
	output {
		// The display suite
		display city_display type: opengl {
			species road aspect: base refresh: false;
			species roadNode aspect: base refresh: false;
			species vehicle aspect: base;
			species ev aspect: base;
			species fuelless_ev aspect: base;
		}
		// A table of the agent parameters in the simulation
		// Uncommenting this table causes massive slowdowns in the simulation and breaks some features
		//inspect "Miles remaining" value: vehicle type: table;
	}
}




