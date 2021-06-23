source("settings.R")

sP_appLinks_dir <- paste0("../shinyParallel_appLinks/", appName, "/")

getPortsStatus <- function(max.sessions) {
  ports <- dir(sP_appLinks_dir)[seq_len(max.sessions)]
  ports <- data.frame(
    port = ports,
    status = factor(rep("Av", length(ports)),
      # Available, Full
      levels = c("Av", "Full")
    )
  )
  return(ports)
}

assignProcess <- function(portsStatus, processes, users.per.session, cData) {
  poStatus <- isolate(portsStatus())
  prStatus <- isolate(processes())

  # server is full
  if (!any(poStatus$status == "Av")) {
    return(NA)
  }

  avPortIdxs <- which(poStatus$status == "Av")
  # First try to get port with no process running
  avPortIdx <- avPortIdxs[!poStatus$port[avPortIdxs] %in% names(prStatus)]

  if (length(avPortIdx) > 0) {
    # Use any, as we have some ports with no process
    avPortIdx <- avPortIdx[[1]]
  } else {
    # Get the port of the process with less connected users
    avPortIdx <- which(poStatus$port == names(which.min(lapply(
      prStatus[as.character(poStatus$port[avPortIdxs])],
      function(x) x$users
    ))))
  }

  avPort <- poStatus$port[[avPortIdx]]
  avPortStr <- as.character(avPort)

  if (!avPortStr %in% names(prStatus)) {
    sessUrl <- urlFromClientData(cData)

    # if the available port does not have a process then create one
    shinyProc <- createProcess(avPortStr, sessUrl)
    prStatus[[avPortStr]] <- shinyProc
  }

  prStatus[[avPortStr]]$users <- prStatus[[avPortStr]]$users + 1
  if (prStatus[[avPortStr]]$users >= users.per.session) {
    poStatus$status[avPortIdx] <- "Full"
  }

  portsStatus(poStatus)
  processes(prStatus)
  return(prStatus[[avPortStr]])
}

urlFromClientData <- function(cData) {
  res <- isolate(paste0(cData$url_protocol, "//", cData$url_hostname))
  port <- isolate(cData$url_port)
  if (port != "") {
    res <- paste0(res, ":", port)
  }

  return(res)
}

createProcess <- function(port, sessUrl) {
  fullUrl <- paste0(sessUrl, "/", sP_appLinks_dir, port)
  return(list(url = fullUrl, port = port, users = 0))
}

deassignProcess <- function(portsStatus, processes, proc, users.per.session = 0) {
  poStatus <- isolate(portsStatus())
  prStatus <- isolate(processes())

  # get updated proc
  proc <- prStatus[[as.character(proc$port)]]
  proc$users <- proc$users - 1
  # update processes status
  prStatus[[as.character(proc$port)]] <- proc

  if (proc$users == 0) {
    # if no users then kill process
    prStatus <- prStatus[names(prStatus) != proc$port]
  }
  # put Av if it is not full
  poStatus$status[poStatus$port == proc$port] <- "Av"

  portsStatus(poStatus)
  processes(prStatus)

  return(NA)
}
