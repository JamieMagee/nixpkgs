#!/usr/bin/env nix-shell
#!nix-shell -i bash -p coreutils curl jq
set -euo pipefail

cd $(dirname "${BASH_SOURCE[0]}")

setKV () {
    sed -i "s|$2 = \".*\"|$2 = \"${3:-}\"|" $1
}

version=$(curl -s --show-error "https://api.github.com/repos/TriliumNext/Trilium/releases/latest" | jq -r '.tag_name' | tail -c +2)
setKV ./package.nix version $version

# Update desktop application
sha256_linux64=$(nix-prefetch-url --quiet https://github.com/TriliumNext/Trilium/releases/download/v${version}/TriliumNotes-v${version}-linux-x64.zip)
sha256_linux64_arm=$(nix-prefetch-url --quiet https://github.com/TriliumNext/Trilium/releases/download/v${version}/TriliumNotes-v${version}-linux-arm64.zip)
sha256_darwin64=$(nix-prefetch-url --quiet https://github.com/TriliumNext/Trilium/releases/download/v${version}/TriliumNotes-v${version}-macos-x64.zip)
sha256_darwin64_arm=$(nix-prefetch-url --quiet https://github.com/TriliumNext/Trilium/releases/download/v${version}/TriliumNotes-v${version}-macos-arm64.zip)
setKV ./package.nix x86_64-linux.sha256 $sha256_linux64
setKV ./package.nix aarch64-linux.sha256 $sha256_linux64_arm
setKV ./package.nix x86_64-darwin.sha256 $sha256_darwin64
setKV ./package.nix aarch64-darwin.sha256 $sha256_darwin64_arm

# Update server
sha256_linux64_server=$(nix-prefetch-url --quiet https://github.com/TriliumNext/Trilium/releases/download/v${version}/TriliumNotes-Server-v${version}-linux-x64.tar.xz)
sha256_linux64_server_arm=$(nix-prefetch-url --quiet https://github.com/TriliumNext/Trilium/releases/download/v${version}/TriliumNotes-Server-v${version}-linux-arm64.tar.xz)
setKV ../trilium-next-server/package.nix version $version
setKV ../trilium-next-server/package.nix serverSource_x64.sha256 $sha256_linux64_server
setKV ../trilium-next-server/package.nix serverSource_arm64.sha256 $sha256_linux64_server_arm
