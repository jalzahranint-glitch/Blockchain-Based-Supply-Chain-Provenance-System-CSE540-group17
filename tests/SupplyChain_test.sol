
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
    // Try registering product 1001 again.
    try supplyChain.registerProduct(
        1001,
        "ipfs://duplicate-product"
    ) {
        Assert.ok(false, "Duplicate product should be rejected");
    } catch {
        Assert.ok(true, "Duplicate product was rejected");
    }
}

function testUnauthorizedRoleAssignment() public {
    // A separate contract acts as a non-administrator.
    UnauthorizedRoleCaller caller = new UnauthorizedRoleCaller();

    try caller.assignRole(supplyChain) {
        Assert.ok(false, "Non-admin role assignment should fail");
    } catch {
        Assert.ok(true, "Non-admin role assignment rejected");
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
    // Register a new product with Created status.
    supplyChain.registerProduct(
        3003,
        "ipfs://test-product-3003"
    );

    // Attempt to skip directly to Delivered.
    try supplyChain.updateStatus(
        3003,
        SupplyChain.ProductStatus.Delivered
    ) {
        Assert.ok(false, "Invalid transition should fail");
    } catch {
        Assert.ok(true, "Invalid transition rejected");
    }

    // Verify that the status has not changed.
    SupplyChain.Product memory product =
        supplyChain.getProduct(3003);

    Assert.equal(
        uint256(product.status),
        uint256(SupplyChain.ProductStatus.Created),
        "Status should remain Created"
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

    // Attempt to transfer directly from Producer to Retailer.
    try supplyChain.transferCustody(
        4004,
        address(invalidRetailer)
    ) {
        Assert.ok(false, "Invalid custody transfer should fail");
    } catch {
        Assert.ok(true, "Invalid custody transfer rejected");
    }

    // Verify custody remains with the Producer.
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



}

