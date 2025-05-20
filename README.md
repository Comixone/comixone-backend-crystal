# comixone-backend

Backend applications for Comixone website

## Project Overview

This project consists of two main applications:

1. **API**: RESTful API service for the frontend application
2. **Workers**: Background job processing service

## Requirements

1. [Crystal language stack](https://crystal-lang.org/) (v1.16.2+)
2. [Kemal web framework](https://kemalcr.com/) for the API
3. [CouchDB database](https://couchdb.apache.org/) as the main database
4. [Dragonfly database](https://dragonflydb.io/) in memory database for fast access, caching, pub/sub

## Project Structure

```
comixone-backend/
├── config.yaml                 # Central configuration file
├── src/
│   ├── config.cr               # Configuration loader
│   ├── comixone-backend.cr     # Main entry point
│   ├── lib/                    # Shared libraries
│   │   ├── couchdb.cr          # CouchDB driver
│   │   └── dragonfly.cr        # Dragonfly (Redis) driver
│   └── apps/
│       ├── api/                # API application
│       │   ├── main.cr         # API entry point
│       │   ├── comixone-api.cr # API application class
│       │   ├── routing/        # API route definitions
│       │   │   ├── base.cr     # Base router class
│       │   │   ├── registry.cr # Router registry
│       │   │   ├── core_router.cr # Core application routes
│       │   │   └── ..._router.cr # Add your routers here
│       │   └── handlers/       # API request handlers
│       │       ├── base.cr     # Base handler class
│       │       ├── root_handler.cr # Handler for root route
│       │       ├── healthcheck_handler.cr # Handler for health checks
│       │       ├── manifest_handler.cr # Handler for manifest
│       │       └── v1/      # V1 namespace
│       │           └── ... # Namespace for sub group, ex.: posts
│       │           	└── ..._handler.cr  # Handler class for sub group, ex.: list_handler
│       └── workers/            # Workers application
│           ├── main.cr         # Workers entry point
│           ├── comixone-workers.cr # Workers application class
│           └── jobs/           # Background jobs
├── scripts/                    # Utility scripts
├── spec/                       # Tests
├── Dockerfile                  # Container definition
└── docker-compose.yml          # Docker compose for local development
```

## Installation

### Install dependencies

```bash
shards install
```

### Configure the application

Copy the example configuration file and adjust as needed:

```bash
cp config.yaml.example config.yaml
```

Edit `config.yaml` to match your environment.

## Running the Application

#### 1. Setup the database

Make sure CouchDB and Dragonfly are running, then run:

```bash
make setup
```

#### 2. Run the API

```bash
make run-api
```

#### 3. Run the Workers (in a separate terminal)

```bash
make run-worker
```

## API Endpoints

### Core Endpoints

- `GET /` - Welcome message
- `GET /healthz` - Health check endpoint (returns `ok` if all services are healthy)
- `GET /manifest` - Application manifest with version and dependency information

## Response Format

All API responses (except `/healthz`) follow this format:

```json
{
  "error": {
    "code": "E_NOT_FOUND",
    "message": "Resource not found"
  },
  "status": "CLIENT_ERROR", // SYSTEM_ERROR, OK
  "body": null,
  "route": "/some/route",
  "handler": "Comixone::Api::Handlers::Posts::GetHandler#handle",

  "debug": {
    "request": {
       "ip": "client ip here",
       "method": "GET",
       "headers": [{ "key": "Content-Type", "value": "text/html" }],
	   "url": {
         "proto": "http",
         "host": "localhost",
         "port": 3000,
         "uri": "/api/posts"
       },
       "query": [{ "key": "offset", "value": "0" }],
       "body": {}
    },
    "info": {
      "timestamp": "2025-01-01 12:00:00",
      "server": "comixone-api",
      "version": "0.1.0"
    }
  } // Only included if ?debug=true is in the URL
}
```

## Code Organization

### Routing

Routes are defined in the `src/apps/api/routing` directory. Each resource has its own router class that inherits from `Routing::Base`. Routes are registered in the `Routing::Registry` which is called during application initialization.

### Handlers

Each API endpoint has a dedicated handler in the `src/apps/api/handlers` directory. Handlers are organized by resource, with each HTTP method having its own handler class that inherits from `Handlers::Base`.

The separation of routing and handlers follows the Single Responsibility Principle:
- Routers are responsible for defining URL patterns and HTTP methods
- Handlers are responsible for processing the request and generating a response

### Workers

The workers application runs background jobs:

- **Cleanup Job**: Runs on a configurable interval to clean up stale data

## Contributing

1. Fork it (<https://github.com/Comixone/comixone-backend/fork>)
2. Create your feature branch (`git checkout -b feat/something`)
3. Commit your changes (`git commit -S -am 'Add some feature' --signoff`)
4. Push to the branch (`git push origin feat/something`)
5. Create a new Pull Request

## Contributors

- [Anar K. Jafarov](https://github.com/num8er) - creator and maintainer# comixone-backend

Backend applications for Comixone website

## Project Overview

This project consists of two main applications:

1. **API**: RESTful API service for the frontend application
2. **Workers**: Background job processing service

## Requirements

1. [Crystal language stack](https://crystal-lang.org/) (v1.16.2+)
2. [Kemal web framework](https://kemalcr.com/) for the API
3. [CouchDB database](https://couchdb.apache.org/) as the main database
4. [Dragonfly database](https://dragonflydb.io) as active database for read operations (sync from main)