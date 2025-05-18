import math 
pragma solidity ^0.8.17;

interface IMockOracle {
    // Function that the contract will call to request randomness QNRGs
    function requestRandomWord(address callbackContract, bytes4 callbackFunctionSignature) external returns (uint256 requestId);
}

/**
*@title QuantumDrivenProtocolScenariosWithRequest
*@dev This contract models a protocol where 3 different scenarios
*are activated by an external randomness input (simulated QRNG)
*using the Request and Reception pattern with a mock oracle.
 */

contract QuantumDrivenProtocolScenariosWithRequest {

    address public immutable oracleCoordinatorAddress;
    mapping(address => uint256) public userBalances;
    uint256 public currentYieldRateMultiplier; 

    mapping(address => uint256) public userGoodInteractions;
    address[] private allActiveUsers;
    mapping(address => bool) private isUserActive;

    mapping(uint256 => bool) public randomnessRequestsPending;

    // --- Events ---

    event AssetDistributed(address indexed user, uint256 amount);
    event GoodInteractionRecorded(address indexed user, uint256 newCount);
    event RandomnessRequested(uint256 indexed requestId);
    event RandomnessFulfilled(uint256 indexed requestId, uint256 indexed randomWord);

    event Scenario1_YieldDoubled(uint256 indexed newYieldRateMultiplier);
    event Scenario2_YieldHalved(uint256 indexed newYieldRateMultiplier);
    event Scenario3_TokensDistributed(address indexed user, uint256 amountDistributed, uint256 remainingInteractions);

    constructor(address _oracleCoordinatorAddress) {
        oracleCoordinatorAddress = _oracleCoordinatorAddress;
        currentYieldRateMultiplier = 10000; 
    }
    function distributeAsset(address user, uint256 amount) public {
            if (!isUserActive[user] && (userBalances[user] == 0 && userGoodInteractions[user] == 0)) {
                allActiveUsers.push(user);
                isUserActive[user] = true;
            }
            userBalances[user] += amount;
            emit AssetDistributed(user, amount);
        }

    function recordGoodInteraction() public {
        if (!isUserActive[msg.sender] && (userBalances[msg.sender] == 0 && userGoodInteractions[msg.sender] == 0)) {
             allActiveUsers.push(msg.sender);
             isUserActive[msg.sender] = true;
        }
        userGoodInteractions[msg.sender]++;
        emit GoodInteractionRecorded(msg.sender, userGoodInteractions[msg.sender]);
    }

    function applyYield() public {
         uint256 rate = currentYieldRateMultiplier;
         uint256 totalUsers = allActiveUsers.length;

         for(uint i = 0; i < totalUsers; i++) {
             address user = allActiveUsers[i];
             uint256 balance = userBalances[user];

             uint256 yieldEarned = (balance * rate) / 10000; 

             if (yieldEarned > 0) {
                  userBalances[user] += yieldEarned;
                  
             }
         }
     }
    // --- Function Callback (Call from the oracle) ---

    /**
     * @dev Callback function that the Oracle Mock will call when it has the random number.
    */
    function fulfillRandomness(uint256 _requestId, uint256 _randomWord) public {
        //Verification
        require(msg.sender == oracleCoordinatorAddress, "Caller is not the authorized Oracle Coordinator");
        require(randomnessRequestsPending[_requestId], "Request ID not pending");

        randomnessRequestsPending[_requestId] = false;

        uint256 scenario = _randomWord % 3; 

        emit RandomnessFulfilled(_requestId, _randomWord); 

        if (scenario == 0) {
            // --- Scenario 1: Multiply Performance x2 ---

            uint256 newYieldRateMultiplier;
                 newYieldRateMultiplier = currentYieldRateMultiplier + 10000; 

            newYieldRateMultiplier = min(newYieldRateMultiplier, 100000);


            currentYieldRateMultiplier = newYieldRateMultiplier;
            emit Scenario1_YieldDoubled(currentYieldRateMultiplier);

        } else if (scenario == 1) {
            // --- Scenario 2: Divide the Performance by 2 ---

             uint256 newYieldRateMultiplier;
             newYieldRateMultiplier = currentYieldRateMultiplier / 2;
             newYieldRateMultiplier = max(newYieldRateMultiplier, 1000); 


            currentYieldRateMultiplier = newYieldRateMultiplier;
            emit Scenario2_YieldHalved(currentYieldRateMultiplier);

        } else {
            // --- Scenario 3: Distribute Tokens to Users with Good Interactions ---

            uint256 totalUsers = allActiveUsers.length;
            uint256 tokensToDistributePerUser = 50; 

            for(uint i = 0; i < totalUsers; i++) {
                address user = allActiveUsers[i];

                if (userGoodInteractions[user] > 0) {
                    userBalances[user] += tokensToDistributePerUser;
                    userGoodInteractions[user] = 0; 

                    emit Scenario3_TokensDistributed(user, tokensToDistributePerUser, userGoodInteractions[user]);
                }
            }
             // Note: Distributing tokens from the contract requires the contract to have the balance.
             // In a real system with an ERC20 token, the contract would need to have those tokens
             // This is just for the Hackaton and time (also economics)
        }
    }
    // --- Function getter ---

    function getUserBalance(address user) public view returns (uint256) {
        return userBalances[user];
    }

    function getUserYieldRateMultiplier() public view returns (uint256) {
        return currentYieldRateMultiplier;
    }

     function getUserGoodInteractions(address user) public view returns (uint256) {
        return userGoodInteractions[user];
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

     function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

}
