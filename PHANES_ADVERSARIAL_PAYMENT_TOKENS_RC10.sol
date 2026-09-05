// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

/*
 Test-only adversarial payment token harnesses for PHANES RC10.
 DO NOT deploy these as production payment assets.
*/

interface IPHANESBuyHarness {
    function buy(
        uint8 expectedStage,
        uint256 maxPaymentAmount,
        uint256 minPhanesReceived,
        uint64 deadline
    ) external;
}

contract FalseReturnPaymentToken {
    string public constant name = "FALSE RETURN";
    string public constant symbol = "FALSE";
    uint8 public constant decimals = 6;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external { balanceOf[to] += amount; }
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount; return true;
    }
    function transfer(address, uint256) external pure returns (bool) { return false; }
    function transferFrom(address, address, uint256) external pure returns (bool) { return false; }
}

contract FeeOnTransferPaymentToken {
    string public constant name = "FEE TOKEN";
    string public constant symbol = "FEE";
    uint8 public constant decimals = 6;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external { balanceOf[to] += amount; }
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount; return true;
    }
    function transfer(address to, uint256 amount) external returns (bool) {
        _move(msg.sender,to,amount); return true;
    }
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 a=allowance[from][msg.sender];
        require(a>=amount,"allowance");
        if(a!=type(uint256).max) allowance[from][msg.sender]=a-amount;
        _move(from,to,amount); return true;
    }
    function _move(address from,address to,uint256 amount) internal {
        require(balanceOf[from]>=amount,"balance");
        uint256 fee=amount/100; // 1%
        balanceOf[from]-=amount;
        balanceOf[to]+=amount-fee;
        // fee disappears from this deliberately non-standard test token
    }
}

contract ReentrantPaymentToken {
    string public constant name = "REENTRANT";
    string public constant symbol = "REENTER";
    uint8 public constant decimals = 6;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public target;
    uint8 public expectedStage;
    uint256 public nestedBudget;
    bool private attacking;

    function configure(address _target,uint8 _stage,uint256 _budget) external {
        target=_target; expectedStage=_stage; nestedBudget=_budget;
    }
    function mint(address to,uint256 amount) external { balanceOf[to]+=amount; }
    function approve(address spender,uint256 amount) external returns(bool){
        allowance[msg.sender][spender]=amount; return true;
    }
    function transfer(address to,uint256 amount) external returns(bool){
        _move(msg.sender,to,amount); return true;
    }
    function transferFrom(address from,address to,uint256 amount) external returns(bool){
        uint256 a=allowance[from][msg.sender];
        require(a>=amount,"allowance");
        if(a!=type(uint256).max) allowance[from][msg.sender]=a-amount;
        _move(from,to,amount);
        if(!attacking && target!=address(0)){
            attacking=true;
            // The nested call is expected to fail against PHANES' reentrancy guard.
            try IPHANESBuyHarness(target).buy(
                expectedStage,
                nestedBudget,
                0,
                uint64(block.timestamp+60)
            ) {} catch {}
            attacking=false;
        }
        return true;
    }
    function _move(address from,address to,uint256 amount) internal {
        require(balanceOf[from]>=amount,"balance");
        balanceOf[from]-=amount; balanceOf[to]+=amount;
    }
}
