// SPDX-License-Identifier: MIT
// https://playqub.it/

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "operator-filter-registry/src/DefaultOperatorFilterer.sol";

contract QubitVoxels is ERC1155, Ownable, ERC2981, DefaultOperatorFilterer 
{
    //--------------------------------------------------VARIABLES---------------------------------------------

    uint96 constant private ROYALTY_FEE = 500; // 5%

    uint256 private MAX_VOXEL_PURCHASE = 20;

    uint256 private MAX_NUM_UNIQUE_ITEMS = 3;
    uint256 private MAX_NUM_ITEMS = 10000;
    uint256 private MINTED_NUM_AMOUNT = 0;

    uint256 private TEAM_MINT_AMOUNT_UNIQUE = 3;
    uint256 private TEAM_MINT_AMOUNT_NON_GENERAL = 12;
    uint256 private TEAM_MINT_AMOUNT_GENERAL = 85;

    mapping(uint256 => uint256) public itemSupplyLimits;
    mapping(uint256 => uint256) public itemMintCounts;

    mapping(address => bool) public whitelist;
    uint256 private _whitelistEndTime;

    string public name = "Qubit Voxels";
    string public symbol = "QBTVXL";

    uint _mintPrice = 0.1 ether;

    bool public saleIsActive = false;

    //--------------------------------------------------CONSTRUCTOR---------------------------------------------

    constructor() ERC1155("ipfs://QmTQ5xd7pFmMtYmhNYtrshkFcjaAYmfSgNWcsFabvRoJj1/{id}.json") Ownable(msg.sender)
    {
        _setDefaultRoyalty(owner(), ROYALTY_FEE);
        whitelist[msg.sender] = true;
        // Set supply limits for each item, pass this in the constructor
        //GENERAL
        itemSupplyLimits[0] = 8500;
        //NON-GENERAL
        itemSupplyLimits[1] = 1200;
        //UNIQUE
        itemSupplyLimits[2] = 300;
        // Minting for the dev team
        devMint();
    }
    //--------------------------------------------------WHITELISTING & SALE---------------------------------------------

    function addToWhitelist(address[] calldata _addresses) external onlyOwner
    {
        for (uint256 i = 0; i < _addresses.length; ++i)
        {
            whitelist[_addresses[i]] = true;
        }
    }

    function removeFromWhitelist(address[] memory _addresses) external onlyOwner
    {
        for (uint256 i = 0; i < _addresses.length; ++i)
        {
            whitelist[_addresses[i]] = false;
        }
    }

    function enableWhitelistEndTime() private
    {
        _whitelistEndTime = block.timestamp + 2 days;
    }

    function disableSaleState() external onlyOwner
    {
        saleIsActive = false;
    }

    function enableSaleState() external onlyOwner
    {
        saleIsActive = true;
        enableWhitelistEndTime();
    }

    //--------------------------------------------------MINTING & WITHDRAW---------------------------------------------

    function mintRandom(uint256 amount) external payable
    {
        require(msg.value >= _mintPrice * amount, "Not enough ETH!");
        require(saleIsActive, "Sale must be active to mint Voxel NFT");
        require(amount > 0, "Invalid amount!");
        require(amount <= MAX_VOXEL_PURCHASE, "Can only mint 20 NFTs at a time");
        require(MINTED_NUM_AMOUNT + amount <= MAX_NUM_ITEMS, "Not enough available NFT's with the passed amount!");

        // Checking whether address is whitelisted during the presale
        if (block.timestamp <= _whitelistEndTime)
        {
            require(whitelist[msg.sender], "Whitelist period still ongoing & address not whitelisted!");
        }

        for (uint256 i = 1; i <= amount; ++i)
        {
            uint256 randomID = uint(keccak256(abi.encodePacked(block.timestamp * i, msg.sender, block.number * i))) % 100;
            
            if (randomID < 3) { randomID = 2;} //3%
            else if (randomID < 15) { randomID = 1;} //12%
            else { randomID = 0;} //85%

            uint256 startID = randomID;

            while (itemMintCounts[randomID] + 1 > itemSupplyLimits[randomID])
            {
                randomID++;
                randomID = randomID % MAX_NUM_UNIQUE_ITEMS;
                if (randomID == startID)
                {
                    revert("Not enough available NFT's with the passed amount for the IDs!");
                }
            }

            _mint(msg.sender, randomID, 1, "");
            ++itemMintCounts[randomID];
        }

        MINTED_NUM_AMOUNT += amount;
    }

    //Minting for the dev team for marketing/showcase/giveaway purposes in constructor
    function devMint() private
    {
        //85 general
        _mint(owner(), 0, TEAM_MINT_AMOUNT_GENERAL, "");
        itemMintCounts[0] += TEAM_MINT_AMOUNT_GENERAL;
        //12 non-general
        _mint(owner(), 1, TEAM_MINT_AMOUNT_NON_GENERAL, "");
        itemMintCounts[1] += TEAM_MINT_AMOUNT_NON_GENERAL;
        //3 unique
        _mint(owner(), 2, TEAM_MINT_AMOUNT_UNIQUE, "");
        itemMintCounts[2] += TEAM_MINT_AMOUNT_UNIQUE;

        MINTED_NUM_AMOUNT += TEAM_MINT_AMOUNT_UNIQUE + TEAM_MINT_AMOUNT_NON_GENERAL + TEAM_MINT_AMOUNT_GENERAL;
    }

    function withdraw() external onlyOwner
    {
        uint256 amount = address(this).balance;
        require(amount > 0, "Nothing to withdraw!");
        
        address _owner = owner();
        (bool sent, ) = _owner.call{value: amount}("");
        require(sent, "Failed to send Ether!");  
    }

    function setBaseURI(string memory baseURI) external onlyOwner
    {
        _setURI(baseURI);
    }

    function supportsInterface(bytes4 interfaceId) public view override( ERC1155, ERC2981 ) returns (bool) { return super.supportsInterface(interfaceId); }

    //--------------------------------------------------ROYALTIES---------------------------------------------

    function setDefaultRoyalty( address receiver, uint96 feeNumerator ) external onlyOwner { _setDefaultRoyalty( receiver, feeNumerator ); }
    function deleteDefaultRoyalty() external onlyOwner { _deleteDefaultRoyalty(); }
}