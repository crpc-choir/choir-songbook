# Build song pages and topic pages from data/catalogue.csv
# Run from the project root:  source("R/build_songs.R")
# Base R only; no packages needed.

cat_df <- read.csv("data/catalogue.csv", stringsAsFactors = FALSE,
                   encoding = "UTF-8", na.strings = "")
cat_df[is.na(cat_df)] <- ""

slugify <- function(x) {
  x <- iconv(x, to = "ASCII//TRANSLIT")
  x <- gsub("[^a-z0-9]+", "-", tolower(x))
  gsub("^-|-$", "", x)
}
q <- function(x) paste0('"', gsub('"', '\\\\"', x), '"')   # safe YAML string
split_topics <- function(x) {
  t <- trimws(strsplit(x, ";", fixed = TRUE)[[1]])
  t[t != ""]
}

if (anyDuplicated(cat_df$id)) stop("Duplicate ids in catalogue.csv: ",
  paste(unique(cat_df$id[duplicated(cat_df$id)]), collapse = ", "))

new_body <- c(
  "",
  "::: {.song-info}",
  "Language: {{< meta song_language >}}  |  Type: {{< meta song_type >}}  |  Key: {{< meta key >}}  |  Composer: {{< meta composer >}}  |  Vestry folder: {{< meta folder >}}",
  ":::",
  "",
  "::: {.lyrics}",
  "*Lyrics not yet entered.*",
  ":::",
  ""
)

cat_df$file <- sprintf("songs/%s-%s.qmd", cat_df$id, slugify(cat_df$title))
created <- 0

for (i in seq_len(nrow(cat_df))) {
  r <- cat_df[i, ]
  topics <- split_topics(r$topics)
  header <- c(
    "---",
    paste("title:", q(r$title)),
    paste0("categories: [", paste(sapply(topics, q), collapse = ", "), "]"),
    paste("song_id:", q(r$id)),
    paste("song_language:", q(r$language)),
    paste("song_type:", q(r$song_type)),
    paste("key:", q(r$key)),
    paste("composer:", q(r$composer)),
    paste("folder:", q(r$folder)),
    paste("audio:", q(r$audio)),
    "---"
  )

  # If a file for this id exists (even under an old title), keep its body.
  old <- list.files("songs", pattern = paste0("^", r$id, "-.*\\.qmd$"), full.names = TRUE)
  if (length(old)) {
    lines <- readLines(old[1], encoding = "UTF-8", warn = FALSE)
    ends <- which(lines == "---")
    body <- if (length(ends) >= 2 && ends[2] < length(lines))
      lines[(ends[2] + 1):length(lines)] else new_body
    if (old[1] != r$file) file.remove(old[1])   # title changed: rename file
  } else {
    body <- new_body
    created <- created + 1
  }
  if (nzchar(r$audio) && !any(grepl("Rehearsal audio", body)))
    body <- c(body, "", "[Rehearsal audio]({{< meta audio >}})")
  writeLines(c(header, body), r$file, useBytes = TRUE)
}

# Rebuild topic pages from scratch
unlink(list.files("topics", pattern = "\\.qmd$", full.names = TRUE))
long <- do.call(rbind, lapply(seq_len(nrow(cat_df)), function(i)
  data.frame(topic = split_topics(cat_df$topics[i]), file = cat_df$file[i])))
topics <- sort(unique(long$topic))

for (t in topics) {
  files <- sort(long$file[long$topic == t])
  writeLines(c(
    "---",
    paste("title:", q(t)),
    "listing:",
    "  contents:",
    paste0("    - ../", files),
    "  type: table",
    "  sort: \"title\"",
    "  filter-ui: true",
    "  fields: [title, song_language, song_type, key, folder]",
    "  field-display-names:",
    "    title: \"Song\"",
    "    song_language: \"Language\"",
    "    song_type: \"Type\"",
    "    key: \"Key\"",
    "    folder: \"Vestry folder\"",
    "---"
  ), file.path("topics", paste0(slugify(t), ".qmd")))
}

counts <- table(long$topic)[topics]
writeLines(c(
  "---", "title: \"Topics\"", "---", "",
  sprintf("- [%s](%s.qmd) (%d)", topics, slugify(topics), as.integer(counts))
), "topics/index.qmd")

message(sprintf("Done: %d songs (%d new), %d topics.", nrow(cat_df), created, length(topics)))
