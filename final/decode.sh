#!/bin/bash

# Target URL (root path):
TARGET="http://$1/"

# Charset for the possible flag, def "THM{...}"
CHARSET="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!/_{}"

# After a stall, get the found from the recovered.txt file:
FOUND=""
if [[ -f recovered.txt ]]; then
  FOUND=$(<recovered.txt)
  echo "[*] Resuming from saved state: '$FOUND'"
fi

# Build user agent from 256 'A's and shift based on FOUND length:
UA=$(printf 'A%.0s' {1..256}) # user agent = 'AAAAAAA ... AAAAA'
shift_count=${#FOUND}         # The recovered flag from the previous run and count its length
UA="${UA:shift_count}"        # Shift the user agent back by the length of the flag found so far

# Compute TEST_WINDOW from full known string
FULL_KNOWN="guest:${UA}:${FOUND}" # Re-build the fully known flag, and keep the user agent AAAAAAAs 
TEST_WINDOW="${FULL_KNOWN: -8}"   # Update the string window to test the newly, updated secret key

# Start, or continue from where we left of in recovered.txt
echo "[*] Starting brute-force against $TARGET ..."
while true; do
  echo
  echo "[*] Known so far: '$FOUND'"
  echo "[*] Fetching cookie with UA length ${#UA}..." # Get the new user agent length

  # Fetch secure_cookie header
  raw_hdr=$(curl -s -D - -A "$UA" "$TARGET" | grep -i '^Set-Cookie: secure_cookie=' || true) # get the secure_cookie
  cookie_val=$(printf '%s' "$raw_hdr" | sed -E 's/.*secure_cookie=([^;]+).*/\1/') # get the cookie value
  # URL-decode the cookie:
  decoded=$(printf '%b' "${cookie_val//%/\\x}") 
  
  # Extract salt and full hash
  SALT="${decoded:0:2}" # The first two characters of the decoded cookie is the salt
  SECURE_COOKIE="$decoded"
  echo "[*] Salt='$SALT'  Cookie='$SECURE_COOKIE'"

  # Slide UA window
  UA="${UA:1}" # Decrease the size of the user agent each time 

   
  echo "[*] Brute-forcing next character..."
  next_char=""
  # Loop through the charset "abcd...ABCD...12345...{}/" and check the result of the hash and the salt with the current block
  for (( i=0; i<${#CHARSET}; i++ )); do
    CH="${CHARSET:i:1}"
    CANDIDATE="${TEST_WINDOW:1}${CH}" # Test the candidate character from the charset
    # Call the crypt function using php with the salt 
    HASH=$(CANDIDATE="$CANDIDATE" SALT="$SALT" php -r 'echo crypt(getenv("CANDIDATE"), getenv("SALT"));')
    
    # Compare the crypt value with the current hashed value
    if [[ "$SECURE_COOKIE" == *"$HASH"* ]]; then
      next_char="$CH"
      FOUND+="$CH" # If match is found, we found the next valid character for the flag
      TEST_WINDOW="$CANDIDATE"
      echo "[+] Found byte: '$CH'  →  '$FOUND'"
      echo "$FOUND" > recovered.txt # save the updated flag to the file in case of hang or exit
      break
    fi
  done
done

echo
echo "=== SECRET RECOVERED ==="
echo "$FOUND" # Display the flag
