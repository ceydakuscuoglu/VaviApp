# VAVI API - Python Flask Backend

This is the backend API for the VAVI (Voice Assistant for Visually Impaired) application.

## Setup

1. Install Python dependencies:
```bash
pip install -r requirements.txt
```

2. Configure database connection in `.env` file:
```
DB_SERVER=localhost
DB_NAME=VAVI
DB_USER=your_username
DB_PASSWORD=your_password
```

3. Make sure you have SQL Server running and accessible.

4. Run the API server:
```bash
python app.py
```

The API will run on `http://localhost:3000`

## API Endpoints

### Root & Info
- `GET /` - API info and version
- `GET /api` - List of all available API endpoints

### Companies
- `GET /api/companies` - Get all companies
- `GET /api/companies/<company_id>` - Get a specific company
- `POST /api/companies` - Create a new company

### Blocks
- `GET /api/blocks` - Get all blocks
- `GET /api/blocks/<block_id>` - Get a specific block
- `GET /api/blocks/company/<company_id>` - Get blocks by company
- `POST /api/blocks` - Create a new block

### Places
- `GET /api/places` - Get all places
- `GET /api/places/<place_id>` - Get a specific place
- `GET /api/places/block/<block_id>` - Get places by block
- `POST /api/places` - Create a new place

### Nodes
- `GET /api/nodes` - Get all nodes
- `GET /api/nodes/<node_id>` - Get a specific node
- `GET /api/nodes/place/<place_id>` - Get nodes by place
- `POST /api/nodes` - Create a new node

### Edges
- `GET /api/edges` - Get all edges
- `GET /api/edges/<edge_id>` - Get a specific edge
- `GET /api/edges/node/<node_id>` - Get edges connected to a node
- `POST /api/edges` - Create a new edge

## Notes

- Uniqueidentifier fields are converted to strings in JSON responses
- Decimal fields are converted to floats in JSON responses
- The API uses CORS to allow requests from the Flutter app

