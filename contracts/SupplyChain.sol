
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

     // The administrator manages participant roles.
     address public immutable administrator;

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
 * @dev Only the current custodian can update the status,
 *      one stage at a time.
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

        require(
            participantRoles[msg.sender] != Role.None &&
            participantRoles[msg.sender] != Role.Viewer,
            "Unauthorized participant"
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
// Ensures products follow the correct custody transfer sequence.
        require(
            (senderRole == Role.Producer &&
             receiverRole == Role.Transporter) ||
            (senderRole == Role.Transporter &&
             receiverRole == Role.Warehouse) ||
            (senderRole == Role.Warehouse &&
             receiverRole == Role.Retailer),
            "Invalid custody transfer path"
        );

        address previousCustodian =
            product.currentCustodian;

        product.currentCustodian = newCustodian;

        emit CustodyTransferred(
            productId,
            previousCustodian,
            newCustodian
        );
    }

 }


 
