
 // SPDX-License-Identifier: MIT
 pragma solidity ^0.8.20;

 /**
  * @title SupplyChain
  * @notice Blockchain-based supply chain provenance system.
  * @dev Tracks product registration, status, and custody.
  */
 contract SupplyChain {

     // Defines the stages of a product's journey.
     enum ProductStatus {
         Created,
         Shipped,
         Received,
         Delivered
     }

     // Stores the essential information for each product.
     struct Product {
         uint256 id;
         address producer;
         address currentCustodian;
         ProductStatus status;
         string metadataURI;
         bool exists;
     }

     // Maps each unique product ID to its information.
     mapping(uint256 => Product) private products;

    

     // Defines the roles of supply chain participants.
     enum Role {
         None,
         Producer,
         Transporter,
         Warehouse,
         Retailer,
         Viewer
     }

     // Stores the assigned role of each participant.
     mapping(address => Role) private participantRoles;
// Tracks the required custodian role for each product.
    mapping(uint256 => Role) private productCustodianRoles;

    // Stores the SHA-256 hash of the latest IoT data for each product.
    mapping(uint256 => bytes32) public productIoTHashes;

     // The administrator manages participant roles.
     
    address public administrator;
    address public pendingAdministrator;


     // Assigns the deployer as the administrator.
     constructor() {
         administrator = msg.sender;
     }

     // Restricts functions to the administrator.
    
    modifier onlyAdministrator() {
        require(
            msg.sender == administrator,
            "Only administrator can perform this action"
        );
        _;
    }

    // Emitted when a new administrator is nominated.
    event AdministrationTransferStarted(
        address indexed currentAdministrator,
        address indexed nominatedAdministrator
    );

   
  
    // Nominates a new administrator.
    // Passing address(0) cancels a pending nomination.
    function transferAdministration(
        address newAdministrator
    ) external onlyAdministrator {
        require(
            newAdministrator != administrator,
            "Already the administrator"
        );

        pendingAdministrator = newAdministrator;

        emit AdministrationTransferStarted(
            administrator,
            newAdministrator
        );
    }

    // Emitted when administration is transferred.
    event AdministrationTransferred(
        address indexed previousAdministrator,
        address indexed newAdministrator
    );

    /**
     * @notice Allows the nominated administrator
     * to accept administrative control.
     */
    function acceptAdministration() external {
        require(
            msg.sender == pendingAdministrator &&
            pendingAdministrator != address(0),
            "Not the pending administrator"
        );

        address previousAdministrator = administrator;

        administrator = msg.sender;
        pendingAdministrator = address(0);

        emit AdministrationTransferred(
            previousAdministrator,
            msg.sender
        );
    }

         

     // Emitted whenever a participant's role changes.
     event ParticipantRoleUpdated(
         address indexed participant,
         Role role
     );

     /**
      * @notice Assigns or changes a participant's role.
      * @dev Only the administrator can assign roles.
      * Setting the role to None removes access.
      */
     function setParticipantRole(
         address participant,
         Role role
     ) external onlyAdministrator {
         require(
             participant != address(0),
             "Invalid participant address"
         );

         participantRoles[participant] = role;

         emit ParticipantRoleUpdated(participant, role);
     }

    /**
     * @notice Returns the assigned role of a participant.
     * @param participant The wallet address to check.
     * @return The participant's role.
     */
    function getParticipantRole(
        address participant
    ) external view returns (Role) {
        return participantRoles[participant];
    }

    // Emitted when a new product is registered.
    event ProductRegistered(
        uint256 indexed productId,
        address indexed producer,
        string metadataURI
    );

    /**
    * @notice Registers a new product in the supply chain.
    * @dev Only an authorized producer can register a product.
    * Each product must have a unique ID.
 */
    function registerProduct(
        uint256 productId,
        string calldata metadataURI
    ) external {
        // Validates the producer's role and product information before registration.
        require(
            participantRoles[msg.sender] == Role.Producer,
            "Only producers can register products"
        );
     
        require(
            productId != 0,
            "Invalid product ID"
        );

        require(
            !products[productId].exists,
            "Product already registered"
        );

        require(
            bytes(metadataURI).length > 0,
            "Metadata reference required"
        );

        products[productId] = Product({
            id: productId,
            producer: msg.sender,
            currentCustodian: msg.sender,
            status: ProductStatus.Created,
            metadataURI: metadataURI,
            exists: true
        });
        productCustodianRoles[productId] = Role.Producer;
        emit ProductRegistered(
            productId,
            msg.sender,
            metadataURI
        );
    }

    /**
 * @notice Returns information about a registered product.
 * @dev Reverts if the product does not exist.
 * @param productId The ID of the product to retrieve.
 * @return The product's stored information.
 */
    function getProduct(
        uint256 productId
    ) external view returns (Product memory) {
        require(
            products[productId].exists,
            "Product does not exist"
        );

        return products[productId];
    }

    // Emitted when a product's status changes.
    event ProductStatusUpdated(
        uint256 indexed productId,
        ProductStatus oldStatus,
        ProductStatus newStatus,
        address indexed updatedBy
    );

    /**
 * @notice Updates the status of a registered product.
 * @dev Only the current custodian with the required role
* can update the status, one stage at a time.
 * @param productId The ID of the product to update.
 * @param newStatus The new status of the product.
 */
    function updateStatus(
        uint256 productId,
        ProductStatus newStatus
    ) external {
        require(
            products[productId].exists,
            "Product does not exist"
        );

        require(
            msg.sender == products[productId].currentCustodian,
            "Only current custodian can update status"
        );

        Role callerRole = participantRoles[msg.sender];

require(
    callerRole == productCustodianRoles[productId],
    "Custodian role mismatch"
);

require(
    (newStatus == ProductStatus.Shipped &&
     callerRole == Role.Transporter) ||
    (newStatus == ProductStatus.Received &&
     callerRole == Role.Warehouse) ||
    (newStatus == ProductStatus.Delivered &&
     callerRole == Role.Retailer),
    "Unauthorized role for status update"
    );

        ProductStatus oldStatus = products[productId].status;

        require(
            uint8(newStatus) == uint8(oldStatus) + 1,
            "Invalid status transition"
        );

        products[productId].status = newStatus;

        emit ProductStatusUpdated(
            productId,
            oldStatus,
            newStatus,
            msg.sender
        );
    }

    // Records when product custody moves from one participant to another.
    event CustodyTransferred(
        uint256 indexed productId,
        address indexed previousCustodian,
        address indexed newCustodian
    );

    /**
 * @notice Transfers product custody to another participant.
 * @dev Only the current authorized custodian can transfer
 *      the product to the next valid role.
 * @param productId The ID of the product to transfer.
 * @param newCustodian The address of the next custodian.
 */
    function transferCustody(
        uint256 productId,
        address newCustodian
    ) external {
        require(
            products[productId].exists,
            "Product does not exist"
        );

        Product storage product = products[productId];

        require(
            msg.sender == product.currentCustodian,
            "Only current custodian can transfer"
        );

        require(
            newCustodian != address(0),
            "Invalid custodian address"
        );

        require(
            newCustodian != msg.sender,
            "Cannot transfer to yourself"
        );

        require(
            product.status != ProductStatus.Delivered,
            "Product already delivered"
        );

        Role senderRole = participantRoles[msg.sender];
        Role receiverRole = participantRoles[newCustodian];
// Ensures the sender's current role matches the
// recorded custodian role before transferring custody.

require(
    senderRole == productCustodianRoles[productId],
    "Custodian role mismatch"
);

// Ensures custody transfers follow the correct role sequence
// and match the product's current status.
     
require(
    (senderRole == Role.Producer &&
     receiverRole == Role.Transporter &&
     product.status == ProductStatus.Created) ||

    (senderRole == Role.Transporter &&
     receiverRole == Role.Warehouse &&
     product.status == ProductStatus.Shipped) ||

    (senderRole == Role.Warehouse &&
     receiverRole == Role.Retailer &&
     product.status == ProductStatus.Received),

    "Invalid custody transfer path or status"
);


        address previousCustodian =
            product.currentCustodian;

        product.currentCustodian = newCustodian;

        productCustodianRoles[productId] = receiverRole;

emit CustodyTransferred(
    productId,
    previousCustodian,
    newCustodian
);
}
     /**
     * @notice Reassigns custody if the current custodian
     * no longer has the required role.
     * @dev Only the administrator can recover custody.
     */
    function adminReassignCustody(
        uint256 productId,
        address newCustodian
    ) external onlyAdministrator {
        require(
            products[productId].exists,
            "Product does not exist"
        );

        Product storage product = products[productId];

        require(
            product.status != ProductStatus.Delivered,
            "Product already delivered"
        );

        Role requiredRole = productCustodianRoles[productId];

        require(
            participantRoles[product.currentCustodian] != requiredRole,
            "Current custodian is still authorized"
        );

        require(
            newCustodian != address(0) &&
            newCustodian != product.currentCustodian,
            "Invalid new custodian"
        );

        require(
            participantRoles[newCustodian] == requiredRole,
            "New custodian must have the required role"
        );

        address previousCustodian = product.currentCustodian;

        product.currentCustodian = newCustodian;

        emit CustodyTransferred(
            productId,
            previousCustodian,
            newCustodian
        );
    }   
   
    // Emitted when an IoT data hash is recorded.
    event IoTHashRecorded(
        uint256 indexed productId,
        bytes32 dataHash,
        address indexed recordedBy
    );

    // Records the SHA-256 hash of off-chain IoT data.
    function recordIoTHash(
        uint256 productId,
        bytes32 dataHash
    ) external {
        require(
            products[productId].exists,
            "Product does not exist"
        );

        require(
            msg.sender == products[productId].currentCustodian,
            "Only current custodian can record IoT data"
        );

        require(
            participantRoles[msg.sender] ==
                productCustodianRoles[productId],
            "Custodian role mismatch"
        );

        require(
            dataHash != bytes32(0),
            "Invalid IoT hash"
        );

        productIoTHashes[productId] = dataHash;

        emit IoTHashRecorded(
            productId,
            dataHash,
            msg.sender
        );
    }
 
    /**
     * @notice Verifies the SHA-256 hash of off-chain IoT data.
     * @dev Returns true when the hash matches the stored value.
     */
    function verifyIoTHash(
        uint256 productId,
        bytes32 dataHash
    ) external view returns (bool) {
        require(
            products[productId].exists,
            "Product does not exist"
        );

        bytes32 storedHash = productIoTHashes[productId];

        return storedHash != bytes32(0) &&
               storedHash == dataHash;
    }



 }


 
