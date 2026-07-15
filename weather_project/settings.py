import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

# --- ADD THIS BLOCK TO NATIVELY LOAD THE .ENV FILE ---
env_file = BASE_DIR / '.env'
if env_file.exists():
    with open(env_file) as f:
        for line in f:
            # Strip whitespace and ignore empty lines or comments
            line = line.strip()
            if line and not line.startswith('#'):
                # Split at the first '=' to separate key and value
                key, value = line.split('=', 1)
                # Clean up any wrapping quotes around values and save to os.environ
                os.environ[key.strip()] = value.strip('"').strip("'").strip()
# -----------------------------------------------------

SECRET_KEY = os.environ.get('SECRET_KEY', 'django-insecure-demo-key-12345')
DEBUG = os.environ.get('DEBUG', 'False') == 'True'
ALLOWED_HOSTS = ['*'] # Allows proxying via Nginx on any RHEL EC2 IP

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'weather_project.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'weather_project.wsgi'

# DB settings read from the .env file dynamically populated by AAP!
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.environ.get('DB_NAME', 'weather_db'),
        'USER': os.environ.get('DB_USER', 'weather_user'),
        'PASSWORD': os.environ.get('DB_PASSWORD', 'SuperSecurePassword123!'),
        'HOST': os.environ.get('DB_HOST', 'localhost'),
        'PORT': os.environ.get('DB_PORT', '5432'),
    }
}

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

STATIC_URL = 'static/'
STATIC_ROOT = os.path.join(BASE_DIR, 'static')
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
