
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

We currently use:

- **Solidity:** To develop the smart contract.
- **Remix IDE:** To write, compile, deploy, and test the contract.
- **Remix VM:** To test the contract locally.
- **GitHub:** To store and share our project files.

The smart contract uses Solidity `^0.8.20` and was compiled using version `0.8.34`.

For later stages, we plan to use Polygon Amoy, MetaMask, IPFS, and a simple web or command-line interface.

## 3. Smart Contract Features

The main smart contract is `SupplyChain.sol`.

It includes six functions:

- `setParticipantRole()` – Assigns or changes a participant's role.
- `getParticipantRole()` – Returns the role assigned to a participant.
- `registerProduct()` – Registers a new product with a unique ID.
- `getProduct()` – Returns information about a registered product.
- `updateStatus()` – Updates a product's status.
- `transferCustody()` – Transfers custody to the next authorized participant.

The contract also uses events to record product registration, role changes, status updates, and custody transfers.

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

```text
contracts/
    SupplyChain.sol
    UnauthorizedRoleCaller.sol

tests/
    SupplyChain_test.sol

README.md
```

- `SupplyChain.sol` contains the main smart contract.
- `UnauthorizedRoleCaller.sol` is a helper contract used for automated testing.
- `SupplyChain_test.sol` contains the automated unit tests.
- `README.md` contains the project description and setup instructions.

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

## 8. How to Use the Contract

After deployment:

1. The administrator assigns participant roles using `setParticipantRole()`.
2. An authorized Producer registers a product using `registerProduct()`.
3. Users can retrieve product information using `getProduct()`.
4. The current custodian transfers the product using `transferCustody()`.
5. The current custodian updates the product status using `updateStatus()`.
6. Users can check assigned roles using `getParticipantRole()`.

Only the administrator can call `setParticipantRole()`.

Participants must follow the allowed custody transfer sequence.

## 9. Testing

We tested the smart contract using Remix VM and the Solidity Unit Testing plugin.

We completed 10 automated tests. In our latest test run, all 10 tests passed with 0 failures.

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

### How to Run the Automated Tests

1. Open the project files in Remix IDE.
2. Activate the **Solidity Unit Testing** plugin from Plugin Manager.
3. Set the test directory to `tests`.
4. Select `SupplyChain_test.sol`.
5. Click **Run**.
6. Check the test results.

Some tests depend on data created by earlier tests, so the complete test suite should be run together.

## 10. Current Status and Future Work

We have completed the main smart contract functions and tested them locally in Remix VM.

The current version supports product registration, participant roles, custody transfers, status updates, and event logging.

In the next stages, we plan to:

- Deploy the contract to the Polygon Amoy testnet.
- Use MetaMask to connect participant wallets.
- Use IPFS to store product metadata.
- Develop a simple interface for product tracking.
- Continue improving automated tests and system evaluation.

These integrations are planned for future development and are not part of the current implementation.
