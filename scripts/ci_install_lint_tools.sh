#!/usr/bin/env bash
# Install pinned CI lint tools (Rojo, StyLua, selene, luau-lsp) and globalTypes.
# Uses the official GitHub Releases API asset route (Accept: application/octet-stream)
# and verifies each release zip against the digest published on the release asset.
# Falls back to browser_download_url only if the API download fails.

set -euo pipefail

# GitHub CLI reads GH_TOKEN; Actions injects GITHUB_TOKEN automatically.
export GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"

: "${ROJO:?}"
: "${STYLUA:?}"
: "${SELENE:?}"
: "${LUAU_LSP_VERSION:?}"

TOOLS_ROOT="${RUNNER_TEMP:?}/ci-lint-tools"
BIN="$TOOLS_ROOT/bin"
mkdir -p "$BIN"

download_release_zip() {
	local repo="$1" tag="$2" asset_name="$3" digest="$4"
	local zip="$TOOLS_ROOT/${asset_name}"
	local asset_id url
	asset_id="$(gh api "repos/${repo}/releases/tags/${tag}" --jq ".assets[] | select(.name==\"${asset_name}\") | .id")"
	if [[ -z "$asset_id" || "$asset_id" == "null" ]]; then
		echo "Release asset not found: ${repo} ${tag} ${asset_name}" >&2
		exit 1
	fi
	url="$(gh api "repos/${repo}/releases/tags/${tag}" --jq ".assets[] | select(.name==\"${asset_name}\") | .browser_download_url")"
	local -a auth
	if [[ -n "${GITHUB_TOKEN:-}" ]]; then
		auth=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
	fi
	if ! curl -fsSL "${auth[@]}" -H "Accept: application/octet-stream" \
		"https://api.github.com/repos/${repo}/releases/assets/${asset_id}" \
		-o "$zip"; then
		echo "API asset download failed for ${asset_name}; trying release CDN URL." >&2
		curl -fsSL --retry 3 --retry-delay 5 --retry-all-errors "${auth[@]}" "$url" -o "$zip"
	fi
	local expected="${digest#sha256:}"
	echo "${expected}  ${zip}" | sha256sum -c -
	unzip -oq "$zip" -d "$BIN"
}

download_global_types() {
	local out="$TOOLS_ROOT/globalTypes.d.luau"
	local -a auth
	if [[ -n "${GITHUB_TOKEN:-}" ]]; then
		auth=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
	fi
	if ! curl -fsSL --retry 3 --retry-delay 5 --retry-all-errors "${auth[@]}" \
		"https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/${LUAU_LSP_VERSION}/scripts/globalTypes.d.luau" \
		-o "$out"; then
		gh api "repos/JohnnyMorganz/luau-lsp/contents/scripts/globalTypes.d.luau?ref=${LUAU_LSP_VERSION}" \
			-H "Accept: application/vnd.github.raw" >"$out"
	fi
	test -s "$out"
}

# Digests from GitHub release metadata for these exact asset names (2026-11-08).
download_release_zip rojo-rbx/rojo "v${ROJO}" "rojo-${ROJO}-linux-x86_64.zip" \
	sha256:a9542a713036897fdbd0173e7a105ea409658333133c949025fcb6f1a7ca909d
download_release_zip JohnnyMorganz/StyLua "v${STYLUA}" "stylua-linux-x86_64.zip" \
	sha256:a485f72bbfa22e4642e77a84b5edc2611a5cab7477b34e2e709dd8f78e919895
download_release_zip Kampfkarren/selene "${SELENE}" "selene-${SELENE}-linux.zip" \
	sha256:d3773393578580074386e69337d35b7acddfbaa9fc38964c07fa3e28436ade9b
download_release_zip JohnnyMorganz/luau-lsp "${LUAU_LSP_VERSION}" "luau-lsp-linux-x86_64.zip" \
	sha256:4ff08890ea0d4b6d9de25fdff1a4c87e0dc9f2e45d782c894e83475e51d55813
download_global_types
chmod +x "$BIN"/*

if [[ -n "${GITHUB_PATH:-}" ]]; then
	echo "$BIN" >>"$GITHUB_PATH"
fi
if [[ -n "${GITHUB_ENV:-}" ]]; then
	echo "GLOBAL_TYPES_PATH=$TOOLS_ROOT/globalTypes.d.luau" >>"$GITHUB_ENV"
fi

"$BIN/rojo" --version
"$BIN/stylua" --version
"$BIN/selene" --version
"$BIN/luau-lsp" --version
