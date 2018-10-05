library('shiny');

shinyUI(
  fluidPage(
    shiny::htmlOutput(outputId='htmlSess'),
    dataTableOutput(outputId='stattable')
  )
)
