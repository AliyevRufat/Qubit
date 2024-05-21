// SPDX-License-Identifier: MIT
// https://playqub.it/

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "./QubitVoxels.sol";

contract QubitCreations is ERC721, Ownable, IERC2981
{
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    string private _mintCode;

    mapping(uint256 => string) private _tokenURIs;
    mapping(string => uint256) public _contestBlueprintsPool;
    mapping(string => uint256[]) _contestBlueprintIds;

    uint private _mintPrice = 0.01 ether;

    QubitVoxels private _qubitVoxels;

    event CreationMinted(address indexed player, uint256 tokenID, string ipfsLink, bytes data);

    constructor(string memory mintCode, address qubitVoxelsAddress) ERC721("Qubit Creations", "QBTCRTNS") Ownable(msg.sender)
    {
        _mintCode = mintCode;
        _qubitVoxels = QubitVoxels(qubitVoxelsAddress);
    }

    //For discount purposes
    function setMintPrice(uint256 newMintPrice) external onlyOwner
    {
        _mintPrice = newMintPrice;
    }

    function getTokenIdCounter() external view returns (uint256)
    {
        return _tokenIdCounter.current();
    }

    function setMintCode(string calldata mintCode) external onlyOwner
    {
        _mintCode = mintCode;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory)
    {
        string memory _tokenURI = _tokenURIs[tokenId];

        return bytes(_tokenURI).length > 0 ? string(abi.encodePacked(_tokenURI)) : "";
    }

    function tokenURIs(uint256[] calldata tokenIds) external view returns (string[] memory)
    {
        string[] memory URIs = new string[](tokenIds.length);

        for (uint256 i = 0; i < tokenIds.length; ++i)
        {
            URIs[i] = _tokenURIs[tokenIds[i]];
        }
        return URIs;
    }

    function ownersOf(uint256[] calldata tokenIds) external view returns (address[] memory)
    {
        address[] memory owners = new address[](tokenIds.length);

        for (uint256 i = 0; i < tokenIds.length; ++i)
        {
            address owner = ownerOf(tokenIds[i]);
            require(owner != address(0), "ERC721: invalid token ID");
            owners[i] = owner;
        }
        return owners;
    }

    function getContestBlueprintIds(string memory contestBlueprint) external view returns (uint256[] memory)
    {
        return _contestBlueprintIds[contestBlueprint];
    }

    function mintCreation(string calldata _tokenURI, string calldata mintCode, string calldata blueprintContest, bytes memory data) external payable
    {
        uint256 totalOwnedVoxels = _qubitVoxels.balanceOf(msg.sender, 0) + _qubitVoxels.balanceOf(msg.sender, 1) + _qubitVoxels.balanceOf(msg.sender, 2);
        require(totalOwnedVoxels > 0, "Doesn't have a Qubit Voxel NFT!");
        require(keccak256(abi.encodePacked((_mintCode))) == keccak256(abi.encodePacked((mintCode))), "Not allowed to mint!");
        require(msg.value >= _mintPrice, "Not enough ETH!");

        uint256 tokenID = _tokenIdCounter.current();
        _mint(msg.sender, tokenID);
        _tokenURIs[tokenID] = _tokenURI;
        _tokenIdCounter.increment();
        _contestBlueprintsPool[blueprintContest] += msg.value;
        _contestBlueprintIds[blueprintContest].push(tokenID);
        emit CreationMinted(msg.sender, tokenID, _tokenURI, data);
    }

    //For burning non Creator Tool minted creations
    function burnCreation(uint256 _tokenId) external onlyOwner
    {
        _burn(_tokenId);
    }

    function updateContestWinnerTokenURI(uint256[] calldata ids, string[] calldata baseURIs) external onlyOwner
    {
        for (uint256 i = 0; i < baseURIs.length; ++i)
        {
            _tokenURIs[ids[i]] = baseURIs[i];
        }
    }

    function royaltyInfo(uint256, uint256 saleAmount) external view override returns (address receiver, uint256 royaltyAmount)
    {
        receiver = owner();
        royaltyAmount = (saleAmount * 5) / 100; // 5%
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, IERC165) returns (bool)
    {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    function distributeRewards(address[] calldata winners, string calldata blueprintContest) external onlyOwner
    {
        uint256 contestBalance = _contestBlueprintsPool[blueprintContest];
        require(contestBalance > 0, "Nothing to distribute!");

        require(winners.length == 3, "More/Less than 3 winners passed!");
        uint256 amountToDistribute = contestBalance / 10 * 9; // 90%

        address payable firstPlace = payable(winners[0]);
        address payable secondPlace = payable(winners[1]);
        address payable thirdPlace = payable(winners[2]);

        uint256 firstPlaceShare = amountToDistribute / 2; // 50%
        uint256 secondPlaceShare = (amountToDistribute - firstPlaceShare) / 5 * 3; // 30%
        uint256 thirdPlaceShare = amountToDistribute - firstPlaceShare - secondPlaceShare; // 20%
        
        _contestBlueprintsPool[blueprintContest] = 0;
        
        (bool sent, ) = firstPlace.call{value: firstPlaceShare }("");
        require(sent, "Failed to send Ether");

        (sent, ) = secondPlace.call{value: secondPlaceShare }("");
        require(sent, "Failed to send Ether");

        (sent, ) = thirdPlace.call{value: thirdPlaceShare }("");
        require(sent, "Failed to send Ether");

        withdraw(contestBalance - amountToDistribute); // 10%
    }

    function withdraw(uint256 amountToDistribute) private
    {
        require(amountToDistribute > 0, "Nothing to withdraw!");

        address payable _owner = payable(owner());
        (bool sent, ) = _owner.call{value: amountToDistribute}("");
        require(sent, "Failed to send Ether");
    }

    function withdraw() external onlyOwner
    {
        uint256 amount = address(this).balance;
        require(amount > 0, "Nothing to withdraw!");
        
        address _owner = owner();
        (bool sent, ) = _owner.call{value: amount}("");
        require(sent, "Failed to send Ether!");  
    }
}