library("shiny")
library("callr")

# loading shinyParallel::runApp args (were saved on HD)
# attaching 'appDir', 'ports', 'max.sessions', 'users.per.session', 'host',
# 'workerId', 'display.mode', 'test.mode'
list2env(get(load(file = paste0(tempdir(), "/env.RData"))), environment())

# get indicated ports (or default), status
portsStatus <- reactiveVal(getPortsStatus(host, ports, max.sessions))

# list of processes (names correspond to ports)
processes <- reactiveVal(list())

shinyServer(function(input, output, session) {
  # check if wants to see users dashboard, or the app
  isAdmin <- isolate(parseQueryString(session$clientData$url_search))

  if ("admin" %in% names(isAdmin)) {
    output$stattable <- renderDataTable({
      stattable <- do.call(rbind, lapply(processes(), function(actProc) {
        c(
          PID = actProc$process$get_pid(),
          Port = actProc$port,
          Users = actProc$users
        )
      }))

      # if there are no processes, also return some info
      if (is.null(stattable)) {
        stattable <- data.frame(
          PID = "NULL", Port = "NULL",
          Users = "0"
        )
      }
      return(stattable)
    })
  } else {
    proc <- assignProcess(
      portsStatus, processes,
      appDir, max.sessions, users.per.session, host, workerId,
      display.mode, test.mode
    )

    # could not assign process
    if (length(proc) == 1 && is.na(proc)) {
      showModal(modalDialog("Retrying...",
        title = "Server is full.",
        footer = NULL
      ))
      output$htmlSess <- renderUI(
        shiny::tags$meta("http-equiv" = "refresh", content = 5)
      )
    } else {
      output$htmlSess <- renderUI(
        shiny::tags$iframe(
          src = proc$url,
          style = paste("top: 0", "left: 0", "width: 100%", "height: 100%",
            "position: absolute", "border: none",
            sep = "; "
          )
        )
      )

      onSessionEnded(function() {
        deassignProcess(portsStatus, processes, proc, users.per.session)
      })
    }
  }
})
