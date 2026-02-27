import sys
from uptime_kuma_api import UptimeKumaApi, MonitorType

API_URL = "http://192.168.3.124:3001"
API_KEY = "uk1_3-h6TtHCitVMy8xT6M9UnCxAKc5XZbtKXbNhVt8B"

try:
    with UptimeKumaApi(API_URL) as api:
        # Check available login methods
        methods = [m for m in dir(api) if "login" in m]
        print("Available login methods:", methods)
        
        try:
            # Let's try token login first if available
            if hasattr(api, "login_by_token"):
                print("Trying login_by_token...")
                api.login_by_token(API_KEY)
            else:
                # Some versions might alias API Key to password if username is empty
                print("Trying standard login with empty username...")
                api.login("", API_KEY)
                
            monitors = api.get_monitors()
            print(f"Success! Found {len(monitors)} monitors.")
        except Exception as auth_e:
            print(f"Auth failed: {auth_e}")

except Exception as e:
    print(f"Connection failed: {e}")
