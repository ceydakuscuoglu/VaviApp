# VAVI API - Quick Reference

## Server Status
- **Local Development**: `http://127.0.0.1:3000` or `http://localhost:3000`
- **Android Emulator**: `http://10.0.2.2:3000`

## Available Endpoints

### Root
- `GET /` - API info
- `GET /api` - Endpoints list

### Companies
- `GET /api/companies` - List all
- `GET /api/companies/{id}` - Get one
- `POST /api/companies` - Create

### Blocks
- `GET /api/blocks` - List all
- `GET /api/blocks/{id}` - Get one
- `GET /api/blocks/company/{companyId}` - Get by company
- `POST /api/blocks` - Create

### Places
- `GET /api/places` - List all
- `GET /api/places/{id}` - Get one
- `GET /api/places/block/{blockId}` - Get by block
- `POST /api/places` - Create

### Nodes
- `GET /api/nodes` - List all
- `GET /api/nodes/{id}` - Get one
- `GET /api/nodes/place/{placeId}` - Get by place
- `POST /api/nodes` - Create

### Edges
- `GET /api/edges` - List all
- `GET /api/edges/{id}` - Get one
- `GET /api/edges/node/{nodeId}` - Get by node
- `POST /api/edges` - Create

## Flutter Integration

The Flutter app uses `ApiService` class in `lib/services/api_service.dart`:
- Base URL: `http://10.0.2.2:3000/api` (Android Emulator)
- All endpoints are implemented with GET and POST methods
- Models are in `lib/models/` directory

## Testing

Test endpoints using:
- Browser: Navigate to `http://127.0.0.1:3000/`
- Postman/Insomnia: Use the endpoints above
- Flutter: Use `ApiService` methods

