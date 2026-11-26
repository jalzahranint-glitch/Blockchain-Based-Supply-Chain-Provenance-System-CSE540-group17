
import csv
import argparse
from pathlib import Path
from statistics import mean, median
from math import ceil
import matplotlib.pyplot as plt

# File paths
BASE = Path(__file__).resolve().parent
# Select original or reproduced experimental data
parser = argparse.ArgumentParser()
parser.add_argument("--reproduced", action="store_true")
args = parser.parse_args()

if args.reproduced:
    CSV_FILE = BASE / "results/reproduced/scalability_results.csv"
    CHARTS_DIR = BASE / "results/reproduced/charts/new_run"
else:
    CSV_FILE = BASE / "results/original/scalability_results.csv"
    CHARTS_DIR = BASE / "results/reproduced/charts/original"

print("Reading:", CSV_FILE)
print("Saving charts to:", CHARTS_DIR)

CHARTS_DIR.mkdir(parents=True, exist_ok=True)

# Read actual experiment results
with open(CSV_FILE, newline="") as f:
    rows = list(csv.DictReader(f))

# Define the tested batch sizes
BATCH_SIZES = [10, 50, 100]
# Each batch size was tested three times
REPEATS = 3

# Validate the measurements
assert len(rows) == 480, "Expected 480 transactions"

summary = {}

# Analyze the results for each batch size
for n in BATCH_SIZES:
    group = [
        r for r in rows
        if int(r["BatchSize"]) == n
    ]

    # Verify the expected number of transactions
    assert len(group) == n * REPEATS

    # Extract gas usage from transaction records
    gas = [int(r["GasUsed"]) for r in group]
    # Sort latency values for statistical analysis
    latency = sorted(float(r["LatencyMs"]) for r in group)

    # Calculate gas and latency statistics
    summary[n] = {
        # Average total gas consumption per run
        "total_gas": sum(gas) / REPEATS,
        # Average gas consumption per product
        "avg_gas": mean(gas),
        "avg_latency": mean(latency),
        "median_latency": median(latency),
        # Calculate P95 using the nearest-rank method
        "p95_latency": latency[ceil(0.95 * len(latency)) - 1]
    }

# Chart 1: Total Gas Consumption
counts = [10, 50, 100]
total_gas = [summary[n]["total_gas"] for n in counts]

plt.figure(figsize=(8, 5))

bars = plt.bar(
    [str(n) for n in counts],
    total_gas,
    color="#287a65"
)

plt.bar_label(bars, fmt="%.0f", padding=4)

plt.title("Total Gas Consumption vs Number of Products")
plt.xlabel("Number of Products")
plt.ylabel("Average Total Gas per Run")

plt.ylim(0, max(total_gas) * 1.2)
plt.grid(axis="y", alpha=0.25)
plt.tight_layout()

plt.savefig(
    CHARTS_DIR / "01_total_gas.png",
    dpi=300
)
plt.close()


# Chart 2: Average Gas per Product
avg_gas = [summary[n]["avg_gas"] for n in counts]

plt.figure(figsize=(8, 5))

plt.plot(
    counts,
    avg_gas,
    marker="o",
    linewidth=2,
    markersize=8,
    color="#287a65"
)

for x, y in zip(counts, avg_gas):
    plt.annotate(
        f"{y:,.2f}",
        (x, y),
        textcoords="offset points",
        xytext=(0, 10),
        ha="center"
    )

plt.title("Average Gas per Product")
plt.xlabel("Number of Products")
plt.ylabel("Average Gas Used")

plt.xticks(counts)
plt.ylim(0, max(avg_gas) * 1.2)
plt.grid(alpha=0.25)
plt.tight_layout()

plt.savefig(
    CHARTS_DIR / "02_average_gas.png",
    dpi=300
)
plt.close()

# Chart 3: Average Local Latency
avg_latency = [summary[n]["avg_latency"] for n in counts]

plt.figure(figsize=(8, 5))

bars = plt.bar(
    [str(n) for n in counts],
    avg_latency,
    color="#287a65"
)

plt.bar_label(bars, fmt="%.3f", padding=4)

plt.title("Average Local Transaction Latency")
plt.xlabel("Number of Products")
plt.ylabel("Average Latency per Transaction (ms)")

plt.ylim(0, max(avg_latency) * 1.2)
plt.grid(axis="y", alpha=0.25)
plt.tight_layout()

plt.savefig(
    CHARTS_DIR / "03_average_latency.png",
    dpi=300
)
plt.close()

# Chart 4: Median and P95 Local Latency
median_latency = [summary[n]["median_latency"] for n in counts]
p95_latency = [summary[n]["p95_latency"] for n in counts]

plt.figure(figsize=(8, 5))

plt.plot(
    counts,
    median_latency,
    marker="o",
    linewidth=2,
    label="Median Latency"
)

plt.plot(
    counts,
    p95_latency,
    marker="s",
    linewidth=2,
    label="P95 Latency"
)

plt.title("Median and P95 Local Transaction Latency")
plt.xlabel("Number of Products")
plt.ylabel("Latency per Transaction (ms)")

plt.xticks(counts)
plt.ylim(0, max(p95_latency) * 1.2)
plt.legend()
plt.grid(alpha=0.25)
plt.tight_layout()

plt.savefig(
    CHARTS_DIR / "04_median_p95_latency.png",
    dpi=300
)
plt.close()

