# Group 17 - Performance Evaluation

Blockchain-Based Supply Chain Provenance System
CSE 540 - Engineering Blockchain Applications

## 1. Evaluation Overview

- Polygon Amoy: 29 successful transaction receipts.
- Read latency: 120 measurements across four products.
- Hardhat scalability: 10, 50, and 100 products,
  with three repetitions per batch size.
- Total scalability transactions: 480.

## 2. Experimental Results

### Polygon Amoy

- transaction_input.csv: Exported transaction data.
- gas_results.csv: Gas usage and transaction fees.
- gas_summary.txt: Gas analysis by operation.
- read_latency_results.csv: Product read measurements.

The overall average read latency was 575.80 ms.
Each product was measured 30 times after warm-up.

### Hardhat Scalability

Original results are stored in results/original/.
Four original charts are stored in results/charts/.

Average gas usage per registration remained
approximately constant as the batch size increased.

## 3. Reproduction Instructions

Python 3.14, Node.js, npm, and internet access
were used in the tested environment.

    python3 -m venv .venv
    source .venv/bin/activate
    python -m pip install -r requirements.txt
    export SSL_CERT_FILE="$(python -m certifi)"
    export REQUESTS_CA_BUNDLE="$SSL_CERT_FILE"
    export MPLBACKEND=Agg

### Polygon Amoy

    cd polygon_amoy
    python collect_gas_receipts.py
    python measure_read_latency.py
    cd ..

### Hardhat

    cd hardhat_scalability
    npm ci
    npx hardhat compile
    npx hardhat run scripts/run_scalability.ts --network hardhatMainnet
    python plot_scalability.py
    python plot_scalability.py --reproduced
    cd ..

New results are saved separately from original data.
The reproduced chart option requires a completed
scalability run.

The read latency script was reconstructed from
the experimental method and tested successfully.

## 4. Dependency Security

Unused development dependencies were removed,
and Zod was updated to version 4.6.6.

Reported npm vulnerabilities decreased from
16 to 4 and finally to 0 on November 25, 2026.
A forced update was rejected due to dependency conflicts.

Tested versions:

- Hardhat: 3.22.0
- Hardhat Ethers: 4.2.2
- Zod: 4.6.6
- Solidity compiler: 0.8.34

All 480 scalability transactions completed successfully.
Gas values matched the original results.

Direct Python dependencies are pinned in requirements.txt.
npm dependencies are locked in package-lock.json.

Zero reported npm vulnerabilities does not guarantee
complete system security. Install-script warnings remained.

## 5. Limitations

- Hardhat latency represents local execution,
  not public blockchain confirmation time.
- Amoy read latency depends on RPC and network conditions.
- Test POL fees do not represent production costs.
- Access control does not guarantee data confidentiality.

Original experiments were preserved. File names and
documentation were reorganized without rerunning them.
