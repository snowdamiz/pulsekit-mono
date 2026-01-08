#!/bin/bash
# PulseKit SDK Build Script for Unix/macOS
# Usage: ./build.sh [command]
# Commands: install, build, test, clean, help

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

status() {
    echo -e "${CYAN}$1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

show_help() {
    cat << EOF
PulseKit SDK Build System

Usage: ./build.sh [command]

Commands:
  install     - Install dependencies for all SDKs
  build       - Build all SDKs (default)
  test        - Run tests for all SDKs
  clean       - Clean all build artifacts
  help        - Show this help message

Individual SDK targets:
  build-ts      - Build TypeScript SDK only
  build-go      - Build Go SDK only
  build-rust    - Build Rust SDK only
  build-elixir  - Build Elixir SDK only
EOF
}

install_deps() {
    status "📦 Installing TypeScript SDK dependencies..."
    cd "$SCRIPT_DIR/typescript" && npm install
    
    status "📦 Installing Elixir SDK dependencies..."
    cd "$SCRIPT_DIR/elixir" && mix deps.get
    
    success "All SDK dependencies installed"
}

build_typescript() {
    status "🔨 Building TypeScript SDK..."
    cd "$SCRIPT_DIR/typescript" && npm run build
    success "TypeScript SDK built"
}

build_go() {
    status "🔨 Building Go SDK..."
    cd "$SCRIPT_DIR/go" && go build -v ./...
    success "Go SDK built"
}

build_rust() {
    status "🔨 Building Rust SDK..."
    cd "$SCRIPT_DIR/rust" && cargo build --release
    success "Rust SDK built"
}

build_elixir() {
    status "🔨 Building Elixir SDK..."
    cd "$SCRIPT_DIR/elixir" && mix compile
    success "Elixir SDK built"
}

build_all() {
    build_typescript
    build_go
    build_rust
    build_elixir
    
    echo ""
    success "All SDKs built successfully!"
    echo ""
    echo "SDK Artifacts:"
    echo "  TypeScript: sdks/typescript/dist/"
    echo "  Go:         sdks/go/ (ready to import)"
    echo "  Rust:       sdks/rust/target/"
    echo "  Elixir:     sdks/elixir/_build/"
}

test_all() {
    status "🧪 Testing TypeScript SDK..."
    cd "$SCRIPT_DIR/typescript" && npm run lint
    
    status "🧪 Testing Go SDK..."
    cd "$SCRIPT_DIR/go" && go test -v ./...
    
    status "🧪 Testing Rust SDK..."
    cd "$SCRIPT_DIR/rust" && cargo test
    
    status "🧪 Testing Elixir SDK..."
    cd "$SCRIPT_DIR/elixir" && mix test
    
    success "All SDK tests passed!"
}

clean_all() {
    status "🧹 Cleaning TypeScript SDK..."
    rm -rf "$SCRIPT_DIR/typescript/dist" "$SCRIPT_DIR/typescript/node_modules"
    
    status "🧹 Cleaning Go SDK..."
    cd "$SCRIPT_DIR/go" && go clean
    
    status "🧹 Cleaning Rust SDK..."
    rm -rf "$SCRIPT_DIR/rust/target"
    
    status "🧹 Cleaning Elixir SDK..."
    rm -rf "$SCRIPT_DIR/elixir/_build" "$SCRIPT_DIR/elixir/deps"
    
    success "All SDKs cleaned"
}

# Main execution
COMMAND="${1:-build}"

case "$COMMAND" in
    help)
        show_help
        ;;
    install)
        install_deps
        ;;
    build)
        build_all
        ;;
    test)
        test_all
        ;;
    clean)
        clean_all
        ;;
    build-ts)
        build_typescript
        ;;
    build-go)
        build_go
        ;;
    build-rust)
        build_rust
        ;;
    build-elixir)
        build_elixir
        ;;
    *)
        echo "Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac

