# Choir Songbook

A searchable song library for the choir, organised by topic, built with Quarto and published on GitHub Pages.

**Live site:** https://github.com/crpc-choir/choir-songbook/

Choir members only need the link. It opens in any phone browser, and can be added to the home screen like an app.

## How it fits together

| Path | What it holds |
|---|---|
| `data/catalogue.csv` | The master list: one row per song (id, title, topics, language, type, key, composer, vestry folder, audio link) |
| `R/build_songs.R` | Creates a page for each new song and rebuilds every topic page from the catalogue |
| `songs/` | One `.qmd` file per song; lyrics are typed here |
| `topics/` | Generated automatically by the script; do not edit by hand |
| `services/` | One file per service with the chosen songs in order |
| `how-to.qmd` | Instructions for choir members, shown on the site |
| `docs/` | The built website that GitHub Pages serves; created by `quarto render`, never edited by hand |

## Console or Terminal?

RStudio has two places to type commands, and each command only works in one of them.

- **Console** (prompt `>`): R code, such as `source("R/build_songs.R")`
- **Terminal**: `quarto` and `git` commands

## Updating the songbook

1. **Catalogue.** Add or edit rows in `data/catalogue.csv`. Give each new song a new id (S008, S009, …) and never reuse or change an id. Separate topics with semicolons, for example `Worship; Thanksgiving`, and spell them the same way every time.
2. **Build pages.** In the Console, run:
   ```r
   source("R/build_songs.R")
   ```
   The script never overwrites lyrics. If a title changes, keep the same id and the file is renamed automatically.
3. **Lyrics.** Open the song's file in `songs/`. Start each line with `| ` and leave a blank line between verses:
   ```
   ### Verse 1
   | First line
   | Second line
   ```
4. **Check locally (optional).** In the Terminal, run `quarto preview`. Press Ctrl+C to stop it.
5. **Publish.** In the Terminal, run:
   ```
   quarto render
   git add .
   git commit -m "Add new songs"
   git push
   ```
   The live site updates one to two minutes after the push. If you skip `quarto render`, the site will not change.

## Publishing setup (already done)

- The site is built into the `docs/` folder (`output-dir: docs` in `_quarto.yml`).
- GitHub Pages is set to **Settings > Pages > Deploy from a branch > master > /docs**.
- The empty `.nojekyll` file in the project root tells GitHub to serve Quarto's files as they are. Do not delete it.
- The repository's default branch is `master`. Work only on `master`, and do not create a `gh-pages` branch or run `quarto publish`; this project uses the `docs` method instead.

## Troubleshooting

- **`Error: object 'quarto' not found`**: a Terminal command was typed in the Console.
- **"The filename, directory name, or volume label syntax is incorrect"**: R code was typed in the Terminal.
- **`cannot open file 'R/build_songs.R'`**: R is in the wrong folder. Open the project with File > Open Project, or `setwd()` to the folder containing `_quarto.yml`.
- **Changing to the D: drive in the Terminal**: use `cd /d D:\path\to\folder`.
- **Site shows a 404**: check that `docs/index.html` exists on GitHub and that Settings > Pages points to master and /docs.

## Keeping it private

A GitHub Pages site on a free account is public, even if the link is only shared with the choir. Keep lyrics to public-domain hymns and catalogue details for everything else. If copyrighted lyrics are needed, move the site behind a login, for example by hosting the `docs` folder on Cloudflare Pages with Cloudflare Access (free for small teams).
