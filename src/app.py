from flask import Flask, jsonify, request
from flask_jwt_extended import (
    create_access_token,
    get_jwt_identity,
    jwt_required,
    JWTManager,
)
from flask_jwt_extended.exceptions import JWTDecodeError
from configuration import Configuration
from models import (
    create_token,
    create_user,
    delete_user_by_id,
    get_all_users,
    get_user_by_username,
    get_user_by_id,
    hash_password,
    update_password,
    update_user_login_time,
    verify_password,
)
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from logging.config import dictConfig
from marshmallow import Schema, fields, validate, ValidationError

# log config taken from flask docs
dictConfig({
    'version': 1,
    'formatters': {'default': {
        'format': '[%(asctime)s] %(levelname)s in %(module)s: %(message)s',
    }},
    'handlers': {'wsgi': {
        'class': 'logging.StreamHandler',
        'formatter': 'default'
    }},
    'root': {
        'level': 'INFO',
    }
})


app=Flask(__name__)
app.config.from_object(Configuration)
jwt=JWTManager(app)

# Rate limiter configuration
limiter = Limiter(
    get_remote_address,
    app=app,
    default_limits=["100 per day", "50 per hour"],
    storage_uri="memory://",
)

# Marshmallow schemas for input validation
class RegisterSchema(Schema):
    username = fields.Str(required=True, validate=validate.Length(min=3, max=20))
    email = fields.Email(required=True)
    password = fields.Str(
        required=True,
        validate=validate.Length(min=8),
        load_only=True # this is done for passwords since they should not be serialized
    )

class LoginSchema(Schema):
    username = fields.Str(required=True, validate=validate.Length(min=3, max=20))
    password = fields.Str(
        required=True,
        validate=validate.Length(min=8),
        load_only=True # this is done for passwords since they should not be serialized
    )

class PasswordUpdateSchema(Schema):
    new_password = fields.Str(
        required=True,
        validate=validate.Length(min=8),
        load_only=True
    )


# ALB health check endpoint
@app.route("/healthCheck", methods=["GET"])
def health():
    app.logger.info("Health check endpoint called")
    return jsonify({"status":"healthy"}), 200


@app.route('/api/register', methods=['POST'])
@limiter.limit("15 per minute") 
def register():
    app.logger.info("/api/register endpoint called by IP: %s", request.remote_addr)
    register_schema = RegisterSchema()
    data = register_schema.load(request.json)
    username = data['username']
    email = data['email']
    password = data['password']
    print("Register attempt for username:", username, email)
   
    try:
        password_hash = hash_password(password)
        user_id = create_user(username=username, email=email, passwordHash=password_hash)
        app.logger.info("/api/register: User %s registered successfully with ID %s", username, user_id)
        return {"user_id": user_id}, 201
    except Exception as e:
        app.logger.error("/api/register: User registration error: %s", str(e))
        return {"error": "Internal server error"}, 500


@app.route("/login", methods=["POST"])
@limiter.limit("15 per minute") 
def login():
    app.logger.info("/login endpoint called from IP: %s", request.remote_addr)
    login_schema = LoginSchema()
    data = login_schema.load(request.json)
    username = data['username']
    password = data['password']
    print("Login attempt for username:", username)
    user = get_user_by_username(username=username)
    if not user:
        app.logger.warning("/login: Login failed for unknown username: %s from %s", username, request.remote_addr)
        return jsonify({"error": "Invalid credentials"}), 401
    user_id, password_hash = user
    if not verify_password(password, password_hash):
        app.logger.warning("/login: Invalid password attempt for id %s from %s", user_id, request.remote_addr)
        return jsonify({"error": "Invalid credentials"}), 401

    token = create_token(user_id)
    update_user_login_time(user_id)
    app.logger.info("/login: User %s (id=%s) logged in successfully", username, user_id)
    return jsonify({"access_token": token, "user_id": user_id}), 200


@app.route("/api/users", methods=["GET"])
@jwt_required()
def fetch_all_users():
    try:
        user_id = get_jwt_identity()
    except:
        user_id = "Faulty user id"
    app.logger.info("GET /api/users: Fetch all users called by user_id=%s from %s", user_id, request.remote_addr)
    return  jsonify({"users": get_all_users()}), 200


@app.route("/api/users/me", methods=["GET"])
@jwt_required()
def get_my_user():
    user_id = get_jwt_identity()
    app.logger.info("GET /api/users/me: called for id =%s from %s", user_id, request.remote_addr)
    user = get_user_by_id(user_id)
    if not user:
        app.logger.warning("GET /api/users/me: User not found for id=%s", user_id)
        return jsonify({"error": "User not found"}), 404
    return jsonify(user), 200


@app.route("/api/users/me", methods=["DELETE"])
@limiter.limit("8 per minute") 
@jwt_required()
def delete_my_user():
    user_id = get_jwt_identity()
    app.logger.warning("DELETE /api/users/me: Delete request for id=%s from %s", user_id, request.remote_addr)
    delete_user_by_id(user_id)
    app.logger.info("DELETE /api/users/me: User %s deleted successfully", user_id)
    return jsonify({"message": "User deleted successfully"}), 200


@app.route("/api/users/me/password", methods=["PUT"])
@limiter.limit("5 per hour") 
@jwt_required()
def update_my_password():
    update_password_schema = PasswordUpdateSchema()
    data = update_password_schema.load(request.json)
    new_password = data['new_password']
    
    user_id = get_jwt_identity()
    app.logger.info("/api/users/me/password: Password update requested for id=%s from %s", user_id, request.remote_addr)
    update_password(user_id, new_password)
    app.logger.info("/api/users/me/password: Password updated for id=%s", user_id)
    return jsonify({"message": "Password updated successfully"}), 200


@app.errorhandler(ValueError)
def handle_value_error(e):
    app.logger.exception("ValueError encountered: %s", str(e))
    return jsonify({"error": "Bad request"}), 400

@app.errorhandler(KeyError)
def handle_key_error(e):
    app.logger.exception("KeyError (missing field): %s", str(e))
    return jsonify({"error": "Missing required field"}), 400

@app.errorhandler(404)
def not_found(e):
    app.logger.warning("404 error for URL: %s", request.url)
    return jsonify({"error": "Not found"}), 404

@app.errorhandler(ConnectionError)
def handle_connection_error(e):
    app.logger.exception("Connection/DB error: %s", str(e))
    return jsonify({"error": "Service temporarily unavailable"}), 503

@app.errorhandler(JWTDecodeError)
def handle_jwt_error(e):
    app.logger.warning("Invalid JWT from %s: %s", request.remote_addr, str(e))
    return jsonify({"error": "Invalid token"}), 401

#Limiter raises a 429 error when rate limit is exceeded
@app.errorhandler(429)
def ratelimit_handler(e):
    app.logger.warning("Rate limit exceeded from %s", request.remote_addr)
    return jsonify({"error": "Too many requests. Please try again later."}), 429

@app.errorhandler(ValidationError)
def validation_error_handler(e):
    app.logger.warning("Validation error from %s: %s", request.remote_addr, str(e))
    return jsonify({"error": "Invalid input"}), 400

@app.errorhandler(Exception)
def handle_generic_error(e):
    app.logger.exception("Generic exception: %s", str(e))
    return jsonify({"error": "Internal server error"}), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)