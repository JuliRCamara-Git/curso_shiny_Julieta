#control shift a --> para que quede prolijo el codigo automaticamente

#1- Instalar y cargar librerías

# chequeamos si las librerías están instaladas y si es necesario se instalan
if ("readxl" %in% installed.packages()[,"Package"]) {library(readxl)} else {install.packages("readxl");library(readxl)}
if ("openxlsx" %in% installed.packages()[,"Package"]) {library(openxlsx)} else {install.packages("openxlsx");library(openxlsx)}
if ("highcharter" %in% installed.packages()[,"Package"]) {library(highcharter)} else {install.packages("highcharter");library(highcharter)}

#2- Descargar proyecciones de población en formato .xls de la web del INDEC

# descarga del archivo
url = "https://www.indec.gob.ar/ftp/cuadros/poblacion/c2_proyecciones_prov_2010_2040.xls"
download.file(url, destfile = "poblacion.xls", mode="wb")

#3- Crear una variable con los nombres de las hojas de la planilla descargada
sheets = readxl::excel_sheets("poblacion.xls")
print(sheets)

#Eliminar el nombre de la primera hoja de la planilla en la variable (ya que no contiene información)
sheets = sheets[sheets!="GraphData"]
print(sheets)

#columnas
orden_letra_b = 2
columnas = LETTERS[seq(orden_letra_b,length(LETTERS), by = 4)][1:6]
print(columnas)

#filas
fila_primer_bloque = 8
fila_ultimo_bloque = 148
filas = seq(fila_primer_bloque,fila_ultimo_bloque, by = 28)
print(filas)

#expand.grid: permite la combinacion de filas y columnas
columnas_y_filas = list(
  columnas,
  filas)
columnas_y_filas = expand.grid(columnas_y_filas)
print(columnas_y_filas)

#Eliminamos las ultimas 5 combinaciones ya que el último bloque sólo dispone de un cuadro
columnas_y_filas = columnas_y_filas[1:(nrow(columnas_y_filas)-5),] 

#Pegamos ambas columnas para obtener los identificadores de celdas tal como los usa Excel
celdas = paste0(columnas_y_filas$Var1,columnas_y_filas$Var2) 
print(celdas)

grupos_de_edad = readxl::read_xls("poblacion.xls", sheet = sheets[1], range = "A8:A28", col_names = F)[[1]] # vector de grupos de edad
sexo = colnames(readxl::read_xls("poblacion.xls", sheet = sheets[1], range = "B4:D4")) # vector de categorías de sexo
anos = 2010:2040 # vector de años

print(grupos_de_edad)
print(sexo)
print(anos)

#Ya tenemos toda la información que necesitamos:
#Las jurisdicciones (a partir de los nombres de las hojas, en la variable sheets)
#Los grupos de edad (en la variable grupos_de_edad)
#Las categorías de sexo (en la variable sexo)
#Las celdas donde empieza cada bloque (en la variable celdas)
#Con esa información podemos recorrer el archivo e ir extrayendo la información para generar un data frame. Ésta será la tarea más compleja.

#5 - Crear el data frame

resultado = data.frame() # creamos en data.frame vacío donde se guardarán los resultados

for (i in sheets) {
  # recorre las hojas del archivo original
  for (j in celdas) {
    # recorre cada una de las celdas donde comienza un bloque de datos
    ano = anos[which(celdas == j)] # identifica el año del bloque que está capturando
    rango = c(j,
              paste0(LETTERS[which(LETTERS == substring(j, 1, 1)) + 2], as.numeric(substring(j, 2, 4)) +
                       20))
    rango = paste(rango, collapse = ":") # obtiene el rango completo del bloque
    cuadro = readxl::read_xls(
      "poblacion.xls",
      sheet = i,
      range = rango,
      col_names = F
    ) # lee el bloque
    colnames(cuadro) = sexo # pone nombre de columnas a los datos obtenidos
    cuadro$ano = ano # agrega el año de los datos
    cuadro$juri = i # agrega la jurisdicción a los datos
    cuadro$edad = grupos_de_edad # agrega las etiquetas de los grupos de edad
    print(cuadro)
    resultado = rbind(resultado,
                      cuadro[, c(4, 5, 6, 1, 2, 3)]) # une los datos obtenidos al data frame donde se almacenarán todos (resultado)
  }
}
#Ahora sí, contamos con un data frame que contiene los datos en un formato amigable:

print(resultado)

#Podemos mejorar la presentación de los datos.
# separamos los códigos de jurisdicción de los nombres
resultado$juri_nombre = substring(resultado$juri,4,max(nchar(resultado$juri)))
resultado$juri = substring(resultado$juri,1,2)

#También podemos usar tidyr (Wickham, Vaughan, and Girlich 2023) para pasar la variable sexo a las filas y DT (Xie, Cheng, and Tan 2023).

if ("tidyr" %in% installed.packages()[, "Package"]) {
  library(tidyr)
} else {
  install.packages("tidyr")
  library(tidyr)
}
if ("DT" %in% installed.packages()[, "Package"]) {
  library(DT)
} else {
  install.packages("DT")
  library(DT)
}

resultado = resultado %>% pivot_longer(cols = 4:6,
                                       names_to = "sexo_nombre",
                                       values_to = "poblacion") # pasa sexo a filas

# codifica sexo
resultado$sexo_codigo = ""
resultado$sexo_codigo[resultado$sexo_nombre == "Ambos sexos"] = "0"
resultado$sexo_codigo[resultado$sexo_nombre == "Varones"] = "1"
resultado$sexo_codigo[resultado$sexo_nombre == "Mujeres"] = "2"

resultado = resultado[, c(1, 2, 4, 7, 5, 3, 6)] # ordena columnas
DT::datatable(resultado)

#Podemos observar que generamos un data frame de 48.825 filas. Si tenemos en cuenta que tabulamos información de 31 años, en 25 jurisdicciones (incluyendo “total país”), para 3 categorías de sexo (incluyendo “ambos sexos”) y 21 grupos de edad, podemos comprobar si nuestro trabajo fue correcto:

filas_data_frame = 48825
n_anos = 31
n_jurisdicciones = 25
n_categorias_sexo = 3
n_grupos_de_edad = 21

filas_esperadas = n_anos * n_jurisdicciones * n_categorias_sexo * n_grupos_de_edad

print(filas_data_frame == filas_esperadas)

#6 - Visualización
#Finalmente, podemos hacer una visualización sencilla de los datos usando los paquetes shiny (Chang et al. 2022), highcharter (Kunst 2022) y htmlwidgets (Vaidyanathan et al. 2023).

library(shiny)
library(dplyr)
library(highcharter)
library(shinyWidgets)

ui <- fluidPage(
  column(
    3,
    br(),
    selectizeInput(
      inputId = "ano",
      label = "Seleccionar año:",
      choices = unique(resultado$ano),
      selected = substring(Sys.Date(), 1, 4)
    ),
    selectizeInput(
      inputId = "juri",
      label = "Seleccionar jurisdicción:",
      choices = unique(resultado$juri_nombre)
    )
  ),
  column(6,
         br(),
         highchartOutput("grafico")),
  column(3)
)

# definimos la lógica para elaborar el gráfico de pirámides a partir de la información ingresada en la ui
server <- function(input, output, session) {
  output$grafico = renderHighchart({
    datos_grafico = resultado[resultado$ano == input$ano &
                                resultado$sexo_codigo != "0" &
                                resultado$juri_nombre == input$juri, ]
    
    highchart() %>%
      hc_chart(type = "bar") %>%
      hc_title(text = paste("Pirámide de población", "-", input$juri, "-", input$ano)) %>%
      hc_xAxis(categories = rev(unique(datos_grafico$edad))) %>%
      hc_yAxis(
        title = list(text = "Población"),
        labels = list(formatter = JS(
          "function() {
                    return Math.abs(this.value);
                  }"
        )),
        max = max(datos_grafico$poblacion) * 1.1,
        min = max(datos_grafico$poblacion) * 1.1 * -1
      ) %>%
      hc_plotOptions(series = list(
        stacking = "normal",
        groupPadding = 0,
        pointPadding = 0,
        borderWidth = .1
      )) %>%
      hc_add_series(
        name = "Varones",
        data = rev(datos_grafico$poblacion[datos_grafico$sexo_codigo == "1"]) *
          -1,
        color = "#d8b365"
      ) %>%
      hc_add_series(
        name = "Mujeres",
        data = rev(datos_grafico$poblacion[datos_grafico$sexo_codigo == "2"]),
        color = "#5ab4ac"
      ) %>%
      hc_legend(align = "right",
                verticalAlign = "top",
                reversed = TRUE) %>%
      hc_tooltip(
        formatter = JS(
          "function () {
                                  if (this.series.name === 'Varones') {
                                    return `<b>${this.series.name}</b></br>${this.y*-1}`
                                  } else if (this.series.name === 'Mujeres') {
                                    return `<b>${this.series.name}</b></br>${this.y}`}}"
        )
      ) %>%
      hc_exporting(enabled = TRUE)
  })
}


# mostramos la aplicación en el servidor local
shinyApp(ui, server)
