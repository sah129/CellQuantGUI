
# Main Driver function.  
# datasetpath: path to dataset, see io.R for file/directory structure
# gui:  set to true when using the GUI.  See app.R.
# progress:  holds information for progress updates when using the GUI.
# interactive:  set to manually prune results in GUI
# factor:  brightness multiplicative factor for membrane channel
# gfp_chan:  frame of GFP channel
# cmac_chan:  frame of CMAC channel
# dic_chan:  frame of DIC channel
# alg: membrane detection algorithm
# cutoff:  cell size cutoff
# outpath:  path to write images and .csv files to
pipeline <- function(datasetpath, gui, progress, factor, gfp_chan, cmac_chan, dic_chan, alg, cutoff, outpath)
{
  cnum = list(
    cmac_channel = as.numeric(cmac_chan),
    gfp_channel = as.numeric(gfp_chan),
    dic_channel = as.numeric(dic_chan))
  
  fact <- switch(factor,
                 "1" = 1,
                 "2" = 2,
                 "3" = 4,
                 "4" = 8,
                 "5" = 16)
  
  chan <- cnum$gfp_channel
  if(alg == "DIC")
    chan <- cnum$dic_channel
  unsuccessful = list()
  imageset <- read_in_imageset_files(datasetpath)
  p_inc <- 1/(nrow(imageset)*5)
  results = list()
  for( row in 1:nrow(imageset))
  {
    out <- tryCatch(
    {
      
      progress$inc(p_inc, message = paste0(imageset[row,"filename"], " (", row, "/",nrow(imageset),")" ))
      channels <- read_in_channels(imageset[row,], datasetpath, cnum)
      img_gray <- convert_to_grayscale(channels)
      
      progress$inc(p_inc, detail = "Detecting cell membranes")
      membranes <- detect_membranes(img_gray, channels, fact, img_gray[,,chan], as.numeric(cutoff), cnum)
      
      progress$inc(p_inc, detail = "Detecting vacuoles")
      vacuoles <- find_vacuoles(membranes, img_gray, channels, cnum)
      
      progress$inc(p_inc, detail = "Filtering cells")
      res <- exclude_and_bind(membranes, vacuoles, as.numeric(cutoff))
    
      progress$inc(p_inc, detail = "Finishing quant")
      final<-tidy_up(membranes,vacuoles,res)
      tiff(filename = paste0(outpath,  "/", imageset[row, "filename"], "_image.tiff"))
      get_display_img(df = final$df,
                    membranes = final$membranes, 
                    col_membranes = 'white', 
                    vacuoles = final$vacuoles, 
                    col_vacuoles ='blue', 
                    removed = membranes$removed,
                    closed_vacuoles = TRUE, 
                    img = channels$gfp, 
                    showRemoved = FALSE, 
                    showMemLabels = TRUE, 
                    showVacLabels = FALSE)
    dev.off()
    
    write.csv(final$df, paste0(outpath, "/", imageset[row, "filename"], '_quant.csv'), row.names=FALSE)
    results[[row]] <- list(df = final$df, filename = imageset[row, "filename"])
    },
    error = function(cond)
    {
      message(paste0("Error analyzing ", imageset[row,"filename"]))
      msg<- cond
      message(paste0("Error message: ", cond))
      results[[row]] <- NULL
      unsuccessful <<- c(unsuccessful, imageset[[row,"filename"]])
    }
    )
  }
  message("End of main")

  message("Writing Unquantified Images File")
  fileConn<-file(paste0(outpath, "/Unquantified Images.txt"))
  if(length(unsuccessful) > 0)
    writeLines(unlist(unsuccessful), fileConn)
  else
    writeLines("No unquantified images.", fileConn)
  close(fileConn)
  
  
  
  settings <- c(paste0(alg, " Detection Algorithm"), paste0("Brightness Setting: ", factor), paste0("Brightness Factor: ", fact), paste0("Cell Area Cutoff: ", cutoff))
  message("Writing Settings File")
  fileConn<-file(paste0(outpath, "/Settings.txt"))
  writeLines(settings, fileConn)
  close(fileConn)
  
  

    return(results)
}


