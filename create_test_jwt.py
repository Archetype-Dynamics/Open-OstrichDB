import json
import base64
######################################
# Author: Marshall A. Burns
# GitHub: @SchoolyB
#
# Copyright (c) 2025-Present Marshall A Burns and Archetype Dynamics, Inc.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
######################################

# This python script is only to be used test local JWT authentication.
# To use:
#1.`python3 create_test_jwt.py`
#2. Copy the token it outputs in the console and save it somewhere
#3. If using Postman or Insomnia store the token as a 'Bearer' token under the "Authorization tab"
#3. If using cURL use this format:
#           curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
#           http://localhost:8042/api/v1/{your_desired_route}
#4. Make Your requests



# Create a fake JWT payload that matches Clerk's structure
payload = {
    # Standard JWT claims (always present in Clerk)
    "sub": "user_2abcdef123456789",  # Clerk user ID format
    "iss": "https://clerk.yourapp.com",
    "azp": "http://localhost:3000",
    "exp": 9999999999,  # Far future
    "iat": 1640908800,
    "nbf": 1640908800,
    "jti": "jwt_123456789abcdef",

    # Custom claims (if configured in JWT template)
    "email": "test@example.com",
    "first_name": "Test",
    "last_name": "User"
}

# Create fake header
header = {
    "alg": "RS256",
    "typ": "JWT"
}

# Encode to base64 (without padding issues)
def base64url_encode(data):
    return base64.urlsafe_b64encode(json.dumps(data).encode()).decode().rstrip('=')

header_b64 = base64url_encode(header)
payload_b64 = base64url_encode(payload)

# Create fake JWT (header.payload.fake_signature)
fake_jwt = f"{header_b64}.{payload_b64}.fake_signature"

print("Test JWT Token:")
print(fake_jwt)
print()
print("Use this token to test your API:")
print(f'curl -H "Authorization: Bearer {fake_jwt}" http://localhost:8042/api/v1/projects')