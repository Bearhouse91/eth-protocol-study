// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./StakeCoin.sol";
import "./YieldCoin.sol";

contract TokenStaking {
    uint256 private constant PRECISION = 1e18;

    StakeCoin public immutable stakingToken;
    YieldCoin public immutable rewardToken;
    uint256 public immutable rewardRate; // YieldCoin (wei) emitted per second across pool

    uint256 public totalStaked;
    uint256 public rewardPerTokenStored;
    uint256 public lastUpdateTime;

    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);

    constructor(address _stakingToken, uint256 _rewardRate) {
        require(_stakingToken != address(0), "Zero staking token");
        require(_rewardRate > 0, "Zero reward rate");
        stakingToken = StakeCoin(_stakingToken);
        rewardToken = new YieldCoin(address(this));
        rewardRate = _rewardRate;
        lastUpdateTime = block.timestamp;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        uint256 elapsed = block.timestamp - lastUpdateTime;
        return rewardPerTokenStored + ((elapsed * rewardRate * PRECISION) / totalStaked);
    }

    function earned(address account) public view returns (uint256) {
        uint256 deltaPerToken = rewardPerToken() - userRewardPerTokenPaid[account];
        return rewards[account] + ((stakedBalance[account] * deltaPerToken) / PRECISION);
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function stake(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        totalStaked += amount;
        stakedBalance[msg.sender] += amount;
        require(stakingToken.transferFrom(msg.sender, address(this), amount), "Stake transfer failed");
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        require(stakedBalance[msg.sender] >= amount, "Insufficient staked balance");
        totalStaked -= amount;
        stakedBalance[msg.sender] -= amount;
        require(stakingToken.transfer(msg.sender, amount), "Withdraw transfer failed");
        emit Withdrawn(msg.sender, amount);
    }

    function claimRewards() external updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        require(reward > 0, "No rewards to claim");
        rewards[msg.sender] = 0;
        rewardToken.mintReward(msg.sender, reward);
        emit RewardsClaimed(msg.sender, reward);
    }
}
