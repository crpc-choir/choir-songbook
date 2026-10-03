# Runs automatically after every `quarto render` (see post-render in _quarto.yml).
# Turns the rendered site into an installable web app (PWA) that works offline:
#   - copies the app manifest and icons into the site
#   - writes the service worker (sw.js) with a fresh version number
#   - adds the app tags to the <head> of every page

out <- Sys.getenv("QUARTO_PROJECT_OUTPUT_DIR", "docs")
if (!dir.exists(out)) quit(save = "no")

version <- format(Sys.time(), "%Y%m%d%H%M%S")
sw <- readLines("pwa/sw.js", warn = FALSE, encoding = "UTF-8")
writeLines(gsub("__VERSION__", version, sw, fixed = TRUE), file.path(out, "sw.js"), useBytes = TRUE)
file.copy("pwa/manifest.webmanifest", file.path(out, "manifest.webmanifest"), overwrite = TRUE)
dir.create(file.path(out, "icons"), showWarnings = FALSE)
file.copy(list.files("pwa/icons", full.names = TRUE), file.path(out, "icons"), overwrite = TRUE)

pwa_head <- paste(
  '<!-- pwa -->',
  '<link rel="manifest" href="{{OFF}}manifest.webmanifest">',
  '<meta name="theme-color" content="#1F3A2E">',
  '<link rel="apple-touch-icon" href="{{OFF}}icons/apple-touch-icon.png">',
  '<meta name="apple-mobile-web-app-capable" content="yes">',
  '<meta name="mobile-web-app-capable" content="yes">',
  '<meta name="apple-mobile-web-app-title" content="CRPC Songbook">',
  '<style>#pwa-offline{display:none;position:fixed;left:50%;bottom:calc(14px + env(safe-area-inset-bottom,0px));transform:translateX(-50%);background:#1F3A2E;color:#F3F1E8;padding:.45rem 1rem;border-radius:999px;font:500 .9rem system-ui,sans-serif;z-index:2000;box-shadow:0 2px 8px rgba(0,0,0,.25);white-space:nowrap}</style>',
  '<script>',
  "if ('serviceWorker' in navigator) addEventListener('load', function () { navigator.serviceWorker.register('{{OFF}}sw.js').catch(function () {}); });",
  "(function () { function show() { var b = document.getElementById('pwa-offline');",
  "  if (!b) { b = document.createElement('div'); b.id = 'pwa-offline'; b.setAttribute('role', 'status'); b.textContent = 'Offline: showing saved songs'; document.body.appendChild(b); }",
  "  b.style.display = navigator.onLine ? 'none' : 'block'; }",
  "  addEventListener('online', show); addEventListener('offline', show); addEventListener('DOMContentLoaded', show); })();",
  '</script>',
  sep = "\n")

pages <- list.files(out, pattern = "\\.html$", recursive = TRUE)
pages <- pages[!startsWith(pages, "site_libs")]
for (f in pages) {
  path <- file.path(out, f)
  x <- readLines(path, warn = FALSE, encoding = "UTF-8")
  if (any(grepl("<!-- pwa -->", x, fixed = TRUE))) next   # already done
  i <- grep("</head>", x, fixed = TRUE)[1]
  if (is.na(i)) next
  depth <- lengths(regmatches(f, gregexpr("/", f)))
  off <- if (depth > 0) strrep("../", depth) else "./"
  x[i] <- sub("</head>", paste0(gsub("{{OFF}}", off, pwa_head, fixed = TRUE), "\n</head>"), x[i], fixed = TRUE)
  writeLines(x, path, useBytes = TRUE)
}
message(sprintf("Offline app ready: %d pages, version %s", length(pages), version))
