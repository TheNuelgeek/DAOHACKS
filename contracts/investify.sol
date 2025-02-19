//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "./IUSDT.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Investify {
    using SafeMath for uint256;
    address[] public DAOmembers;
    uint256 public constant MINIMUMMEMBER = 5;
    uint256 public contractBalance;
    //struct holding information of business

    IUSDT usdt = IUSDT(address(0x8607D0Ab76985e845B03A6011aA13eDD1Cb21126));
    struct BusinessOwner {
        address business;
        uint256 amount;
        uint256 AmountGenerated;
        uint256 rate;
        address[] investors;
        mapping(address => uint256) investorsBalances;
        bool status;
    }

    mapping(address => bool) whiteListedBusiness;
    mapping(address => uint256) payOut;
    mapping(address => mapping(address => bool)) memberVote;
    mapping(address => uint96) VotesCount;
    mapping(address => BusinessOwner) public businessowner;

    event Business(address, bool);
    event Investment(
        address from,
        address indexed to,
        uint256 amount,
        uint256 moneyGeneratedperBusiness
    );
    event EquityDetails(uint256 _amount, address indexed Business);

    constructor(address[] memory _DAOmembers) {
        assert(_DAOmembers.length >= MINIMUMMEMBER);
        DAOmembers = _DAOmembers;
    }

    /// @notice DaoMembers to vote and automatically whitelist if minimum vote is reached.
    /// @param _addr The address of the business to whitelist.

    function VoteWhitelistBusiness(address _addr) public returns (uint96) {
        assert(checkMember());
        assert(!(memberVote[msg.sender][_addr]));
        VotesCount[_addr]++;
        if (VotesCount[_addr] >= calMinimumVote()) {
            WhiteListBusiness(_addr);
        }
        memberVote[msg.sender][_addr] = true;
        return VotesCount[_addr];
    }

    /// @notice DaoMember to vote and automatically blacklist when minimum vote is reached.
    /// @param _addr The Business address to blacklist.

    function VoteBlacklistBusiness(address _addr) public returns (uint96) {
        assert(checkMember());
        assert((memberVote[msg.sender][_addr]));
        VotesCount[_addr]++;
        if (VotesCount[_addr] >= calMinimumVote()) {
            BlacklistBusiness(_addr);
        }
        memberVote[msg.sender][_addr] = false;
        return VotesCount[_addr];
    }

    /// @notice DaoMembers to vote and automatically Add the member if minimum vote is reached.
    /// @param _addr The address of the member to add to the DAO.

    function AddMembertoDAO(address _addr) public returns (uint256) {
        assert(checkMember());
        assert(!(memberVote[msg.sender][_addr]));
        VotesCount[_addr]++;
        if (VotesCount[_addr] == calMinimumVote()) {
            DAOmembers.push(_addr);
        }
        memberVote[msg.sender][_addr] = true;
        return VotesCount[_addr];
    }

    /// @notice DaoMember update the business requesting for fund onchain.
    /// @param _amount The _amount needed for the business.

    function addBusiness(
        uint256 _amount,
        uint256 _rate,
        address business
    ) public {
        assert(checkMember());
        assert(whiteListedBusiness[business]);
        require(payOut[business] == 0, "you are still owing investors");

        BusinessOwner storage BO = businessowner[business];
        BO.business = business;
        BO.amount = _amount;
        BO.rate = (_rate.mul(10000)).div(100);
        BO.status = true;

        emit EquityDetails(BO.amount, BO.business);
    }

    /// @notice User Invest Usdt in a whitelisted business.
    /// @param business The address of the business user wants to invest in.
    /// @param _amount The usdt value they want to stake in the business.

    function InvestInBusiness(address business, uint256 _amount)
        public
        payable
    {
        BusinessOwner storage BO = businessowner[business];
        assert(BO.status);
        require(usdt.balanceOf(msg.sender) >= _amount, "insufficiient amount");
        require(
            BO.amount + _amount < BO.AmountGenerated,
            "Required Loan amount met"
        );
        usdt.transferFrom(msg.sender, address(this), _amount);
        BO.AmountGenerated += _amount;
        BO.investors.push(msg.sender);
        BO.investorsBalances[msg.sender] += _amount;
        contractBalance += _amount;
        uint256 _moneyGenerated = moneyGenerated(business);

        emit Investment(
            msg.sender,
            BO.business,
            BO.investorsBalances[msg.sender],
            _moneyGenerated
        );
    }

    function withdraw(uint256 amount) public {
        BusinessOwner storage BO = businessowner[msg.sender];
        payOut[msg.sender] = BO.AmountGenerated.add(
            BO.AmountGenerated.mul(BO.rate).div(10000)
        );
        uint256 AmountGenerated = BO.AmountGenerated;
        BO.AmountGenerated = 0;
        usdt.transfer(msg.sender, AmountGenerated);
        BO.status = false;
    }

    /// @notice check the total amount investors has ivested in a particular business
    /// @param bus The address of the business.

    function moneyGenerated(address bus) public view returns (uint256) {
        return businessowner[bus].AmountGenerated;
    }

    /// @notice check if a business address has been whitelist.
    /// @param _addr The address of the business.

    function viewWhiteListedBusiness(address _addr) public view returns (bool) {
        return whiteListedBusiness[_addr];
    }

    /// @notice whitelist an address
    /// @param _addr the address of the business to whitelist

    function WhiteListBusiness(address _addr) internal {
        assert(!whiteListedBusiness[_addr]);
        whiteListedBusiness[_addr] = true;
        emit Business(_addr, true);
    }

    /// @notice blacklist an address
    /// @param _addr the address of the business to blacklist

    function BlacklistBusiness(address _addr) internal {
        whiteListedBusiness[_addr] = false;
    }

    /// @notice check if a user is part of the DAO member
    function checkMember() internal view returns (bool status) {
        status;
        for (uint256 i; i < DAOmembers.length; i++) {
            if (DAOmembers[i] == msg.sender) status = true;
        }
    }

    /// @notice calculate 70% of the total members in the dao
    function calMinimumVote() internal view returns (uint256 value) {
        value = (DAOmembers.length * 70) / 100;
    }
}
