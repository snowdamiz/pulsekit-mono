# PulseKit SDK Build System
# Usage: make build       - Build all SDKs
#        make build-ts    - Build TypeScript SDK only
#        make build-go    - Build Go SDK only
#        make build-rust  - Build Rust SDK only
#        make build-elixir - Build Elixir SDK only
#        make clean       - Clean all build artifacts
#        make test        - Run tests for all SDKs
#        make install     - Install dependencies for all SDKs

.PHONY: all build clean test install help
.PHONY: build-ts build-go build-rust build-elixir
.PHONY: test-ts test-go test-rust test-elixir
.PHONY: install-ts install-go install-rust install-elixir

# Default target
all: build

help:
	@echo "PulseKit SDK Build System"
	@echo ""
	@echo "Usage:"
	@echo "  make install   - Install dependencies for all SDKs"
	@echo "  make build     - Build all SDKs"
	@echo "  make test      - Run tests for all SDKs"
	@echo "  make clean     - Clean all build artifacts"
	@echo ""
	@echo "Individual SDK targets:"
	@echo "  make install-ts    - Install TypeScript SDK dependencies"
	@echo "  make build-ts      - Build TypeScript SDK"
	@echo "  make test-ts       - Test TypeScript SDK"
	@echo ""
	@echo "  make build-go      - Build/verify Go SDK"
	@echo "  make test-go       - Test Go SDK"
	@echo ""
	@echo "  make install-rust  - Install Rust SDK dependencies"
	@echo "  make build-rust    - Build Rust SDK"
	@echo "  make test-rust     - Test Rust SDK"
	@echo ""
	@echo "  make install-elixir - Install Elixir SDK dependencies"
	@echo "  make build-elixir  - Build Elixir SDK"
	@echo "  make test-elixir   - Test Elixir SDK"

# Install all dependencies
install: install-ts install-elixir
	@echo "✅ All SDK dependencies installed"

install-ts:
	@echo "📦 Installing TypeScript SDK dependencies..."
	cd typescript && npm install

install-rust:
	@echo "📦 Fetching Rust SDK dependencies..."
	cd rust && cargo fetch

install-elixir:
	@echo "📦 Installing Elixir SDK dependencies..."
	cd elixir && mix deps.get

# Build all SDKs
build: build-ts build-go build-rust build-elixir
	@echo ""
	@echo "✅ All SDKs built successfully!"
	@echo ""
	@echo "SDK Artifacts:"
	@echo "  TypeScript: sdks/typescript/dist/"
	@echo "  Go:         sdks/go/ (ready to import)"
	@echo "  Rust:       sdks/rust/target/"
	@echo "  Elixir:     sdks/elixir/_build/"

build-ts:
	@echo "🔨 Building TypeScript SDK..."
	cd typescript && npm run build
	@echo "✅ TypeScript SDK built"

build-go:
	@echo "🔨 Building Go SDK..."
	cd go && go build -v ./...
	@echo "✅ Go SDK built"

build-rust:
	@echo "🔨 Building Rust SDK..."
	cd rust && cargo build --release
	@echo "✅ Rust SDK built"

build-elixir:
	@echo "🔨 Building Elixir SDK..."
	cd elixir && mix compile
	@echo "✅ Elixir SDK built"

# Test all SDKs
test: test-ts test-go test-rust test-elixir
	@echo ""
	@echo "✅ All SDK tests passed!"

test-ts:
	@echo "🧪 Testing TypeScript SDK..."
	cd typescript && npm run lint
	@echo "✅ TypeScript SDK tests passed"

test-go:
	@echo "🧪 Testing Go SDK..."
	cd go && go test -v ./...
	@echo "✅ Go SDK tests passed"

test-rust:
	@echo "🧪 Testing Rust SDK..."
	cd rust && cargo test
	@echo "✅ Rust SDK tests passed"

test-elixir:
	@echo "🧪 Testing Elixir SDK..."
	cd elixir && mix test
	@echo "✅ Elixir SDK tests passed"

# Clean all build artifacts
clean:
	@echo "🧹 Cleaning TypeScript SDK..."
	rm -rf typescript/dist typescript/node_modules
	@echo "🧹 Cleaning Go SDK..."
	cd go && go clean
	@echo "🧹 Cleaning Rust SDK..."
	rm -rf rust/target
	@echo "🧹 Cleaning Elixir SDK..."
	rm -rf elixir/_build elixir/deps
	@echo "✅ All SDKs cleaned"

