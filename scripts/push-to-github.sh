#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

OWNER="${1:-}"
REPO_NAME="sampan"
TAG="${2:-v1.0.0}"

echo "======================================================"
echo "⛵ Sampan (সাম্পান) — GitHub Repository Publisher"
echo "======================================================"

echo "[1/4] Running automated verification suite..."
node scripts/verify-all.mjs

echo "[2/4] Checking GitHub CLI authentication..."
if ! gh auth status >/dev/null 2>&1; then
  echo "GitHub CLI session expired or missing. Launching 'gh auth login'..."
  gh auth login -h github.com -p https -w
fi

if [[ -z "$OWNER" ]]; then
  OWNER="$(gh api user --jq '.login')"
fi

FULL_REPO="${OWNER}/${REPO_NAME}"
REMOTE_URL="https://github.com/${FULL_REPO}.git"

echo "[3/4] Ensuring public repository '${FULL_REPO}' exists..."
if ! gh repo view "$FULL_REPO" >/dev/null 2>&1; then
  gh repo create "$FULL_REPO" \
    --public \
    --description "Sampan (সাম্পান) — Local-First, Zero-Cloud P2P Mesh for Travel & Co-Presence (BLE + SoftAP Hub)" \
    --source=. \
    --remote=origin
else
  if git remote get-url origin >/dev/null 2>&1; then
    git remote set-url origin "$REMOTE_URL"
  else
    git remote add origin "$REMOTE_URL"
  fi
fi

echo "[4/4] Pushing branch and tag (${TAG})..."
BRANCH="$(git branch --show-current)"
git push -u origin "$BRANCH"

if ! git rev-parse "$TAG" >/dev/null 2>&1; then
  git tag -a "$TAG" -m "Sampan ${TAG} — Initial Local-First P2P Mesh Release"
fi
git push origin "$TAG"

echo "✅ Pushed to https://github.com/${FULL_REPO}"
