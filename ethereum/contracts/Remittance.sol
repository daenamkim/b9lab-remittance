pragma solidity 0.5.10;

import './Pausable.sol';

contract ExchangeShop {
    function updateBalance(address receiver, uint value) public;
}

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

    event LogRemit(address indexed sender);
    event LogWithdrawed(address indexed receiver);

    function _generateKey(
        string memory seed1,
        string memory password1,
        string memory seed2,
        string memory password2
    ) private view returns (bytes32) {
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
        require(_passwordKeyStore[key] == 0, 'Same password pair should not be used');

        _passwordKeyStore[key] = now + expire;
        balances[key] += msg.value;
    }

    function checkKey(
        string memory password1,
        string memory password2
    ) public onlyOwner view returns (uint, uint, bytes32) {
        bytes32 key = _generateKey(_seed1, password1, _seed2, password2);
        return (_passwordKeyStore[key], now, key);
    }

    function remit(string memory password1, string memory password2, address receiver) public whenNotPaused returns (uint) {
        bytes32 key = _generateKey(_seed1, password1, _seed2, password2);
        require(_passwordKeyStore[key] != 0, 'Key must be in the key store');
        require(_passwordKeyStore[key] > now, 'Key should not be expired');
        require(balances[key] > 0, 'Balance should be greater than 0');
        require(receiver != address(0), 'Reciever shoudl have an address');

        msg.sender.transfer(balances[key]);
        // Send value information of receiver
        bool ok = ExchangeShop(msg.sender).call(
            abi.encodeWithSignature('updateBalance(address,uint)', receiver, balances[key])
        );
        require(ok, 'updateBalance should be called');

        balances[key] = 0;
        _passwordKeyStore[key] = 0;
        emit LogRemit(msg.sender);
    }

    function withdrawed(address receiver) external {
        emit LogWithdrawed(receiver);
    }

    function setSeeds(string memory seed1, string memory seed2) public onlyOwner whenNotPaused {
        _seed1 = seed1;
        _seed2 = seed2;
    }

    function getSeeds() public onlyOwner view returns (string memory, string memory) {
        return (_seed1, _seed2);
    }
}
