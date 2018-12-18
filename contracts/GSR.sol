pragma solidity ^0.4.24;

import "./GEOToken.sol";
import "./math/SafeMath8.sol";
import "./math/SafeMath.sol";
import "./math/SafeMath16.sol";

contract GeoServiceRegistry {

    using SafeMath8 for uint8;
    using SafeMath16 for uint16;
    using SafeMath for uint256;

    /* STORAGE
    */

    GEOToken public token;

    mapping(address => uint256) public deposit;

    // (registry name) => (epoch) => (candidate address) => (total votes amount)
    mapping(string => mapping(uint16 => mapping(address => uint256))) private totalTokensForCandidate;
    // (registry name) => (epoch) => (voter address) => (vote amounts)
    mapping(string => mapping(uint16 => mapping(address => uint256[]))) private amountTokenForCandidateFromVoter;
    // (registry name) => (epoch) => (voter address) => (candidates addresses)
    mapping(string => mapping(uint16 => mapping(address => address[]))) private candidateForVoter;

    mapping(string => bool) private registryName;
    // (registry name) => (epoch) => (total votes amount)
    mapping(string => mapping(uint16 => uint256)) private totalVotesForNewRegistry;
    // (registry name) => (epoch) => (voter address) => (amount vote from address)
    mapping(string => mapping(uint16 => mapping(address => uint256))) private votesForNewRegistry;

    uint16 public currentEpoch;
    uint16 private voteForEpoch;
    uint256 private epochTimeLimit;
    uint256 private epochZero;

    /* EVENTS
    */

    event NewEpoch(uint256 _number);
    event NewRegistry(string _name);

    /* MODIFIERS
    */

    modifier registryExist(string _name)
    {
        require(registryName[_name]);
        _;
    }

    /* CONSTRUCTOR
    */

    constructor(address _geoAddress)
    public
    {
        token = GEOToken(_geoAddress);
        epochTimeLimit = 7 days;
        currentEpoch = 0;
        voteForEpoch = 1;
        epochZero = now;
    }

    /* FUNCTIONS
    */

    function _voteForNewRegistry(
        string _registryName,
        uint256 _amount)
    private
    {
        checkAndUpdateEpoch();
        require(registryName[_registryName] == false);
        totalVotesForNewRegistry[_registryName][voteForEpoch] = totalVotesForNewRegistry[_registryName][voteForEpoch].sub(votesForNewRegistry[_registryName][voteForEpoch][msg.sender]);
        totalVotesForNewRegistry[_registryName][voteForEpoch] = totalVotesForNewRegistry[_registryName][voteForEpoch].add(_amount);
        votesForNewRegistry[_registryName][voteForEpoch][msg.sender] = _amount;
        if (totalVotesForNewRegistry[_registryName][voteForEpoch] >= token.totalSupply() / 10) {
            registryName[_registryName] = true;
            emit NewRegistry(_registryName);
        }
    }

    function _vote(
        string _registryName,
        address[] _candidates,
        uint256[] _amounts)
    registryExist(_registryName)
    private
    {
        require(_candidates.length < 10 && _candidates.length == _amounts.length);
        uint256 oldCandidatesCount = candidateForVoter[_registryName][voteForEpoch][msg.sender].length;
        for (uint256 o = 0; o < oldCandidatesCount; o++) {
            address oldCandidate = candidateForVoter[_registryName][voteForEpoch][msg.sender][o];
            totalTokensForCandidate[_registryName][voteForEpoch][oldCandidate] = totalTokensForCandidate[_registryName][voteForEpoch][oldCandidate].sub(amountTokenForCandidateFromVoter[_registryName][voteForEpoch][msg.sender][o]);
        }
        delete candidateForVoter[_registryName][voteForEpoch][msg.sender];
        delete amountTokenForCandidateFromVoter[_registryName][voteForEpoch][msg.sender];
        uint256 candidatesCount = _candidates.length;
        for (uint256 n = 0; n < candidatesCount; n++) {
            address candidate = _candidates[n];
            totalTokensForCandidate[_registryName][voteForEpoch][candidate] = totalTokensForCandidate[_registryName][voteForEpoch][candidate].add(_amounts[n]);
            candidateForVoter[_registryName][voteForEpoch][msg.sender].push(candidate);
            amountTokenForCandidateFromVoter[_registryName][voteForEpoch][msg.sender].push(_amounts[n]);
        }
    }

    function voteService(
        string _registryName,
        address[] _candidates,
        uint256[] _amounts)
    public
    {
        checkAndUpdateEpoch();
        require(token.lockupExpired() < now);
        uint256 amount = sumOfArray(_amounts);
        if (deposit[msg.sender] < amount) {
            deposit[msg.sender] = deposit[msg.sender].add(amount);
            token.transferFrom(msg.sender, address(this), amount);
        }
        _vote(_registryName, _candidates, _amounts);
    }

    function voteServiceLockup(
        string _registryName,
        address[] _candidates,
        uint256[] _amounts)
    public
    {
        checkAndUpdateEpoch();
        require(token.lockupExpired() > now);
        uint256 amount = sumOfArray(_amounts);
        require(token.balanceOf(msg.sender) >= amount);
        _vote(_registryName, _candidates, _amounts);
    }

    function voteServiceForNewRegistry(
        string _registryName,
        uint256 _amount)
    public
    {
        checkAndUpdateEpoch();
        require(token.lockupExpired() < now);
        if (deposit[msg.sender] < _amount) {
            deposit[msg.sender] = deposit[msg.sender].add(_amount);
            token.transferFrom(msg.sender, address(this), _amount);
        }
        _voteForNewRegistry(_registryName, _amount);
    }

    function voteServiceLockupForNewRegistry(
        string _registryName,
        uint256 _amount)
    public
    {
        checkAndUpdateEpoch();
        require(token.lockupExpired() > now);
        _voteForNewRegistry(_registryName, _amount);
    }

    function withdraw()
    public
    {
        checkAndUpdateEpoch();
        require(deposit[msg.sender] > 0);
        token.transfer(msg.sender, deposit[msg.sender]);
        deposit[msg.sender] = 0;
    }

    function getTotalTokensVotedForCandidate(
        string _registryName,
        uint16 _epoch,
        address _candidate)
    view
    public
    returns (uint256)
    {
        return totalTokensForCandidate[_registryName][_epoch][_candidate];
    }

    function isRegistryExist(string _registryName)
    view
    public
    returns (bool)
    {
        return registryName[_registryName];
    }

    function getTotalVotesForNewRegistry(string _registryName)
    view
    public
    returns (uint256)
    {
        return totalVotesForNewRegistry[_registryName][voteForEpoch];
    }

    /**
    * @dev Check and change number of current epoch
    */
    function checkAndUpdateEpoch()
    public
    {
        uint256 epochFinishTime = (epochZero + (epochTimeLimit.mul(currentEpoch + 1)));
        if (epochFinishTime < now) {
            currentEpoch = uint16((now.sub(epochZero)).div(epochTimeLimit));
            voteForEpoch = currentEpoch + 1;
            emit NewEpoch(currentEpoch);
        }
    }

    function sumOfArray(uint256[] _array)
    pure
    public
    returns (uint256)
    {
        uint256 amount = 0;
        for (uint256 n = 0; n < _array.length; n++) {
            amount = amount.add(_array[n]);
        }
        return amount;
    }

}
