#' Installs a multi-session Shiny app in a server
#'
#' Installs a Shiny app in a Shiny server, with the multi-session feature
#' enabled.
#' It will run in \code{max.sessions}, each with the Shiny app working.
#' So, comunication between users is limited, if this needs to be done, then
#' save and load data on hard disk (or use RStudio server pro).
#'
#' @param appDir The application to run. Should be one of the following:
#'   \itemize{
#'   \item A directory containing \code{server.R}, plus, either \code{ui.R} or
#'    a \code{www} directory that contains the file \code{index.html}.
#'   \item A directory containing \code{app.R}.
#'   }
#' @param appName Name of the app (path to access it on the server).
#' @param max.sessions Number of sessions to use. Defaults to the
#'   \code{shinyParallel.max.sessions} option, is set, or \code{2L} if not.
#' @param users.per.session Maximum number of admited users per each session.
#'   Defaults to the
#'   \code{shinyParallel.users.per.session} option, is set, or \code{Inf} if
#'   not.
#' @param shinyServerPath Path where shiny-server apps are installed by default.
#'
#' @examples
#' \dontrun{
#' # If we have a Shiny app at '~/myShinyApp', i.e., we can test our app by:
#' # shinyParallel::runApp('~/myShinyApp');
#'
#' # then we can install the app by typing
#' shinyParallel::installShinyParallel("~/myShinyApp")
#' }
#' @export
#' @importFrom R.utils createLink
installShinyParallel <- function(appDir = getwd(),
                                 appName = basename(appDir),
                                 max.sessions = getOption("shinyParallel.max.sessions", 20L),
                                 users.per.session =
                                   getOption("shinyParallel.users.per.session", Inf),
                                 shinyServerPath = "/srv/shiny-server/") {
  if (!(max.sessions > 0 && users.per.session > 0)) {
    stop("max.sessions and users.per.session must be greater than 0.")
  }

  if (file.access(shinyServerPath, mode = 2) != 0) {
    stop(paste0(
      "Current user cant write to ", shinyServerPath,
      ' path. Maybe run it as root: "sudo R"'
    ))
  }

  if (!file.exists(shinyServerPath)) {
    stop(paste0(
      "Is shiny server installed? Can not find server path: ",
      shinyServerPath
    ))
  }

  if (appName == "") {
    stop("Please provide appName.")
  }

  appDir <- normalizePath(appDir)

  ## copy shinyServer files
  print("Copying shinyParallel server files.")

  # try to find shinyParallel server files
  serverFiles <- system.file("shinyParallel_server", package = "shinyParallel")
  if (serverFiles == "") {
    stop("Error. Try re-installing `shinyParallel`.")
  }

  toPath <- paste0(shinyServerPath, appName)

  dir.create(toPath, showWarnings = FALSE)
  invisible(lapply(dir(serverFiles, full.names = TRUE), function(x) file.copy(x, toPath)))

  cat(paste0(
    "users.per.session <- ", users.per.session, ";\n",
    "max.sessions <- ", max.sessions, ";\n",
    "appName <- '", appName, "';\n"
  ), file = paste0(toPath, "/settings.R"))

  ## copy app files
  print("Copying app files.")
  appLinksPath <- paste0(shinyServerPath, "shinyParallel_appLinks")
  dir.create(appLinksPath, showWarnings = FALSE)
  actAppLinksPath <- paste0(appLinksPath, "/", appName)
  dir.create(actAppLinksPath, showWarnings = FALSE)
  oldWd <- getwd() # backup WD
  setwd(actAppLinksPath)
  invisible(lapply(seq_len(max.sessions), function(i) {
    createLink(paste0(appName, "_", i), appDir, overwrite = TRUE)
  }))
  # setwd(oldWd); # restore WD
  return()
}
