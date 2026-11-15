
 // SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "remix_tests.sol";
import "../contracts/SupplyChain.sol";
import "../contracts/UnauthorizedRoleCaller.sol";

contract SupplyChainTest {
    SupplyChain supplyChain;
    UnauthorizedRoleCaller transporterContract;
    UnauthorizedRoleCaller warehouseContract;
    UnauthorizedRoleCaller retailerContract;
    function beforeAll() public {
        // Deploy a fresh contract for testing.
        supplyChain = new SupplyChain();

        // Give this test contract the Producer role.
        supplyChain.setParticipantRole(
            address(this),
            SupplyChain.Role.Producer
        );
    }

    function testProductRegistration() public {
        // Register a sample product.
        supplyChain.registerProduct(
            1001,
            "ipfs://example-product-1001"
        );

        // Retrieve the registered product.
        SupplyChain.Product memory product =
            supplyChain.getProduct(1001);

        // Verify that the product was registered correctly.
        Assert.equal(
            product.id,
            uint256(1001),
            "Product ID should be 1001"
        );

        Assert.ok(
            product.exists,
            "Product should exist"
        );

        Assert.equal(
            product.producer,
            address(this),
            "Producer should match"
        );

        Assert.equal(
            uint256(product.status),
            uint256(SupplyChain.ProductStatus.Created),
            "Initial status should be Created"
        );
    }



function testDuplicateProductRejection() public {
    // Attempt to register an existing product again.
    try supplyChain.registerProduct(
        1001,
        "ipfs://duplicate-product"
    ) {
        Assert.ok(false, "Duplicate product should be rejected");
    } catch Error(string memory reason) {
        Assert.equal(
            reason,
            "Product already registered",
            "Expected duplicate product rejection"
        );
    } catch {
        Assert.ok(false, "Unexpected rejection reason");
    }
}




function testUnauthorizedRoleAssignment() public {
    // A separate contract acts as a non-administrator.
    UnauthorizedRoleCaller caller =
        new UnauthorizedRoleCaller();

    try caller.assignRole(supplyChain) {
        Assert.ok(
            false,
            "Non-admin role assignment should fail"
        );
    } catch Error(string memory reason) {
        Assert.equal(
            reason,
            "Only administrator can perform this action",
            "Expected administrator permission rejection"
        );
    } catch {
        Assert.ok(
            false,
            "Unexpected rejection reason"
        );
    }
}


function testProducerToTransporterTransfer() public {
   
    
transporterContract = new UnauthorizedRoleCaller();
address transporter = address(transporterContract);


    // Assign the transporter role.
    supplyChain.setParticipantRole(
        transporter,
        SupplyChain.Role.Transporter
    );

    // Transfer custody of product 1001.
    supplyChain.transferCustody(1001, transporter);

    // Retrieve the updated product.
    SupplyChain.Product memory product =
        supplyChain.getProduct(1001);

    // Verify the new custodian.
    Assert.equal(
        product.currentCustodian,
        transporter,
        "Custody should transfer to transporter"
    );
}

function testTransporterToWarehouseTransfer() public {
    // Create a warehouse participant.
    warehouseContract = new UnauthorizedRoleCaller();
    address warehouse = address(warehouseContract);

    // Assign the Warehouse role.
    supplyChain.setParticipantRole(
        warehouse,
        SupplyChain.Role.Warehouse
    );

    // Transporter updates the status before transferring custody.
    transporterContract.changeProductStatus(
        supplyChain,
        1001,
        SupplyChain.ProductStatus.Shipped
    );

    // The transporter transfers custody to the warehouse.
    transporterContract.transferProduct(
        supplyChain,
        1001,
        warehouse
    );

    // Verify the new custodian.
    SupplyChain.Product memory product =
        supplyChain.getProduct(1001);

    Assert.equal(
        product.currentCustodian,
        warehouse,
        "Custody should transfer to warehouse"
    );
}

function testWarehouseToRetailerTransfer() public {
   // Create a retailer participant.
retailerContract = new UnauthorizedRoleCaller();

address retailer = address(retailerContract);
    

    // Assign the Retailer role.
    supplyChain.setParticipantRole(
        retailer,
        SupplyChain.Role.Retailer
    );

    // Warehouse marks the product as Received
    // before transferring custody to Retailer.
    warehouseContract.changeProductStatus(
        supplyChain,
        1001,
        SupplyChain.ProductStatus.Received
    );

    // The warehouse transfers custody to the retailer.
    warehouseContract.transferProduct(
        supplyChain,
        1001,
        retailer
    );

    // Verify the new custodian.
    SupplyChain.Product memory product =
        supplyChain.getProduct(1001);

    Assert.equal(
        product.currentCustodian,
        retailer,
        "Custody should transfer to retailer"
    );
}

function testProductStatusUpdates() public {
    // Create a fresh product for status testing.
    supplyChain.registerProduct(
        2002,
        "ipfs://test-product-2002"
    );

    // Assign the product to the transporter.
    supplyChain.transferCustody(
        2002,
        address(transporterContract)
    );

    // Transporter updates the status to Shipped.
    transporterContract.changeProductStatus(
        supplyChain,
        2002,
        SupplyChain.ProductStatus.Shipped
    );

    // Verify the Shipped status.
    SupplyChain.Product memory product =
        supplyChain.getProduct(2002);

    Assert.equal(
        uint256(product.status),
        uint256(SupplyChain.ProductStatus.Shipped),
        "Status should be Shipped"
    );

    // Transfer custody to Warehouse.
    transporterContract.transferProduct(
        supplyChain,
        2002,
        address(warehouseContract)
    );

    // Warehouse updates status to Received.
    warehouseContract.changeProductStatus(
        supplyChain,
        2002,
        SupplyChain.ProductStatus.Received
    );

    // Verify the Received status.
    product = supplyChain.getProduct(2002);

    Assert.equal(
        uint256(product.status),
        uint256(SupplyChain.ProductStatus.Received),
        "Status should be Received"
    );

    // Transfer custody to Retailer.
    warehouseContract.transferProduct(
        supplyChain,
        2002,
        address(retailerContract)
    );

    // Retailer updates status to Delivered.
    retailerContract.changeProductStatus(
        supplyChain,
        2002,
        SupplyChain.ProductStatus.Delivered
    );

    // Verify the final status.
    product = supplyChain.getProduct(2002);

    Assert.equal(
        uint256(product.status),
        uint256(SupplyChain.ProductStatus.Delivered),
        "Status should be Delivered"
    );
}

function testInvalidStatusTransition() public {
    // Register a new product.
    supplyChain.registerProduct(
        3003,
        "ipfs://test-product-3003"
    );

    // Transfer custody to the authorized transporter.
    supplyChain.transferCustody(
        3003,
        address(transporterContract)
    );

    // Valid transition from Created to Shipped.
    transporterContract.changeProductStatus(
        supplyChain,
        3003,
        SupplyChain.ProductStatus.Shipped
    );

    // Try updating to Shipped again.
    // The role is valid, but the transition is invalid.
    try transporterContract.changeProductStatus(
        supplyChain,
        3003,
        SupplyChain.ProductStatus.Shipped
    ) {
        Assert.ok(false, "Invalid transition should fail");
    } catch Error(string memory reason) {
        Assert.equal(
            reason,
            "Invalid status transition",
            "Expected transition rejection"
        );
    } catch {
        Assert.ok(false, "Unexpected rejection reason");
    }

    SupplyChain.Product memory product =
        supplyChain.getProduct(3003);

    Assert.equal(
        uint256(product.status),
        uint256(SupplyChain.ProductStatus.Shipped),
        "Status should remain Shipped"
    );
}

function testInvalidCustodyTransfer() public {
    // Register a new product.
    supplyChain.registerProduct(
        4004,
        "ipfs://test-product-4004"
    );

    // Create a participant with the Retailer role.
    UnauthorizedRoleCaller invalidRetailer =
        new UnauthorizedRoleCaller();

    supplyChain.setParticipantRole(
        address(invalidRetailer),
        SupplyChain.Role.Retailer
    );

    // Attempt an invalid Producer-to-Retailer transfer.
    try supplyChain.transferCustody(
        4004,
        address(invalidRetailer)
    ) {
        Assert.ok(false, "Invalid custody transfer should fail");
    } catch Error(string memory reason) {
        Assert.equal(
            reason,
            "Invalid custody transfer path or status",
            "Expected invalid custody transfer rejection"
        );
    } catch {
        Assert.ok(false, "Unexpected rejection reason");
    }

    // Verify that custody remains with the Producer.
    SupplyChain.Product memory product =
        supplyChain.getProduct(4004);

    Assert.equal(
        product.currentCustodian,
        address(this),
        "Custody should remain with Producer"
    );
}







function testTransferAfterDeliveryRejection() public {
    // Product 2002 was delivered in a previous test.
    SupplyChain.Product memory product =
        supplyChain.getProduct(2002);

    Assert.equal(
        uint256(product.status),
        uint256(SupplyChain.ProductStatus.Delivered),
        "Product must be Delivered before this test"
    );

    address previousCustodian = product.currentCustodian;

    // Create another participant.
    UnauthorizedRoleCaller newTransporter =
        new UnauthorizedRoleCaller();

    supplyChain.setParticipantRole(
        address(newTransporter),
        SupplyChain.Role.Transporter
    );

    // Verify that the transaction fails because
    // the product has already been delivered.
    try retailerContract.transferProduct(
        supplyChain,
        2002,
        address(newTransporter)
    ) {
        Assert.ok(false, "Transfer after delivery should fail");
    } catch Error(string memory reason) {
        Assert.equal(
            reason,
            "Product already delivered",
            "Expected delivered-product rejection"
        );
    } catch {
        Assert.ok(false, "Unexpected rejection reason");
    }

    // Verify that custody remains unchanged.
    product = supplyChain.getProduct(2002);

    Assert.equal(
        product.currentCustodian,
        previousCustodian,
        "Custody should remain unchanged"
    );
}



function testAdministrationNomination() public {
    address candidate = address(0x1234);

    supplyChain.transferAdministration(candidate);

    Assert.equal(
        supplyChain.pendingAdministrator(),
        candidate,
        "Pending administrator should match"
    );

    supplyChain.transferAdministration(address(0));

    Assert.equal(
        supplyChain.pendingAdministrator(),
        address(0),
        "Nomination should be cancelled"
    );
}

function testAdministrationAcceptance() public {
    // Deploy a separate contract for this test.
    SupplyChain freshContract = new SupplyChain();

    // Create a new administrator candidate.
    UnauthorizedRoleCaller candidate =
        new UnauthorizedRoleCaller();

    // Nominate the candidate.
    freshContract.transferAdministration(
        address(candidate)
    );

    // Candidate accepts administration.
    candidate.acceptAdmin(freshContract);

    // Verify the new administrator.
    Assert.equal(
        freshContract.administrator(),
        address(candidate),
        "New administrator should match"
    );

    // Verify the pending nomination is cleared.
    Assert.equal(
        freshContract.pendingAdministrator(),
        address(0),
        "Pending administrator should be cleared"
    );
}

function testAdminCustodyRecovery() public {
    // Create a fresh supply chain.
    SupplyChain fresh = new SupplyChain();

    fresh.setParticipantRole(
        address(this),
        SupplyChain.Role.Producer
    );

    fresh.registerProduct(5005, "ipfs://recovery-test");

    // Assign the original transporter.
    UnauthorizedRoleCaller oldTransporter =
        new UnauthorizedRoleCaller();

    fresh.setParticipantRole(
        address(oldTransporter),
        SupplyChain.Role.Transporter
    );

    fresh.transferCustody(5005, address(oldTransporter));

    // Create a replacement transporter.
    UnauthorizedRoleCaller newTransporter =
        new UnauthorizedRoleCaller();

    fresh.setParticipantRole(
        address(newTransporter),
        SupplyChain.Role.Transporter
    );

    // Revoke the original transporter's role.
    fresh.setParticipantRole(
        address(oldTransporter),
        SupplyChain.Role.None
    );

    // Recover custody using administrator privileges.
    fresh.adminReassignCustody(
        5005,
        address(newTransporter)
    );

    SupplyChain.Product memory product =
        fresh.getProduct(5005);

    Assert.equal(
        product.currentCustodian,
        address(newTransporter),
        "Custody recovery should succeed"
    );
}

function testCannotReassignActiveCustodian() public {
    SupplyChain fresh = new SupplyChain();

    fresh.setParticipantRole(
        address(this),
        SupplyChain.Role.Producer
    );

    fresh.registerProduct(6006, "ipfs://active-test");

    UnauthorizedRoleCaller original =
        new UnauthorizedRoleCaller();

    UnauthorizedRoleCaller replacement =
        new UnauthorizedRoleCaller();

    fresh.setParticipantRole(
        address(original),
        SupplyChain.Role.Transporter
    );

    fresh.setParticipantRole(
        address(replacement),
        SupplyChain.Role.Transporter
    );

    fresh.transferCustody(6006, address(original));

    // Administrator must not replace an active custodian.
    try fresh.adminReassignCustody(
        6006,
        address(replacement)
    ) {
        Assert.ok(false, "Recovery should be rejected");
    } catch Error(string memory reason) {
        Assert.equal(
            reason,
            "Current custodian is still authorized",
            "Expected active custodian rejection"
        );
    } catch {
        Assert.ok(false, "Unexpected rejection reason");
    }

    SupplyChain.Product memory product =
        fresh.getProduct(6006);

    Assert.equal(
        product.currentCustodian,
        address(original),
        "Original custodian should remain"
    );
}
function testCannotReassignToWrongRole() public {
    // Deploy a fresh contract.
    SupplyChain fresh = new SupplyChain();

    fresh.setParticipantRole(
        address(this),
        SupplyChain.Role.Producer
    );

    fresh.registerProduct(
        7007,
        "ipfs://wrong-role-test"
    );

    // Create and authorize the original transporter.
    UnauthorizedRoleCaller oldTransporter =
        new UnauthorizedRoleCaller();

    fresh.setParticipantRole(
        address(oldTransporter),
        SupplyChain.Role.Transporter
    );

    fresh.transferCustody(
        7007,
        address(oldTransporter)
    );

    // Revoke the original transporter's role.
    fresh.setParticipantRole(
        address(oldTransporter),
        SupplyChain.Role.None
    );

    // Create a replacement with the wrong role.
    UnauthorizedRoleCaller wrongReplacement =
        new UnauthorizedRoleCaller();

    fresh.setParticipantRole(
        address(wrongReplacement),
        SupplyChain.Role.Warehouse
    );

    // The administrator must reject the wrong role.
    try fresh.adminReassignCustody(
        7007,
        address(wrongReplacement)
    ) {
        Assert.ok(false, "Wrong role should be rejected");
    } catch Error(string memory reason) {
        Assert.equal(
            reason,
            "New custodian must have the required role",
            "Expected wrong-role rejection"
        );
    } catch {
        Assert.ok(false, "Unexpected rejection reason");
    }

    // Verify custody remains unchanged.
    SupplyChain.Product memory product =
        fresh.getProduct(7007);

    Assert.equal(
        product.currentCustodian,
        address(oldTransporter),
        "Original custodian should remain"
    );
}

function testIoTHashVerification() public {
    // Deploy a fresh contract.
    SupplyChain fresh = new SupplyChain();

    fresh.setParticipantRole(
        address(this),
        SupplyChain.Role.Producer
    );

    fresh.registerProduct(
        1001,
        "demo://product-1001"
    );

    // SHA-256 of original IoT data.
    bytes32 originalHash = hex"2bde5c0902cb8b643b3d62fa5830c661104383e2b76ba4a570f2168828630426";

    // SHA-256 of modified IoT data.
    bytes32 tamperedHash = hex"27501076d287514e3f1823dcadae33d182a0e8bd42750590f1493b5e43bf6c48";

    fresh.recordIoTHash(1001, originalHash);

    // Original data must pass verification.
    Assert.ok(
        fresh.verifyIoTHash(1001, originalHash),
        "Original IoT hash should match"
    );

    // Modified data must fail verification.
    Assert.ok(
        !fresh.verifyIoTHash(1001, tamperedHash),
        "Tampered IoT hash should not match"
    );
}

function testUnauthorizedIoTHashRecording() public {
    // Deploy a fresh contract for testing.
    SupplyChain fresh = new SupplyChain();

    // Assign the Producer role to the test contract.
    fresh.setParticipantRole(
        address(this),
        SupplyChain.Role.Producer
    );

    // Register a new product.
    fresh.registerProduct(
        8008,
        "demo://iot-security-test"
    );

    // Create an unauthorized participant.
    UnauthorizedRoleCaller unauthorized =
        new UnauthorizedRoleCaller();

    bytes32 testHash = sha256(
        bytes("simulated-iot-data")
    );

    // Attempt to record an IoT hash without permission.
    try unauthorized.submitIoTHash(
        fresh,
        8008,
        testHash
    ) {
        Assert.ok(
            false,
            "Unauthorized recording should fail"
        );
    } catch Error(string memory reason) {
        Assert.equal(
            reason,
            "Only current custodian can record IoT data",
            "Expected unauthorized caller rejection"
        );
    } catch {
        Assert.ok(
            false,
            "Unexpected rejection reason"
        );
    }

    // Verify that no hash was stored.
    Assert.ok(
        fresh.productIoTHashes(8008) == bytes32(0),
        "IoT hash should remain empty"
    );
}

}
