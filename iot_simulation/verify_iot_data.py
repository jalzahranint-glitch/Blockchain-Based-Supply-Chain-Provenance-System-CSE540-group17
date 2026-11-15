
import hashlib
from pathlib import Path

# Load the original SHA-256 hash.
original_hash = Path("original_hash.txt").read_text().strip()

# Calculate the current IoT file hash.
current_hash = hashlib.sha256(
    Path("iot_readings.json").read_bytes()
).hexdigest()

print("Original Hash:", original_hash)
print("Current Hash: ", current_hash)

# Verify that the data has not been modified.
if original_hash == current_hash:
    print("VERIFIED: IoT data has not been modified.")
else:
    print("WARNING: IoT data has been modified!")
