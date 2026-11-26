
import { network } from "hardhat";
import { mkdirSync, writeFileSync } from "node:fs";
import { performance } from "node:perf_hooks";

// Scalability experiment settings
const BATCH_SIZES = [10, 50, 100];
const REPEATS = 3;
const OUTPUT_DIR = "results/reproduced";


async function main() {
  mkdirSync(OUTPUT_DIR, { recursive: true });

  const measurements: string[] = [
    "BatchSize,Repeat,ProductIndex,GasUsed,LatencyMs"
  ];

  for (const batchSize of BATCH_SIZES) {
    for (let repeat = 1; repeat <= REPEATS; repeat++) {

      // Create a fresh local blockchain for each run
      const { ethers } = await network.create();

      const [admin, producer] = await ethers.getSigners();

      // Deploy the same SupplyChain contract
      const contract = await ethers.deployContract(
        "SupplyChain",
        [],
        admin
      );
      await contract.waitForDeployment();

      // Give the producer permission to register products
      const roleTx = await contract.setParticipantRole(
        await producer.getAddress(),
        1
      );
      await roleTx.wait();

      console.log(
        `Ready: ${batchSize} products, repetition ${repeat}`
      );


      // Connect as the Producer
      const producerContract = await ethers.getContractAt(
        "SupplyChain",
        await contract.getAddress(),
        producer
      );

      for (let i = 1; i <= batchSize; i++) {
        const productId = 100000 + i;
        const uri =
          `demo://group17/product-${String(i).padStart(6, "0")}`;

        // Measure local transaction completion time
        const start = performance.now();

        const tx = await producerContract.registerProduct(
          productId,
          uri
        );

        const receipt = await tx.wait();
        const end = performance.now();

        if (!receipt || receipt.status !== 1) {
          throw new Error(`Transaction failed: ${productId}`);
        }

        const gasUsed = receipt.gasUsed.toString();
        const latencyMs = (end - start).toFixed(3);

        measurements.push(
          `${batchSize},${repeat},${i},${gasUsed},${latencyMs}`
        );
      }

      // Save results after each completed repetition
      writeFileSync(
        `${OUTPUT_DIR}/scalability_results.csv`,
        measurements.join("\n") + "\n"
      );

      console.log(`Completed: ${batchSize}, run ${repeat}`);
    }
  }

  console.log("All scalability experiments completed!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

