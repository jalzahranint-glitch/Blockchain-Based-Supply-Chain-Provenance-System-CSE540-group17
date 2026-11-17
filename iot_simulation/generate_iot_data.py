
import json
import random
import hashlib
from pathlib import Path
from datetime import datetime, timedelta, timezone
# Generate simulated IoT readings for product 18001.
rng = random.Random(540)
start = datetime(2026, 11, 14, 9, 0, tzinfo=timezone.utc)

readings = []

for i in range(20):
    reading = {
        "timestamp": (
            start + timedelta(minutes=i * 5)
        ).isoformat(),
        "temperature": round(rng.uniform(2, 8), 1),
        "humidity": round(rng.uniform(45, 65), 1)
    }
    readings.append(reading)

data = {
    "productId": 18001,
    "sensorId": "SENSOR-001",
    "location": "Warehouse A",
    "readings": readings
}

json_file = Path("iot_readings.json")
hash_file = Path("original_hash.txt")

# Protect the original evidence from accidental overwrite.
if json_file.exists() or hash_file.exists():
    raise SystemExit("Files already exist. No files overwritten.")

# Save off-chain sensor data.
json_file.write_text(
    json.dumps(data, indent=2) + "\n",
    encoding="utf-8"
)

# Calculate SHA-256 from the saved file.
data_hash = hashlib.sha256(
    json_file.read_bytes()
).hexdigest()

hash_file.write_text(data_hash + "\n", encoding="utf-8")

print("Generated 20 IoT readings.")
print("Product ID:", data["productId"])
print("SHA-256:", "0x" + data_hash)
