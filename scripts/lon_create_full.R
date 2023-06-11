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
# LON construction. Including Monotonic Edges and Compressed Plateaus
# From fully enumerated NPP landscapes
# Input:  zip file containing Nodes and Edges as text files (fully enumerated LONs)
# Output: RData files with LON graph objects

# Check if required packages are installed or not. Install if required
packages <- c("igraph")
if (length(setdiff(packages, rownames(installed.packages()))) > 0) {
  install.packages(setdiff(packages, rownames(installed.packages())))  
}

# Load required packages
library(igraph)  # Network analysis and visualisation

rm(list = ls(all.names = TRUE))  # Remove all objectes from previous work


# Location of input and output  
infolder ="data/lon_full/" 
outfolder  <- "lons_full/"

# Default colours for node and edges 
# LON  model has 3 types of perturbation edges: (i)mprovement, (e)qual, (w)orsening
pi_ecol <-  "gray50" # Opaque dark gray improvement edges
# alpha is for transparency: (as an opacity, 0 means fully transparent,  max (255) opaque)
pe_ecol <- rgb(0, 0, 250, max = 255, alpha = 150)  # transp. blue for neutral edges
pw_ecol <- rgb(0, 250, 0, max = 255, alpha = 150)  # transp. green for worsening edges
# Node coloring for global and local sinks and other optima
colgs <- "#d7191c"       # Color of global sinks (red)
colls <- "#2b83ba"       # Color of local (i.e non-global) sinks (blue)
collo <- "gray65"        # Color for all other optima (gray)


create_lon <- function(instance) {
   ## Read data from zip file and construct the network models
   print(instance)
   zipname <- paste0(infolder,instance)
   bname <- substr(instance,1, nchar(instance)-4)
   nodename <- paste0(bname, ".nodes")
   edgename <- paste0(bname, ".edges")
   edges <- read.table(unz(zipname, edgename), header = F, colClasses = c("integer", "integer", "numeric"))
   colnames(edges) <- c("start", "end", "weight")
   nodes <- read.table(unz(zipname, nodename), header = F, colClasses = c("integer", "integer", "numeric"))
   colnames(nodes) <- c("id", "fitness", "basin.size")
   
   ## Create LON from dataset of nodes and edges
   LON <- graph_from_data_frame(d = edges, directed = T, vertices = nodes)
   LON <- simplify(LON, remove.multiple=FALSE, remove.loops=TRUE)  # Remove self loops
   best <- min(nodes$fitness)   # since we are minimising, and is full enumeration best is the minimum fitness
   cat("Global Optimum Value:", best,"\n")
   
   ## Networks. 3 Models
   # LON:  Containing all local optima and edges
   # MLON: LON with keeping only monotonic sequences (non-deteriorating edges)
   # CMLON: MLON with compressed meta-plateaus used to identify sinks
   
   # get the list of edges and fitness values in order to filter 
   el <- as_edgelist(LON)
   fits <- V(LON)$fitness
   names <- V(LON)$name
   # get the fitness values at each endpoint of an edge
   f1 <- fits[match(el[,1], names)]
   f2 <- fits[match(el[,2], names)]
   # Assuming a minimisation problem
   E(LON)[which(f2<f1)]$type <- "improving"   # improving edges
   E(LON)[which(f2>f1)]$type <- "worsening"   # worsening edges
   E(LON)[which(f2==f1)]$type <- "equal"      # equal fitness (neutral) edges
   # Coloring edges according to type
   E(LON)$color[E(LON)$type == "improving"] <- pi_ecol
   E(LON)$color[E(LON)$type == "equal"] <- pe_ecol
   E(LON)$color[E(LON)$type == "worsening"] <- pw_ecol
   # Coloring nodes
   V(LON)$color <- collo  # default local optima 
   V(LON)$color[which(degree(LON,mode="out") == 0)] <- colls # local sinks
   V(LON)$color[V(LON)$fitness == best] <- colgs   # global sinks
   # Default size of nodes in LON model is the basin size (fully enumerated)
   V(LON)$size <- V(LON)$basin.size
   
   ## Monotonic LON keeps only the edges that correspond to non-deteriorating moves
   ## MLON inherits all the other properties from LON (nodes colours and size and edges colour)
   MLON <- subgraph.edges(LON, which(E(LON)$type != "worsening"), delete.vertices = F) # Vertices are kept to maintain ID names
   MLON <- simplify(MLON, remove.multiple=FALSE, remove.loops=TRUE)  # Remove self-loops
   
   ## Constructing the CMLON. Contract meta-neutral-networks (pleteaus) to single nodes
   mlon_sise <- V(MLON)$size  # Keep original size as it will be modified to construct the CMLON
   V(MLON)$size<-1            # required to construct the CMLON, size will be agregaterd
   # check connectivity within meta-plateaus, only merge minima that are connected
   gnn <- subgraph.edges(LON, which(f2==f1), delete.vertices=FALSE)
   # get the components that are connected at the same fitness level
   nn_memb <- components(gnn, mode="weak")$membership
   # contract neutral connected components saving cardinality into node size
   CMLON <- contract.vertices(MLON, mapping = nn_memb, 
                              vertex.attr.comb = list(fitness = "first", size = "sum", "ignore"))
   # The size of nodes is the aggregation/sum of nodes in the plateau
   # remove self-loops and contract multiple edges 
   CMLON <- simplify(CMLON, edge.attr.comb = list(weight="sum"))
   # identify sinks i.e nodes without outgoing edges 
   sinks_ids <-which(degree(CMLON, mode = "out")==0)
   sinks_fit <- vertex_attr(CMLON, "fitness")[sinks_ids]
   global_opt <- V(CMLON)[fitness == best]
   
   ## Add colour to CMLON nodes and edges. 
   V(CMLON)$color <- collo  # default colour for local optima  
   V(CMLON)$color[V(CMLON) %in% sinks_ids] <- colls   # Colour of suboptimal sinks
   V(CMLON)$color[V(CMLON)$fitness == best] <- colgs  # Colour of global sinks
   E(CMLON)$color <- pi_ecol # edges are all improving in CMLON, so improving color used.
   # Restoure MLON size, as it was modified to construct CMLON
   V(MLON)$size <- mlon_sise 
   
   # Compute funnel metrics: number of local and global sinks  
   nsinks <- length(sinks_ids)     # Number of sinks 
   nglobals <- length(global_opt)  # Number of global sinks
   # More funnel metrics
   # Incoming strength of global optima sinks / normalised by the total incoming strength of sinks
   igs<-sinks_ids[sinks_fit==best]  # index of global sinks
   ils<-sinks_ids[sinks_fit>best]   # index of local sinks -- might be empty 
   sing <- sum(strength(graph = CMLON, vids = igs, mode = "in", loops = F), na.rm = T)  # global sinks
   sinl <- sum(strength(graph = CMLON, vids = ils, mode = "in", loops = F), na.rm = T)  # local sinks
   gstrength <- sing/(sing+sinl)   # normalised incoming strength of global sinks
   lstrength <- sinl/(sing+sinl)   # normalised incoming strength of local sinks
   # File name to save graph objects and other useful variables
   dfile = paste0(outfolder,bname,".RData")
   save(LON, MLON, CMLON, best, sinks_fit, nsinks, nglobals, gstrength, lstrength, file=dfile)
}


# ---- read all files in the given input folder ----------------
dataf <- list.files(infolder)

lapply(dataf, create_lon)