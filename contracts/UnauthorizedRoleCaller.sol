
 // SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./SupplyChain.sol";

contract UnauthorizedRoleCaller {
    function assignRole(SupplyChain target) external {
        target.setParticipantRole(
            address(this),
            SupplyChain.Role.Producer
        );
    }

function transferProduct(
    SupplyChain target,
    uint256 productId,
    address newCustodian
) external {
    target.transferCustody(productId, newCustodian);
}

function changeProductStatus(
    SupplyChain target,
    uint256 productId,
    SupplyChain.ProductStatus newStatus
) external {
    target.updateStatus(productId, newStatus);
}

function acceptAdmin(SupplyChain target) external {
    target.acceptAdministration();
}

    // Simulates an unauthorized attempt to record IoT data.
    function submitIoTHash(
        SupplyChain target,
        uint256 productId,
        bytes32 dataHash
    ) external {
        target.recordIoTHash(productId, dataHash);
    }

}

