#!/bin/python3
import binascii
import struct
import sys
import os


def crc(d):
    """Compute a 4-byte checksum of d."""
    return struct.pack("<I", binascii.crc32(d))


def x(d):
    """No spaces, please."""
    return binascii.unhexlify(d.replace(" ", ""))


if len(sys.argv) != 2:
    print("ERROR: python3 {} NEW_SOUND_FILE.mp3".format(sys.argv[0]))
    sys.exit(1)

print("[-] Searching for Slack dir")
dir_slack = os.path.expanduser('~') + "/.config/Slack/Cache/Cache_Data"


# Not used
def find_slack_path() -> str:
    """Something."""
    print("[-] Searching for hummus sound cache file")

    # import ipdb;ipdb.set_trace()
    command_grep = os.popen("grep -ira hummus-200e354.mp3 \"{}\"".
                            format(dir_slack) + "/*_s")

    command_grep_output = command_grep.read()

    if not command_grep_output or "matches" not in command_grep_output:
        print("ERROR: No Hummus sound cache file! Go to " +
              "Slack-->Preferences-->Notifications-->Select Hummus, " +
              "then close Slack and try again")
        sys.exit(1)

    hummus_sound_cache_filename = command_grep_output.\
        split("Cache_Data/")[1].split(" matches")[0]
    hummus_sound_cache_filepath = dir_slack + "/" + hummus_sound_cache_filename
    print("[-] Found hummus sound cache file '{}'".
          format(hummus_sound_cache_filename))
    return hummus_sound_cache_filepath


# Use this because the the function above has trouble parsing the binary files.
hummus_sound_cache_filepath = dir_slack + "/e3d6a602201da2bc_s"

# "bv1-13" in the string below: Looks like this number changes with updates..
req_resource = "1/0/" + "https://a.slack-edge.com/bv1-13/hummus-200e354.mp3"
new_sound_file = sys.argv[1]
new_file_data = open(new_sound_file, "rb").read()
print("[-] Overwriting cache file '{}' with '{}'".format(hummus_sound_cache_filepath, new_sound_file))


new_cache_data = b""
new_cache_data += x("30 5C 72 A7 1B 6D FB FC 09 00 00 00")  # magic
new_cache_data += struct.pack("<I", len(req_resource))      # resource path len
# new_cache_data += crc(b"") + b"\x00\x00\x00\x00"            # ?
new_cache_data += b"\xed\xe8\xd5\xf2\x00\x00\x00\x00"       # ?
new_cache_data += req_resource.encode()                     # requested resource
new_cache_data += x("6B 67 53 65 01 BF 97 EB 00 00 00 00 00 00 00 00") # magic ?
print("len of sound file: {} (in binary {})".format(len(new_file_data), struct.pack("<I", len(new_file_data))))
new_cache_data += struct.pack("<I", len(new_file_data)) + b"\x00\x00\x00\x00"           # resource len
new_cache_data += crc(new_file_data) + b"\x00\x00\x00\x00"      # resource checksum
new_cache_data += new_file_data


with open(hummus_sound_cache_filepath, "wb") as f:
    f.write(new_cache_data)

print("[-] DONE! Please restart Slack and change the notification sound to Hummus (Slack-->Preferences-->Notifications-->Select Hummus)")