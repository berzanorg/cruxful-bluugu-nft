// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";

string constant NAME = "Bluugu by Cruxful";
string constant SYMBOL = "BLUUGU";

contract NFT is ERC721Enumerable {
    uint256 immutable _supply;
    address immutable _team;
    uint256 immutable _guaranteedSeconds;
    uint256 immutable _nonGuaranteedSeconds;
    uint256 immutable _guaranteedPrice;
    uint256 immutable _nonGuaranteedPrice;
    uint256 immutable _publicPrice;
    uint256 immutable _deployTimestamp;
    uint256 immutable _startTimestamp;
    mapping(address => MintStatus) public getMintStatus;

    enum MintStatus {
        CannotMint,
        CanMint,
        MayMint,
        Minted
    }

    enum MintPhase {
        NotStarted,
        Guaranteed,
        NonGuaranteed,
        Public
    }

    constructor(
        uint256 supply,
        uint256 premint,
        address team,
        uint256 startTimestamp,
        uint256 guaranteedSeconds,
        uint256 nonGuaranteedSeconds,
        uint256 guaranteedPrice,
        uint256 nonGuaranteedPrice,
        uint256 publicPrice,
        address[] memory guaranteedAllowlist,
        address[] memory nonGuaranteedAllowlist
    ) ERC721(NAME, SYMBOL) {
        require(supply >= premint + guaranteedAllowlist.length);

        _supply = supply;
        _team = team;
        _startTimestamp = startTimestamp;
        _guaranteedSeconds = guaranteedSeconds;
        _nonGuaranteedSeconds = nonGuaranteedSeconds;
        _guaranteedPrice = guaranteedPrice;
        _nonGuaranteedPrice = nonGuaranteedPrice;
        _publicPrice = publicPrice;
        _deployTimestamp = block.timestamp;

        for (uint256 i = 0; i < guaranteedAllowlist.length; i++) {
            getMintStatus[guaranteedAllowlist[i]] = MintStatus.CanMint;
        }

        for (uint256 i = 0; i < nonGuaranteedAllowlist.length; i++) {
            getMintStatus[nonGuaranteedAllowlist[i]] = MintStatus.MayMint;
        }

        for (uint256 i = 0; i < premint; i++) {
            _mint(team, i);
        }
    }

    function tokenURI(uint256 /*tokenId*/ ) public pure override returns (string memory) {
        return "https://ipfs.io/ipfs/bafybeigd7zii34xj7ug3x6x5h76uj2fdqn6exgw2ptxrdqdsn5lnz3jmw4/0";
    }

    function mint() external payable {
        require(block.timestamp >= _startTimestamp, "Mint is not live.");
        uint256 tokenId = totalSupply();
        require(tokenId < _supply, "All are minted.");
        MintStatus mintStatus = getMintStatus[msg.sender];
        require(mintStatus != MintStatus.Minted, "Already minted.");

        if (block.timestamp < _startTimestamp + _guaranteedSeconds) {
            require(mintStatus == MintStatus.CanMint, "Cannot mint.");
            require(msg.value == _guaranteedPrice, "Not paid for.");
            _mint(msg.sender, tokenId);
        } else if (block.timestamp < _startTimestamp + _guaranteedSeconds + _nonGuaranteedSeconds) {
            require(mintStatus == MintStatus.CanMint || mintStatus == MintStatus.MayMint, "Cannot mint.");
            require(msg.value == _nonGuaranteedPrice, "Not paid for.");
            _mint(msg.sender, tokenId);
        } else {
            require(msg.value == _publicPrice, "Not paid for.");
            _mint(msg.sender, tokenId);
        }

        (bool ok,) = payable(_team).call{value: msg.value}("");
        require(ok, "Cannot send.");

        getMintStatus[msg.sender] = MintStatus.Minted;
    }

    function getPhase() external view returns (MintPhase, uint256, uint256, uint256, uint256) {
        if (block.timestamp < _startTimestamp) {
            return (MintPhase.NotStarted, _startTimestamp - block.timestamp, _guaranteedPrice, totalSupply(), _supply);
        } else if (block.timestamp < _startTimestamp + _guaranteedSeconds) {
            return (
                MintPhase.Guaranteed,
                _startTimestamp + _guaranteedSeconds - block.timestamp,
                _guaranteedPrice,
                totalSupply(),
                _supply
            );
        } else if (block.timestamp < _startTimestamp + _guaranteedSeconds + _nonGuaranteedSeconds) {
            return (
                MintPhase.NonGuaranteed,
                _startTimestamp + _guaranteedSeconds + _nonGuaranteedSeconds - block.timestamp,
                _nonGuaranteedPrice,
                totalSupply(),
                _supply
            );
        } else {
            return (MintPhase.Public, 0, _publicPrice, totalSupply(), _supply);
        }
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        public
        view
        virtual
        returns (address receiver, uint256 amount)
    {
        tokenId;
        return (_team, (salePrice * 5) / 100);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }
}
