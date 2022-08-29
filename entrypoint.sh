#!/bin/bash

set -e

if [[ -z $INPUT_GITHUB_TOKEN ]]; then
  echo 'Missing input "github_token".' >&2
  exit 1
fi

echo "Configuring Git username, email, and pull behavior..."
git config --local user.name "${INPUT_GIT_NAME}"
git config --local user.email "${INPUT_GIT_EMAIL}"
git config --local pull.rebase true
echo "Git name: $(git config --get user.name)"
echo "Git email: $(git config --get user.email)"

PIP_CMD=('pip' 'install')
if [[ $INPUT_COMMITIZEN_VERSION == 'latest' ]]; then
  PIP_CMD+=('commitizen')
else
  PIP_CMD+=("commitizen==${INPUT_COMMITIZEN_VERSION}")
fi
IFS=" " read -r -a INPUT_EXTRA_REQUIREMENTS <<<"$INPUT_EXTRA_REQUIREMENTS"
PIP_CMD+=("${INPUT_EXTRA_REQUIREMENTS[@]}")
echo "${PIP_CMD[@]}"
"${PIP_CMD[@]}"
echo "Commitizen version: $(cz version)"

PREV_REV="$(cz version --project)"

CZ_CMD=('cz')
if [[ $INPUT_NO_RAISE ]]; then
  CZ_CMD+=('--no-raise' "$INPUT_NO_RAISE")
fi
CZ_CMD+=('bump' '--yes')
if [[ $INPUT_DRY_RUN == 'true' ]]; then
  CZ_CMD+=('--dry-run')
fi
if [[ $INPUT_CHANGELOG == 'true' ]]; then
  CZ_CMD+=('--changelog')
fi
if [[ $INPUT_PRERELEASE ]]; then
  CZ_CMD+=('--prerelease' "$INPUT_PRERELEASE")
fi
if [[ $INPUT_COMMIT == 'false' ]]; then
  CZ_CMD+=('--files-only')
fi
if [[ $INPUT_INCREMENT ]]; then
  CZ_CMD+=('--increment' "$INPUT_INCREMENT")
fi
if [[ $INPUT_CHANGELOG_INCREMENT_FILENAME ]]; then
  CZ_CMD+=('--changelog-to-stdout')
  echo "${CZ_CMD[@]}" ">$INPUT_CHANGELOG_INCREMENT_FILENAME"
  "${CZ_CMD[@]}" >"$INPUT_CHANGELOG_INCREMENT_FILENAME"
else
  echo "${CZ_CMD[@]}"
  "${CZ_CMD[@]}"
fi

REV="$(cz version --project)"
if [[ $REV == "$PREV_REV" ]]; then
  INPUT_PUSH='false'
fi
echo "REVISION=${REV}" >>"$GITHUB_ENV"
echo "::set-output name=version::${REV}"

CURRENT_BRANCH="$(git branch --show-current)"
INPUT_BRANCH="${INPUT_BRANCH:-$CURRENT_BRANCH}"
INPUT_REPOSITORY="${INPUT_REPOSITORY:-$GITHUB_REPOSITORY}"
INPUT_GITHUB_ACTOR=${INPUT_GITHUB_ACTOR:-$GITHUB_ACTOR}

echo "Repository: ${INPUT_REPOSITORY}"
echo "Actor: ${GITHUB_ACTOR}"

if [[ $INPUT_PUSH == 'true' ]]; then
  if [[ $INPUT_MERGE != 'true' && $GITHUB_EVENT_NAME == 'pull_request' ]]; then
    echo "Refusing to push on pull_request event since that would merge the pull request." >&2
    echo "You probably want to run on push to your default branch instead." >&2
  else
    echo "Pushing to branch..."
    REMOTE_REPO="https://${INPUT_GITHUB_ACTOR}:${INPUT_GITHUB_TOKEN}@github.com/${INPUT_REPOSITORY}.git"
    git pull "$REMOTE_REPO" "$INPUT_BRANCH"
    git push "$REMOTE_REPO" "HEAD:${INPUT_BRANCH}" --tags
  fi
else
  echo "Not pushing"
fi
echo "Done."
