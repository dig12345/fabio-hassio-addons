#!/usr/bin/env bash
# Publish a new version of an addon: bump version, update changelog, bump repo version, commit & push.
#
# Usage:
#   ./scripts/publish-addon.sh <addon_slug> [new_version] [changelog_message]
#   ./scripts/publish-addon.sh syncthing
#   ./scripts/publish-addon.sh syncthing 2.0.15 "Fix media folder permissions"
#   ./scripts/publish-addon.sh syncthing 2.0.15 "Fix permissions" --no-push
#
#   # Addon uses upstream image (version must match existing tag): only bump repo + changelog
#   ./scripts/publish-addon.sh syncthing --changelog-only "Fix media permissions"
#
# If new_version is omitted (and not --changelog-only), the patch version is bumped (e.g. 2.0.14 -> 2.0.15).
# If changelog_message is omitted, the addon CHANGELOG gets "Addon release" for the new version.

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

ADDON_SLUG="${1:?Usage: $0 <addon_slug> [new_version] [changelog_message] [--no-push] [--changelog-only]}"
NEW_VERSION="$2"
CHANGELOG_MSG="$3"
NO_PUSH=""
CHANGELOG_ONLY=""
for arg in "$@"; do
  [[ "$arg" == --no-push ]] && NO_PUSH=1
  [[ "$arg" == --changelog-only ]] && CHANGELOG_ONLY=1
done
# If --changelog-only, shift so changelog_message is $2
[[ -n "$CHANGELOG_ONLY" ]] && CHANGELOG_MSG="$2"

CONFIG_YAML="$REPO_ROOT/$ADDON_SLUG/config.yaml"
CHANGELOG_MD="$REPO_ROOT/$ADDON_SLUG/CHANGELOG.md"
REPOSITORY_YAML="$REPO_ROOT/repository.yaml"

if [[ ! -f "$CONFIG_YAML" ]]; then
  echo "Error: addon config not found: $CONFIG_YAML"
  exit 1
fi

CURRENT_VERSION=$(grep -E '^version:\s*' "$CONFIG_YAML" | sed -E 's/version:\s*["]?([^"]*)["]?/\1/' | tr -d ' ')
if [[ -z "$CURRENT_VERSION" ]]; then
  echo "Error: could not read version from $CONFIG_YAML"
  exit 1
fi

if [[ -n "$CHANGELOG_ONLY" ]]; then
  NEW_VERSION="$CURRENT_VERSION"
  echo "Changelog-only: keeping version $CURRENT_VERSION (use when addon image tag is fixed upstream)"
elif [[ -z "$NEW_VERSION" ]]; then
  # Bump patch: 2.0.14 -> 2.0.15, 10.11.6 -> 10.11.7
  if [[ "$CURRENT_VERSION" =~ ^([0-9]+\.[0-9]+\.)([0-9]+)(.*)$ ]]; then
    PATCH="${BASH_REMATCH[2]}"
    REST="${BASH_REMATCH[3]}"
    NEW_VERSION="${BASH_REMATCH[1]}$((PATCH + 1))$REST"
  else
    echo "Error: cannot auto-bump version format: $CURRENT_VERSION (use X.Y.Z)"
    exit 1
  fi
  echo "Auto-bumped version: $CURRENT_VERSION -> $NEW_VERSION"
else
  echo "Publishing version: $NEW_VERSION (current: $CURRENT_VERSION)"
fi

if [[ -z "$CHANGELOG_MSG" ]]; then
  CHANGELOG_MSG="Addon release"
fi

# Update config.yaml version (skip when --changelog-only)
if [[ -z "$CHANGELOG_ONLY" ]]; then
  sed -i.bak -E "s/^(version:)\s*.*/\1 $NEW_VERSION/" "$CONFIG_YAML"
  rm -f "$CONFIG_YAML.bak"
fi

# Prepend new changelog section
if [[ -f "$CHANGELOG_MD" ]]; then
  NEW_HEADER="## $NEW_VERSION (addon)"
  ENTRY="$NEW_HEADER

- $CHANGELOG_MSG

"
  echo -n "$ENTRY" > "$CHANGELOG_MD.new"
  cat "$CHANGELOG_MD" >> "$CHANGELOG_MD.new"
  mv "$CHANGELOG_MD.new" "$CHANGELOG_MD"
  echo "Updated $CHANGELOG_MD"
else
  echo "Note: no CHANGELOG.md at $CHANGELOG_MD"
fi

# Bump repository version so HA store sees an update
if [[ -f "$REPOSITORY_YAML" ]] && grep -q '^version:' "$REPOSITORY_YAML"; then
  REPO_VER=$(grep -E '^version:\s*[0-9]+' "$REPOSITORY_YAML" | sed -E 's/version:\s*([0-9]+)/\1/' | tr -d ' ')
  NEXT_REPO_VER=$((REPO_VER + 1))
  sed -i.bak -E "s/^(version:)\s*[0-9]+/\1 $NEXT_REPO_VER/" "$REPOSITORY_YAML"
  rm -f "$REPOSITORY_YAML.bak"
  echo "Bumped repository version: $REPO_VER -> $NEXT_REPO_VER"
fi

# Commit and push
git add "$CONFIG_YAML"
[[ -f "$CHANGELOG_MD" ]] && git add "$CHANGELOG_MD"
[[ -f "$REPOSITORY_YAML" ]] && git add "$REPOSITORY_YAML"

COMMIT_MSG="$ADDON_SLUG: release $NEW_VERSION - $CHANGELOG_MSG"
[[ -n "$CHANGELOG_ONLY" ]] && COMMIT_MSG="$ADDON_SLUG: changelog - $CHANGELOG_MSG"
git commit -m "$COMMIT_MSG"

if [[ -n "$NO_PUSH" ]]; then
  echo "Committed (no push). Run: git push origin main"
else
  git push origin main
  echo "Pushed. Refresh the add-on store in HA to see the update."
fi
