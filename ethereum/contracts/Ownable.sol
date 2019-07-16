pragma solidity 0.5.10;

contract Ownable {
  address private _owner;

  constructor() public {
    _owner = msg.sender;
  }

  modifier onlyOwner() {
    require(msg.sender == _owner, 'Should be only owner');

    _;
  }

  function getOwner() public view returns (address) {
    return _owner;
  }
}
