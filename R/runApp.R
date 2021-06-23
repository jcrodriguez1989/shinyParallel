#' Run Shiny Application
#'
#' Runs a Shiny application. This function normally does not return; interrupt R
#' to stop the application (usually by pressing Ctrl+C or Esc).
#' It runs \code{max.sessions} processes, each with a shiny::runApp working.
#' So, comunication between users is limited, if this needs to be done, then
#' save and load data on hard disk (or use RStudio server pro).
#'
#' The host parameter was introduced in Shiny 0.9.0. Its default value of
#' \code{"127.0.0.1"} means that, contrary to previous versions of Shiny, only
#' the current machine can access locally hosted Shiny apps. To allow other
#' clients to connect, use the value \code{"0.0.0.0"} instead (which was the
#' value that was hard-coded into Shiny in 0.8.0 and earlier).
#'
#' @param appDir The application to run. Should be one of the following:
#'   \itemize{
#'   \item A directory containing \code{server.R}, plus, either \code{ui.R} or
#'    a \code{www} directory that contains the file \code{index.html}.
#'   \item A directory containing \code{app.R}.
#'   \item An \code{.R} file containing a Shiny application, ending with an
#'    expression that produces a Shiny app object.
#'   \item A list with \code{ui} and \code{server} components.
#'   \item A Shiny app object created by \code{\link{shinyApp}}.
#'   }
#' @param ports The TCP ports that the application should listen on. First port
#'   will be used for shinyParallel server, and the remaining for each session.
#'   If the \code{ports} are not specified, and the \code{shiny.ports} option is
#'   set (with \code{options(shiny.ports = c(XX,..,ZZ)}), then those ports will
#'   be used. Otherwise, use random ports.
#' @param max.sessions Number of sessions to use. Defaults to the
#'   \code{shinyParallel.max.sessions} option, is set, or \code{2L} if not.
#' @param users.per.session Maximum number of admited users per each session.
#'   Defaults to the
#'   \code{shinyParallel.users.per.session} option, is set, or \code{Inf} if
#'   not.
#' @param launch.browser If true, the system's default web browser will be
#'   launched automatically after the app is started. Defaults to true in
#'   interactive sessions only. This value of this parameter can also be a
#'   function to call with the application's URL.
#' @param host The IPv4 address that the application should listen on. Defaults
#'   to the \code{shiny.host} option, if set, or \code{"127.0.0.1"} if not. See
#'   Details.
#' @param workerId Can generally be ignored. Exists to help some editions of
#'   Shiny Server Pro route requests to the correct process.
#' @param quiet Should Shiny status messages be shown? Defaults to FALSE.
#' @param display.mode The mode in which to display the application. If set to
#'   the value \code{"showcase"}, shows application code and metadata from a
#'   \code{DESCRIPTION} file in the application directory alongside the
#'   application. If set to \code{"normal"}, displays the application normally.
#'   Defaults to \code{"auto"}, which displays the application in the mode given
#'   in its \code{DESCRIPTION} file, if any.
#' @param test.mode Should the application be launched in test mode? This is
#'   only used for recording or running automated tests. Defaults to the
#'   \code{shiny.testmode} option, or FALSE if the option is not set.
#'
#' @examples
#' \dontrun{
#' # Start app in the current working directory
#' shinyParallel::runApp()
#'
#' # Start app in a subdirectory called myapp
#' shinyParallel::runApp("myapp")
#' }
#'
#' ## Only run this example in interactive R sessions
#' if (interactive()) {
#'   options(device.ask.default = FALSE)
#'
#'   # Apps can be run without a server.r and ui.r file
#'   shinyParallel::runApp(list(
#'     ui = bootstrapPage(
#'       numericInput("n", "Number of obs", 100),
#'       plotOutput("plot")
#'     ),
#'     server = function(input, output) {
#'       output$plot <- renderPlot({
#'         hist(runif(input$n))
#'       })
#'     }
#'   ))
#'
#'
#'   # Another example
#'   shinyParallel::runApp(list(
#'     ui = fluidPage(column(3, wellPanel(
#'       numericInput("n", label = "Is it prime?", value = 7, min = 1),
#'       actionButton("check", "Check!")
#'     ))),
#'     server = function(input, output) {
#'       # Check if n is prime.
#'       # Not R optimized.
#'       # No Fermat, Miller-Rabin, Solovay-Strassen, Frobenius, etc tests.
#'       # Check if n is divisable up to n-1 !!
#'       isPrime <- function(n) {
#'         res <- TRUE
#'         i <- 2
#'         while (i < n) {
#'           res <- res && n %% i != 0
#'           i <- i + 1
#'         }
#'         return(res)
#'       }
#'       observeEvent(input$check, {
#'         showModal(modalDialog(
#'           ifelse(isPrime(isolate(input$n)),
#'             "Yes it is!", "Nope, not a prime."
#'           ),
#'           footer = NULL,
#'           easyClose = TRUE
#'         ))
#'       })
#'     }
#'   ))
#'
#'
#'   # Running a Shiny app object
#'   app <- shinyApp(
#'     ui = bootstrapPage(
#'       numericInput("n", "Number of obs", 100),
#'       plotOutput("plot")
#'     ),
#'     server = function(input, output) {
#'       output$plot <- renderPlot({
#'         hist(runif(input$n))
#'       })
#'     }
#'   )
#'   shinyParallel::runApp(app)
#' }
#' @export
#' @importFrom callr r_bg
#' @importFrom shiny runApp
runApp <- function(appDir = getwd(),
                   ports = getOption("shiny.ports"),
                   max.sessions = getOption("shinyParallel.max.sessions", 20L),
                   users.per.session =
                     getOption("shinyParallel.users.per.session", Inf),
                   launch.browser = getOption(
                     "shiny.launch.browser",
                     interactive()
                   ),
                   host = getOption("shiny.host", "127.0.0.1"),
                   workerId = "",
                   quiet = FALSE,
                   display.mode = c("auto", "normal", "showcase"),
                   test.mode = getOption("shiny.testmode", FALSE)) {
  # args distribution:
  # appDir          (shiny)
  # ports           (both) must be a vector of ports, one per session
  # launch.browser  (shinyParallel) function to open main url
  # host            (both)
  # workerId        (both)
  # quiet           (shinyParallel)
  # display.mode    (shiny)
  # test.mode       (shiny)

  if (!(max.sessions > 0 && users.per.session > 0)) {
    stop("max.sessions and users.per.session must be greater than 0.")
  }

  # we need one port for the server, and n ports for n sessions
  if (length(ports) > 0 && length(ports) < (max.sessions + 1)) {
    stop("Must give at least max.sessions + 1 ports.")
  }

  # args to be used by each shiny created session
  env2save <- as.list(environment())[
    c(
      "appDir", "ports", "max.sessions", "users.per.session", "host",
      "workerId", "display.mode", "test.mode"
    )
  ]

  # try to load the shinyParallel server app
  serverAppDir <- system.file("shiny", "shinyParallelServer",
    package = "shinyParallel"
  )
  if (serverAppDir == "") {
    stop("Could not find GUI directory. Try re-installing `shinyParallel`.")
  }

  # the shiny app will run with the same tempdir, so in this way we can pass
  # the environment
  save(env2save, file = paste0(tempdir(), "/env.RData"))
  shiny::runApp(
    appDir = serverAppDir, port = ports[[1]],
    launch.browser = launch.browser, host = host, workerId = workerId,
    quiet = quiet
  )
}
