ShinyParallel
================

Run [Shiny](http://shiny.rstudio.com/) applications in a multi-session
mode.

Prevents that if a user executes a long computing task penalizing
others.

ShinyParallel manages incoming users and redistributes them between
multiple sessions created for your Shiny app. It provides two modes of
use:

-   From an R console: ShinyParallel reimplements the function
    `shiny::runApp(<params>)`. In this sense, the only thing to do to
    run an app in multi-session mode is to call it using
    `shinyParallel::runApp(<params>)`.
-   Installing ShinyParallel in a Shiny server (**may require root**):
    by the `shinyParallel::installShinyParallel(<params>)` function,
    ShinyParallel is installed in your Shiny server for any desired app.

**Note:** ShinyParallel should work on any operating system that
supports R, however it has been tested only under Linux (Ubuntu).

## Features

-   Run a Shiny app in multiple sessions (processes / physical cores).
-   Decide the maximum number of users per session.
-   It allows to visualize the number of users currently present in each
    session.

## Installation

ShinyParallel is currently only available as a GitHub package. To
install it run the following from an R console:

``` r
if (!require("remotes")) {
  install.packages("remotes")
}
remotes::install_github("jcrodriguez1989/shinyParallel")
```

## runApp mode

### Usage

If you run your Shiny app like this:

``` r
runApp(appDir=myApp, <otherParams>)
```

Just replace it by:

``` r
shinyParallel::runApp(appDir=myApp, <otherParams>)
```

The only parameter that varies is `port`, in `shinyParallel::runApp` the
parameter is modified by `ports`. And instead of being `numeric` of
length 1, it will now be numeric of length equal to the number of ports
available to use. Where the first port will be used by the ShinyParallel
app, and the rest by the generated sessions.

The `shinyParallel::runApp` function has two additional parameters:

-   `max.sessions`: Maximum number of sessions to use.
-   `users.per.session`: Maximum number of admited users per each
    session.

### Example

``` r
library("shiny")

# Create a Shiny app object
app <- shinyApp(
  ui = fluidPage(
    column(3, wellPanel(
      numericInput("n", label = "Is it prime?", value = 7, min = 1),
      actionButton("check", "Check!")
    ))
  ),
  server = function(input, output) {
    # Check if n is prime.
    # Not R optimized.
    # No Fermat, Miller-Rabin, Solovay-Strassen, Frobenius, etc tests.
    # Check if n is divisable up to n-1 !!
    isPrime <- function(n) {
      res <- TRUE
      i <- 2
      while (i < n) {
        res <- res && n %% i != 0
        i <- i + 1
      }
      return(res)
    }
    observeEvent(input$check, {
      showModal(modalDialog(
        ifelse(isPrime(isolate(input$n)),
          "Yes it is!", "Nope, not a prime."
        ),
        footer = NULL,
        easyClose = TRUE
      ))
    })
  }
)

# Run it with Shiny
shiny::runApp(app)
# Run it with ShinyParallel default params
shinyParallel::runApp(app)
# Run it with ShinyParallel, give one session per user
shinyParallel::runApp(app, max.sessions = Inf, users.per.session = 1)
```

In this example, if the app is run with `shiny::runApp`, and a user
wants to calculate if the number 179424691 is prime then the app will be
blocked for other users for some minutes, if the app is run with
`shinyParallel::runApp` not.

If the shiny app url is `http://<url>:<port>/` then enter
`http://<url>:<port>/?admin` to view a panel that lists the number of
users currently present in each session.

## installShinyParallel mode

### Usage

If your application is at `<myAppPath>`, i.e., from an R terminal
`runApp(<myAppPath>)` starts the app, then to install it on the server
just run R as root (or make sure the actual user has write permissions
on the Shiny server) and run the `installShinyParallel(<myAppPath>)`
command.

### Example

First, let’s create our Shiny app, from a Linux terminal type:

``` bash
cd ~;
mkdir myShinyApp;
echo "
    library('shiny');
    
    # Create a Shiny app object
    app <- shinyApp(
      ui = fluidPage(
        column(3, wellPanel(
          numericInput('n', label = 'Is it prime?', value = 7, min = 1),
          actionButton('check', 'Check!')
        )
      )),
      server = function(input, output) {
        # Check if n is prime.
        # Not R optimized.
        # No Fermat, Miller-Rabin, Solovay-Strassen, Frobenius, etc tests.
        # Check if n is divisable up to n-1 !!
        isPrime <- function(n) {
          res <- TRUE;
          i <- 2;
          while (i < n) {
            res <- res && n %% i != 0;
            i <- i + 1;
          }
          return(res);
        }
        observeEvent(input\$check, {
          showModal(modalDialog(
            ifelse(isPrime(isolate(input\$n)),
                'Yes it is!', 'Nope, not a prime.'),
            footer = NULL,
            easyClose = TRUE
          ))
        })
      }
    )
" > myShinyApp/app.R;
```

So now we can try our app, and install it with multi-session feature,
from a R (sudo) console type:

``` r
library("shinyParallel")
# And install it
shinyParallel::installShinyParallel("./myShinyApp",
  max.sessions = 20,
  users.per.session = 5
)
```

## Limitations

-   Each session that ShinyParallel generates is independent of the
    others, i.e., the global variables of a session (shiny app) will not
    be modified in another one. Two users present in different session
    will not be able to interact with the same values of the variables.
