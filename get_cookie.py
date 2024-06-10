# I got this mostly from the internet. Chrome stores cookies in a Cookie file
# under the Chrome profile directory. Cookies are encrypted using a password
# which is available online, or possibly needs to be found in the keychain(?).
# Here I find the cookie for the VMS I want to access. This only works as long
# as I'm logged in in the browser.

from Crypto.Cipher import AES
from Crypto.Protocol.KDF import PBKDF2
from sqlite3 import dbapi2
import sys


def decrypt_with_key(encrypted_value, key, salt, iv, length, iterations):
    my_pass = key.encode('utf8')

    key = PBKDF2(my_pass, salt, length, iterations)
    cipher = AES.new(key, AES.MODE_CBC, IV=iv)

    decrypted = cipher.decrypt(encrypted_value)
    return clean(decrypted)

def clean(x):
    return x[:-x[-1]].decode('utf8').replace("\x08", "")  # Remove backspace characters

def decrypt(encrypted_value):
    # Trim off the 'v10' that Chrome/ium prepends
    encrypted_value = encrypted_value[3:]

    # Default values used by both Chrome and Chromium in OSX and Linux
    salt = b'saltysalt'
    iv = b' ' * 16
    length = 16 
    iterations = 1  # 1003 on Mac, 1 on Linux

    try:
        # This is the old password which Google still uses sometimes.
        key = 'peanuts'
        return decrypt_with_key(encrypted_value, key, salt, iv, length, iterations)
    except UnicodeDecodeError:
        # This is the new password, retrieved from seahorse.
        key = 'R1LVz6+VIq4eGyCEm6wqYg=='
        return decrypt_with_key(encrypted_value, key, salt, iv, length, iterations)


database = "/home/lightningman/.config/google-chrome/Profile 3/Cookies"
sql = 'SELECT name, encrypted_value FROM cookies WHERE host_key like "%%%s%%"' % sys.argv[1]

with dbapi2.connect(database) as conn:
    cursor = conn.cursor()
    cursor.execute(sql)
    rows = cursor.fetchall()
    conn.rollback()

cookies = {}
for name, enc_val in rows:
    val = decrypt(enc_val)
    cookies[name] = val

if "va" not in cookies:
    print("No cookie found. Are you logged in to the VMS UI?", file=sys.stderr)
else:
    print(cookies["va"])
