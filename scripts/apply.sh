#!/usr/bin/env bash
# Apply the Clodex look to a fresh Hermes checkout.
#
#   ./scripts/apply.sh              # clones into ~/Projects/hermes-clodex
#   ./scripts/apply.sh /path/dir    # or into a directory you name
#   ./scripts/apply.sh .            # apply to an existing checkout at BASE_SHA
#
# Needs Node >= 26 (the desktop app declares it) and pnpm. Expect ~5 minutes,
# most of it dependency install + the desktop build.
set -euo pipefail

BASE_SHA="3b42157858"
UPSTREAM="https://github.com/NousResearch/hermes-agent.git"
TARGET="${1:-$HOME/Projects/hermes-clodex}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

command -v git >/dev/null || die "git is required"
command -v pnpm >/dev/null || die "pnpm is required (npm is refused at the repo root)"
node -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 26 ? 0 : 1)' \
  || die "Node >= 26 is required (found $(node -v))"

if [[ "$TARGET" == "." ]]; then
  say "Applying patches to the current checkout"
  [[ -d .git ]] || die "not a git checkout"
  [[ "$(git rev-parse --short HEAD)" == "${BASE_SHA:0:10}" ]] \
    || die "this checkout is not at $BASE_SHA — clone fresh or check out that commit first"
else
  [[ -e "$TARGET" ]] && die "$TARGET already exists"
  say "Cloning hermes-agent into $TARGET"
  git clone --quiet "$UPSTREAM" "$TARGET"
  cd "$TARGET"
  git checkout --quiet "$BASE_SHA"
fi

say "Applying 6 patches"
for patch in "$HERE"/patches/*.patch; do
  printf '  %s\n' "$(basename "$patch")"
  git apply --whitespace=nowarn "$patch"
done

say "Installing dependencies (pnpm)"
pnpm install --frozen-lockfile

say "Building the desktop app"
( cd apps/desktop && npm run pack )

cat <<DONE

Done. The app is at:
  $TARGET/apps/desktop/release/mac-arm64/Hermes.app

Launch it, then in Appearance pick the "Clodex" theme. The look's layout is
already in the build; the theme only supplies the palette (the same one
skin/clodex.yaml carries for the no-build route).

To go back to stock: git checkout $BASE_SHA && pnpm install && npm run pack
DONE
