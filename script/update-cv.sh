#!/usr/bin/env bash
#
# update-cv.sh — compile the CV and publish it to the website.
#
# Your CV source lives in Overleaf (synced to Dropbox), which only stores the
# .tex (no compiled PDF). This script compiles it locally, copies the resulting
# PDF into the site's assets/, then commits and pushes so GitHub Pages serves
# the new version. Run it after you finish editing on Overleaf and the Dropbox
# sync has caught up:
#
#     ./script/update-cv.sh
#
# Override any default with an env var, e.g.:
#     CV_TEX=main.tex ./script/update-cv.sh        # publish the academic CV instead
#     AUTO_PUSH=0 ./script/update-cv.sh            # commit but do not push
#
set -euo pipefail

# ---- config (override via environment) -------------------------------------
CV_SRC_DIR="${CV_SRC_DIR:-$HOME/Library/CloudStorage/Dropbox/Apps/Overleaf/CV}"
CV_TEX="${CV_TEX:-industry-CV.tex}"
SITE_DIR="${SITE_DIR:-$HOME/projects/personal/wonkyoc.github.io}"
DEST="${DEST:-assets/cv.pdf}"
COMMIT_MSG="${COMMIT_MSG:-Update CV ($(date +%Y-%m-%d))}"
AUTO_PUSH="${AUTO_PUSH:-1}"   # 1 = commit and push, 0 = commit only

# ---- sanity checks ---------------------------------------------------------
[[ -f "$CV_SRC_DIR/$CV_TEX" ]] || { echo "ERROR: $CV_SRC_DIR/$CV_TEX not found"; exit 1; }
[[ -d "$SITE_DIR/.git" ]]      || { echo "ERROR: $SITE_DIR is not a git repo"; exit 1; }

# ---- compile in a scratch dir so aux files never touch the Overleaf folder --
build="$(mktemp -d)"
trap 'rm -rf "$build"' EXIT
cp "$CV_SRC_DIR/$CV_TEX" "$build/"

echo "Compiling $CV_TEX ..."
cd "$build"
if command -v latexmk >/dev/null 2>&1; then
  latexmk -pdf -interaction=nonstopmode -halt-on-error "$CV_TEX" >build.log 2>&1
else
  # two passes so \lastpage / references settle
  pdflatex -interaction=nonstopmode -halt-on-error "$CV_TEX" >build.log 2>&1
  pdflatex -interaction=nonstopmode -halt-on-error "$CV_TEX" >build.log 2>&1
fi

pdf="${CV_TEX%.tex}.pdf"
[[ -f "$pdf" ]] || { echo "ERROR: compile failed. Last log lines:"; tail -25 build.log; exit 1; }

# ---- publish ---------------------------------------------------------------
cp "$pdf" "$SITE_DIR/$DEST"
echo "Published -> $SITE_DIR/$DEST"

cd "$SITE_DIR"
if git diff --quiet -- "$DEST"; then
  echo "No change in $DEST; nothing to commit."
  exit 0
fi

git add "$DEST"
git commit -m "$COMMIT_MSG"
if [[ "$AUTO_PUSH" == "1" ]]; then
  git push
  echo "Pushed. GitHub Pages will redeploy in a minute or two."
else
  echo "Committed locally (push skipped; AUTO_PUSH=0)."
fi
