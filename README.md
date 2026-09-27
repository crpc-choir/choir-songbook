# Choir Songbook

A searchable song library for the choir, organised by topic, built with Quarto and published on GitHub Pages.

## How it fits together

| Path | What it holds |
|---|---|
| `data/catalogue.csv` | The master list: one row per song (id, title, topics, language, type, key, composer, vestry folder, audio link) |
| `R/build_songs.R` | Creates a page for each new song and rebuilds every topic page from the catalogue |
| `songs/` | One `.qmd` file per song; lyrics are typed here |
| `topics/` | Generated automatically; do not edit by hand |
| `services/` | One file per service with the chosen songs in order |
| `how-to.qmd` | Instructions for choir members, shown on the site |

## Everyday workflow

1. Add or edit rows in `data/catalogue.csv` (topics separated by semicolons).
2. In RStudio, from the project folder: `source("R/build_songs.R")`
3. Type lyrics into the new files in `songs/`.
4. Preview with `quarto preview`, then commit and push.

The script never overwrites lyrics. Ids are permanent: if a title changes, keep the same id and the file is renamed for you.

## First-time publishing

1. Create a GitHub repository and push this folder to the `main` branch.
2. Run `quarto publish gh-pages` once from your computer. This creates the `gh-pages` branch.
3. In the repository, go to Settings > Pages and set the source to the `gh-pages` branch.
4. From then on, every push to `main` republishes the site through `.github/workflows/publish.yml`.

## Keeping it private

A site on GitHub Pages from a free account is public even if nobody is given the link. If the library will hold copyrighted lyrics, consider putting it behind a login, for example by hosting the rendered `_site` folder on Cloudflare Pages with Cloudflare Access (free for small teams), or restricting lyrics to public-domain hymns and keeping only catalogue details for everything else.
