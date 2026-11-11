#!/usr/bin/env bash
# Publishes Quiet Home from the source repo to this repo. Run by .github/workflows/publish.yml.
#
#   .github/publish.sh SOURCE_DIR                    newest tag on each channel, if not yet published
#   .github/publish.sh SOURCE_DIR VERSION stable|beta  release/v<VERSION> at the tip of main or beta
#
# SOURCE_DIR: clone of the source repo with origin/main, origin/beta and tags. Tags vX.Y.Z are
# stable, vX.Y.Z-beta are beta; a tag not on its channel's branch (main or beta) is published from
# that branch's tip. The checks and copy are the source's tools/publish-release.sh.
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }
[[ $# -eq 1 || $# -eq 3 ]] || die "usage: $0 SOURCE_DIR [VERSION stable|beta]"
SRC=$1
DEST=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

branch_of() { if [[ $1 == stable ]]; then echo main; else echo beta; fi; }
current() { sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$DEST/$1.json" 2>/dev/null; }
newer() { [[ $1 != "$2" && $(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1) == "$1" ]]; }

# publish VERSION CHANNEL REF
publish() {
  local ver=$1 ch=$2 ref=$3 branch commit v
  branch=$(branch_of "$ch")
  commit=$(git -C "$SRC" rev-parse --verify -q "$ref^{commit}") || die "$ref not found"
  if ! git -C "$SRC" merge-base --is-ancestor "$commit" "origin/$branch"; then
    echo "$ref isn't on $branch: publishing from the tip of $branch"
    commit=$(git -C "$SRC" rev-parse "origin/$branch")
  fi
  git -C "$SRC" checkout -q --detach "$commit"
  v=$ver # a tag like v2.0.0 also finds release/v2.0
  while [[ ! -d $SRC/release/v$v && $v =~ ^(.+\.[0-9]+)\.0$ ]]; do v=${BASH_REMATCH[1]}; done
  if ! command -v aapt > /dev/null || ! command -v apksigner > /dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y -qq aapt apksigner > /dev/null
  fi
  "$SRC/tools/publish-release.sh" "$v" "$ch" "$DEST"
}

if [[ $# -eq 3 ]]; then
  [[ $3 == stable || $3 == beta ]] || die "channel must be stable or beta"
  publish "$2" "$3" "origin/$(branch_of "$3")"
  exit 0
fi

failed=0
for ch in stable beta; do
  if [[ $ch == stable ]]; then re='^[vV]([0-9]+(\.[0-9]+)*)$'; else re='^[vV]([0-9]+(\.[0-9]+)*)-beta$'; fi
  best= tag=
  for t in $(git -C "$SRC" tag -l); do
    [[ $t =~ $re ]] || continue
    if [[ -z $best ]] || newer "${BASH_REMATCH[1]}" "$best"; then best=${BASH_REMATCH[1]} tag=$t; fi
  done
  cur=$(current "$ch")
  if [[ -z $best ]]; then
    echo "$ch: no tags"
  elif [[ -n $cur ]] && ! newer "$best" "$cur"; then
    echo "$ch: $cur, up to date (newest tag $tag)"
  else
    echo "$ch: $cur -> $best ($tag)"
    ( publish "$best" "$ch" "refs/tags/$tag" ) || failed=1
  fi
done
exit $failed
