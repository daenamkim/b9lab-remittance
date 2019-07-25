pragma solidity 0.5.10;

import "./Pausable.sol";
import "./SafeMath.sol";

contract Remittance is Pausable {
    using SafeMath for uint256;

    mapping (address => mapping (bytes32 => uint)) public balances;
    mapping (address => mapping (bytes32 => bool)) public notifications;

    event LogRemit(address indexed sender, uint value);
    event LogWithdrawed(address indexed to);

    function generateHash(address to, string memory secretTo, string memory secretExchangeShop) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(to, secretTo, secretExchangeShop));
    }

    function checkHash(address to, string memory secretTo, string memory secretExchangeShop, bytes32 hash) public pure returns (bool) {
        if (generateHash(to, secretTo, secretExchangeShop) == hash) {
            return true;
        }

        return false;
    }

    function deposit(address to, bytes32 hash) public onlyOwner whenNotPaused payable returns (bool) {
        require(msg.value > 0, "Value must be bigger than 0");
        require(hash != bytes32(0), "Hash must be valid");
        require(to != address(0), "Address must be valid");

        balances[to][hash] = balances[to][hash].add(msg.value);

        return true;
    }

    function remit(address to, string calldata secretTo, string calldata secretExchangeShop) external whenNotPaused returns (bool) {
        bytes32 hash = generateHash(to, secretTo, secretExchangeShop);
        require(to != address(0), "Address must be valid");
        require(checkHash(to, secretTo, secretExchangeShop, hash), "Secrets must be valid");

        uint value = balances[to][hash];
        require(value > 0, "Balance must be bigger than 0");

        balances[to][hash] = 0;
        // TODO: set gas?
        // TODO: security/no-call-value: Consider using 'transfer' in place of 'call.value()'.
        (bool ok,) = msg.sender.call.value(value)(abi.encodeWithSignature("deposit(address)", to));
        require(ok, "Deposit to Exchange Shop must be successful");

        emit LogRemit(msg.sender, value);
        notifications[to][generateHash(to, secretTo, "")] = true;

        return true;
    }

    function withdrawedFromExchangeShop(address to, string calldata secretTo) external returns (bool) {
        bytes32 hash = generateHash(to, secretTo, "");
        require(notifications[to][hash], "Notfication doesn't exist");

        notifications[to][hash] = false;
        emit LogWithdrawed(to);

        return true;
    }
}
