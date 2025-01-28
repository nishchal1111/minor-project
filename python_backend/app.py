from flask import Flask, request, jsonify
from flask_jwt_extended import JWTManager, create_access_token, jwt_required
from flask_sqlalchemy import SQLAlchemy
from datetime import timedelta
import bcrypt

# Initialize Flask App
app = Flask(__name__)

# Setup the Flask-JWT-Extended configuration
app.config["JWT_SECRET_KEY"] = "your_jwt_secret_key"  # Secret key for encoding/decoding JWT tokens
app.config["SQLALCHEMY_DATABASE_URI"] = "sqlite:///users.db"  # Database URL
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False  # To avoid warning

# Initialize the JWT manager and SQLAlchemy
jwt = JWTManager(app)
db = SQLAlchemy(app)

# Create the User model
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password = db.Column(db.String(200), nullable=False)

# Create the database tables if they don't exist
with app.app_context():
    db.create_all()

# User Registration Route (Optional, if needed)
@app.route("/register", methods=["POST"])
def register():
    data = request.get_json()
    email = data.get("email")
    password = data.get("password")

    # Hash the password
    hashed_password = bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt())

    # Save the new user to the database
    new_user = User(email=email, password=hashed_password)
    db.session.add(new_user)
    db.session.commit()

    return jsonify({"message": "User registered successfully"}), 201

# User Login Route to get JWT token
@app.route("/login", methods=["POST"])
def login():
    data = request.get_json()
    email = data.get("email")
    password = data.get("password")

    # Query the user from the database
    user = User.query.filter_by(email=email).first()

    if user and bcrypt.checkpw(password.encode("utf-8"), user.password.encode("utf-8")):
        # Create a JWT token that expires in 24 hours
        access_token = create_access_token(identity=email, fresh=True, expires_delta=timedelta(days=1))

        return jsonify(access_token=access_token), 200  # Return the JWT token

    return jsonify({"message": "Invalid email or password"}), 401

# Protected Route Example (Requires JWT)
@app.route("/protected", methods=["GET"])
@jwt_required()
def protected():
    return jsonify(message="This is a protected route."), 200

if __name__ == "__main__":
    app.run(debug=True)