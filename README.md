
# Blockchain-Based Supply Chain Provenance System

**CSE 540 – Engineering Blockchain Applications**  
**Group 17 | Fall B 2026**

**Team Members:**
- Sarah Al Humudh
- Jawaher Alzahrani
- Razan Alshehri
- Arya Ravindra Patil

## 1. Project Overview

Our project is a blockchain-based system that tracks products as they move through a supply chain.

The system records product registration, custody transfers, and status updates. Each product has a unique ID, and its information is stored in a Solidity smart contract.

Our goal is to make product tracking more transparent and reliable by recording important supply chain activities on the blockchain.

## 2. Tools and Technologies

- **Solidity:** Smart contract development.
- **Remix IDE and Remix VM:** Local development and testing.
- **GitHub:** Source code and documentation.
- **Python:** IoT simulation and performance evaluation.
- **SHA-256:** Data integrity verification.
- **Polygon Amoy:** Public testnet deployment and testing.
- **MetaMask:** Wallet connection and transaction authorization.
- **Web Interface:** Interaction with the smart contract.
- **Hardhat:** Local scalability experiments.
- **Web3.py:** Gas analysis and read latency measurements.
- **Matplotlib:** Performance visualization.

The smart contract uses Solidity `^0.8.20` and was compiled using version `0.8.34`.

## 3. Smart Contract Features

The main smart contract is `SupplyChain.sol`.

The main smart contract includes the following functions:
- `setParticipantRole()` – Assigns or changes participant roles.
- `getParticipantRole()` – Returns a participant's assigned role.
- `registerProduct()` – Registers a new product with a unique ID.
- `getProduct()` – Returns information about a registered product.
- `updateStatus()` – Updates a product's status.
- `transferCustody()` – Transfers custody to the next authorized participant.
- `transferAdministration()` – Nominates a new administrator.
- `acceptAdministration()` – Allows the nominated administrator to accept control.
- `adminReassignCustody()` – Reassigns custody when the current custodian is no longer authorized.
- `recordIoTHash()` – Records the SHA-256 hash of off-chain IoT data.
- `verifyIoTHash()` – Checks whether an IoT data hash matches the stored hash.
  
The contract also uses events to record product registration, role changes, status updates, custody transfers, administration changes, and IoT hash recordings.

## 4. Participant Roles

The system includes an administrator and five participant roles:

- **Administrator:** Assigns and manages participant roles.
- **Producer:** Registers new products.
- **Transporter:** Receives products for transportation.
- **Warehouse:** Receives products for storage.
- **Retailer:** Receives products at the final stage.
- **Viewer:** A read-only role that cannot register products, update status, or transfer custody.

Product information can also be viewed by users without an assigned role.

The administrator does not automatically have the Producer role. To register products, the administrator must assign the Producer role to an account.

## 5. Product Tracking Process

Products move through the following participants:

**Producer → Transporter → Warehouse → Retailer**

Each product also moves through four status stages:

**Created → Shipped → Received → Delivered**

Only the current custodian can transfer a product or update its status.

The contract checks participant roles and prevents invalid custody transfers, duplicate product IDs, and incorrect status transitions.

## 6. Repository Structure

    Frontend/
        public/
        src/
        index.html
        package.json
        package-lock.json
        vite.config.js

    contracts/
        SupplyChain.sol
        UnauthorizedRoleCaller.sol

    iot_simulation/
        generate_iot_data.py
        verify_iot_data.py
        iot_readings.json
        iot_readings_tampered.json
        original_hash.txt

    tests/
        SupplyChain_test.sol

    README.md

- `Frontend/` contains the web interface and wallet integration.
- `contracts/` contains the smart contract and supporting contract for access control testing.
- `iot_simulation/` contains Python scripts and sample IoT data for integrity verification.
- `tests/` contains automated smart contract unit tests.
- `README.md` contains project documentation.

## 7. How to Compile and Deploy

1. Open [Remix IDE](https://app.remix.live/).
2. Open the project workspace or create a new workspace.
3. Add the `contracts/SupplyChain.sol` file.
4. Open the **Solidity Compiler** tab.
5. Select Solidity compiler version `0.8.34`.
6. Click **Compile SupplyChain.sol**.
7. Open the **Deploy & Run Transactions** tab.
8. Select **Remix VM** as the environment.
9. Select the `SupplyChain` contract.
10. Click **Deploy**.

The account that deploys the contract becomes the administrator.

No real cryptocurrency is needed when testing in Remix VM.
The contract has been deployed and tested locally using Remix VM. Deployment to the Polygon Amoy testnet is planned for a later stage.

## 8. How to Use the Contract

After deployment:


1. The administrator assigns participant roles using `setParticipantRole()`.
2. An authorized Producer registers a product using `registerProduct()`.
3. Users can retrieve product information using `getProduct()`.
4. The current custodian transfers the product using `transferCustody()`.
5. The current custodian updates the product status using `updateStatus()`.
6. Users can check assigned roles using `getParticipantRole()`.
7. The administrator can nominate a new administrator using `transferAdministration()`. The nominated account must call `acceptAdministration()` to complete the transfer.
8. If a custodian loses the required role, the administrator can reassign custody using `adminReassignCustody()`.
9. The current authorized custodian can record an IoT data hash using `recordIoTHash()`.
10. Users can verify the recorded IoT hash using `verifyIoTHash()`.

Only the administrator can assign participant roles or reassign custody when the current custodian is no longer authorized.

Participants must follow the allowed custody transfer sequence.

The IoT hash verification function returns `true` when the provided hash matches the stored hash and `false` when it does not match.

### Web Interface

The web interface allows users to connect their MetaMask wallets to Polygon Amoy and interact with the deployed smart contract.

Users can register products, retrieve product information, transfer custody, update product status, and record IoT data hashes.

All write operations are subject to role-based access control.

## 9. Testing
We tested the smart contract locally using Remix VM and the Solidity Unit Testing plugin.

We completed 17 automated tests. In our latest test run, all 17 tests passed with 0 failures.

The tests cover:

1. Product registration.
2. Duplicate product rejection.
3. Unauthorized role assignment rejection.
4. Producer to Transporter custody transfer.
5. Transporter to Warehouse custody transfer.
6. Warehouse to Retailer custody transfer.
7. Product status updates from Created to Delivered.
8. Invalid status transition rejection.
9. Invalid custody transfer rejection.
10. Custody transfer rejection after delivery.
11. Administration nomination.
12. Administration acceptance.
13. Administrator custody recovery.
14. Reassignment rejection when the current custodian is still authorized.
15. Reassignment rejection when the new custodian has an incorrect role.
16. IoT hash verification.
17. Unauthorized IoT hash recording rejection.

### How to Run the Automated Tests

1. Open the project files in Remix IDE.
2. Activate the **Solidity Unit Testing** plugin from Plugin Manager.
3. Set the test directory to `tests`.
4. Select `SupplyChain_test.sol`.
5. Click **Run**.
6. Check the test results.

Some tests depend on data created by earlier tests, so the complete test suite should be run together.

### IoT Data Integrity Testing

We also tested IoT data integrity using Python and SHA-256.

The simulation generated 20 sensor readings containing temperature and humidity values.

We calculated the SHA-256 hash of the original data and verified that it matched the hash recorded in the smart contract.

We then modified a temperature reading to simulate data tampering.

The original hash returned `true` during verification, while the modified data hash returned `false`.

These tests were performed locally using Python and Remix VM.

### Performance Evaluation

Performance was evaluated using Polygon Amoy and Hardhat.

- Gas Analysis: 29 successful transaction receipts.
- Read Latency: 120 measurements across four products.
- Average Read Latency: 575.80 ms.
- Scalability: 480 product registration transactions.
- Batch Sizes: 10, 50, and 100 products.
- Repetitions: Three runs per batch size.

Gas usage per registration remained approximately constant as the batch size increased.

All evaluation scripts were successfully rerun, and the original results were preserved.

Local Hardhat execution times do not represent public blockchain confirmation times.

## 10. Current Status and Future Work

The project includes a deployed smart contract, role-based access control, product tracking, a web interface, and IoT data integrity verification.

Gas analysis, read latency measurements, and scalability experiments have been completed.

### Future Work

- Integrate IPFS for decentralized off-chain data storage.
- Integrate real IoT devices instead of simulated sensor readings.
- Improve privacy protection for sensitive supply chain data.
- Evaluate performance under larger workloads and concurrent users.

The current system is a prototype for blockchain-based supply chain provenance.

## 11. How to Run the IoT Simulation

The `iot_simulation` folder contains Python scripts and sample sensor data used to demonstrate data integrity verification.

### Requirements

- Python 3
- No additional Python libraries are required.

### Steps

1. Open a terminal.
2. Navigate to the `iot_simulation` directory:

```bash
cd iot_simulation
```

3. Verify the original IoT data:

```bash
python3 verify_iot_data.py
```

If the data has not been modified, the script displays:

```text
VERIFIED: IoT data has not been modified
```

4. Compare the original and modified IoT data hashes:

```bash
shasum -a 256 iot_readings.json iot_readings_tampered.json
```

The two files produce different SHA-256 hashes, demonstrating how modifications to the sensor data can be detected.

The `generate_iot_data.py` script was used to create the original 20 simulated sensor readings and their SHA-256 hash. The generated files are already included in the repository.

The original hash can also be recorded using `recordIoTHash()` and checked using `verifyIoTHash()` in Remix VM.




