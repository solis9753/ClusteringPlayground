# Copyright 2021 Observational Health Data Sciences and Informatics
#
# This file is part of ClusteringPlayground
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# library(dplyr)
# labels <- readRDS(file.path(outputFolder, "labels.rds"))
# labels <- readRDS(file.path(outputFolder, "clusters1K.rds"))


#' Title
#'
#' @param outputFolder 
#' @param labels 
#'
#' @return
#' @export
plot2D <- function(outputFolder, labels) {
  distances <- readRDS(file.path(outputFolder, "distances.rds"))
  idxToRowId <- readRDS(file.path(outputFolder, "idxToRowId.rds"))
  
  ParallelLogger::logInfo("Computing 2D coordinates")
  umapSettings <- umap::umap.defaults
  umapSettings$metric <- "cosine"
  map <- umap::umap(distances, input = "dist", config = umapSettings)
  
  points <- data.frame(x = map$layout[, 1],
                       y = map$layout[, 2],
                       rowId = idxToRowId$rowId) 
    
  # Add labels
  points <- points %>%
    inner_join(labels, by = "rowId")
  
  # Find centroids
  centroids <- points %>%
    group_by(.data$label) %>%
    summarise(x = mean(.data$x),
              y = mean(.data$y)) %>%
    filter(.data$label != "Cluster 0")
  
  nClusters <- length(unique(labels$label))
  colors <- c("#666666", RColorBrewer::brewer.pal(nClusters -1, name = "Paired"))

  ParallelLogger::logInfo("Plotting")
  plot <- ggplot2::ggplot(points, ggplot2::aes(x = .data$x, y = .data$y)) +
    ggplot2::geom_point(ggplot2::aes(color = .data$label), shape = 16, alpha = 0.4) +
    ggplot2::geom_label(ggplot2::aes(label = .data$label), data = centroids) + 
    ggplot2::scale_color_manual(values = colors) +
    ggplot2::theme(panel.background = ggplot2::element_blank(),
                   axis.text = ggplot2::element_blank(),
                   axis.ticks = ggplot2::element_blank(),
                   axis.title = ggplot2::element_blank(),
                   legend.position = "none",
                   legend.background = ggplot2::element_blank(),
                   legend.key = ggplot2::element_blank(),
                   legend.title = ggplot2::element_blank())
  
  ggplot2::ggsave(filename = file.path(outputFolder, "plot.png"), width = 7.5, height = 7.5, dpi = 150)
}

#' Title
#'
#' @param outputFolder 
#' @param conceptIds 
#'
#' @return
#' @export
labelByCovariate <- function(outputFolder,
                             conceptIds = c(201254, 201826)) {
  covariateData <- FeatureExtraction::loadCovariateData(file.path(outputFolder, "CovariateData.zip"))
  
  conceptPriority <- data.frame(priority = 1:length(conceptIds),
                                conceptId = conceptIds)
  labels <- covariateData$covariateRef %>%
    inner_join(conceptPriority, copy = TRUE, by = "conceptId") %>%
    select(.data$covariateId, .data$covariateName, .data$priority) %>%
    inner_join(covariateData$covariates, by = "covariateId") %>%
    select(.data$rowId, label = .data$covariateName, .data$priority) %>%
    arrange(.data$rowId, .data$priority) %>%
    collect()
  
  labels <- labels[!duplicated(labels$rowId), ]
  labels$label <- gsub(".*index: ", "", labels$label)
  labels <- labels %>%
    select(-.data$priority)
  
  rowIds <- covariateData$covariates %>%
    distinct(.data$rowId) %>%
    pull()
  
  rowIds <- rowIds[!rowIds %in% labels$rowId]
  if (length(rowIds) > 0) {
    labels <- bind_rows(labels,
                        tibble(rowId = rowIds,
                               label = "Other"))
  }
  saveRDS(labels, file.path(outputFolder, "labels.rds"))
}

plot3D <- function(outputFolder, labels) {
  distances <- readRDS(file.path(outputFolder, "distances.rds"))
  idxToRowId <- readRDS(file.path(outputFolder, "idxToRowId.rds"))
  
  ParallelLogger::logInfo("Computing 3D coordinates")
  umapSettings <- umap::umap.defaults
  umapSettings$metric <- "cosine"
  umapSettings$n_components <- 3
  map <- umap::umap(distances, input = "dist", config = umapSettings)
  
  points <- data.frame(x = map$layout[, 1],
                       y = map$layout[, 2],
                       z = map$layout[, 3],
                       rowId = idxToRowId$rowId) 
  
  # Add labels
  points <- points %>%
    inner_join(labels, by = "rowId")
  
  saveRDS(points, file.path(outputFolder, "points.rds"))
  
  ParallelLogger::logInfo("Plotting")
  fig <- plotly::plot_ly(type = "scatter3d", 
                         data = points, 
                         x = ~x, 
                         y = ~y, 
                         z = ~z, 
                         color = ~label,
                         alpha = 0.5)
  axis <- list(showticklabels = FALSE,
               text = "",
               showgrid = TRUE)
  fig <- fig %>% 
    plotly::layout(scene = list(xaxis = axis,
                                     yaxis = axis,
                                     zaxis = axis))
  fig
  
  ggplot2::ggsave(filename = file.path(outputFolder, "plot.png"), width = 7.5, height = 7.5, dpi = 150)
}
