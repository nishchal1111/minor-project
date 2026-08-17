from flask import Flask, request, jsonify, render_template, send_from_directory
from flask_socketio import SocketIO, emit
import jwt
import datetime
import os
import random
import firebase_admin
from firebase_admin import credentials, firestore
from fetch_locations import get_service_locations
from math import radians, sin, cos, sqrt, atan2
from config import Config, DevelopmentConfig, ProductionConfig
import smtplib
from email.message import EmailMessage
import requests
from twilio.rest import Client
from dotenv import load_dotenv
from geopy.geocoders import Nominatim
from geopy.extra.rate_limiter import RateLimiter
import time
# Load environment variables from .env file
load_dotenv()

# Initialize Flask app
app = Flask(__name__)

# Load configuration based on environment
env = os.getenv('FLASK_ENV', 'development')
if env == 'production':
    app.config.from_object(ProductionConfig)
else:
    app.config.from_object(DevelopmentConfig)

# Explicitly set Twilio config from environment variables
app.config['TWILIO_ACCOUNT_SID'] = os.getenv('TWILIO_ACCOUNT_SID')
app.config['TWILIO_AUTH_TOKEN'] = os.getenv('TWILIO_AUTH_TOKEN')
app.config['TWILIO_PHONE_NUMBER'] = os.getenv('TWILIO_PHONE_NUMBER')

# Initialize Twilio client
if app.config['TWILIO_ACCOUNT_SID'] and app.config['TWILIO_AUTH_TOKEN'] and app.config['TWILIO_PHONE_NUMBER']:
    twilio_client = Client(app.config['TWILIO_ACCOUNT_SID'], app.config['TWILIO_AUTH_TOKEN'])
else:
    print("Twilio configuration is incomplete. SMS notifications will not work.")
    twilio_client = None

socketio = SocketIO(app, cors_allowed_origins="*")

# Ensure uploads directory exists
UPLOAD_FOLDER = app.config['UPLOAD_FOLDER']
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

# KMC contact details
KMC_PHONE = "01-4231312"
KMC_EMAIL = "kmc.alerts@example.com"
KMC_LOCATION = (27.7041, 85.3141)
KMC_PROVIDER_NAME = "KMC Office"  # Default for sewage, garbage, illegalparking
FIRESTATION_MOCK_LOCATION = (27.7000, 85.3200)  # Example mock location for firefighter
FIRESTATION_MOCK_PROVIDER_NAME = "NEPAL FIRE AND SAFETY SOLUTIONS PVT.LTD"

# Initialize Firebase Admin SDK
cred = credentials.Certificate('hello-d38dd-firebase-adminsdk-fbsvc-d114f4cf19.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

# OTP storage (use Redis or database in production)
otp_storage = {}

# Initialize Nominatim geocoder with increased timeout
geolocator = Nominatim(user_agent="kmc_dashboard", timeout=10)

# Add rate limiter to respect Nominatim's usage policy (1 request per second)
geocode_with_rate_limit = RateLimiter(
    geolocator.reverse,
    min_delay_seconds=1,  # Minimum delay between requests
    max_retries=3,        # Retry up to 3 times on failure
    error_wait_seconds=5  # Wait 5 seconds between retries
)

# Cache for geocoding results to avoid repeated requests
geocode_cache = {}

# Socket.IO event handlers
@socketio.on('connect')
def handle_connect():
    print('Client connected')
    emit('connect', {'message': 'Connected to server'})

@socketio.on('disconnect')
def handle_disconnect():
    print('Client disconnected')

@socketio.on('new_alert')
def handle_new_alert(alert):
    print(f"New alert received: {alert}")
    emit('new_alert', alert, broadcast=True)

@socketio.on('alert_updated')
def handle_alert_updated(alert):
    print(f"Alert updated: {alert}")
    emit('alert_updated', alert, broadcast=True)

def send_notification(phone, message):
    print(f"Sending notification to {phone}: {message}")
    try:
        if "@" in phone:
            msg = EmailMessage()
            msg.set_content(message)
            msg['Subject'] = "KMC Emergency Alert"
            msg['From'] = app.config['MAIL_USERNAME']
            msg['To'] = phone
            with smtplib.SMTP(app.config['MAIL_SERVER'], app.config['MAIL_PORT']) as server:
                server.starttls()
                server.login(app.config['MAIL_USERNAME'], app.config['MAIL_PASSWORD'])
                server.send_message(msg)
                print(f"Email sent to {phone}")
        else:
            if not twilio_client:
                raise ValueError("Twilio client not initialized due to missing configuration")
            twilio_number = app.config['TWILIO_PHONE_NUMBER']
            if not twilio_number:
                raise ValueError("TWILIO_PHONE_NUMBER is not set in configuration")
            print(f"Using Twilio number: {twilio_number}")
            message = twilio_client.messages.create(
                body=message,
                from_=twilio_number,
                to=phone
            )
            print(f"SMS sent to {phone}, SID: {message.sid}")
    except Exception as e:
        print(f"Notification failed: {str(e)}")
        # Optionally, raise the exception to fail the request
        # raise e  # Uncomment if you want Flask to return 500 on notification failure

def haversine_distance(coord1, coord2):
    R = 6371
    lat1, lon1 = radians(coord1[0]), radians(coord1[1])
    lat2, lon2 = radians(coord2[0]), radians(coord2[1])
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlon / 2) ** 2
    c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return R * c

@app.route("/api/send-otp", methods=["POST"])
def send_otp():
    data = request.get_json()
    phone_number = data.get("phoneNumber")
    print(f"Received request with phone_number: {phone_number}")
    
    if not phone_number:
        return jsonify({"error": "Phone number is required", "status": 400}), 400

    otp = str(random.randint(100000, 999999))
    otp_storage[phone_number] = {
        "otp": otp,
        "timestamp": datetime.datetime.now(datetime.UTC)
    }
    print(f"Generated OTP: {otp}")
    
    message = f"Your KMC Alert OTP is: {otp}. Valid for 5 minutes."
    send_notification(phone_number, message)
    
    return jsonify({"message": "OTP sent successfully", "status": 200}), 200

@app.route("/api/verify-otp", methods=["POST"])
def verify_otp():
    data = request.get_json()
    phone_number = data.get("phoneNumber")
    entered_otp = data.get("otp")
    
    if not phone_number or not entered_otp:
        return jsonify({"error": "Phone number and OTP are required", "status": 400}), 400
    
    stored_data = otp_storage.get(phone_number)
    if not stored_data or stored_data["otp"] != entered_otp:
        return jsonify({"error": "Invalid OTP", "status": 401}), 401
    
    time_diff = (datetime.datetime.now(datetime.UTC) - stored_data["timestamp"]).total_seconds()
    if time_diff > 300:
        del otp_storage[phone_number]
        return jsonify({"error": "OTP expired", "status": 401}), 401
    
    token = jwt.encode({
        'phone': phone_number,
        'exp': datetime.datetime.now(datetime.UTC) + datetime.timedelta(hours=24)
    }, app.config['JWT_SECRET_KEY'], algorithm="HS256")
    
    del otp_storage[phone_number]
    
    return jsonify({"message": "OTP verified", "token": token, "status": 200}), 200

def token_required(f):
    def decorated(*args, **kwargs):
        token = request.headers.get('Authorization')
        if not token:
            return jsonify({"error": "Token is missing", "status": 401}), 401
        
        try:
            if token.startswith('Bearer '):
                token = token.split(' ')[1]
            jwt.decode(token, app.config['JWT_SECRET_KEY'], algorithms=["HS256"])
        except jwt.ExpiredSignatureError:
            return jsonify({"error": "Token has expired", "status": 401}), 401
        except jwt.InvalidTokenError:
            return jsonify({"error": "Invalid token", "status": 401}), 401
        return f(*args, **kwargs)
    decorated.__name__ = f.__name__
    return decorated

@app.route("/send_alert", methods=["POST"])
@token_required
def send_alert():
    if request.content_type.startswith('application/json'):
        data = request.get_json(silent=True) or {}
        user_lat = data.get("latitude")
        user_lon = data.get("longitude")
        service_type = data.get("service_type", "ambulance").lower()
        phone_number = data.get("phone_number")
    else:
        user_lat = request.form.get("latitude")
        user_lon = request.form.get("longitude")
        service_type = request.form.get("service_type", "ambulance").lower()
        phone_number = request.form.get("phone_number")

    if not user_lat or not user_lon:
        return jsonify({"error": "Latitude and longitude are required", "status": 400}), 400

    try:
        user_lat = float(user_lat)
        user_lon = float(user_lon)
    except (ValueError, TypeError):
        return jsonify({"error": "Invalid latitude or longitude values", "status": 400}), 400

    photo = request.files.get("photo") if not request.content_type.startswith('application/json') else None
    photo_path = None
    if photo:
        try:
            photo_filename = f"{service_type}_{int(user_lat*1000)}_{int(user_lon*1000)}.jpg"
            photo_path = os.path.join(app.config['UPLOAD_FOLDER'], photo_filename)
            photo.save(photo_path)
        except Exception as e:
            return jsonify({"error": f"Failed to save photo: {str(e)}", "status": 500}), 500

    user_location = (user_lat, user_lon)
    radius = 20000
    try:
        services = get_service_locations(user_lat, user_lon, service_type, radius=radius)
    except Exception as e:
        return jsonify({"error": f"Failed to fetch {service_type} locations: {str(e)}", "status": 500}), 500

    if not services:
        return jsonify({"error": f"No {service_type}s found nearby", "status": 404}), 404

    try:
        # nearest_service = min(services, key=lambda x: haversine_distance(user_location, x[:2]))
        if services and len(services) > 1:
    # Find the nearest service using haversine distance
            nearest_service = min(services, key=lambda x: haversine_distance(user_location, x[:2]))
        elif services:  # Handle case where there's only one service
            nearest_service = services[0]
        else:
    # Handle case where no services are found
            nearest_service = None

        if nearest_service:
    # Safely extract latitude and longitude
            nearest_service_latlon = nearest_service[:2] if len(nearest_service) >= 2 else (None, None)
    # Safely extract the provider name
            nearest_service_name = nearest_service[2] if len(nearest_service) > 2 else "Unknown"
            print(f"Nearest service location: {nearest_service}")
        else:
            print("No services found nearby.")
    except Exception as e:
        return jsonify({"error": f"Failed to find nearest {service_type}: {str(e)}", "status": 500}), 500

    if service_type in ["ambulance", "firefighter", "policeman"]:
        astar_url = os.getenv("ASTAR_URL", "http://172.16.31.2:5000/shortest-path")
        try:
            response = requests.post(astar_url, json={
                "latitude": user_lat,
                "longitude": user_lon,
                "service_type": service_type,
                "nearest_ambulance": nearest_service[:2]
            })
            response.raise_for_status()
            astar_result = response.json()
            nearest_service = astar_result.get("nearest_ambulance", nearest_service[:2])
            if service_type == "firefighter" and not nearest_service:
                nearest_service = FIRESTATION_MOCK_LOCATION
                nearest_service_name = FIRESTATION_MOCK_PROVIDER_NAME
            alert_message = f"Emergency alert! Nearest {service_type} at {nearest_service} requested."
        except requests.exceptions.RequestException as e:
            return jsonify({"error": f"Failed to call A* service: {str(e)}", "status": 500}), 500
    else:
        alert_message = f"KMC Alert: {service_type.capitalize()} service requested at {user_lat}, {user_lon}"
        if photo_path:
            alert_message += f" Photo uploaded: {photo_path}"
        if phone_number:
            alert_message += f" Contact: {phone_number}"
        send_notification(KMC_PHONE, alert_message)
        if KMC_EMAIL:
            send_notification(KMC_EMAIL, alert_message)
        if service_type in ["sewage", "garbage", "illegalparking"]:
            nearest_service = KMC_LOCATION
            nearest_service_name = KMC_PROVIDER_NAME
        elif service_type == "firefighter" and not nearest_service:
            nearest_service = FIRESTATION_MOCK_LOCATION
            nearest_service_name = FIRESTATION_MOCK_PROVIDER_NAME

    alert_data = {
        "user_latitude": user_lat,
        "user_longitude": user_lon,
        "service_type": service_type,
        "nearest_service": {
            "service_latitude": nearest_service[0],
            "service_longitude": nearest_service[1]
        },
        "timestamp": firestore.SERVER_TIMESTAMP,
        "phone_number": phone_number,
        "photo_path": photo_path if photo_path else None,
        "notification_sent": alert_message,
        "provider_name": nearest_service_name,
        "status": "pending"
        
    }
    try:
        alert_ref = db.collection("alerts").add(alert_data)
        print(f"Alert saved to Firestore with ID: {alert_ref[1].id}")
    except Exception as e:
        print(f"Failed to save alert to Firestore: {str(e)}")
        return jsonify({"error": f"Failed to save alert: {str(e)}", "status": 500}), 500

    return jsonify({"message": "Alert sent", "nearest_ambulance": nearest_service, "status": 200}), 200

@app.route("/dashboard")
def dashboard():
    return render_template("dashboard.html")

# @app.route("/api/alerts", methods=["GET"])
# @token_required
# def get_alerts():
#     print("Received GET request for /api/alerts")
#     try:
#         service_type = request.args.get("service_type")
#         query = db.collection("alerts").order_by("timestamp", direction=firestore.Query.DESCENDING)
#         if service_type:
#             query = query.where("service_type", "==", service_type.lower())
        
#         alerts = []
#         for doc in query.stream():
#             data = doc.to_dict()
#             data["id"] = doc.id
#             if "timestamp" in data and data["timestamp"]:
#                 data["timestamp"] = data["timestamp"].isoformat()
#             alerts.append(data)
#         print(f"Returning {len(alerts)} alerts")
#         return jsonify({"alerts": alerts, "status": 200})
#     except Exception as e:
#         print(f"Error fetching alerts: {str(e)}")
#         return jsonify({"error": str(e), "status": 500}), 500


@app.route("/api/alerts", methods=["GET"])
# @token_required  # Temporarily remove or comment out
def get_alerts():
    print("Received GET request for /api/alerts")
    try:
        service_type = request.args.get("service_type")
        query = db.collection("alerts").order_by("timestamp", direction=firestore.Query.DESCENDING)
        if service_type:
            query = query.where("service_type", "==", service_type.lower())
        
        alerts = []
        for doc in query.stream():
            data = doc.to_dict()
            data["id"] = doc.id
            if "timestamp" in data and data["timestamp"]:
                data["timestamp"] = data["timestamp"].isoformat()

            nearest_service = data.get("nearest_service", {})
            provider_name = data.get("provider_name", "Unknown")
            data["provider_name"] = provider_name
            try:
                coords = (data["user_latitude"], data["user_longitude"])
                # Check if the result is already in the cache
                if coords in geocode_cache:
                    data["user_place_name"] = geocode_cache[coords]
                else:
                    location = geocode_with_rate_limit(coords, language="en")
                    place_name = location.address if location else "Unknown Location"
                    geocode_cache[coords] = place_name  # Cache the result
                    data["user_place_name"] = place_name
            except Exception as e:
                print(f"Reverse geocoding failed for {data['user_latitude']}, {data['user_longitude']}: {str(e)}")
                data["user_place_name"] = "Unknown Location"
            alerts.append(data)
        print(f"Returning {len(alerts)} alerts")
        return jsonify({"alerts": alerts, "status": 200})
    except Exception as e:
        print(f"Error fetching alerts: {str(e)}")
        return jsonify({"error": str(e), "status": 500}), 500

@app.route("/api/alerts/<alert_id>/resolve", methods=["POST"])
@token_required
def resolve_alert(alert_id):
    try:
        db.collection("alerts").document(alert_id).update({"status": "resolved"})
        updated_alert = db.collection("alerts").document(alert_id).get().to_dict()
        updated_alert["id"] = alert_id
        socketio.emit('alert_updated', updated_alert)
        return jsonify({"message": f"Alert {alert_id} marked as resolved", "status": 200}), 200
    except Exception as e:
        print(f"Error resolving alert: {str(e)}")
        return jsonify({"error": str(e), "status": 500}), 500

# @app.route("/respond_to_alert", methods=["POST"])
# @token_required
# def respond_to_alert():
#     data = request.json
#     alert_id = data.get("alert_id")
#     response_message = data.get("response_message")

#     if not all([alert_id, response_message]):
#         return jsonify({"error": "Missing required fields", "status": 400}), 400

#     try:
#         alert_ref = db.collection("alerts").document(alert_id)
#         alert_ref.update({
#             "response": {
#                 "message": response_message,
#                 "timestamp": firestore.SERVER_TIMESTAMP
#             },
#             "status": "Responded"
#         })
#         updated_alert = alert_ref.get().to_dict()
#         updated_alert["id"] = alert_id
#         if "response" in updated_alert and "timestamp" in updated_alert["response"]:
#             updated_alert["response"]["timestamp"] = updated_alert["response"]["timestamp"].isoformat() if updated_alert["response"]["timestamp"] else None
#         socketio.emit('alert_updated', updated_alert)
#         return jsonify({"message": "Response recorded successfully", "status": 200}), 200
#     except Exception as e:
#         return jsonify({"error": f"Failed to record response: {str(e)}", "status": 500}), 500

@app.route("/respond_to_alert", methods=["POST"])
@token_required
def respond_to_alert():
    data = request.json
    alert_id = data.get("alert_id")
    response_message = data.get("response_message")

    if not all([alert_id, response_message]):
        return jsonify({"error": "Missing required fields", "status": 400}), 400

    try:
        alert_ref = db.collection("alerts").document(alert_id)
        update_data = {
            "response": {
                "message": response_message,
                "timestamp": firestore.SERVER_TIMESTAMP
            },
            "status": "Responded"
        }
        alert_ref.update(update_data)
        # Verify the update
        updated_doc = alert_ref.get()
        if not updated_doc.exists:
            raise Exception("Alert document not found after update")
        updated_alert = updated_doc.to_dict()
        updated_alert["id"] = alert_id
        if "timestamp" in updated_alert and updated_alert["timestamp"]:
            updated_alert["timestamp"] = updated_alert["timestamp"].isoformat()
        if "response" in updated_alert and "timestamp" in updated_alert["response"]:
            updated_alert["response"]["timestamp"] = updated_alert["response"]["timestamp"].isoformat() if updated_alert["response"]["timestamp"] else None
        # Ensure all necessary fields are included
        updated_alert["user_latitude"] = updated_alert.get("user_latitude")
        updated_alert["user_longitude"] = updated_alert.get("user_longitude")
        updated_alert["service_type"] = updated_alert.get("service_type")
        updated_alert["provider_name"] = updated_alert.get("provider_name")
        updated_alert["nearest_service"] = updated_alert.get("nearest_service", {})
        updated_alert["phone_number"] = updated_alert.get("phone_number")
        updated_alert["user_place_name"] = updated_alert.get("user_place_name", "Unknown Location")
        print(f"Emitting updated alert: {updated_alert}")  # Debugging
        socketio.emit('alert_updated', updated_alert, broadcast=True)
        return jsonify({"message": "Response recorded successfully", "status": 200}), 200
    except Exception as e:
        print(f"Error in respond_to_alert: {str(e)}")  # Debugging
        return jsonify({"error": f"Failed to record response: {str(e)}", "status": 500}), 500

@app.route("/uploads/<filename>")
def uploaded_file(filename):
    try:
        return send_from_directory(app.config['UPLOAD_FOLDER'], filename)
    except Exception as e:
        return jsonify({"error": f"Failed to serve photo: {str(e)}", "status": 404}), 404

if __name__ == "__main__":
    socketio.run(app, host="0.0.0.0", port=5001, debug=app.config['DEBUG'])




