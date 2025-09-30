# Open-Ostrich

Open-source implementation of the OstrichDB database backend written in Odin.

## Overview

Open-OstrichDB is the open-source version of OstrichDB, a hierarchical NoSQL database system designed for efficient data organization and retrieval. This implementation provides the core database engine functionality with a RESTful API server, written entirely in the Odin programming language.

**Note:** This is the open-source reference implementation. The production OstrichDB backend is closed-source and may contain additional enterprise features.

## Architecture

OstrichDB uses a hierarchical data structure organized as:

```
Projects
  Collections
     Clusters
        Records
```

### Core Components

- **Engine** (`src/core/engine/`): Core database engine and data processing logic
- **Server** (`src/core/server/`): HTTP server with RESTful API endpoints
- **Data Layer** (`src/core/engine/data/`): Data structures and file operations for Collections, Clusters, and Records
- **Security** (`src/core/engine/security/`): Encryption, decryption, and key management
- **Configuration** (`src/core/config/`): Configuration management and dynamic path handling
- **Projects** (`src/core/engine/projects/`): Project lifecycle and user isolation
- **Library** (`src/library/`): Common types, utilities, and shared functionality

## Features

### Data Management
- **Hierarchical Organization**: Projects contain Collections, which contain Clusters of Records
- **Rich Data Types**: Support for strings, integers, floats, booleans, dates, arrays, and more
- **Flexible Querying**: Search, filter, and sort records with query parameters
- **User Isolation**: Multi-tenant architecture with user-specific project spaces

### Security
- **End-to-End Encryption**: Collections can be encrypted with user-specific master keys
- **JWT Authentication**: Token-based authentication for API access
- **Access Control**: User-based project ownership and access verification
- **Secure Operations**: Automatic encrypt/decrypt cycles for data operations

### API & Server
- **RESTful API**: Complete REST API with `/api/v1/` endpoints
- **CORS Support**: Configurable cross-origin resource sharing
- **Health Monitoring**: Built-in health check and server monitoring
- **Request Logging**: Comprehensive logging and audit trails

## API Endpoints

### Projects
- `GET /api/v1/projects` - List user's projects
- `POST /api/v1/projects/{name}` - Create new project
- `PUT /api/v1/projects/{name}?rename={newname}` - Rename project
- `DELETE /api/v1/projects/{name}` - Delete project

### Collections
- `GET /api/v1/projects/{project}/collections` - List collections in project
- `POST /api/v1/projects/{project}/collections/{name}` - Create collection
- `GET /api/v1/projects/{project}/collections/{name}` - Get collection info
- `PUT /api/v1/projects/{project}/collections/{name}?rename={newname}` - Rename collection
- `DELETE /api/v1/projects/{project}/collections/{name}` - Delete collection

### Clusters
- `GET /api/v1/projects/{project}/collections/{collection}/clusters` - List clusters
- `POST /api/v1/projects/{project}/collections/{collection}/clusters/{name}` - Create cluster
- `GET /api/v1/projects/{project}/collections/{collection}/clusters/{name}` - Get cluster data
- `PUT /api/v1/projects/{project}/collections/{collection}/clusters/{name}?rename={newname}` - Rename cluster
- `DELETE /api/v1/projects/{project}/collections/{collection}/clusters/{name}` - Delete cluster

### Records
- `GET /api/v1/projects/{project}/collections/{collection}/clusters/{cluster}/records` - List records
- `POST /api/v1/projects/{project}/collections/{collection}/clusters/{cluster}/records/{name}?type={TYPE}&value={value}` - Create record
- `GET /api/v1/projects/{project}/collections/{collection}/clusters/{cluster}/records/{id_or_name}` - Get specific record
- `PUT /api/v1/projects/{project}/collections/{collection}/clusters/{cluster}/records/{name}?{update_params}` - Update record
- `DELETE /api/v1/projects/{project}/collections/{collection}/clusters/{cluster}/records/{name}` - Delete record

### Filtering & Search
Records support advanced querying with parameters:
- `?type=STRING` - Filter by data type
- `?search=pattern` - Search in record names
- `?value=exact` - Match exact values
- `?valueContains=partial` - Partial value matching
- `?sortBy=name|value|type|id` - Sort results
- `?sortOrder=asc|desc` - Sort direction
- `?limit=N&offset=N` - Pagination

## Configuration

The server uses JSON configuration files in the `config/` directory:

- `development.json` - Development environment settings
- `production.json` - Production environment settings

Key configuration sections:
- **Server**: Port, host, connection limits
- **Database**: Storage paths, file size limits, backup settings
- **Security**: Encryption, authentication, rate limiting
- **CORS**: Cross-origin request handling
- **Logging**: Log levels, file rotation, audit trails

## Getting Started

### Prerequisites
- [Odin compiler](https://odin-lang.org/) installed
- Basic understanding of hierarchical database concepts

### Building and Running

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd Open-Ostrich
   ```

2. **Build and run the project**
   ```bash
   ./scripts/local_build.sh
   ```

The build script will compile the project and start the server on `localhost:8042` by default (configurable in `config/development.json`).

## Data Types

OstrichDB supports rich data types for records:

**Basic Types:**
- `CHAR`
- `STRING` / `STR` /
- `INTEGER` / `INT`
- `FLOAT` / `FLT`
- `BOOLEAN` / `BOOL`
- `DATE`,
- `TIME`,
- `DATETIME`
- `UUID`
- `NULL`

**Array Types:**
- `[]STRING`, `[]INTEGER`, `[]FLOAT`, `[]BOOLEAN`
- `[]DATE`, `[]TIME`, `[]DATETIME`, `[]UUID`
 Note: You can use the data type's shorthand e.g: `[]STR` or `[]INT`


## License

Copyright (c) 2025-Present Marshall A Burns and Archetype Dynamics, Inc.

Licensed under the Apache License, Version 2.0. See LICENSE.md for details.

---

**Note**: This open-source version provides the core OstrichDB functionality. For enterprise features and support, please contact Archetype Dynamics, Inc.