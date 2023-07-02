// SPDX-License-Identifier: WTFPL
pragma solidity ^0.8.21;

/**
         DO WHAT THE FUCK YOU WANT TO PRIVATE LICENSE 
                Version 2, December 2004 

 Copyright (C) 2004 Sam Hocevar <sam(at)hocevar.net> 

 Everyone is permitted to copy and distribute verbatim or modified 
 copies of this license document, and changing it is allowed as long 
 as the name is changed. 

            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE 
   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION 

  0. You just DO WHAT THE FUCK YOU WANT TO.
 */
import {IVotingEscrow as IVE} from "./interfaces/veRAM.sol";
import {INFPManager} from "./interfaces/NFPManager.sol";
import {IVoter} from "./interfaces/Voter.sol";
import {UUPSUpgradeable} from "@ozu/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable as Ownable} from "@ozu/access/OwnableUpgradeable.sol";
import {IERC20} from "@oz/token/ERC20/IERC20.sol";

/**
 * @title Lender
 * @author z (Twitter: @zdotftm, Discord: @lkmc)
 * @notice A contract that lends out veRAM NFT boosts to borrowers at a set price in 
 * ether per hour. Obviously we cant make the boost end after x amount of time without
 * a keeper, so users pay per second over time when they end their boost or claim RAM 
 * rewards. They have to deposit their LP to stake, so there's no incentive to perpetually 
 * keep your LP in the protocol while not paying the rent rate. A 20% fee gets taken off rewards,
 * 50% of that gets sent to the veNFT provider, the other 50% gets sent to the protocol sig.
 * 
 * Error codes:
 * code | meaning 
 * 101  | NFT transfer failed
 * 102  | NFP transfer failed
 * 
 * 201  | Incorrect payment
 * 202  | Ether transfer failed 
 * 
 * 403  | Forbidden
 * 404  | Not found
 */

contract Lender is UUPSUpgradeable, Ownable {
    address public veNFT = 0xAAA343032aA79eE9a6897Dab03bef967c3289a06;
    address public NFP = 0xAA277CB7914b7e5514946Da92cb9De332Ce610EF; // the A's represent pyramids
    address public RAM = 0xAAA6C1E32C55A7Bfa8066A6FAE9b42650F262418;
    address public voter = 0xAAA2564DEb34763E3d05162ed3f5C2658691f499;

    address public z = 0xFAA4ed12dc0aA5427B9A31755bb4F488196015d1;

    struct veInfo {
        address owner;
        uint256 price;
        bool active;
        uint256 deactivationTime;
    }

    struct nfpDepositInfo {
        address owner;
        uint256 veNFT;
        uint256 lastUpdate;
    }

    /**
     * @notice Info here is (owner, price, active)
     */
    mapping(uint256 tokenId => veInfo info) public info;
    /**
     * @notice info here is (owner, attached veNFT)
     */
    mapping(uint256 nfpId => nfpDepositInfo info) public nfpInfo;

    event DepositedNFT(uint256 indexed tokenId, uint256 price);
    bytes32 private depositSelector = bytes32(keccak256("DepositedNFT(uint256,uint256)"));


    function initialize() initializer {
        __Ownable_init();
    }

    /**
     * depositNFTWithPrice
     * @param tokenId The NFT tokenId to rent out
     * @param price The renting price in ether per hour 
     */
    function depositNFTWithPrice(
        uint256 tokenId,
        uint256 price
    ) external {
        // Transfer us the veNFT
        IVE(veNFT).safeTransferFrom(msg.sender, address(this), tokenId);
        // If for some reason this failed, then we revert, with code 101
        require(IVE(veNFT).ownerOf(tokenId) == address(this), "101");
        // Store the data in the mapping
        // Build the veInfo
        veInfo packed = veInfo(msg.sender, price, true, 0);
        assembly {
            // Store the tokenId in memory at slot 0
            mstore(0, tokenId)
            // Store the slot of the mapping in memory at slot 1
            mstore(32, info.slot)
            // Hash the data stored in memory in slot 0 and slot 1
            let hash := keccak256(0, 64)
            // Store the packed data in the slot we just computed
            sstore(hash, packed)
            // Start building the DepositedNFT event 
            // Load the DepositedNFT selector from storage
            let selector := sload(depositSelector.slot)
            // Emit the event with indexed value being in slot 1, using the selector that was
            // retrieved earlier, and the price of renting the NFT
            log2(0, 32, selector, price)
        }
    }

    /**
     * stakeNFPToNFT
     * @param nfpId The ID of the NFP the user is staking
     * @param tokenId The veRAM tokenId that the user wants their position to be boosted by 
     */
    function stakeNFPToNFT(
        uint256 nfpId,
        uint256 tokenId
    ) external {
        // We use this more than 2 times in this function so we store it in memory
        // for readability 
        INFPManager memory manager = INFPManager(NFP);
        // Transfer the NFP into the contract
        manager.safeTransferFrom(msg.sender, address(this), nfpId);
        // If for some reason the transfer failed, revert
        require(manager.ownerOf(nfpId) == address(this), "102");
        // Store this deposit
        nfpInfo[nfpId] = nfpDepositInfo(msg.sender, tokenId, block.timestamp); 
        // It's in our custody now, so we boost it, and that's it for now
        manager.switchAttatchment(nfpId, tokenId);
    }

    /**
     * claimRewards
     * @param gauge The address of the gauge that we want to claim from
     * @param nfpId the nfpId to claim for
     */
    function claimRewards(
        address gauge,
        uint256 nfpId
    ) public payable {
        // Get the attatched veNFT
        (address owner, uint256 tokenId, uint256 lastUpdate) = nfpInfo(nfpId);
        // Get the owner of that veNFT
        (address veOwner, uint256 price, bool active, uint256 withdrawTime) = info(tokenId);
        // Calculate the hours that have passed since the last update
        uint256 timePassed = (active ? block.timestamp : withdrawTime) - lastUpdate;
        uint256 hoursPassed = (timePassed - (timePassed % 3600)) / 3600
        // Pay the lender of the veNFT if they haven't withdrawn it
        _payDepositor(veOwner, price, hoursPassed);
        // We use this more than 2 times
        IERC20 ram = IERC20(RAM);
        // Store the amount of RAM in the contract before claiming
        uint256 ramBeforeClaim = ram.balanceOf(address(this));
        // Claim all the RAM rewards into the contract
        IVoter(voter).claimClGaugeRewards([gauge], [[RAM]], [[nfpId]]);
        // Get how much ram we have now
        uint256 ramAfterClaim = ram.balanceOf(address(this));
        // Define a variable for the fees we take
        uint256 finalFee;
        assembly {
            // Calculate the fee we take (10%)
            fee := div(sub(ramBeforeClaim, ramAfterClaim), 10)
            // Calculate the split between lender and protocol
            finalFee := div(fee, 2)
        }
        // Send the remaining RAM to the staker
        ram.transferFrom(address(this), owner, (ramBeforeClaim - ramAfterClaim) - finalFee * 2);
        // Send the RAM fee to the lender
        ram.transferFrom(address(this), veOwner, finalFee);
        // Send the RAM fee to me
        ram.transferFrom(address(this), z, finalFee);
        // We have updated the nfp deposit
        nfpInfo[nfpId].lastUpdate = block.timestamp;
    }

    /**
     * withdraw
     * @param gauge The address of the gauge that we want to claim from
     * @param nfpId the nfpId to withdraw
     */
    function withdraw(
        address gauge,
        uint256 nfpId
    ) external payable {
        // Get the NFP data
        (address owner,,) = nfpInfo[nfpId];
        // Claim the rewards, which also handles payments
        claimRewards(gauge, nfpId);
        // Make sure the owner is also the sender
        require(msg.sender == owner, "403");
        // De-attatch
        INFPManager(NFP).switchAttachment(nfpId, 0);
        // Send it back to the owner
        INFPManager(NFP).safeTransferFrom(address(this), owner, nfpId);
    }

    /**
     * withdrawNFT
     * @param tokenId the veNFT token to withdraw
     */
    function withdrawNFT(
        uint256 tokenId
    ) external {
        // Get the veNFT info
        (address veOwner,,) = info(tokenId);
        // Only allow the owner of the veNFT to do this
        require(veOwner == msg.sender, "403");
        // Deactivate the veNFT and save when it was withdrawn
        info[tokenId].active = false; info[tokenID].deactivationTime = block.timestamp;
        // Transfer the veNFT to the owner
        IVE(veNFT).transferFrom(address(this), veOwner, tokenId);
    }

    function voteWithNFT(
        uint256 tokenId,
        address[] calldata _poolVote,
        uint256[] calldata _weights
    ) external {
        // Get the veNFT info
        (address veOwner,,) = info(tokenId);
        // Only allow the owner of the veNFT to do this
        require(veOwner == msg.sender, "403");
        // Vote
        IVoter(voter).vote(tokenId, _poolVote, _weights);
    }

    function claimBribesAndFees(
        uint256 tokenId,
        address[] calldata _fees,
        address[][] calldata _tokens,
        address[] calldata _bribes
    ) external {
        // Get the veNFT info
        (address veOwner,,) = info(tokenId);
        // Claim bribes and fees for the veNFT
        IVoter(voter).claimBribes(_bribes, _tokens, tokenId);
        IVoter(voter).claimFees(_fees, _tokens, tokenId);
        // Go through all the tokens and send our balance to the sender
        uint256 tl = _tokens.length;
        for (uint i; i<tl;) {
            uint256 ttl = _tokens[i].length;
            for (uint j; j<ttl;) {
                // Get our balance
                uint256 balance = IERC20(_tokens[i][j]).balanceOf(address(this));
                // Send our balance
                IERC20(_tokens[i][j]).transferFrom(address(this), veOwner, balance);
                // Increase j by one
                unchecked {
                    j++;
                }
            }
            // Increase i by one
            unchecked {
                i++;
            }
        }
    }

    function _payDepositor(
        address veOwner,
        uint256 price,
        uint256 hoursPassed
    ) internal {
        // Calculate how much ether the user needs to pay
        uint256 etherToPay = price * hoursPassed;
        // Has the user paid that?
        require(msg.value >=  etherToPay, "201");
        // Send all the payment to the lender
        (bool s, ) = veOwner.call{value: etherToPay}("");
        // Did the payment succeed?
        require(s, "202");
        // Send a refund to the user
        (bool r, ) = msg.sender.call{value: msg.value - etherToPay}("");
        // Did the refund succeed?
        require(r, "202");
    }

    fallback () {
        // Require is cheaper on Arbitrum 
        require(false, "404");
    }
}