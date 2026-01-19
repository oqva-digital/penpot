#!/usr/bin/env bash
set -euo pipefail

# Script to generate secret keys and strong passwords

ENV_FILE="${1:-.env.local}"

if [ ! -f "$ENV_FILE" ]; then
    echo "File $ENV_FILE not found. Creating..."
    touch "$ENV_FILE"
fi

# Function to generate PENPOT_SECRET_KEY (512 bits base64)
generate_secret_key() {
    if command -v python3 &> /dev/null; then
        python3 -c "import secrets; print(secrets.token_urlsafe(64))"
    elif command -v openssl &> /dev/null; then
        openssl rand -base64 64 | tr -d '\n'
    else
        echo "Error: Python3 or OpenSSL required to generate keys"
        exit 1
    fi
}

# Function to generate strong password
generate_password() {
    local length="${1:-32}"
    if command -v openssl &> /dev/null; then
        openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
    elif command -v python3 &> /dev/null; then
        python3 -c "import secrets, string; print(''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range($length)))"
    else
        echo "Error: OpenSSL or Python3 required to generate passwords"
        exit 1
    fi
}

# Function to update or add variable in .env
set_env_var() {
    local key="$1"
    local value="$2"
    
    if grep -q "^${key}=" "$ENV_FILE"; then
        # Update existing variable
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
        else
            # Linux/Windows (Git Bash, WSL)
            sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
        fi
    else
        # Add new variable
        echo "${key}=${value}" >> "$ENV_FILE"
    fi
}

# Generate PENPOT_SECRET_KEY if it doesn't exist or has default value
if ! grep -q "^PENPOT_SECRET_KEY=" "$ENV_FILE" || grep -q "^PENPOT_SECRET_KEY=change-this-insecure-key" "$ENV_FILE"; then
    echo "Generating PENPOT_SECRET_KEY..."
    SECRET_KEY=$(generate_secret_key)
    set_env_var "PENPOT_SECRET_KEY" "$SECRET_KEY"
    echo "✓ PENPOT_SECRET_KEY generated"
else
    echo "✓ PENPOT_SECRET_KEY already exists"
fi

# Generate POSTGRES_PASSWORD if it doesn't exist
if ! grep -q "^POSTGRES_PASSWORD=" "$ENV_FILE"; then
    echo "Generating POSTGRES_PASSWORD..."
    POSTGRES_PASS=$(generate_password 32)
    set_env_var "POSTGRES_PASSWORD" "$POSTGRES_PASS"
    echo "✓ POSTGRES_PASSWORD generated"
else
    echo "✓ POSTGRES_PASSWORD already exists"
fi

# Generate PENPOT_DATABASE_PASSWORD if it doesn't exist (can be different from POSTGRES_PASSWORD)
if ! grep -q "^PENPOT_DATABASE_PASSWORD=" "$ENV_FILE"; then
    echo "Generating PENPOT_DATABASE_PASSWORD..."
    DB_PASS=$(generate_password 32)
    set_env_var "PENPOT_DATABASE_PASSWORD" "$DB_PASS"
    echo "✓ PENPOT_DATABASE_PASSWORD generated"
else
    echo "✓ PENPOT_DATABASE_PASSWORD already exists"
fi

echo ""
echo "Keys and passwords generated successfully in $ENV_FILE"
echo "⚠️  IMPORTANT: Keep this file secure and do not share it!"
