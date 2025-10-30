from flask import Flask
from flask import jsonify
from flask import request

from flask_jwt_extended import create_access_token
from flask_jwt_extended import get_jwt_identity
from flask_jwt_extended import jwt_required
from flask_jwt_extended import JWTManager
from configuration import Configuration
from models import create_user, delete_user_by_id, get_all_users, get_user_by_username, get_user_by_id, hash_password, update_password, update_user_login_time, verify_password
import traceback

app=Flask(__name__)
app.config.from_object(Configuration)
jwt=JWTManager(app)

# ALB health check endpoint
@app.route("/healthCheck", methods=["GET"])
def health(): 
    return jsonify({"status":"healthy"}), 200

@app.route('/api/register', methods=['POST'])
def register():
    try:

        data = request.json
        username = data['username']
        email = data['email']
        password = data['password']
        
        password_hash = hash_password(password)
        user_id = create_user(username, email, password_hash)
        return {"user_id": user_id}, 201
    except Exception as e:
        print(f"Error during registration: {e}")
        traceback.print_exc()
        return {"error": "Internal server error", "debug": str(e)}, 500

@app.route("/login", methods=["POST"])
def login():
    data = request.json
    username = data['username']
    password = data['password']
    user = get_user_by_username(username=username)
    if not user: 
        return jsonify({"msg": "Invalid username"}), 401
    user_id, password_hash = user
    if not verify_password(password, password_hash):
          return jsonify({"error": "Invalid credentials"}), 401
    token = create_access_token(user_id)
    update_user_login_time(user_id)
    return jsonify({"access_token": token, "user_id": user_id}), 200


@app.route("/api/users", methods=["GET"])
@jwt_required()
def fetch_all_users():
    return  jsonify({"users": get_all_users()}), 200

@app.route("/api/users/me", methods=["GET"])
@jwt_required()
def get_my_user():
    
    user_id = get_jwt_identity()
    user = get_user_by_id(user_id)
    return  jsonify(user), 200

@app.route("/api/users/me", methods=["DELETE"])
@jwt_required()
def delete_my_user():
    user_id = get_jwt_identity()
    delete_user_by_id(user_id)
    return jsonify({"message": "User deleted successfully"}), 200

@app.route("/api/users/me/password", methods=["PUT"])
@jwt_required()
def update_my_password():
    data = request.json
    new_password = data['new_password']
    user_id = get_jwt_identity()
    update_password(user_id, new_password)
    return jsonify({"message": "User deleted successfully"}), 200


@app.errorhandler(ValueError)
def handle_value_error(e):
    return jsonify({"error": str(e)}), 400

@app.errorhandler(KeyError)
def handle_key_error(e):
    return jsonify({"error": f"Missing field: {str(e)}"}), 400

@app.errorhandler(404)
def not_found(e):
    return jsonify({"error": "Resource not found"}), 404

@app.errorhandler(ConnectionError)
def handle_connection_error(e):
    return jsonify({"error": "Database unavailable"}), 503

@app.errorhandler(Exception)
def handle_generic_error(e):
    return jsonify({"error": "Internal server error"}), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)