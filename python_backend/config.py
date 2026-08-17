# config.py
import os

class Config:
    SECRET_KEY = os.getenv("SECRET_KEY", os.urandom(32).hex())
    JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", os.urandom(32).hex())
    MAIL_SERVER = 'smtp.gmail.com'
    MAIL_PORT = 587
    MAIL_USE_TLS = True
    MAIL_USERNAME = os.getenv("MAIL_USERNAME", "your_email@gmail.com")
    MAIL_PASSWORD = os.getenv("MAIL_PASSWORD", "your_app_specific_password")
    UPLOAD_FOLDER = os.getenv("UPLOAD_FOLDER", "uploads")
    TWILIO_ACCOUNT_SID = os.getenv("REMOVED")
    TWILIO_AUTH_TOKEN = os.getenv("REMOVED_TWILIO_TOKEN")
    TWILIO_PHONE_NUMBER = os.getenv("REMOVED_TWILIO_PHONE")

class DevelopmentConfig(Config):
    DEBUG = True

class ProductionConfig(Config):
    DEBUG = False