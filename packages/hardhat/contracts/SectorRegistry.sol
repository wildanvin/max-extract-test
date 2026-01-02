// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Minimal interface for the MaxExtract core contract described in your spec.
interface IMaxExtract {
    function broadcast() external returns (uint256 sectorId);
    function updateRegistry() external returns (uint256 sectorId);

    function playerToSector(address player) external view returns (uint256 sectorId);
}

contract SectorRegistry {
    // ---- Config ----
    IMaxExtract public immutable MAX_EXTRACT;

    /// @notice The buy-in EOA that deployed this registry (must match tx.origin in protocol flow)
    address public immutable owner;

    // ---- State ----
    uint256 public sectorId; // Store your sector ID
    mapping(string => address) public modules; // Your module registry

    // ---- Events ----
    event Broadcast(uint256 indexed sectorId, address indexed owner, address indexed registry);
    event RegistryUpdated(uint256 indexed sectorId, address indexed owner, address indexed registry);
    event ModuleSet(string key, address module);

    error NotOwner();
    error InvalidEOA();
    error ZeroAddress();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address maxExtract) {
        if (maxExtract == address(0)) revert ZeroAddress();
        MAX_EXTRACT = IMaxExtract(maxExtract);
        owner = msg.sender; // this should be the same EOA that did buy-in
    }

    /// @notice Chapter 1: calls MaxExtract.broadcast() and stores the returned sectorId.
    /// Requirements:
    /// - Must be triggered by the same account that bought into the game.
    /// - Enforced by requiring tx.origin == owner and msg.sender == owner (direct EOA call).
    function broadcast() external onlyOwner returns (uint256 id) {
        // Enforce the exact call path the spec wants: EOA -> Registry -> MaxExtract
        // That implies:
        // - msg.sender must be the EOA owner (not another contract)
        // - tx.origin must be that same EOA
        if (tx.origin != owner) revert InvalidEOA();

        id = MAX_EXTRACT.broadcast();
        sectorId = id;

        emit Broadcast(id, owner, address(this));
    }

    /// @notice If you deploy a NEW registry later, call this from the NEW registry (spec mentions updateRegistry()).
    /// This wrapper exists so you can update via the registry itself.
    function updateRegistryOnMaxExtract() external onlyOwner returns (uint256 id) {
        //if (tx.origin != owner) revert InvalidEOA();

        id = MAX_EXTRACT.updateRegistry();
        sectorId = id;

        emit RegistryUpdated(id, owner, address(this));
    }

    /// @notice Add/replace a module contract address (credentials, staking, fuel, etc.)
    function setModule(string calldata key, address module) external onlyOwner {
        if (module == address(0)) revert ZeroAddress();
        modules[key] = module;
        emit ModuleSet(key, module);
    }

    /// @notice Convenience: read sector directly from MaxExtract mapping (helps debugging)
    function sectorIdFromCore() external view returns (uint256) {
        return MAX_EXTRACT.playerToSector(owner);
    }
}

