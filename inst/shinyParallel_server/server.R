library("shiny")

# get indicated ports (or default), status
# a port will refer to an appLink number
portsStatus <- reactiveVal(getPortsStatus(max.sessions))

# list of processes (names correspond to appLink number)
processes <- reactiveVal(list())

shinyServer(function(input, output, session) {
  # check if wants to see users dashboard, or the app
  isAdmin <- isolate(parseQueryString(session$clientData$url_search))

  if ("admin" %in% names(isAdmin)) {
    output$stattable <- renderDataTable({
      stattable <- do.call(rbind, lapply(processes(), function(actProc) {
        c(
          Session = actProc$port,
          Users = actProc$users
        )
      }))

      # if there are no processes, also return some info
      if (is.null(stattable)) {
        stattable <- data.frame(Session = "NULL", Users = "0")
      }
      return(stattable)
    })
  } else {
    cData <- session$clientData
    proc <- assignProcess(portsStatus, processes, users.per.session, cData)

    # could not assign process
    if (length(proc) == 1 && is.na(proc)) {
      showModal(modalDialog("Retrying... If waiting too long, refresh page.",
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
