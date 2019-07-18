pragma solidity 0.5.10;

import './Pausable.sol';

contract Remittance is Pausable {
    mapping(bytes32 => uint) private _passwordKeyStore;
    mapping(bytes32 => uint) public balances;
    string private _seed1;
    string private _seed2;

    constructor (string memory seed1, string memory seed2) public {
      require(bytes(seed1).length > 0 && bytes(seed2).length > 0, 'Seed must be passed');
      require(keccak256(abi.encodePacked(seed1)) != keccak256(abi.encodePacked(seed2)), 'Each seed must be different');
      _seed1 = seed1;
      _seed2 = seed2;
    }

    event LogRemit(address sender);

    function _generateKey(
      string memory seed1,
      string memory password1,
      string memory seed2,
      string memory password2
    ) private view returns (bytes32) {
      // NOTE: password1, password2 will be passed from outside
      bytes32 password1Encoded = keccak256(abi.encodePacked(this, seed1, password1));
      bytes32 password2Encoded = keccak256(abi.encodePacked(this, seed2, password2));
      return keccak256(abi.encodePacked(this, password1Encoded, password2Encoded));
    }

    function deposit(
      string memory password1,
      string memory password2,
      uint expire
    ) public payable onlyOwner whenNotPaused {
      bytes32 password1Check = keccak256(abi.encodePacked(password1));
      bytes32 password2Check = keccak256(abi.encodePacked(password2));
      require(password1Check != password2Check, 'Each password should be different');

      bytes32 key = _generateKey(_seed1, password1, _seed2, password2);
      require(_passwordKeyStore[key] == 0, 'One of passwords is used in the key store');

      _passwordKeyStore[key] = now + expire;
      balances[key] += msg.value;
    }

    function checkKey(
      string memory password1,
      string memory password2
    ) public onlyOwner whenNotPaused view returns (uint, uint, bytes32) {
      bytes32 key = _generateKey(_seed1, password1, _seed2, password2);
      return (_passwordKeyStore[key], now, key);
    }

    function remit(string memory password1, string memory password2) public whenNotPaused {
      bytes32 key = _generateKey(_seed1, password1, _seed2, password2);
      require(_passwordKeyStore[key] != 0, 'Key must be in the key store');
      require(_passwordKeyStore[key] > now, 'Key should not be expired');
      require(balances[key] > 0, 'Balance should be greater than 0');

      msg.sender.transfer(balances[key]);
      balances[key] = 0;
      _passwordKeyStore[key] = 0;
      emit LogRemit(msg.sender);
    }

    function setSeeds(string memory seed1, string memory seed2) public onlyOwner whenNotPaused {
      _seed1 = seed1;
      _seed2 = seed2;
    }

    function getSeeds() public onlyOwner whenNotPaused view returns (string memory, string memory) {
      return (_seed1, _seed2);
    }
}
