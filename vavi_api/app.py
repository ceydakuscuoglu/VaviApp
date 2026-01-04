from flask import Flask, jsonify, request
from flask_cors import CORS
import pymssql
import os
from dotenv import load_dotenv
import uuid

# Load environment variables
load_dotenv()

app = Flask(__name__)
CORS(app)

# Database configuration from .env
DB_CONFIG = {
    'server': os.getenv('DB_SERVER', 'localhost'),
    'database': os.getenv('DB_NAME', 'VAVI'),
    'user': os.getenv('DB_USER', ''),
    'password': os.getenv('DB_PASSWORD', ''),
}

def get_db_connection():
    """Create and return a database connection"""
    try:
        # Support Windows Authentication if no user/password provided
        if DB_CONFIG['user'] and DB_CONFIG['password']:
            conn = pymssql.connect(
                server=DB_CONFIG['server'],
                database=DB_CONFIG['database'],
                user=DB_CONFIG['user'],
                password=DB_CONFIG['password']
            )
        else:
            # Try Windows Authentication (trusted connection)
            # Note: pymssql doesn't support Windows Auth directly, so user/password is required
            # If you need Windows Auth, you'll need to use pyodbc instead
            raise Exception("Database credentials (DB_USER and DB_PASSWORD) are required in .env file")
        return conn
    except Exception as e:
        print(f"Database connection error: {str(e)}")
        print(f"Attempted connection to: Server={DB_CONFIG['server']}, Database={DB_CONFIG['database']}")
        raise

def convert_uniqueidentifier_to_string(value):
    """Convert uniqueidentifier to string"""
    if value is None:
        return None
    return str(value)

def convert_decimal_to_float(value):
    """Convert decimal to float"""
    if value is None:
        return None
    return float(value)

# ==================== ROOT & HEALTH CHECK ====================

@app.route('/', methods=['GET'])
def root():
    """Root endpoint"""
    return jsonify({
        'message': 'VAVI API is running',
        'version': '1.0.0',
        'endpoints': {
            'companies': '/api/companies',
            'blocks': '/api/blocks',
            'places': '/api/places',
            'nodes': '/api/nodes',
            'edges': '/api/edges'
        }
    }), 200

@app.route('/api', methods=['GET'])
def api_root():
    """API root endpoint"""
    return jsonify({
        'message': 'VAVI API',
        'endpoints': {
            'companies': '/api/companies',
            'blocks': '/api/blocks',
            'places': '/api/places',
            'nodes': '/api/nodes',
            'edges': '/api/edges'
        }
    }), 200

# ==================== COMPANY ENDPOINTS ====================

@app.route('/api/companies', methods=['GET'])
def get_companies():
    """Get all companies"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT CompanyID, CompanyName FROM Company")
        rows = cursor.fetchall()
        
        companies = []
        for row in rows:
            companies.append({
                'companyID': convert_uniqueidentifier_to_string(row[0]),
                'companyName': row[1]
            })
        
        cursor.close()
        conn.close()
        return jsonify(companies), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/companies', methods=['POST'])
def create_company():
    """Create a new company"""
    try:
        data = request.get_json()
        company_id = str(uuid.uuid4())
        company_name = data.get('companyName')
        
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO Company (CompanyID, CompanyName) VALUES (%s, %s)",
            (company_id, company_name)
        )
        conn.commit()
        cursor.close()
        conn.close()
        
        return jsonify({
            'companyID': company_id,
            'companyName': company_name
        }), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/companies/<company_id>', methods=['GET'])
def get_company(company_id):
    """Get a specific company by ID"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "SELECT CompanyID, CompanyName FROM Company WHERE CompanyID = %s",
            (company_id,)
        )
        row = cursor.fetchone()
        
        if row:
            company = {
                'companyID': convert_uniqueidentifier_to_string(row[0]),
                'companyName': row[1]
            }
            cursor.close()
            conn.close()
            return jsonify(company), 200
        else:
            cursor.close()
            conn.close()
            return jsonify({'error': 'Company not found'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ==================== BLOCK ENDPOINTS ====================

@app.route('/api/blocks', methods=['GET'])
def get_blocks():
    """Get all blocks"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT BlockID, CompanyID, BlockName FROM Block")
        rows = cursor.fetchall()
        
        blocks = []
        for row in rows:
            blocks.append({
                'blockID': convert_uniqueidentifier_to_string(row[0]),
                'companyID': convert_uniqueidentifier_to_string(row[1]),
                'blockName': row[2]
            })
        
        cursor.close()
        conn.close()
        return jsonify(blocks), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/blocks', methods=['POST'])
def create_block():
    """Create a new block"""
    try:
        data = request.get_json()
        block_id = str(uuid.uuid4())
        company_id = data.get('companyID')
        block_name = data.get('blockName')
        
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO Block (BlockID, CompanyID, BlockName) VALUES (%s, %s, %s)",
            (block_id, company_id, block_name)
        )
        conn.commit()
        cursor.close()
        conn.close()
        
        return jsonify({
            'blockID': block_id,
            'companyID': company_id,
            'blockName': block_name
        }), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/blocks/<block_id>', methods=['GET'])
def get_block(block_id):
    """Get a specific block by ID"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "SELECT BlockID, CompanyID, BlockName FROM Block WHERE BlockID = %s",
            (block_id,)
        )
        row = cursor.fetchone()
        
        if row:
            block = {
                'blockID': convert_uniqueidentifier_to_string(row[0]),
                'companyID': convert_uniqueidentifier_to_string(row[1]),
                'blockName': row[2]
            }
            cursor.close()
            conn.close()
            return jsonify(block), 200
        else:
            cursor.close()
            conn.close()
            return jsonify({'error': 'Block not found'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/blocks/company/<company_id>', methods=['GET'])
def get_blocks_by_company(company_id):
    """Get all blocks for a specific company"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "SELECT BlockID, CompanyID, BlockName FROM Block WHERE CompanyID = %s",
            (company_id,)
        )
        rows = cursor.fetchall()
        
        blocks = []
        for row in rows:
            blocks.append({
                'blockID': convert_uniqueidentifier_to_string(row[0]),
                'companyID': convert_uniqueidentifier_to_string(row[1]),
                'blockName': row[2]
            })
        
        cursor.close()
        conn.close()
        return jsonify(blocks), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ==================== PLACE ENDPOINTS ====================

@app.route('/api/places', methods=['GET'])
def get_places():
    """Get all places"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT PlaceID, BlockID, PlaceType, Floor, PlaceName FROM Place")
        rows = cursor.fetchall()
        
        places = []
        for row in rows:
            places.append({
                'placeID': convert_uniqueidentifier_to_string(row[0]),
                'blockID': convert_uniqueidentifier_to_string(row[1]),
                'placeType': row[2],
                'floor': row[3],
                'placeName': row[4]
            })
        
        cursor.close()
        conn.close()
        return jsonify(places), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/places', methods=['POST'])
def create_place():
    """Create a new place"""
    try:
        data = request.get_json()
        place_id = str(uuid.uuid4())
        block_id = data.get('blockID')
        place_type = data.get('placeType')
        floor = data.get('floor')
        place_name = data.get('placeName')
        
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO Place (PlaceID, BlockID, PlaceType, Floor, PlaceName) VALUES (%s, %s, %s, %s, %s)",
            (place_id, block_id, place_type, floor, place_name)
        )
        conn.commit()
        cursor.close()
        conn.close()
        
        return jsonify({
            'placeID': place_id,
            'blockID': block_id,
            'placeType': place_type,
            'floor': floor,
            'placeName': place_name
        }), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/places/<place_id>', methods=['GET'])
def get_place(place_id):
    """Get a specific place by ID"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "SELECT PlaceID, BlockID, PlaceType, Floor, PlaceName FROM Place WHERE PlaceID = %s",
            (place_id,)
        )
        row = cursor.fetchone()
        
        if row:
            place = {
                'placeID': convert_uniqueidentifier_to_string(row[0]),
                'blockID': convert_uniqueidentifier_to_string(row[1]),
                'placeType': row[2],
                'floor': row[3],
                'placeName': row[4]
            }
            cursor.close()
            conn.close()
            return jsonify(place), 200
        else:
            cursor.close()
            conn.close()
            return jsonify({'error': 'Place not found'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/places/block/<block_id>', methods=['GET'])
def get_places_by_block(block_id):
    """Get all places for a specific block"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "SELECT PlaceID, BlockID, PlaceType, Floor, PlaceName FROM Place WHERE BlockID = %s",
            (block_id,)
        )
        rows = cursor.fetchall()
        
        places = []
        for row in rows:
            places.append({
                'placeID': convert_uniqueidentifier_to_string(row[0]),
                'blockID': convert_uniqueidentifier_to_string(row[1]),
                'placeType': row[2],
                'floor': row[3],
                'placeName': row[4]
            })
        
        cursor.close()
        conn.close()
        return jsonify(places), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ==================== NODE ENDPOINTS ====================

@app.route('/api/nodes', methods=['GET'])
def get_nodes():
    """Get all nodes"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT NodeID, PlaceID, PositionX, PositionY, PositionZ FROM Node")
        rows = cursor.fetchall()
        
        nodes = []
        for row in rows:
            nodes.append({
                'nodeID': convert_uniqueidentifier_to_string(row[0]),
                'placeID': convert_uniqueidentifier_to_string(row[1]),
                'positionX': convert_decimal_to_float(row[2]),
                'positionY': convert_decimal_to_float(row[3]),
                'positionZ': convert_decimal_to_float(row[4])
            })
        
        cursor.close()
        conn.close()
        return jsonify(nodes), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/nodes', methods=['POST'])
def create_node():
    """Create a new node"""
    try:
        data = request.get_json()
        node_id = str(uuid.uuid4())
        place_id = data.get('placeID')
        position_x = data.get('positionX')
        position_y = data.get('positionY')
        position_z = data.get('positionZ')
        
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO Node (NodeID, PlaceID, PositionX, PositionY, PositionZ) VALUES (%s, %s, %s, %s, %s)",
            (node_id, place_id, position_x, position_y, position_z)
        )
        conn.commit()
        cursor.close()
        conn.close()
        
        return jsonify({
            'nodeID': node_id,
            'placeID': place_id,
            'positionX': position_x,
            'positionY': position_y,
            'positionZ': position_z
        }), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/nodes/<node_id>', methods=['GET'])
def get_node(node_id):
    """Get a specific node by ID"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "SELECT NodeID, PlaceID, PositionX, PositionY, PositionZ FROM Node WHERE NodeID = %s",
            (node_id,)
        )
        row = cursor.fetchone()
        
        if row:
            node = {
                'nodeID': convert_uniqueidentifier_to_string(row[0]),
                'placeID': convert_uniqueidentifier_to_string(row[1]),
                'positionX': convert_decimal_to_float(row[2]),
                'positionY': convert_decimal_to_float(row[3]),
                'positionZ': convert_decimal_to_float(row[4])
            }
            cursor.close()
            conn.close()
            return jsonify(node), 200
        else:
            cursor.close()
            conn.close()
            return jsonify({'error': 'Node not found'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/nodes/place/<place_id>', methods=['GET'])
def get_nodes_by_place(place_id):
    """Get all nodes for a specific place"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "SELECT NodeID, PlaceID, PositionX, PositionY, PositionZ FROM Node WHERE PlaceID = %s",
            (place_id,)
        )
        rows = cursor.fetchall()
        
        nodes = []
        for row in rows:
            nodes.append({
                'nodeID': convert_uniqueidentifier_to_string(row[0]),
                'placeID': convert_uniqueidentifier_to_string(row[1]),
                'positionX': convert_decimal_to_float(row[2]),
                'positionY': convert_decimal_to_float(row[3]),
                'positionZ': convert_decimal_to_float(row[4])
            })
        
        cursor.close()
        conn.close()
        return jsonify(nodes), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ==================== EDGE ENDPOINTS ====================

@app.route('/api/edges', methods=['GET'])
def get_edges():
    """Get all edges"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT EdgeID, EdgeType, SourceNodeID, TargetNodeID, Distance FROM Edge")
        rows = cursor.fetchall()
        
        edges = []
        for row in rows:
            edges.append({
                'edgeID': convert_uniqueidentifier_to_string(row[0]),
                'edgeType': row[1],
                'sourceNodeID': convert_uniqueidentifier_to_string(row[2]),
                'targetNodeID': convert_uniqueidentifier_to_string(row[3]),
                'distance': convert_decimal_to_float(row[4])
            })
        
        cursor.close()
        conn.close()
        return jsonify(edges), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/edges', methods=['POST'])
def create_edge():
    """Create a new edge"""
    try:
        data = request.get_json()
        edge_id = str(uuid.uuid4())
        edge_type = data.get('edgeType')
        source_node_id = data.get('sourceNodeID')
        target_node_id = data.get('targetNodeID')
        distance = data.get('distance')
        
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO Edge (EdgeID, EdgeType, SourceNodeID, TargetNodeID, Distance) VALUES (%s, %s, %s, %s, %s)",
            (edge_id, edge_type, source_node_id, target_node_id, distance)
        )
        conn.commit()
        cursor.close()
        conn.close()
        
        return jsonify({
            'edgeID': edge_id,
            'edgeType': edge_type,
            'sourceNodeID': source_node_id,
            'targetNodeID': target_node_id,
            'distance': distance
        }), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/edges/<edge_id>', methods=['GET'])
def get_edge(edge_id):
    """Get a specific edge by ID"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "SELECT EdgeID, EdgeType, SourceNodeID, TargetNodeID, Distance FROM Edge WHERE EdgeID = %s",
            (edge_id,)
        )
        row = cursor.fetchone()
        
        if row:
            edge = {
                'edgeID': convert_uniqueidentifier_to_string(row[0]),
                'edgeType': row[1],
                'sourceNodeID': convert_uniqueidentifier_to_string(row[2]),
                'targetNodeID': convert_uniqueidentifier_to_string(row[3]),
                'distance': convert_decimal_to_float(row[4])
            }
            cursor.close()
            conn.close()
            return jsonify(edge), 200
        else:
            cursor.close()
            conn.close()
            return jsonify({'error': 'Edge not found'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/edges/node/<node_id>', methods=['GET'])
def get_edges_by_node(node_id):
    """Get all edges connected to a specific node (as source or target)"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "SELECT EdgeID, EdgeType, SourceNodeID, TargetNodeID, Distance FROM Edge WHERE SourceNodeID = %s OR TargetNodeID = %s",
            (node_id, node_id)
        )
        rows = cursor.fetchall()
        
        edges = []
        for row in rows:
            edges.append({
                'edgeID': convert_uniqueidentifier_to_string(row[0]),
                'edgeType': row[1],
                'sourceNodeID': convert_uniqueidentifier_to_string(row[2]),
                'targetNodeID': convert_uniqueidentifier_to_string(row[3]),
                'distance': convert_decimal_to_float(row[4])
            })
        
        cursor.close()
        conn.close()
        return jsonify(edges), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=3000, debug=True)

