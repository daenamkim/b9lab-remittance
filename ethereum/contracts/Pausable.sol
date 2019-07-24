pragma solidity 0.5.10;

import "./Ownable.sol";

contract Pausable is Ownable {
    bool private _paused = false;

    event LogPaused(address owner);
    event LogUnpaused(address owner);

    modifier whenNotPaused() {
        require(!_paused, "Should not be paused");

        _;
    }

    modifier whenPaused() {
        require(_paused, "Should be paused");

        _;
    }

    function pause() public onlyOwner whenPaused {
        _paused = true;

        emit LogPaused(msg.sender);
    }

    function unpause() public onlyOwner whenNotPaused {
        _paused = false;

        emit LogUnpaused(msg.sender);
    }
}
