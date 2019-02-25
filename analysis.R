library(zoo)

signals = read.csv("/Users/sreeharirammohan/Desktop/Sit-to-stand test/all_signals.csv")[-1,] # first observation seems to have a lot of NAs
normalized = scale(signals,center = TRUE,scale = TRUE) # normalize signals before combining them
combined = na.approx(rowMeans(normalized,na.rm = TRUE)) # combine signals
combined = runmed(combined, 3) # Use running median to get rid of outliers 
combined = kernapply(as.vector(combined), kernel("daniell", 5)) # further smoothing
plot(combined,t='l',ylab = "value", xlab="time") # plot the smoothed signal
title("Smoothed normalized combined signal")

pgram = spec.pgram (combined, na.action = na.omit, spans = c(3,3)) # periodogram with smoothing
period = 1/pgram$freq[which.max(pgram$spec)] # read the period from periodogram
ceiling(nrow(signals) / period) # get the number of squats
