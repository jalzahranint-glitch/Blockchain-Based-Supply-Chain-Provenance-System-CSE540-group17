from web3 import Web3
from time import perf_counter
from statistics import mean, median
from math import ceil
from datetime import datetime
from pathlib import Path
import csv
import os

# Configure the Polygon Amoy RPC endpoint
RPC_URL = os.getenv("AMOY_RPC_URL",
                    "https://polygon-amoy.drpc.org")

# Address of the deployed SupplyChain contract
CONTRACT = "0xb038fc9d3922f8dd06085b0d3548d30b90a82e67"

# Select four products for the latency experiment
PRODUCTS = [17001, 18001, 19001, 20001]
# Number of measured reads per product
REPEATS = 30

# Connect to the blockchain using Web3
w3 = Web3(Web3.HTTPProvider(RPC_URL))
address = Web3.to_checksum_address(CONTRACT)

# Verify that the connected network is Polygon Amoy
assert w3.eth.chain_id == 80002

# Generate the selector for the getProduct function
selector = Web3.keccak(text="getProduct(uint256)")[:4]

records = []
times = {p: [] for p in PRODUCTS}

# Read product information using eth_call
def read_product(product_id):
    data = selector + product_id.to_bytes(32, "big")
    return w3.eth.call({"to": address, "data": data})

# Warm-up requests (not measured)
for product_id in PRODUCTS:
    assert len(read_product(product_id)) > 0

# Interleaved timed reads
for run in range(1, REPEATS + 1):
    for product_id in PRODUCTS:
        # Measure the RPC response time in milliseconds
        start = perf_counter()
        result = read_product(product_id)
        ms = (perf_counter() - start) * 1000

        if len(result) == 0:
            raise RuntimeError("Empty response")

        # Store the measured latency for each product
        times[product_id].append(ms)
        records.append([
            product_id, run, round(ms, 3), len(result)
        ])

    if run % 5 == 0:
        print(f"Completed round {run}/{REPEATS}")

for product_id in PRODUCTS:
    values = times[product_id]
    # Calculate the 95th percentile latency
    p95 = sorted(values)[ceil(0.95 * len(values)) - 1]

    print(f"\nProduct {product_id}")
    print(f"Average: {mean(values):.2f} ms")
    print(f"Median: {median(values):.2f} ms")
    print(f"P95: {p95:.2f} ms")

# Keep new measurements separate from original results
out = Path(__file__).resolve().parent / "reproduced"
out.mkdir(exist_ok=True)

# Generate a timestamped filename
filename = out / (
    f"read_latency_"
    f"{datetime.now():%Y%m%d_%H%M%S}.csv"
)

# Save all latency measurements to a CSV file
with filename.open("x", newline="") as f:
    writer = csv.writer(f)
    writer.writerow([
        "Product ID", "Run",
        "Latency (ms)", "Response Bytes"
    ])
    writer.writerows(records)

print(f"\nSaved {len(records)} measurements")
print(filename)
