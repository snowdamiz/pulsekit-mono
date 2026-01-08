# PulseKit SDKs

This directory contains the official PulseKit SDKs for multiple languages:

| SDK | Language | Directory |
|-----|----------|-----------|
| TypeScript/JavaScript | TypeScript | `typescript/` |
| Go | Go | `go/` |
| Rust | Rust | `rust/` |
| Elixir | Elixir | `elixir/` |

## Quick Start

### Building All SDKs

**Using Make (recommended):**
```bash
cd sdks
make install   # Install dependencies
make build     # Build all SDKs
```

**Using PowerShell (Windows):**
```powershell
cd sdks
.\build.ps1 install   # Install dependencies
.\build.ps1 build     # Build all SDKs
```

**Using Bash (Unix/macOS):**
```bash
cd sdks
chmod +x build.sh
./build.sh install   # Install dependencies
./build.sh build     # Build all SDKs
```

## Available Commands

| Command | Description |
|---------|-------------|
| `install` | Install dependencies for all SDKs |
| `build` | Build all SDKs |
| `test` | Run tests for all SDKs |
| `clean` | Clean all build artifacts |
| `build-ts` | Build TypeScript SDK only |
| `build-go` | Build Go SDK only |
| `build-rust` | Build Rust SDK only |
| `build-elixir` | Build Elixir SDK only |

## Requirements

To build all SDKs, you need:

- **Node.js 18+** (for TypeScript SDK)
- **Go 1.21+** (for Go SDK)
- **Rust 1.70+** (for Rust SDK)
- **Elixir 1.14+** (for Elixir SDK)

## SDK Documentation

Each SDK has its own README with detailed usage instructions:

- [TypeScript SDK](./typescript/README.md)
- [Go SDK](./go/README.md)
- [Rust SDK](./rust/README.md)
- [Elixir SDK](./elixir/README.md)

## Publishing

### TypeScript
```bash
cd typescript
npm publish --access public
```

### Go
The Go SDK is published automatically when tagged in the main repository.

### Rust
```bash
cd rust
cargo publish
```

### Elixir
```bash
cd elixir
mix hex.publish
```

