# PulseKit SDK Build Script for Windows
# Usage: .\build.ps1 [command]
# Commands: install, build, test, clean, help

param(
    [Parameter(Position=0)]
    [string]$Command = "build"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Status { param([string]$msg) Write-Host $msg -ForegroundColor Cyan }
function Write-OK { param([string]$msg) Write-Host "✅ $msg" -ForegroundColor Green }

switch ($Command) {
    "help" {
        @"
PulseKit SDK Build System

Usage: .\build.ps1 [command]

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
"@
    }
    
    "install" {
        Write-Status "📦 Installing TypeScript SDK dependencies..."
        Push-Location "$ScriptDir\typescript"; npm install; Pop-Location
        
        Write-Status "📦 Installing Elixir SDK dependencies..."
        Push-Location "$ScriptDir\elixir"; mix deps.get; Pop-Location
        
        Write-OK "All SDK dependencies installed"
    }
    
    "build" {
        Write-Status "🔨 Building TypeScript SDK..."
        Push-Location "$ScriptDir\typescript"; npm run build; Pop-Location
        Write-OK "TypeScript SDK built"
        
        Write-Status "🔨 Building Go SDK..."
        Push-Location "$ScriptDir\go"; go build -v ./...; Pop-Location
        Write-OK "Go SDK built"
        
        Write-Status "🔨 Building Rust SDK..."
        Push-Location "$ScriptDir\rust"; cargo build --release; Pop-Location
        Write-OK "Rust SDK built"
        
        Write-Status "🔨 Building Elixir SDK..."
        Push-Location "$ScriptDir\elixir"; mix compile; Pop-Location
        Write-OK "Elixir SDK built"
        
        Write-Host ""
        Write-OK "All SDKs built successfully!"
        Write-Host ""
        Write-Host "SDK Artifacts:"
        Write-Host "  TypeScript: sdks/typescript/dist/"
        Write-Host "  Go:         sdks/go/ (ready to import)"
        Write-Host "  Rust:       sdks/rust/target/"
        Write-Host "  Elixir:     sdks/elixir/_build/"
    }
    
    "build-ts" {
        Write-Status "🔨 Building TypeScript SDK..."
        Push-Location "$ScriptDir\typescript"; npm run build; Pop-Location
        Write-OK "TypeScript SDK built"
    }
    
    "build-go" {
        Write-Status "🔨 Building Go SDK..."
        Push-Location "$ScriptDir\go"; go build -v ./...; Pop-Location
        Write-OK "Go SDK built"
    }
    
    "build-rust" {
        Write-Status "🔨 Building Rust SDK..."
        Push-Location "$ScriptDir\rust"; cargo build --release; Pop-Location
        Write-OK "Rust SDK built"
    }
    
    "build-elixir" {
        Write-Status "🔨 Building Elixir SDK..."
        Push-Location "$ScriptDir\elixir"; mix compile; Pop-Location
        Write-OK "Elixir SDK built"
    }
    
    "test" {
        Write-Status "🧪 Testing TypeScript SDK..."
        Push-Location "$ScriptDir\typescript"; npm run lint; Pop-Location
        
        Write-Status "🧪 Testing Go SDK..."
        Push-Location "$ScriptDir\go"; go test -v ./...; Pop-Location
        
        Write-Status "🧪 Testing Rust SDK..."
        Push-Location "$ScriptDir\rust"; cargo test; Pop-Location
        
        Write-Status "🧪 Testing Elixir SDK..."
        Push-Location "$ScriptDir\elixir"; mix test; Pop-Location
        
        Write-OK "All SDK tests passed!"
    }
    
    "clean" {
        Write-Status "🧹 Cleaning TypeScript SDK..."
        Remove-Item -Recurse -Force "$ScriptDir\typescript\dist" -ErrorAction SilentlyContinue
        Remove-Item -Recurse -Force "$ScriptDir\typescript\node_modules" -ErrorAction SilentlyContinue
        
        Write-Status "🧹 Cleaning Go SDK..."
        Push-Location "$ScriptDir\go"; go clean; Pop-Location
        
        Write-Status "🧹 Cleaning Rust SDK..."
        Remove-Item -Recurse -Force "$ScriptDir\rust\target" -ErrorAction SilentlyContinue
        
        Write-Status "🧹 Cleaning Elixir SDK..."
        Remove-Item -Recurse -Force "$ScriptDir\elixir\_build" -ErrorAction SilentlyContinue
        Remove-Item -Recurse -Force "$ScriptDir\elixir\deps" -ErrorAction SilentlyContinue
        
        Write-OK "All SDKs cleaned"
    }
    
    default {
        Write-Host "Unknown command: $Command"
        & $MyInvocation.MyCommand.Path help
    }
}
