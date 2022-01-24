pragma solidity ^0.5.0;

import "./KIP17.sol";
import "./KIP17Metadata.sol";
import "./KIP17Enumerable.sol";
import "./roles/MinterRole.sol";
import "./math/SafeMath.sol";
import "./utils/String.sol";

contract KIP17Syl is KIP17, KIP17Enumerable, KIP17Metadata, MinterRole{

    // To prevent bot attack, we record the last contract call block number.
    mapping (address => uint256) private _lastCallBlockNumber;
    uint256 private _antibotInterval;

    // If someone burns NFT in the middle of minting,
    // the tokenId will go wrong, so use the index instead of totalSupply().
    uint256 private _mintIndexForSale;

    address private _metakongzContract;

    uint256 private _mintLimitPerBlock;           // Maximum purchase nft per person per block
    uint256 private _mintLimitPerSale;            // Maximum purchase nft per person per sale

    string  private _tokenBaseURI;
    uint256 private _mintStartBlockNumber;        // In blockchain, blocknumber is the standard of time.
    uint256 private _maxSaleAmount;               // Maximum purchase volume of normal sale.
    uint256 private _mintPrice;                   // Could be 200 or 300.

    constructor () public {
      //init explicitly.
      _mintIndexForSale = 0;
    }

    function withdraw() external onlyMinter{
      msg.sender.transfer(address(this).balance);
    }

    function mintingInformation() external view returns (uint256[7] memory){
      uint256[7] memory info =
        [_antibotInterval, _mintIndexForSale, _mintLimitPerBlock, _mintLimitPerSale, 
          _mintStartBlockNumber, _maxSaleAmount, _mintPrice];
      return info;
    }

    function mintSyl(uint256 requestedCount) external payable {
      require(_lastCallBlockNumber[msg.sender].add(_antibotInterval) < block.number, "Bot is not allowed");
      require(block.number >= _mintStartBlockNumber, "Not yet started");
      require(requestedCount > 0 && requestedCount <= _mintLimitPerBlock, "Too many requests or zero request");
      require(msg.value == _mintPrice.mul(requestedCount), "Not enough Klay");
      require(_mintIndexForSale.add(requestedCount) <= _maxSaleAmount, "Exceed max amount");
      require(balanceOf(msg.sender) + requestedCount <= _mintLimitPerSale, "Exceed max amount per person");

      bool success;
      bytes memory data;
      (success, data) = _metakongzContract.call(abi.encodeWithSignature("balanceOf(address)", msg.sender));
      if(!success){
        revert();
      }
      uint256 balanceOfSender = abi.decode(data, (uint256));
      require(balanceOfSender > 0, "Sender should have at least one metakongz");

      for(uint256 i = 0; i < requestedCount; i++) {
        _mint(msg.sender, _mintIndexForSale);
        _setTokenURI(_mintIndexForSale,
                     string(abi.encodePacked(_tokenBaseURI, String.uint2str(_mintIndexForSale), ".json")));
        _mintIndexForSale = _mintIndexForSale.add(1);
      }
      _lastCallBlockNumber[msg.sender] = block.number;
    }

    function setupSale(uint256 newAntibotInterval, 
                       address newMetakongzContract,
                       uint256 newMintLimitPerBlock,
                       uint256 newMintLimitPerSale,
                       string calldata newTokenBaseURI, 
                       uint256 newMintStartBlockNumber,
                       uint256 newMaxSaleAmount,
                       uint256 newMintPrice) external onlyMinter{
      _antibotInterval = newAntibotInterval;
      _metakongzContract = newMetakongzContract;
      _mintLimitPerBlock = newMintLimitPerBlock;
      _mintLimitPerSale = newMintLimitPerSale;
      _tokenBaseURI = newTokenBaseURI;
      _mintStartBlockNumber = newMintStartBlockNumber;
      _maxSaleAmount = newMaxSaleAmount;
      _mintPrice = newMintPrice;
    }
}
