pragma solidity 0.5.10;

import "./Pausable.sol";
import "./SafeMath.sol";

contract Remittance {
    function remit(address recipient, bytes32 secretRecipient, bytes32 secretExchangeShop) external returns (bool);
    function withdrawedFromExchangeShop(address recipient, bytes32 secretRecipient) external returns (bool);
    function generateHash(address recipient, bytes32 secretRecipient, bytes32 secretExchangeShop) public pure returns (bytes32);
    function checkHash(address recipient, bytes32 secretRecipient, bytes32 secretExchangeShop, bytes32 hash) public pure returns (bool);
}

contract ExchangeShop is Pausable {
    using SafeMath for uint256;

    mapping(address => uint) public balances;
    mapping(address => address) public senders;

    function exchange(
        Remittance remittanceContract,
        address recipient,
        bytes32 secretRecipient,
        bytes32 secretExchangeShop
    ) public whenNotPaused {
        // TODO: security/no-low-level-calls: Avoid using low-level function 'call'.
        (bool ok, bytes memory hash) = address(remittanceContract).call(
            abi.encodeWithSignature(
                "generateHash(address,string,string)",
                recipient,
                secretRecipient,
                secretExchangeShop
            )
        );
        require(ok, "generateHash must be called successfully");

        (ok,) = address(remittanceContract).call(
            abi.encodeWithSignature(
                "checkHash(address,string,string,bytes32)",
                recipient,
                secretRecipient,
                secretExchangeShop,
                hash
            )
        );
        require(ok, "Hash must be valid");

        // request a remittance with some commission
        (ok,) = address(remittanceContract).call(
            abi.encodeWithSignature("remit(address,string,string)", recipient, secretRecipient, secretExchangeShop)
        );
        require(ok, "Remit must be called successfully");

        senders[recipient] = address(remittanceContract);
    }

    function deposit(address recipient) external payable whenNotPaused returns (bool) {
        require(recipient != address(0), "Address must be valid");
        require(msg.value > 0, "Value must be bigger than 0");

        // TODO: how to do exchange rate?
        balances[recipient] = balances[recipient].add(msg.value);

        return true;
    }

    function withdraw(bytes32 secretRecipient) public whenNotPaused returns (bool) {
        address sender = senders[msg.sender];
        require(sender != address(0), "Sender address must be valid");

        (bool ok, bytes memory hash) = address(sender).call(
            abi.encodeWithSignature(
                "generateHash(address,string,string)",
                msg.sender,
                secretRecipient,
                ""
            )
        );
        require(ok, "generateHash() must be called successfully");

        (ok,) = address(sender).call(
            abi.encodeWithSignature(
                "checkHash(address,string,string,bytes32)",
                msg.sender,
                secretRecipient,
                "",
                hash
            )
        );
        require(ok, "Hash must be valid");

        uint value = balances[msg.sender];
        balances[msg.sender] = 0;
        msg.sender.transfer(value);

        // notify to original sender
        (ok,) = address(sender).call(
            abi.encodeWithSignature(
                "withdrawedFromExchangeShop(address,string)",
                msg.sender,
                secretRecipient
            )
        );
        require(ok, "withdrawedFromExchangeShop() must be called successfully");

        return true;
    }
}
