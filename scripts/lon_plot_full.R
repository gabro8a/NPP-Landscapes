###################################################################################################################
# Analysis of Local Optima Networks (LONs) 
# Copyright (c) 2018 Gabriela Ochoa and Nadarajen Veerapen.
# Updated for Search Landscape Analysis Tutorial (June 2023)
# Case study: Number Partitioning Problem (NPP) fully enumerated LONs
# Associated Research Paper:
# Ochoa, Gabriela; Veerapen, Nadarajen; Daolio, Fabio; Tomassini, Marco. 
# Understanding Phase Transitions with LONs: Number Partitioning as a Case Study. 
# Evolutionary Computation in Combinatorial Optimization - EvoCOP 2017, pp. 233-248, 2017
# 
# Visualisation of the LON models: LON, MLON and CMLON 
# Input:  RData files with LON graph objects
# Output: Files with plots
###################################################################################################################

# Check if required packages are installed or not. Install if required
packages <- c("igraph", "rgl")
if (length(setdiff(packages, rownames(installed.packages()))) > 0) {
  install.packages(setdiff(packages, rownames(installed.packages())))  
}

# Load required packages
library(igraph)  # Network analysis and visualisation
library(rgl)     # 3D plots

rm(list = ls(all.names = TRUE))  # Remove all objectes from previous work


# Location of input and output  
infolder ="lons_full/" 
outfolder  <- "plots/"


# Functions
# ----------------------------------------------------------------------------------------
# Width of edges based on their weight
edgeWidth<-function(N, minw, maxw) {
   ewidth <- 1
   if (ecount(N) > 0) {
      ewidth <- (maxw * E(N)$weight)/max(E(N)$weight)
      ewidth = ifelse(ewidth > minw, ewidth, minw)
      ewidth = ifelse(ewidth < maxw, ewidth, maxw)
   }
   return (ewidth)
}

# ----------------------------------------------------------------------------------------
# Size of nodes based on their strength (weighted vertex degree)
nodeSizeStrength<-function(N, minsize, maxsize) {
   vsize <- maxsize
   if (ecount(N) > 0) {
      vsize =  5* graph.strength(N, mode="in")
      vsize =  ifelse(vsize > minsize, vsize, minsize)
      vsize =  ifelse(vsize < maxsize, vsize, maxsize)
   }
   return (vsize)
}

#----------------------------------------------------------------------------------------------------------------------------
# Plot Network in 2D. Either in the screen or as pdf file (if bpdf is True) 
# N:      Graph object
# tit:    String describing network, instance and type of LON
# ewidth: edge  width 
# asize:  arrow size for plots
# ecurv:  curvature of the edges (0 = non, 1 = max)
# mylay:  graph layout as a parameter
# bpdf:   boolean TRUE for generating a pdf
# fname: base name for plot file

plotNet <-function(N, tit, nsize, ewidth, asize, ecurv, mylay, bpdf, fname) {
   if (bpdf)  { # PDF for saving the 2D plot
      ofname <- paste0(outfolder, fname,"_", tit, '.pdf')
      pdf(ofname) 
      print(ofname)
   }
   vframecol <- ifelse(V(N)$fitness == best, "black", "gray50") # darker outline for global optima
   title <- paste(inst, tit,'Nodes:',vcount(N), 'Edges:',ecount(N))
   plot(N, layout = mylay, main = title, vertex.label = NA,
        vertex.size = nsize, vertex.frame.color = vframecol,
        edge.width = ewidth, edge.arrow.size = asize, edge.curved = ecurv)
   if (bpdf)
      dev.off()
}

#-----------------------------------------------------------------------------
# Plot network in 3D 
# N = Network 
# z: the z coordinate, normally fitness, but can have some scaling.
# ewidth: vector with edge widths
# asize: arrow size for plots
# mylayout: layout as a paremter so I can use the same for 2D and 3D

plotNet3D <-function(N, z, ewidth, asize, mylay) {
   mylayout3D <- cbind(mylay, z) # append z coordinate to the 2D layout
   rgl.open()      # open new window
   bg3d("white")   # set background to white 
   rglplot(N, layout = mylayout3D, edge.width = ewidth, edge.arrow.size = asize, vertex.label = NA)
}

#------------------------------------------------------------------------
# Creates a sub-network with nodes with and below a given fitness level 
# Keeping those nodes with a fitness below a percentile
# the higher the percentile the more nodes are kept.
# This function can be used to visualise large networks

pruneNodesFit <- function(N, perc) {
   # subset network nodes below fvalue fitness
   Top <- induced.subgraph(N, V(N)$fitness <= quantile(V(N)$fitness,perc))
   return (simplify(Top))
}

## Main -----------------------------------------------------------------------------------
# ---- read all files in the given input folder ----------------
dataf <- list.files(infolder)
# Process a single file at a time for simplicity

instance <- dataf[1]   # Select the first file in the folder

# Load data
fname <- paste0(infolder,instance)   
load(fname, verbose = F)

####  METRICS  ####
# Many metrics can be computed for networks, here we report some basic LON metrics 
# and funnel metrics (CMLON model) known to relate to search difficulty
print("Metrics of the LON model")
cat("Number of nodes (local optima):", vcount(LON), "\n")
cat("Number of global optima:", length(V(LON)[fitness == best]), "\n")
print("Number of Edges:")
cat("Total:", ecount(LON), "\n")
cat("Improving:", length(E(LON)[type == "improving"]), "\n")
cat("Neutral:", length(E(LON)[type == "equal"]), "\n")
cat("Worsening:", length(E(LON)[type == "worsening"]), "\n")

print("Funnel Metrics ")    
cat("Total number of sinks (funnels):", nsinks, "\n")
cat("Number of global sinks (funnels):", nglobals, "\n")
cat("Fitness of sinks:", sinks_fit, "\n")
cat("Normalised incoming strength of global sinks:", gstrength, "\n")
cat("Normalised incoming strength of sub-optimal (local) sinks:", lstrength, "\n")

#### VISUALISATION ####
# For large networks pruning might be required. Small networks can be visualised quickly.
# LON MODEL
inst <- substr(instance,1, nchar(instance)-6)  # instannce name without extension to save plots
lonlay <- layout.fruchterman.reingold(LON)  # you can select a different different layot.
ew <- edgeWidth(LON, 0.1, 2.5)      # set width of edges proportional weight
ns <- nodeSizeStrength(LON, 4, 15) # set size of nodes proportional to incoming strength
# Plot 2D LON with indicated parameter values. Both screen plot, and PDF file are produced
plotNet(N = LON,  tit = "lon", nsize = ns, ewidth = ew, asize = 0.1, ecurv = 0.4, mylay = lonlay, bpdf = F, fname = inst)
plotNet(N = LON,  tit = "lon", nsize = ns, ewidth = ew, asize = 0.3, ecurv = 0.4, mylay = lonlay, bpdf = T, fname = inst)
# Plot 3D LON with indicated parameter values. Use same layout and edge width
zcoord <- log(V(LON)$fitness + 1)   # Use log to accentuate differences in fitness
plotNet3D(N = LON, z = zcoord, ewidth = ew, asize = 1, mylay = lonlay)
# Demo of animating a 3D image using LON Model as an example. Rotation applies to current active window.
play3d(spin3d(axis = c(1, 0, 0), rpm = 10), duration = 4) # rotation x axis to "vertical" position
play3d(spin3d(axis = c(0, 0, 1), rpm = 8), duration = 8)  # spin z axis

# MLON MODEL
mlonlay <- layout_nicely(MLON)
ew <- edgeWidth(MLON, 0.3, 2)
ns <- nodeSizeStrength(MLON, 5, 18)  # set size of nodes proportional to incoming strength
# Plot 2D LON with indicated parameter values in the Screen and as PDF file
plotNet(N = MLON, tit = "mlon", nsize = ns, ewidth = ew, asize = 0.1, ecurv = 0.4, mylay = mlonlay, bpdf = F, fname = inst)
plotNet(N = MLON, tit = "mlon", nsize = ns, ewidth = ew, asize = 0.3, ecurv = 0.4, mylay = mlonlay, bpdf = T, fname = inst)

# Plot 3D LON with indicated parameter values. Use same layout and edge width
zcoord <- log(V(MLON)$fitness + 1)   # Use log to accentuate differences in fitness
plotNet3D(N = MLON, z = zcoord, ewidth = ew, asize = 2, mylay = mlonlay) 

# CMLON MODEL
cmlonlay <- layout_nicely(CMLON)
ew <- edgeWidth(CMLON, 1, 4)
ns <- V(CMLON)$size + 1 # set size as orginal in the CMLON model (size of plateaus)
# Plot 2D LON with indicated parameter values
plotNet(N = CMLON, tit = "cmlon", nsize = ns, ewidth = ew, asize = 0.2, ecurv=0.4, mylay = cmlonlay, bpdf = F, fname = inst) 
plotNet(N = CMLON, tit = "cmlon", nsize = ns, ewidth = ew, asize = 0.4, ecurv=0.4, mylay = cmlonlay, bpdf = T, fname = inst)
# Plot 3D LON with indicated parameter values. Use same layouta and edge width
zcoord <-log(V(CMLON)$fitness + 1)   # Use log to accentuate differences in fitness
plotNet3D(N = CMLON, z = zcoord, ewidth = ew, asize = 2.5, mylay = cmlonlay)