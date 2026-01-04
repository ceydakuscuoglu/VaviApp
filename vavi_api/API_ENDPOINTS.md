# VAVI API - Complete Endpoint Reference

Base URL: `http://127.0.0.1:3000` (or `http://localhost:3000`)

## Root Endpoints

- **GET** `/` - API information and version
- **GET** `/api` - List of all available API endpoints

## Company Endpoints

- **GET** `/api/companies` - Get all companies
- **GET** `/api/companies/<company_id>` - Get a specific company by ID
- **POST** `/api/companies` - Create a new company

### Example POST Request Body:
```json
{
  "companyName": "Example Company"
}
```

## Block Endpoints

- **GET** `/api/blocks` - Get all blocks
- **GET** `/api/blocks/<block_id>` - Get a specific block by ID
- **GET** `/api/blocks/company/<company_id>` - Get all blocks for a specific company
- **POST** `/api/blocks` - Create a new block

### Example POST Request Body:
```json
{
  "companyID": "123e4567-e89b-12d3-a456-426614174000",
  "blockName": "Building A"
}
```

## Place Endpoints

- **GET** `/api/places` - Get all places
- **GET** `/api/places/<place_id>` - Get a specific place by ID
- **GET** `/api/places/block/<block_id>` - Get all places for a specific block
- **POST** `/api/places` - Create a new place

### Example POST Request Body:
```json
{
  "blockID": "123e4567-e89b-12d3-a456-426614174000",
  "placeType": "Room",
  "floor": 1,
  "placeName": "Conference Room 101"
}
```

## Node Endpoints

- **GET** `/api/nodes` - Get all nodes
- **GET** `/api/nodes/<node_id>` - Get a specific node by ID
- **GET** `/api/nodes/place/<place_id>` - Get all nodes for a specific place
- **POST** `/api/nodes` - Create a new node

### Example POST Request Body:
```json
{
  "placeID": "123e4567-e89b-12d3-a456-426614174000",
  "positionX": 10.5,
  "positionY": 20.3,
  "positionZ": 0.0
}
```

## Edge Endpoints

- **GET** `/api/edges` - Get all edges
- **GET** `/api/edges/<edge_id>` - Get a specific edge by ID
- **GET** `/api/edges/node/<node_id>` - Get all edges connected to a node (as source or target)
- **POST** `/api/edges` - Create a new edge

### Example POST Request Body:
```json
{
  "edgeType": "Hallway",
  "sourceNodeID": "123e4567-e89b-12d3-a456-426614174000",
  "targetNodeID": "223e4567-e89b-12d3-a456-426614174001",
  "distance": 15.5
}
```

## Response Format

All endpoints return JSON responses. Success responses include the requested data, while error responses follow this format:

```json
{
  "error": "Error message here"
}
```

## Status Codes

- `200` - Success (GET requests)
- `201` - Created (POST requests)
- `404` - Not Found
- `500` - Server Error

## Notes

- All uniqueidentifier fields are returned as strings
- All decimal fields are returned as floats/doubles
- The API supports CORS for Flutter app requests
- For Android Emulator, use `http://10.0.2.2:3000` instead of `localhost`

