// SPDX-License-Identifier: MIT

//This is a Smart Contract that has a borrow/lend money function
//The idea is as follows:
//Person A wants to borrow 10 Ether. For that Person A creates a "Request". When the
//Request is created, it is available for everyone. If Person B wants to lend Person A
//the 10 Ether, Person B accepts the "Request" and sends the 10 Ether to the Smart Contract.
//Person A then has to pay back the borrowed amount (10 Ether), a fee as rewards for the lender
//to incentivize people to lend money and a service fee for us maintaining the platform.
//If all debts are paid back, the "Request" becomes fulfilled and is inactive. 
//
//To outsorce the problem of trust for borrowers we created our own token as ERC1155 Token.
//We assume, that only trusted people own this token (e.g. people have to be registered with their full name). 
//By that, the Smart Contract for this task becomes cleaner and has an integrated safety function to only borrow money
//to trustet people.
pragma solidity ^0.8.9;

import "node_modules/@openzeppelin/contracts/utils/Counters.sol";
import "node_modules/@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "ULToken.sol";

contract UltimateLend {

    //using the OpenZeppelin SmartContract to count the amount of Requests
    using Counters for Counters.Counter;
    Counters.Counter internal requestID;

    address owner;

    //enum for the states that a Request has
    enum requestState{created, accepted, fulfilled}

    //mapping that contains the amount of debts open
    //extra mapping to check amount for a specific address (can't efficiently search for an address in a struct
    //thats why we the mapping)
    mapping(address => uint256) debtAmount;

    //smart contract for our own Ultimate Lend Troken
    IERC1155 ULToken;
    
    //since we are using ERC1155 on which you can mint multiple token, we have to specify the token ID
    uint256 currentTokenId;

    //structure contains all data of a Request to borrow money
    struct stc_moneyRequest {
        address payable lender;     //the address that lends the money
        address payable borrower;   //the address that requests the money
        uint256 fees;               //the amount of fees to be paid by the borrower
        uint256 borrowedAmount;     //the amount the borrower requests
        uint256 totalAmount;        //the requested amount + fees
        uint256 openAmount;         //the amount thats still open to be paid back by the borrower
        requestState state;         //the state of the current Request
    }

    //map a Request ID to the Request data
    mapping(uint256 => stc_moneyRequest) public moneyRequests;

    modifier onlyOwner() {
        require(owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    //modifier for functions that should only be executable by someone that owns the custom token
    modifier hasCustomToken() {
        require(ULToken.balanceOf(msg.sender, currentTokenId) > 0);
        _;
    }

    //constructor only initializes the custom token smart contract and the ID of the token
    //both can be changed afterwards by the owner (owner = deployer of this contract)
    constructor(address _tokenSmartContract, uint256 _tokenId) {

        ULToken = IERC1155(_tokenSmartContract);
        currentTokenId = _tokenId;

        owner = msg.sender;

    }

    //____________
    //Borrow functions

    //with this function a trusted person can open a Request to borrow money.
    function createMoneyRequest(uint256 _amount) public hasCustomToken {
        uint256 fees = calcFees(_amount);
        uint256 totalAmount = _amount + fees;
        moneyRequests[calcID()] = stc_moneyRequest(payable(address(0x0)), payable(msg.sender), fees, _amount, totalAmount, totalAmount, requestState.created);
        
    }
    
    //if a Request is accepted and money is lent, this function is used to pay back the
    //borrowed money and fees included
    //add additional mapping for lender => requestID
    function payDebts(uint256 _requestID) public payable {
        require(msg.value > 0);
        require(debtAmount[msg.sender] > 0);
        require(debtAmount[msg.sender] >= msg.value);
        require(moneyRequests[_requestID].state == requestState.accepted);

        //transfer the paid money to the lender
        moneyRequests[_requestID].lender.transfer(msg.value);

        //reduce debts by the paid amount
        moneyRequests[_requestID].openAmount -= msg.value;
        debtAmount[msg.sender] -= moneyRequests[_requestID].openAmount;


        //bring to an own internal function
        //if all debts are paid, note that in the variables
        if(moneyRequests[_requestID].openAmount == 0) {
            moneyRequests[_requestID].state = requestState.fulfilled;
        }
    }

    //if someone that borrowed money wants to check the open debts for his address
    //this function return the left amount
    function getOpenDebts() view public returns(uint256) {
        return debtAmount[msg.sender];
    }

    //____________
    //Lend functions

    //to accept an open Request this function is called. As message
    //value the amount to be lend is required, therefor the function is
    //marked as payable
    function lendMoney(uint256 _requestID) public payable {
        require(msg.value == moneyRequests[_requestID].borrowedAmount);
        require(moneyRequests[_requestID].state == requestState.created);
        
        //set the lender for this money request
        moneyRequests[_requestID].lender = payable(msg.sender);

        //transfer the lent money to the borrower
        moneyRequests[_requestID].borrower.transfer(msg.value);

        //change state of the money request
        moneyRequests[_requestID].state = requestState.accepted;

        //set debt counter for borrower
        debtAmount[moneyRequests[_requestID].borrower] = moneyRequests[_requestID].totalAmount;

    }

    //____________
    //Util functions 

    //calculates the overall amount fees for lender + service fee
    function calcFees(uint256 _amount) pure public returns(uint256) {
        return _amount*2/100;
    }

    //this calculates the service fee part
    function calcServiceFee(uint256 _overallFees) pure public returns(uint256) {
        return _overallFees*1/100;
    }

    //counts up the requestID and returns the new value
    function calcID() public returns(uint256) {
        requestID.increment();
        return requestID.current();
    }

    //function for the owner/deployer of this SC to change the smart contract for the custom Token
    function changeTokenSmartContract(address _smartContractAddress) public onlyOwner {
        ULToken = IERC1155(_smartContractAddress);
    }

    //function for the owner/deployer of this SC to change the token ID of the custom token
    function changeTokenId(uint256 _tokenId) public onlyOwner {
        currentTokenId = _tokenId;
    }
}
