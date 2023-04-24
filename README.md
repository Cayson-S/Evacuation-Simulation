# BEV Disaster Evacuation Simulation

## Background
This code simulates vehicle evacuations from natural disasters. The focus of this project is on Battery Electric Vehicles (BEVs) and charging infrastructure 
along evacuation routes. This built for my honors thesis.

## Usage Instructions
<p>&emsp;The simulation was written in GAML which is available through GAMA platform. GAML is similar to the Java programming language. 
GAMA is available to download from https://gama-platform.org/. The code should be run through the GAMA platform. </p>

<p>&emsp;Once GAMA is downloaded, create a new project. Add the data from the /includes directory into the project directory of the same name. The names of the 
files in the code (or after starting the simulation) will need to be changed to the desired colums. Only .shp files can be used for the simulation. The code 
works (consider testing it using the test files), so if new files are being used and the simulation doesn't work it is likely an issue with the shape files used. 
GAMA is very particular about the graph structure, so ensure that the graph is structured exactly as the demo files. Should you need additional support, consider 
reading through my thesis, which breaks down the simulation in detail.</p>

## Project Organization

    ├── includes                            <- The data used for the simulation.
    │   ├── mobile_nodes.shp
    │   ├── mobile_roads.shp
    |   ├── test_node.shp
    │   └── test_road.shp
    ├── models                              <- The GAML simulation files.
    |   └── ev_evacuations.gaml
    ├── README.md                           <- The README for developers using this project.
    └── SEIPEL_Cayson_S23ThesisFinal.pdf    <- The README for developers using this project.
