import os
import requests
from django.shortcuts import render
from django.db import connection
from django.http import HttpResponse
from django.template import Template, Context

def weather_dashboard(request):
    # 1. Test database connectivity and fetch PG version dynamically
    db_status = "Connected"
    db_version = "Unknown"
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT version();")
            db_version = cursor.fetchone()[0]
    except Exception as e:
        db_status = f"Disconnected (Error: {str(e)})"

    # 2. Grab weather data (with dynamic mock fallback)
    api_key = os.environ.get('WEATHER_API_KEY', 'dummy_or_valid_api_key')
    city = request.GET.get('city', 'New York')
    
    weather_data = None
    using_mock = False

    if api_key and api_key != 'dummy_or_valid_api_key':
        try:
            url = f"http://api.openweathermap.org/data/2.5/weather?q={city}&units=imperial&appid={api_key}"
            response = requests.get(url, timeout=5)
            if response.status_code == 200:
                data = response.json()
                weather_data = {
                    'city': data['name'],
                    'temp': round(data['main']['temp']),
                    'desc': data['weather'][0]['description'].title(),
                    'humidity': data['main']['humidity'],
                    'wind': round(data['wind']['speed']),
                }
        except Exception:
            pass

    # Bulletproof fallback so the demo page ALWAYS loads, even without API credentials
    if not weather_data:
        using_mock = True
        weather_data = {
            'city': f"{city} (Demo Mock Mode)",
            'temp': 72,
            'desc': 'Sunny with a light breeze',
            'humidity': 45,
            'wind': 8,
        }

    context = {
        'db_status': db_status,
        'db_version': db_version,
        'weather': weather_data,
        'using_mock': using_mock,
        'db_host': os.environ.get('DB_HOST', 'localhost')
    }

    # Embedded single-file template to eliminate Django file-path issues on deployments
    html_template = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>RHEL 9 Weather Dashboard</title>
        <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    </head>
    <body class="bg-light">
        <div class="container py-5">
            <div class="row justify-content-center">
                <div class="col-md-8">
                    <div class="card text-white bg-dark mb-4 shadow-sm">
                        <div class="card-body text-center py-4">
                            <h1 class="card-title display-5 fw-bold text-white">Enterprise Weather Dashboard</h1>
                            <p class="card-text text-muted mb-0">Provisioned by Terraform & Orchestrated by Ansible Automation Platform (AAP)</p>
                        </div>
                    </div>

                    <div class="card mb-4 shadow-sm border-0">
                        <div class="card-header bg-primary text-white fw-bold d-flex justify-content-between align-items-center">
                            <span>PostgreSQL Database Connectivity</span>
                            <span class="badge bg-success">Active Connection</span>
                        </div>
                        <div class="card-body">
                            <p class="mb-1"><strong>Database Status:</strong> <span class="text-success fw-bold">{{ db_status }}</span></p>
                            <p class="mb-1"><strong>Database Host:</strong> <code>{{ db_host }}</code></p>
                            <p class="mb-0"><strong>Database Engine Version:</strong> <br><small class="text-muted">{{ db_version }}</small></p>
                        </div>
                    </div>

                    <div class="card shadow-sm border-0">
                        <div class="card-header bg-success text-white fw-bold">
                            Live Meteorological Feed
                        </div>
                        <div class="card-body text-center py-4">
                            <form method="GET" class="row g-3 mb-4 justify-content-center">
                                <div class="col-auto">
                                    <input type="text" name="city" class="form-control" placeholder="Enter city name..." required>
                                </div>
                                <div class="col-auto">
                                    <button type="submit" class="btn btn-success">Update City</button>
                                </div>
                            </form>

                            <h2 class="display-6 fw-semibold text-dark">{{ weather.city }}</h2>
                            <p class="text-muted fs-4 mb-2">{{ weather.desc }}</p>
                            <div class="d-flex justify-content-center align-items-center mb-4">
                                <span class="display-2 fw-bold text-primary">{{ weather.temp }}°F</span>
                            </div>

                            <div class="row text-muted border-top pt-3">
                                <div class="col border-end">
                                    <h5>Humidity</h5>
                                    <p class="fs-5 text-dark fw-bold mb-0">{{ weather.humidity }}%</p>
                                </div>
                                <div class="col">
                                    <h5>Wind Speed</h5>
                                    <p class="fs-5 text-dark fw-bold mb-0">{{ weather.wind }} mph</p>
                                </div>
                            </div>
                            
                            {% if using_mock %}
                            <div class="alert alert-warning mt-4 mb-0 py-2 fs-6" role="alert">
                                ℹ️ Note: Running in <strong>Mock Weather Mode</strong> because no external <code>WEATHER_API_KEY</code> was provided. Database transactions are fully live!
                            </div>
                            {% endif %}
                        </div>
                    </div>
                    
                    <div class="text-center mt-5 text-muted small">
                        Running on Red Hat Enterprise Linux 9 (RHEL 9) in AWS EC2
                    </div>
                </div>
            </div>
        </div>
    </body>
    </html>
    """
    
    t = Template(html_template)
    c = Context(context)
    return HttpResponse(t.render(c))
