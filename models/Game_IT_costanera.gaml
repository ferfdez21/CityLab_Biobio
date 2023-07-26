/**
* Name: gamit Costanera
* Author: Arnaud Grignard, Tri Nguyen Huu, Patrick Taillandier, Benoit Gaudou
* Description: Describe here the model and its experiments
* Tags: Mobility, Costanera
*/

model gamit

import "./species/Building.gaml"
import "./species/Bus.gaml"
import "./species/External_City.gaml"
import "./species/People.gaml"
import "./species/Road.gaml"

import "./configuration.gaml"

global {
	
	
	map<string,map<string,int>> activity_data;
	map<string, float> proportion_per_type;
	map<string, float> proba_bike_per_type;
	map<string, float> proba_car_per_type;	
	map<string,rgb> color_per_mobility;
	map<string,float> width_per_mobility;
	map<string,float> speed_per_mobility;
	map<string,graph> graph_per_mobility;
	map<string,float> weather_coeff_per_mobility;
	map<string,list<float>> charact_per_mobility;
	map<road,float> congestion_map;  
	map<string,map<string,list<float>>> weights_map <- map([]);
	list<list<float>> weather_of_month;
	
	// INDICATOR
	map<string,int> transport_type_cumulative_usage <- map(mobility_list collect (each::0));
	map<string,int> transport_type_usage <- map(mobility_list collect (each::0));
	map<string,float> transport_type_distance <- map(mobility_list collect (each::0.0)) + ["bus_people"::0.0];
	map<string, int> buildings_distribution <- map(color_per_category.keys collect (each::0));
	
	float weather_of_day min: 0.0 max: 1.0;	

	init {
		gama.pref_display_flat_charts <- true;
		do import_shapefiles;	
		do profils_data_import;
		do activity_data_import;
		do criteria_file_import;
		do characteristic_file_import;
		do import_weather_data;
		do compute_graph;

		create bus_stop number: 6 {
			location <- one_of(building).location;
		}
		
		create bus {
			stops <- list(bus_stop);
			location <- first(stops).location;
			stop_passengers <- map<bus_stop, list<people>>(stops collect(each::[]));
		}		
		
		create people number: nb_people {
			type <- proportion_per_type.keys[rnd_choice(proportion_per_type.values)];
			has_car <- flip(proba_car_per_type[type]);
			has_bike <- flip(proba_bike_per_type[type]);
			living_place <- one_of(building where (each.usage = "R"));
			current_place <- living_place;
			location <- any_location_in(living_place);
			color <- color_per_type[type];
			closest_bus_stop <- bus_stop with_min_of(each distance_to(self));						
			do create_trip_objectives;
		}	
		save "cycle,walking,bike,car,bus,average_speed,walk_distance,bike_distance,car_distance,bus_distance, bus_people_distance" to: "../results/mobility.csv";
		
		
	}
	
    reflex save_simu_attribute when: (cycle mod 100 = 0){
    	save [cycle,transport_type_usage.values[0] ,transport_type_usage.values[1], transport_type_usage.values[2], transport_type_usage.values[3], mean (people collect (each.speed)), transport_type_distance.values[0],transport_type_distance.values[1],transport_type_distance.values[2],transport_type_distance.values[3],transport_type_distance.values[4]] rewrite:false to: "../results/mobility.csv" format:"csv";
	    // Reset value
	    transport_type_usage <- map(mobility_list collect (each::0));
	    transport_type_distance <- map(mobility_list collect (each::0.0)) + ["bus_people"::0.0];
	    if(cycle = 5000){
	    	do pause;
	    }
	}
	
	
	action import_weather_data {
		matrix weather_matrix <- matrix(weather_coeff);
		loop i from: 0 to:  weather_matrix.rows - 1 {
			weather_of_month << [float(weather_matrix[1,i]), float(weather_matrix[2,i])];
		}
	}
	action profils_data_import {
		matrix profile_matrix <- matrix(profile_file);
		loop i from: 0 to:  profile_matrix.rows - 1 {
			string profil_type <- profile_matrix[0,i];
			if(profil_type != "") {
				proba_car_per_type[profil_type] <- float(profile_matrix[2,i]);
				proba_bike_per_type[profil_type] <- float(profile_matrix[3,i]);
				proportion_per_type[profil_type] <- float(profile_matrix[4,i]);
			}
		}
	}
	

	
	action activity_data_import {
		matrix activity_matrix <- matrix (activity_file);
		loop i from: 1 to:  activity_matrix.rows - 1 {
			string people_type <- activity_matrix[0,i];
			map<string, int> activities;
			string current_activity <- "";
			loop j from: 1 to:  activity_matrix.columns - 1 {
				string act <- activity_matrix[j,i];
				if (act != current_activity) {
					activities[act] <-j;
					 current_activity <- act;
				}
			}
			activity_data[people_type] <- activities;
		}
	}
	
	action criteria_file_import {
		matrix criteria_matrix <- matrix (criteria_file);
		int nbCriteria <- criteria_matrix[1,0] as int;
		int nbTO <- criteria_matrix[1,1] as int ;
		int lignCategory <- 2;
		int lignCriteria <- 3;
		
		loop i from: 5 to:  criteria_matrix.rows - 1 {
			string people_type <- criteria_matrix[0,i];
			int index <- 1;
			map<string, list<float>> m_temp <- map([]);
			if(people_type != "") {
				list<float> l <- [];
				loop times: nbTO {
					list<float> l2 <- [];
					loop times: nbCriteria {
						add float(criteria_matrix[index,i]) to: l2;
						index <- index + 1;
					}
					string cat_name <-  criteria_matrix[index-nbTO,lignCategory];
					loop cat over: cat_name split_with "|" {
						add l2 at: cat to: m_temp;
					}
				}
				add m_temp at: people_type to: weights_map;
			}
		}
	}
	
	action characteristic_file_import {
		matrix mode_matrix <- matrix (mode_file);
		loop i from: 0 to:  mode_matrix.rows - 1 {
			string mobility_type <- mode_matrix[0,i];
			if(mobility_type != "") {
				list<float> vals <- [];
				loop j from: 1 to:  mode_matrix.columns - 2 {
					vals << float(mode_matrix[j,i]);	
				}
				charact_per_mobility[mobility_type] <- vals;
				color_per_mobility[mobility_type] <- rgb(mode_matrix[7,i]);
				width_per_mobility[mobility_type] <- float(mode_matrix[8,i]);
				speed_per_mobility[mobility_type] <- float(mode_matrix[9,i]);
				weather_coeff_per_mobility[mobility_type] <- float(mode_matrix[10,i]);
			}
		}
	}
		
	action import_shapefiles {
		create road from: roads_shapefile {
			mobility_allowed <-["walking","bike","car","bus"];
			capacity <- shape.perimeter / 10.0;
			congestion_map [self] <- shape.perimeter;
		}
		create building from: buildings_shapefile with: [usage::string(read ("Usage")),scale::string(read ("Scale")),category::string(read ("Category"))]{
			color <- color_per_category[category];
		}
		create externalCities from: external_cities_shapefile with: [];		
	}
		
	
	action compute_graph {
		loop mobility_mode over: color_per_mobility.keys {
			graph_per_mobility[mobility_mode] <- as_edge_graph(road where (mobility_mode in each.mobility_allowed)) use_cache false;	
		}
	}
		
	reflex update_road_weights {
		ask road {
			do update_speed_coeff;	
			congestion_map [self] <- speed_coeff;
		}
	}
	
	reflex update_buildings_distribution{
		buildings_distribution <- map(color_per_category.keys collect (each::0));
		ask building{
			buildings_distribution[usage] <- buildings_distribution[usage]+1;
		}
	}
	
	reflex update_weather when: weatherImpact and every(#day){
		list<float> weather_m <- weather_of_month[current_date.month - 1];
		weather_of_day <- gauss(weather_m[0], weather_m[1]);
	}			
}


grid gridHeatmaps height: 50 width: 50 {
	int pollution_level <- 0 ;
	int density<-0;
	rgb pollution_color <- rgb(255-pollution_level*10,255-pollution_level*10,255-pollution_level*10) update:rgb(255-pollution_level*10,255-pollution_level*10,255-pollution_level*10);
	rgb density_color <- rgb(255-density*50,255-density*50,255-density*50) update:rgb(255-density*50,255-density*50,255-density*50);
	
	aspect density{
		draw shape color:density_color at:{location.x+current_date.hour*world.shape.width,location.y};
	}
	
	aspect pollution{
		draw shape color:pollution_color;
	}
	
	reflex raz when: every(1#hour) {
		pollution_level <- 0;
	}
}


experiment gameit type: gui {
	output {
		display map type: opengl draw_env: false background: #black refresh:every(10#cycle){
			//species gridHeatmaps aspect:pollution;
			//species pie;
			species building aspect:depth refresh: false;
			species road ;		
			species people aspect:base ;
			species externalCities aspect:base;
								
			graphics "time" {
				draw string(current_date.hour) + "h" + string(current_date.minute) +"m" color: # white font: font("Helvetica", 25, #italic) at: {world.shape.width*0.9,world.shape.height*0.55};
			}
			
			overlay position: { 5, 5 } size: { 240 #px, 680 #px } background: # black transparency: 1.0 border: #black 
            {
            	
                rgb text_color<-#white;
                float y <- 30#px;
  				draw "Building Usage" at: { 40#px, y } color: text_color font: font("Helvetica", 25, #bold) perspective:false;
                y <- y + 30 #px;
                loop type over: color_per_category.keys
                {
                    draw square(20#px) at: { 20#px, y } color: color_per_category[type] border: #white;
                    draw type at: { 40#px, y + 4#px } color: text_color font: font("Helvetica", 25, #plain) perspective:false;
                    y <- y + 25#px;
                }
                 y <- y + 30 #px;     
                draw "People Type" at: { 40#px, y } color: text_color font: font("Helvetica", 25, #bold) perspective:false;
                y <- y + 30 #px;
                loop type over: color_per_type.keys
                {
                    draw square(10#px) at: { 20#px, y } color: color_per_type[type] border: #white;
                    draw type at: { 40#px, y + 4#px } color: text_color font: font("Helvetica", 25, #plain) perspective:false;
                    y <- y + 25#px;
                }
				y <- y + 30 #px;
                draw "Mobility Mode" at: { 40#px, 600#px } color: text_color font: font("Roboto", 25, #bold) perspective:false;
                map<string,rgb> list_of_existing_mobility <- map<string,rgb>(["Walking"::#green,"Bike"::#yellow,"Car"::#red,"Bus"::#blue]);
                y <- y + 30 #px;
                
                loop i from: 0 to: length(list_of_existing_mobility) -1 {    
                  // draw circle(10#px) at: { 20#px, 600#px + (i+1)*25#px } color: list_of_existing_mobility.values[i]  border: #white;
                   draw list_of_existing_mobility.keys[i] at: { 40#px, 610#px + (i+1)*20#px } color: list_of_existing_mobility.values[i] font: font("Helvetica", 18, #plain) perspective:false; 			
		        }     
            }
            
            chart "Cumulative Trip"background:#black  type: pie size: {0.6,0.6} position: {world.shape.width*1.1,world.shape.height*0 - 300} color: #white axes: #yellow title_font: 'Menlo' title_font_size: 30.0 
			tick_font: 'Menlo' tick_font_size: 20 tick_font_style: 'bold' label_font: 'Menlo' label_font_size: 64 label_font_style: 'bold' x_label: 'Nice Xlabel' y_label:'Nice Ylabel'
			{
				loop i from: 0 to: length(transport_type_cumulative_usage.keys)-1	{
				  data transport_type_cumulative_usage.keys[i] value: transport_type_cumulative_usage.values[i] color:color_per_mobility[transport_type_cumulative_usage.keys[i]];
				}
			}
			chart "People Distribution" background:#black  type: pie size: {0.6,0.6} position: {world.shape.width*1.1,world.shape.height*0.6} color: #white axes: #yellow title_font: 'Menlo' title_font_size: 30.0 
			tick_font: 'Menlo' tick_font_size: 20 tick_font_style: 'bold' label_font: 'Menlo' label_font_size: 64 label_font_style: 'bold' x_label: 'Nice Xlabel' y_label:'Nice Ylabel'
			{
				loop i from: 0 to: length(proportion_per_type.keys)-1	{
				  data proportion_per_type.keys[i] value: proportion_per_type.values[i] color:color_per_type[proportion_per_type.keys[i]];
				}
			}
		} 				
	}
}
