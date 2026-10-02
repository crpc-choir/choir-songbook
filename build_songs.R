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


# ---- Rehearsal audio -------------------------------------------------------
# The `audio` column can hold one link, or several labelled links separated
# by semicolons, e.g.  Full: audio/S001-full.mp3; Soprano: https://youtu.be/xyz
# Supported: MP3/M4A files in the audio/ folder, YouTube, Google Drive, any URL.
media_embed <- function(url) {
  if (grepl("youtube\\.com|youtu\\.be", url))
    return(sprintf("{{< video %s >}}", url))
  id <- regmatches(url, regexec("drive\\.google\\.com/file/d/([^/?]+)", url))[[1]]
  if (length(id))
    return(sprintf('<iframe class="drive-audio" src="https://drive.google.com/file/d/%s/preview" allow="autoplay" loading="lazy"></iframe>', id[2]))
  if (!grepl("^https?://", url)) url <- paste0("../", sub("^/+", "", url))
  if (grepl("\\.(mp3|m4a|aac|wav|ogg)(\\?.*)?$", url, ignore.case = TRUE))
    return(sprintf('<audio controls preload="none" src="%s"></audio>\n\n[Download for offline listening](%s)', url, url))
  sprintf("[Listen](%s)", url)
}

audio_block <- function(audio) {
  items <- trimws(strsplit(audio, ";", fixed = TRUE)[[1]])
  items <- items[items != ""]
  if (!length(items)) return(character(0))
  out <- c("<!-- audio-start -->", "::: {.rehearsal-audio}", "#### Rehearsal audio", "")
  for (it in items) {
    m <- regmatches(it, regexec("^([^:/]{1,40}):\\s+(\\S+)$", it))[[1]]
    if (length(m)) { label <- trimws(m[2]); url <- m[3] } else { label <- ""; url <- it }
    if (nzchar(label)) out <- c(out, sprintf("**%s**", label), "")
    out <- c(out, media_embed(url), "")
  }
  c(out, ":::", "<!-- audio-end -->")
}

set_audio <- function(body, audio) {
  # remove any previous audio block (and the old one-line link format)
  s <- which(body == "<!-- audio-start -->"); e <- which(body == "<!-- audio-end -->")
  if (length(s) && length(e) && e[1] >= s[1]) {
    end <- e[1]
    while (end < length(body) && body[end + 1] == "") end <- end + 1  # blank lines after the block
    body <- body[-(s[1]:end)]
  }
  body <- body[!grepl("^\\[Rehearsal audio\\]\\(", body)]
  blk <- audio_block(audio)
  if (!length(blk)) return(body)
  at <- which(body == "::: {.lyrics}")[1]
  if (is.na(at)) c(body, "", blk) else append(body, c(blk, ""), after = at - 1)
}

# ---- Safeguards --------------------------------------------------------------
# Song files whose id has left the catalogue, or whose id now belongs to a
# different song, are moved to songs/_retired/ (never deleted). Quarto ignores
# folders starting with "_", so retired songs disappear from the site but their
# lyrics stay on disk and can be copied back if needed.
retired_dir <- "songs/_retired"
notes <- character(0)

retire <- function(f, why) {
  dir.create(retired_dir, showWarnings = FALSE)
  dest <- file.path(retired_dir, basename(f))
  if (file.exists(dest))
    dest <- file.path(retired_dir, sub("\\.qmd$", format(Sys.time(), "-%Y%m%d-%H%M%S.qmd"), basename(f)))
  file.rename(f, dest)
  notes <<- c(notes, sprintf("RETIRED  %s -> %s\n         (%s)", basename(f), dest, why))
}

read_title <- function(lines) {
  ends <- which(lines == "---")
  if (length(ends) < 2) return(NA_character_)
  t <- grep("^title:", lines[ends[1]:ends[2]], value = TRUE)[1]
  if (is.na(t)) return(NA_character_)
  t <- sub('^title:\\s*"?(.*?)"?\\s*$', "\\1", t, perl = TRUE)
  gsub('\\\\"', '"', t)
}

# 0 = same title, 1 = completely different (ignores case, spaces and punctuation)
title_distance <- function(a, b) {
  norm <- function(x) trimws(gsub("\\s+", " ", gsub("[^a-z0-9 ]", " ", tolower(x))))
  a <- norm(a); b <- norm(b)
  as.numeric(adist(a, b)) / max(nchar(a), nchar(b), 1)
}
SAME_SONG_LIMIT <- 0.35   # title changes bigger than this are treated as a different song

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
    paste("has_audio:", q(if (nzchar(trimws(r$audio))) "Yes" else "")),
    "---"
  )

  # If a file for this id exists (even under an old title), keep its body.
  old <- list.files("songs", pattern = paste0("^", r$id, "-.*\\.qmd$"), full.names = TRUE)
  if (length(old) > 1) {                       # several files share this id
    keep <- if (r$file %in% old) r$file else old[1]
    for (f in setdiff(old, keep)) retire(f, sprintf("extra file for id %s", r$id))
    old <- keep
  }
  body <- NULL
  if (length(old)) {
    lines <- readLines(old, encoding = "UTF-8", warn = FALSE)
    old_title <- read_title(lines)
    if (!is.na(old_title) && title_distance(old_title, r$title) > SAME_SONG_LIMIT) {
      # The id now belongs to a different song: don't carry the old lyrics over
      retire(old, sprintf('id %s was "%s", now "%s" - started a fresh page', r$id, old_title, r$title))
    } else {
      ends <- which(lines == "---")
      body <- if (length(ends) >= 2 && ends[2] < length(lines))
        lines[(ends[2] + 1):length(lines)] else new_body
      if (!is.na(old_title) && old_title != r$title)
        notes <- c(notes, sprintf('RENAMED  %s: "%s" -> "%s" (lyrics kept)', r$id, old_title, r$title))
      if (old != r$file) file.remove(old)
    }
  }
  if (is.null(body)) {
    body <- new_body
    created <- created + 1
  }
  body <- set_audio(body, r$audio)
  writeLines(c(header, body), r$file, useBytes = TRUE)
}

# Song files whose id is no longer in the catalogue
all_files <- list.files("songs", pattern = "\\.qmd$", full.names = TRUE)
file_ids <- sub("^([^-]+)-.*$", "\\1", basename(all_files))
for (f in all_files[!file_ids %in% cat_df$id & !startsWith(basename(all_files), "_")])
  retire(f, "id no longer in catalogue.csv")

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
    "  fields: [title, song_language, song_type, key, folder, has_audio]",
    "  field-display-names:",
    "    title: \"Song\"",
    "    song_language: \"Language\"",
    "    song_type: \"Type\"",
    "    key: \"Key\"",
    "    folder: \"Vestry folder\"",
    "    has_audio: \"Audio\"",
    "---"
  ), file.path("topics", paste0(slugify(t), ".qmd")))
}

counts <- table(long$topic)[topics]
writeLines(c(
  "---", "title: \"Topics\"", "---", "",
  sprintf("- [%s](%s.qmd) (%d)", topics, slugify(topics), as.integer(counts))
), "topics/index.qmd")

message(sprintf("Done: %d songs (%d new), %d topics.", nrow(cat_df), created, length(topics)))
if (length(notes)) {
  message("\nPlease check:\n", paste(notes, collapse = "\n"))
  message("\nRetired pages keep their lyrics in ", retired_dir,
          ". If a retirement was a mistake, copy the lyrics back into the new page.")
}
