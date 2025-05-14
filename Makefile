.PHONY: setup setup-db build run-api run-workers clean format lint test

# Default target
all: build

# Setup the project
setup:
	@echo "Setting up the project..."
	@shards install
	@setup-db

setup-db:
	@crystal scripts/setup_db.cr	

# Build the applications
build:
	@echo "Building applications..."
	@mkdir -p bin
	@crystal build --release src/apps/api/main.cr -o bin/comixone-api
	@crystal build --release src/apps/workers/main.cr -o bin/comixone-workers
	@echo "Build completed successfully!"

# Run the API
run-api:
	@echo "Starting API..."
	@crystal src/apps/api/main.cr

# Run the Workers
run-workers:
	@echo "Starting Workers..."
	@crystal src/apps/workers/main.cr

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf bin
	@rm -rf .shards
	@rm -rf lib

# Run tests
test:
	@echo "Running tests..."
	@crystal spec

# Format code
format:
	@echo "Formatting code..."
	@crystal tool format

# Check code style
lint:
	@echo "Linting code..."
	@crystal tool format --check

# Show help
help:
	@echo "Available targets:"
	@echo "  setup        - Set up the project, install dependencies"
	@echo "  setup-db     - Set up database items"
	@echo "  build        - Build the applications"
	@echo "  run-api      - Run the API application"
	@echo "  run-workers  - Run the Workers application"
	@echo "  clean        - Clean build artifacts"
	@echo "  test         - Run tests"
	@echo "  format       - Format code"
	@echo "  lint         - Check code style"
