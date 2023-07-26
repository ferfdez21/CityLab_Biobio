model configuration

global {
	//PARAMETERS
	bool updatePollution <-false parameter: "Pollution:" category: "Simulation";
	bool updateDensity <-false parameter: "Density:" category: "Simulation";
	bool weatherImpact <-true parameter: "Weather impact:" category: "Simulation";
		
	//ENVIRONMENT
	float step <- 1 #mn;
	date starting_date <-date([2023,7,11,6,0]);
	string case_study <- "costanera" ;
	int nb_people <- 1000;
	
    string cityGISFolder <- "./../includes/City/"+case_study;
	file<geometry> buildings_shapefile <- file<geometry>(cityGISFolder+"/Buildings.shp");
	file<geometry> external_cities_shapefile <- file<geometry>(cityGISFolder+"/Cities.shp");
	
	file<geometry> roads_shapefile <- file<geometry>(cityGISFolder+"/Roads.shp");
	geometry shape <- envelope(roads_shapefile);
	
	// MOBILITY DATA
	list<string> mobility_list <- ["walking", "bike","car","bus"];
	file activity_file <- file("./../includes/ActivityPerProfile.csv");
	file criteria_file <- file("./../includes/CriteriaFile.csv");
	file profile_file <- file("./../includes/Profiles.csv");
	file mode_file <- file("./../includes/Modes.csv");
	file weather_coeff <- file("./../includes/weather_coeff_per_month_south_hemisphere.csv");
	
	map<string,rgb> color_per_category <- [ "Restaurant"::rgb("#2B6A89"), "Night"::rgb("#1B2D36"),"GP"::rgb("#244251"), "Cultural"::rgb("#2A7EA6"), "Shopping"::rgb("#1D223A"), "HS"::rgb("#FFFC2F"), "Uni"::rgb("#807F30"), "O"::rgb("#545425"), "R"::rgb("#222222"), "Park"::rgb("#24461F")];	
	map<string,rgb> color_per_type <- [ "High School Student"::rgb("#FFFFB2"), "College student"::rgb("#FECC5C"),"Young professional"::rgb("#FD8D3C"),  "Mid-career workers"::rgb("#F03B20"), "Executives"::rgb("#BD0026"), "Home maker"::rgb("#0B5038"), "Retirees"::rgb("#8CAB13")];
	
}