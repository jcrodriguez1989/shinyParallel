ShinyParallel
================

Run [Shiny](http://shiny.rstudio.com/) applications in a multi-session mode without the need for Shiny Server.

Prevents that if a user executes a long computing task penalizing others.

ShinyParallel reimplements the function *shiny::runApp(&lt;params&gt;)*. In this sense, the only thing to do to run an app in multi-session mode is to call it using *shinyParallel::runApp(&lt;params&gt;)*.

Features
--------

-   Run a Shiny app in multiple sessions (processes / physical cores).
-   Decide the maximum number of users per session.
-   It allows to visualize the number of users currently present in each session.

Installation
------------

ShinyParallel is currently only available as a GitHub package. To install it run the following from an R console:

``` r
if (!require("devtools"))
  install.packages("devtools")
devtools::install_github("jcrodriguez1989/shinyParallel")
```

Usage
-----

If you run your Shiny app like this:

``` r
runApp(appDir=myApp, <otherParams>)
```

Just replace it by:

``` r
shinyParallel::runApp(appDir=myApp, <otherParams>)
```

The only parameter that varies is *port*, in shinyParallel::runApp the parameter is modified by *ports*. And instead of being *numeric* of length 1, it will now be numeric of length equal to the number of ports available to use. Where the first port will be used by the ShinyParallel app, and the rest by the generated sessions.

La funcion shinyParallel::runApp tiene dos parametros adicionales:

-   *max.sessions*: Maximum number of sessions to use.
-   *users.per.session*: Maximum number of admited users per each session.

Example
-------

``` r
library("shiny");

# Create a Shiny app object
app <- shinyApp(
  ui = fluidPage(
    column(3, wellPanel(
      numericInput('n', label='Is it prime?', value=7, min=1),
      actionButton('check', 'Check!')
    )
  )),
  server = function(input, output) {
    # Check if n is prime.
    # Not R optimized.
    # No Fermat, Miller-Rabin, Solovay-Strassen, Frobenius, etc tests.
    # Check if n is divisable up to n-1 !!
    isPrime <- function(n) {
      res <- !F;
      i <- 2;
      while (i < n) {
        res <- res && n %% i !=0;
        i <- i+1;
      }
      return(res);
    }
    observeEvent(input$check, {
      showModal(modalDialog(
        ifelse(isPrime(isolate(input$n)),
            'Yes it is!', 'Nope, not a prime.'),
        footer=NULL,
        easyClose=!F
      ))
    })
  }
)

# Run it with Shiny
shiny::runApp(app);

# Run it with ShinyParallel default params
shinyParallel::runApp(app);

# Run it with ShinyParallel, give one session per user
shinyParallel::runApp(app, max.sessions=Inf, users.per.session=1);
```

In this example, if the app is run with shiny::runApp, and a user wants to calculate if the number 179424691 is prime then the app will be blocked for other users for some minutes, if the app is run with shinyParallel::runApp not.

If the shiny app url is `http://<url>:<port>/` then enter `http://<url>:<port>/?admin` to view a panel that lists the number of users currently present in each session.

Limitations
-----------

-   Each session that ShinyParallel generates is independent of the others, i.e., the global variables of a session (shiny app) will not be modified in another one. Two users present in different session will not be able to interact with the same values of the variables.
