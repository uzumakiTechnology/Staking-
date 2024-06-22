// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";
import "./ISobajaswapV1Router01.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Staking is ReentrancyGuard, Ownable {
    uint256 public constant maximumStakeAmount = 300000 * 10 ** 18; // 300.000 USD
    uint256 public constant minimumStakeAmount = 100 * 10 ** 18; // 100 USD
    uint256 public ethRate = 2000;
    uint256 public  minimumETH = (100 * 10 ** 18) / ethRate;
    uint256 public  maximumETH = (300000 * 10 ** 18) / ethRate;
    uint256 public constant periodLength = 10 days;
    uint256 public constant lockLength = 20 days;

    address rewardToken = 0xABE326Ec882388da5eafb6BfBAD95872640E2484;
    address WETH = 0x20b28B1e4665FFf290650586ad76E977EAb90c5D;
    address USDT = 0x0c4A4B034843D9b867cBe7B324Cfc2831E2D7Ab9;
    address ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address USDC = 0x5f264cE5FD3708Af4DfBafB6234BD307801Fa550;

    ISobajaswapV1Router01 public ROUTER;

    uint256 totalUserStaking;

    struct Position {
        uint256 id;
        uint256 period;
        uint256 stakedAmount;
        uint256 timeStart;
        uint256 timeEnd;
        uint256 lastTimeReward;
        uint256 totalReward;
        bool isWithdrawn;
        uint256 poolId;
        uint256 actualAmount; // original amount before being converted by
    }

    struct Pool {
        uint256 id;
        address stakeToken;
        uint256 totalStakeAmount;
        uint256 totalUser;
        uint256 totalRewardAmount;
    }

    struct User {
        address userAddress;
        Position[] position;
    }

    Pool[] public pools;

    /*  Mappings
        PoolStakingRates : provide pool id, track the rate the pool have
        stakingPosition : provide user address, receive that address Position
        users : store user information
    */
    mapping(uint256 => mapping(uint256 => uint256)) private PoolStakingRates;
    mapping(address => Position[]) public stakingPosition;
    mapping(address => User[]) public users;
    mapping(address => bool) private poolExists;

    /* Events */
    event Staked(
        address indexed user,
        uint256 indexed stakedAmount,
        uint256 poolId,
        uint256 period,
        uint256 positionId
    );

    event Harvested(
        address indexed user,
        uint256 amount,
        uint256 positionId,
        uint256 poolId
    );

    event Withdrawn(
        address indexed user,
        uint256 amount,
        uint256 positionId,
        uint256 poolId
    );

    event PoolCreated(
        address indexed addressToken,
        uint256 indexed rewardAmount,
        uint256 indexed poolId
    );

    event StakingRateUpdate(
        uint256 indexed staking_period,
        uint256 staking_rate,
        uint256 poolId
    );

    event UserUpdated(address indexed userAddress, Position position);

    event PoolUpdated(Pool pool);

    constructor(address _swapRouter, address _stakingTokenAddress) {
        require(
            _swapRouter != address(0) && _stakingTokenAddress != address(0),
            "Staking token and router address can not be zero"
        );

        rewardToken = _stakingTokenAddress;
        ROUTER = ISobajaswapV1Router01(_swapRouter);
    }

    function createPool(
        address _stakeToken,
        uint256 _rewardAmount
    ) external onlyOwner {
        require(
            _rewardAmount > 0,
            "Reward amount transfer must greater than zero"
        );
        require(
            _stakeToken == ETH || _stakeToken == USDC || _stakeToken == USDT,
            "Staking token is Invalid, must choose between ETH, USDC, USDT"
        );
        require(!poolExists[_stakeToken], "Pool already exist for this token");

        require(
            IERC20(rewardToken).transferFrom(
                msg.sender,
                address(this),
                _rewardAmount
            ),
            "Reward token transfer failed"
        );

        uint256 poolId = pools.length;
        pools.push(
            Pool({
                id: poolId,
                stakeToken: _stakeToken,
                totalStakeAmount: 0,
                totalUser: 0,
                totalRewardAmount: _rewardAmount
            })
        );

        PoolStakingRates[poolId][30] = 25;
        PoolStakingRates[poolId][60] = 40;
        PoolStakingRates[poolId][90] = 60;
        PoolStakingRates[poolId][180] = 80;
        PoolStakingRates[poolId][365] = 120;

        poolExists[_stakeToken] = true;
        emit PoolCreated(_stakeToken, _rewardAmount, poolId);
    }

    function setStakingRate(
        uint256 _stakingPeriod,
        uint256 _stakingRate,
        uint256 _poolId
    ) external onlyOwner {
        require(
            _stakingPeriod > 0,
            "Staking Period must be greater than 0 days"
        );
        require(_stakingRate > 0, "Staking rate must be greater than 0%");
        require(_poolId < pools.length, "Invalid Pool ID");

        PoolStakingRates[_poolId][_stakingPeriod] = _stakingRate;
        emit StakingRateUpdate(_stakingPeriod, _stakingRate, _poolId);
    }

    function getStakingPositionCount(
        address _userAddress
    ) public view returns (uint256) {
        return stakingPosition[_userAddress].length;
    }

    function getStakingPositionByIndex(
        address _userAddress,
        uint256 _positionIndex
    ) external view returns (Position memory) {
        return stakingPosition[_userAddress][_positionIndex];
    }

    // For round result only
    function roundUp(uint256 num) private pure returns (uint256) {
        uint256 remainder = num % 10;
        if (remainder == 0) {
            return num;
        } else {
            uint256 difference = 10 - remainder;
            return num + difference;
        }
    }

    function deposit(
        uint256 amount,
        uint256 period,
        uint256 poolId
    ) public payable nonReentrant {
        require(poolId < pools.length, "This pool does not exist");


        Pool storage pool = pools[poolId];

        require(
            PoolStakingRates[poolId][period] != 0,
            "Invalid Staking Period"
        );
        uint256 stakingPeriod = period * 1 days;
        uint256 currentPositionCount = getStakingPositionCount(msg.sender);

        if (currentPositionCount == 0) {
            totalUserStaking++;
        }

        uint256 actualAmount = amount;

        if (pool.stakeToken != rewardToken) {
            if (pool.stakeToken == ETH) {
                require(
                    msg.value == amount,
                    "ETH sent doesn't match your amount"
                );
                require(
                    minimumETH <= amount && maximumETH >= amount,
                    "ETH amount must be within allowed range"
                );

                address[] memory path = new address[](2);
                path[0] = WETH;
                path[1] = rewardToken;
                uint256[] memory amounts_out = ISobajaswapV1Router01(ROUTER)
                    .getAmountsOut(amount, path);

                require(
                    amounts_out[1] > 0,
                    "insufficient liquidity for this trade"
                );

                amount = amounts_out[1];
            } else if (pool.stakeToken == USDT || pool.stakeToken == USDC) {
                address tokenAddress = pool.stakeToken == USDT ? USDT : USDC;

                // Check the approved allowance
                uint256 approvedAllowance = IERC20(tokenAddress).allowance(msg.sender, address(this));
                require(approvedAllowance >= amount, "Insufficient allowance for token transfer");


                address[] memory path = new address[](2);
                path[0] = tokenAddress;
                path[1] = rewardToken;

                uint256[] memory amounts_out = ISobajaswapV1Router01(ROUTER)
                    .getAmountsOut(amount, path);

                require(
                    amounts_out[1] > 0,
                    "Insufficient liquidity for this trade"
                );
                require(
                    minimumStakeAmount <= amounts_out[1] &&
                        maximumStakeAmount >= amounts_out[1],
                    "Staking amount must be within allowed range"
                );
                IERC20(tokenAddress).transferFrom(
                    msg.sender,
                    address(this),
                    amount
                );

                amount = amounts_out[1];
            }
        } else {
            // If stake token is the reward token
            IERC20(rewardToken).transferFrom(msg.sender, address(this), amount);
        }

        Position memory newPosition = Position({
            id: currentPositionCount,
            period: period,
            stakedAmount: amount,
            timeStart: block.timestamp,
            timeEnd: block.timestamp + stakingPeriod,
            lastTimeReward: block.timestamp,
            totalReward: 0,
            isWithdrawn: false,
            poolId: poolId,
            actualAmount: actualAmount
        });

        console.log("Actual amount", newPosition.actualAmount);
        stakingPosition[msg.sender].push(newPosition);
        pool.totalStakeAmount += actualAmount;
        pool.totalUser++;
        emit Staked(msg.sender, amount, poolId, period, newPosition.id);
        emit UserUpdated(msg.sender, newPosition);
        emit PoolUpdated(pool);
    }

    function _calculateRewardAndUpdate(
        Position storage position
    ) internal returns (uint256) {
        uint256 timeSinceLastCollect;
        uint256 remainingDays = 0;
        uint256 rewardRemainingDays = 0;

        uint256 annualInterestRate = PoolStakingRates[position.poolId][
            position.period
        ]; // %

        if (block.timestamp >= position.timeEnd) {
            timeSinceLastCollect = position.timeEnd - position.lastTimeReward;
            remainingDays = position.period % 10;
        } else {
            if (block.timestamp - position.lastTimeReward < lockLength) {
                timeSinceLastCollect =
                    block.timestamp -
                    position.lastTimeReward;
                remainingDays = 0;
            } else {
                timeSinceLastCollect =
                    block.timestamp -
                    position.lastTimeReward -
                    lockLength;
                remainingDays = 0;
            }
        }

        uint256 profitPeriod = timeSinceLastCollect / periodLength;
        uint256 rewardPerPeriodLength = (
            (
                ((position.stakedAmount * annualInterestRate * periodLength) /
                    365 /
                    100)
            )
        );
        uint256 totalReward = rewardPerPeriodLength * profitPeriod;

        if (remainingDays > 0) {
            rewardRemainingDays = ((
                (position.stakedAmount * annualInterestRate * remainingDays)
            ) /
                365 /
                100);
            totalReward += rewardRemainingDays;
        }

        position.lastTimeReward +=
            (profitPeriod * periodLength) +
            remainingDays;
        console.log("From calc function", totalReward);
        return roundUp(totalReward);
    }

    function harvest(
        uint256 _positionIndex
    ) external nonReentrant returns (uint256) {
        require(
            _positionIndex < stakingPosition[msg.sender].length,
            "Staking position index out of bound"
        );
        Position storage harvestPosition = stakingPosition[msg.sender][
            _positionIndex
        ];

        Pool storage pool = pools[harvestPosition.poolId];

        uint256 timeRequest = block.timestamp - harvestPosition.timeStart;

        require(timeRequest >= 30 days, " Harvest not allowed before 30 days");
        uint256 timeSinceLastHarvest = harvestPosition.timeEnd -
            harvestPosition.lastTimeReward;
        require(timeSinceLastHarvest != 0, "Already harvested all reward");

        uint256 totalReward = _calculateRewardAndUpdate(harvestPosition);

        harvestPosition.totalReward += totalReward;
        pool.totalRewardAmount -= totalReward;

        require(
            pool.totalRewardAmount > 0,
            "Reward remainings are not availables"
        );

        emit Harvested(msg.sender, totalReward, _positionIndex, pools.length);
        IERC20(rewardToken).transfer(msg.sender, totalReward);
        emit UserUpdated(msg.sender, harvestPosition);
        emit PoolUpdated(pool);
        return totalReward;
    }

    function withdraw(
        uint256 _positionIndex
    ) external  nonReentrant returns (uint256) {
        require(
            _positionIndex < stakingPosition[msg.sender].length,
            "Index out of bound"
        );
        Position storage withdrawPosition = stakingPosition[msg.sender][
            _positionIndex
        ];

        Pool storage pool = pools[withdrawPosition.poolId];
        require(
            !withdrawPosition.isWithdrawn,
            "Position has already been withdraw"
        );

        uint256 current_position_count = getStakingPositionCount(msg.sender);
        if (current_position_count == 0) {
            totalUserStaking--;
        }

        uint256 totalReward = _calculateRewardAndUpdate(withdrawPosition);
        if (totalReward > pools[withdrawPosition.poolId].totalRewardAmount) {
            totalReward = 0;
        } else {
            pools[withdrawPosition.poolId].totalRewardAmount -= totalReward;
        }

        withdrawPosition.isWithdrawn = true;
        uint256 totalWithdraw = withdrawPosition.stakedAmount + totalReward;
        withdrawPosition.totalReward += totalReward;
        pool.totalStakeAmount -= withdrawPosition.actualAmount;
        emit Withdrawn(
            msg.sender,
            totalWithdraw,
            _positionIndex,
            pools.length
        );
        IERC20(rewardToken).transfer(msg.sender, totalReward);

        if (pools[withdrawPosition.poolId].stakeToken == ETH) {
            uint256 beforeBalance = address(this).balance;

            (bool success, ) = payable(msg.sender).call{
                value: withdrawPosition.actualAmount
            }("");

            require(success, "ETH transfer failed");

            uint256 afterBalance = address(this).balance;

            require(
                afterBalance ==
                    beforeBalance - withdrawPosition.actualAmount,
                "Balance check failed"
            );
        } else {
            IERC20(pools[withdrawPosition.poolId].stakeToken).transfer(
                msg.sender,
                withdrawPosition.actualAmount
            );
        }
        pool.totalUser--;
        emit UserUpdated(msg.sender, withdrawPosition);
        emit PoolUpdated(pool);

        return totalWithdraw;
    }

    function getTotalPoolStakeAmount(
        uint256 poolId
    ) public view returns (uint256) {
        Pool storage pool = pools[poolId];
        return pool.totalStakeAmount;
    }

    function getTotalUserStaking() public view returns (uint256) {
        return totalUserStaking;
    }

    function getClaimableReward(
        Position memory position
    ) internal view returns (uint256) {
        uint256 timeSinceLastCollect;
        uint256 remainingDays = 0;
        uint256 rewardRemainingDays = 0;

        if (position.isWithdrawn) {
            return 0;
        }

        uint256 annualInterestRate = PoolStakingRates[position.poolId][
            position.period
        ];

        if (block.timestamp >= position.timeEnd) {
            timeSinceLastCollect = position.timeEnd - position.lastTimeReward;
            remainingDays = position.period % 10;
        } else {
            if(block.timestamp - position.lastTimeReward < lockLength){
                timeSinceLastCollect = block.timestamp - position.lastTimeReward;
                remainingDays = 0;
            } else {
                timeSinceLastCollect =
                    block.timestamp -
                    position.lastTimeReward -
                    lockLength;
                remainingDays = 0;
            }

        }

        uint256 profitPeriod = timeSinceLastCollect / periodLength;

        uint256 rewardPerPeriodLength = (
            (
                ((position.stakedAmount * annualInterestRate * periodLength) /
                    365 /
                    100)
            )
        );

        uint256 totalReward = rewardPerPeriodLength * profitPeriod;

        // If more than 365, not calculate rewardRemaingdays
        if (remainingDays > 0 && position.lastTimeReward < position.timeEnd) {
            rewardRemainingDays =
                (
                    (((position.stakedAmount * annualInterestRate) / 100) *
                        remainingDays)
                ) /
                365;
            totalReward += rewardRemainingDays;
        }

        return roundUp(totalReward);
    }

    function displayClaimableReward(
        address userAddress,
        uint256 position_index
    ) public view returns (uint256) {
        Position memory position = stakingPosition[userAddress][position_index];
        uint256 reward = getClaimableReward(position);
        console.log("claimable reward", reward);
        return reward;
    }

    function getUserStakingHistory(
        address userAddress
    ) public view returns (Position[] memory) {
        return stakingPosition[userAddress];
    }

    function getTotalReward(
        address userAddress,
        uint256 position_index
    ) public view returns (uint256) {
        Position storage position = stakingPosition[userAddress][
            position_index
        ];
        console.log(
            "Total reward in getTotalReward function",
            position.totalReward
        );
        return position.totalReward;
    }

    function setETHRate(uint256 _newRate) external onlyOwner {
        ethRate = _newRate;
    }
}
