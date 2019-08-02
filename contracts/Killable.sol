pragma solidity 0.5.10;

import './Pausable.sol';

contract Killable is Pausable {
    bool public killed;

    event LogKilled(address killedBy);

    modifier whenNotKilled() {
        require(!killed, "Should not be killed");

        _;
    }

    function kill() public onlyOwner whenNotKilled {
        killed = true;

        emit LogKilled(msg.sender);
    }
}
