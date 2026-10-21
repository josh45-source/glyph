# Brush points in the scatterplot to list the cars in a table.
#
# Run it with:
#   shiny::runApp(system.file("examples", "shiny-brush", package = "glyph"))

library(shiny)
library(glyph)

cars <- mtcars[, c("mpg", "cyl", "wt", "hp")]
cars$cyl <- as.integer(cars$cyl)
cars$hp <- as.integer(cars$hp)

ui <- fluidPage(
  titlePanel("Brushing cars"),
  p("Drag across the plot to select cars. Press Escape, or click",
    "Clear selection, to start again."),
  glyphOutput("plot", height = "400px"),
  textOutput("count"),
  tableOutput("rows")
)

server <- function(input, output, session) {
  output$plot <- renderGlyph(
    glyph(cars, x = wt, y = mpg) |>
      mark_point(color = factor(cyl)) |>
      interact(brush = TRUE, tooltip = TRUE)
  )

  # Row numbers of `cars`, or NULL when nothing is selected.
  selected <- reactive(input$plot_selected)

  output$count <- renderText({
    n <- length(selected())
    if (is.null(selected())) "No cars selected."
    else if (n == 1) "1 car selected."
    else paste(n, "cars selected.")
  })

  output$rows <- renderTable({
    req(selected())
    cars[selected(), ]
  }, rownames = TRUE)
}

shinyApp(ui, server)
