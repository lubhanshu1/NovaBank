import os
from dotenv import load_dotenv

# Load .env file from project root
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
load_dotenv(os.path.join(BASE_DIR, '.env'))

class Config:
    DB_HOST = os.getenv('DB_HOST', '127.0.0.1')
    DB_PORT = int(os.getenv('DB_PORT', '3306'))
    DB_USER = os.getenv('DB_USER', 'root')
    DB_PASSWORD = os.getenv('DB_PASSWORD', '')
    DB_SSL_CA = os.getenv('DB_SSL_CA', '') or None
    DB_NAME = os.getenv('DB_NAME', 'novabank')
    
    DB_POOL_NAME = os.getenv('DB_POOL_NAME', 'novabank_pool')
    DB_POOL_SIZE = int(os.getenv('DB_POOL_SIZE', '10'))
    
    SECRET_KEY = os.getenv('SECRET_KEY', 'CHANGE_ME_BEFORE_DEPLOYMENT')
    DEBUG = os.getenv('FLASK_DEBUG', '0') == '1'
    PORT = int(os.getenv('PORT', '5000'))

