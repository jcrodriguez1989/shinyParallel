library('httpuv');

getPortsStatus <- function(host, ports, max.sessions) {
  # Reject ports in this range that are considered unsafe by Chrome
  # http://superuser.com/questions/188058/which-ports-are-considered-unsafe-on-chrome
  # https://github.com/rstudio/shiny/issues/1784
  if (is.null(ports))
    ports <- setdiff(3000:8000, c(3659, 4045, 6000, 6665:6669, 6697));

  if (is.vector(ports)) {
    ports <- data.frame(port=ports,
                        status=factor(rep('DK', length(ports)),
                                      # Dont Know, Not Working, Available, Full
                                      levels=c('DK', 'NW', 'Av', 'Full'))
    )
  }

  # if we have reached max sessions then return the same object
  if (sum(ports$status %in% c('Av', 'Full')) >= max.sessions)
    return(ports)

  # if there are no more ports to try, then lets try on previous not working
  if (sum(ports$status == 'DK') == 0)
    ports$status[ports$status == 'NW'] <- 'DK';

  # test all ports until any is available
  for (i in which(ports$status == 'DK')) {
    # Test port to see if we can use it
    tmp <- try(httpuv::startServer(host, ports$port[[i]], list()), silent=TRUE);
    ports$status[[i]] <- 'NW';
    if (!inherits(tmp, 'try-error')) {
      httpuv::stopServer(tmp);
      ports$status[[i]] <- 'Av';
    }
    if (sum(ports$status %in% c('Av', 'Full')) == max.sessions)
      break;
  }

  return(ports);
}

assignProcess <- function(portsStatus, processes,
                          appDir, max.sessions, users.per.session, host,
                          workerId, display.mode, test.mode) {
  poStatus <- isolate(portsStatus());
  prStatus <- isolate(processes());

  # if there is no available port then try to find any
  if (sum(poStatus$status == 'Av') == 0)
    poStatus <- getPortsStatus(host, poStatus, max.sessions);

  # could not find any port to use, or server is full
  if (!any(poStatus$status == 'Av'))
    return(NA);

  avPortIdxs <- which(poStatus$status == 'Av');
  # First try to get port with no process running
  avPortIdx <- avPortIdxs[!poStatus$port[avPortIdxs] %in% names(prStatus)];

  if (length(avPortIdx) > 0) {
    # Use any, as we have some ports with no process
    avPortIdx <- avPortIdx[[1]];
  } else {
    # Get the port of the process with less connected users
    avPortIdx <- which(poStatus$port == names(which.min(lapply(
      prStatus[ as.character(poStatus$port[avPortIdxs]) ],
      function(x) x$users
    ))))
  }

  avPort <- poStatus$port[[avPortIdx]];
  avPortStr <- as.character(avPort);

  if (!avPortStr %in% names(prStatus)) {
    # if the available port does not have a process then create one
    shinyProc <- createProcess(appDir, avPort, host, workerId, display.mode,
                               test.mode);
    if (length(shinyProc) == 1 && is.na(shinyProc))
      return(NA);
    prStatus[[avPortStr]] <- shinyProc;
  }

  prStatus[[avPortStr]]$users <- prStatus[[avPortStr]]$users+1;
  if (prStatus[[avPortStr]]$users >= users.per.session) {
    poStatus$status[avPortIdx] <- 'Full';
  }

  portsStatus(poStatus);
  processes(prStatus);
  return(prStatus[[avPortStr]]);
}

createProcess <- function(appDir, port, host, workerId, display.mode,
                          test.mode) {
  shinyProc <- r_bg(
    function(appDir, port, host, workerId, display.mode, test.mode)
      shiny::runApp(appDir=appDir, port=port, host=host, workerId=workerId,
                    display.mode=display.mode, test.mode=test.mode),
    args=list(appDir=appDir, port=port, host=host, workerId=workerId,
              display.mode=display.mode, test.mode=test.mode)
  );
  sessUrl <- NA;
  for (i in seq_len(10)) { # give n retries
    errLines <- shinyProc$read_error_lines();
    errLines <- errLines[grep("Listening on ", errLines)];
    if (length(errLines) > 0) {
      sessUrl <- sub('.*http', 'http', errLines);
      break;
    }
    Sys.sleep(1); # give 1 second to start server
  }
  if (is.na(sessUrl)) {
    # if after n retries it did not work then give message
    print(shinyProc$read_output_lines());
    return(NA);
  }

  return(c(process=shinyProc, url=sessUrl, port=port, users=0));
}

deassignProcess <- function(portsStatus, processes, proc, users.per.session=0) {
  poStatus <- isolate(portsStatus());
  prStatus <- isolate(processes());

  # get updated proc
  proc <- prStatus[[as.character(proc$port)]];
  proc$users <- proc$users-1;
  # update processes status
  prStatus[[as.character(proc$port)]] <- proc;

  if (proc$users == 0) {
    # if no users then kill process
    proc$process$kill();
    prStatus <- prStatus[names(prStatus) != proc$port];
    poStatus$status[poStatus$port == proc$port] <- 'Av';
  } else if (proc$users < users.per.session) {
    # put Av if it is not full
    poStatus$status[poStatus$port == proc$port] <- 'Av';
  }

  portsStatus(poStatus);
  processes(prStatus);

  return(NA);
}
