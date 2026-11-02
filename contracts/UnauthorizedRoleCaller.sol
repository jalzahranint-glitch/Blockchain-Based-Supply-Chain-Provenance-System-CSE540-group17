
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

}

