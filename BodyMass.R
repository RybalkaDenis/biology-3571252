# Installing packages
install.packages("dplyr")
install.packages("ggplot2")
install.packages("multcompView")
install.packages("rstudioapi")
install.packages("ggtext")

# Load libraries
library(dplyr)
library(ggplot2)
library(multcompView)
library(ggtext)

# Setting working directory to current
current_path = rstudioapi::getActiveDocumentContext()$path 
setwd(dirname(current_path ))

rawData <- read.csv("RawData.csv", skip= 11)

# Un-comment compound variable one by one to get complete results

# compound <- "Aniline"
# compound <- "Formaldehyde"
compound <- "Ortho-xylene"

# Label localization
language <- "en"
compoundName <- switch(compound,
                       "Aniline" = ifelse(language == "en", "aniline", "аніліну"),
                       "Formaldehyde" = ifelse(language == "en", "formaldehyde", "формальдегіду"),
                       "Ortho-xylene" = ifelse(language == "en", "ortho-xylene", "орто-ксилену"),
                       NA  # Default case
)


labelXUA <- bquote("Концентрація " ~ .(compoundName) ~ "в кормовому субстраті, мг/кг")
labelYUA <- expression("Зміна маси тіла " * italic("T. molitor") * ", мг/доба");

labelXEN <- bquote("Concentration of " ~ .(compoundName) ~ " in the feed substrate, mg/kg")
labelYEN <- expression("Body mass change of " * italic("T. molitor") * ", mg/day");

if (language == "en") {
  labelX <- labelXEN
  labelY <- labelYEN
} else {
  labelX <- labelXUA
  labelY <- labelYUA
}


# Filter the dataset for "chosen compound" and "Control"
compoundData <- rawData %>% filter(Compound %in% c(compound, "Control"))
colnames(compoundData) <- c("Compound", "Concentration", "StartWeight", "EndWeight", "GregarinaCount", "Change", "ChangePercent")
compoundData <- compoundData %>% filter(!is.na(GregarinaCount))
compoundData$Concentration <- factor(compoundData$Concentration, ordered = T)

# Experiment lasted for 10 days
compoundData$Change <- as.numeric(compoundData$Change) / 10

# We need max values to get correct scales points
maxValues <- compoundData %>%
  group_by(Concentration) %>%
  summarise(maxChange = ceiling(max(Change)))

# Perform ANOVA
anovaResult <- aov(Change ~ Concentration, data = compoundData)
summary(anovaResult)

# Tukey's HSD Test for pairwise comparisons
tukeyResult <- TukeyHSD(anovaResult)
summary(tukeyResult)  # Check pairwise comparison results
letters <- multcompLetters4(anovaResult, tukeyResult)$Concentration$Letters

# Counting speciments in each group
groupCounts <- compoundData %>%
  group_by(Concentration) %>%
  summarise(N = n())

updatedYLabels <- groupCounts %>%
  mutate(label = paste0(Concentration, "<br>(<i>N</i> = ", N, ")"))

# Prepare annotation data
annotation_data <- data.frame(
  Concentration = levels(compoundData$Concentration),
  label = letters
)

annotation_data <- annotation_data %>%
  left_join(maxValues, by = "Concentration")

# Create the boxplot with annotations
ggplot(compoundData, aes(x = Concentration, y = Change)) +
  geom_boxplot(width = 0.2, outlier.shape = 8, outlier.color = "red", outlier.size = 2) +
  stat_summary(
    fun = mean, geom = "point", shape = 23, size = 3, fill = "blue", color = "black"
  ) +  # Add mean points
  stat_summary(
    fun = mean, geom = "line",
    aes(group = 1),  # Ensures all points are connected
    color = "blue", size = 1
  ) +
  stat_summary(fun = mean, 
               geom = "text", 
               aes(label = gsub("-", "\u2212", format(round(..y.., 2), nsmall = 2))),
               hjust = -1, 
               color = "blue",
  ) +  # Mean labels
  geom_jitter(
    aes(color = Concentration), width = 0.2, size = 2, alpha = 0.6
  ) +  # Add jittered points
  scale_y_continuous(
    breaks = seq(floor(min(compoundData$Change)), ceiling(max(compoundData$Change)), by = 1),
    limits = c(min(as.numeric(as.character(compoundData$Change)) - 0.5), 
               max(as.numeric(as.character(compoundData$Change))) + 0.5),
    labels = ~sub("-", "\u2212", .x),
  ) +  # Set y-axis scale to increment by 1
  geom_text(
    data = annotation_data,
    aes(x = Concentration, y = maxChange + 0.2, label = label),
    inherit.aes = FALSE,
    size = 3.5
  ) +
  scale_x_discrete(labels = updatedYLabels$label) +  # Set custom labels
  labs(
    x = labelX,
    y = labelY,
  ) +
  theme_minimal() +
  theme(legend.position = "none") +
  theme(
    axis.text.x = element_markdown(size = 10, hjust = 0.5),
    axis.text.y = element_markdown(size = 10, hjust = 0.5),
    axis.title = element_text(size = 12, face = "bold"),
    plot.title = element_text(size = 10, face = "bold", hjust = 0.5),
    legend.position = "none"
  )


