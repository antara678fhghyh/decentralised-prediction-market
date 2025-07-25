// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title DecentralizedPredictionMarket
 * @dev A smart contract for creating and managing prediction markets
 * @author Decentralized Prediction Market Team
 */
contract DecentralizedPredictionMarket {
    
    // Struct to represent a prediction market
    struct Market {
        uint256 id;
        string question;
        string[] options;
        uint256 endTime;
        bool resolved;
        uint256 winningOption;
        address creator;
        uint256 totalPool;
        mapping(uint256 => uint256) optionPools;
        mapping(address => mapping(uint256 => uint256)) userBets;
    }
    
    // State variables
    uint256 public marketCounter;
    mapping(uint256 => Market) public markets;
    mapping(address => uint256[]) public userMarkets;
    
    // Events
    event MarketCreated(
        uint256 indexed marketId,
        address indexed creator,
        string question,
        uint256 endTime
    );
    
    event BetPlaced(
        uint256 indexed marketId,
        address indexed user,
        uint256 optionIndex,
        uint256 amount
    );
    
    event MarketResolved(
        uint256 indexed marketId,
        uint256 winningOption,
        uint256 totalPool
    );
    
    event WinningsWithdrawn(
        uint256 indexed marketId,
        address indexed user,
        uint256 amount
    );
    
    // Modifiers
    modifier marketExists(uint256 _marketId) {
        require(_marketId < marketCounter, "Market does not exist");
        _;
    }
    
    modifier marketActive(uint256 _marketId) {
        require(block.timestamp < markets[_marketId].endTime, "Market has ended");
        require(!markets[_marketId].resolved, "Market is already resolved");
        _;
    }
    
    modifier onlyCreator(uint256 _marketId) {
        require(msg.sender == markets[_marketId].creator, "Only creator can resolve");
        _;
    }
    
    /**
     * @dev Creates a new prediction market
     * @param _question The question for the prediction market
     * @param _options Array of possible outcomes
     * @param _duration Duration of the market in seconds
     */
    function createMarket(
        string memory _question,
        string[] memory _options,
        uint256 _duration
    ) external returns (uint256) {
        require(bytes(_question).length > 0, "Question cannot be empty");
        require(_options.length >= 2, "At least 2 options required");
        require(_duration > 0, "Duration must be positive");
        
        uint256 marketId = marketCounter++;
        Market storage newMarket = markets[marketId];
        
        newMarket.id = marketId;
        newMarket.question = _question;
        newMarket.options = _options;
        newMarket.endTime = block.timestamp + _duration;
        newMarket.resolved = false;
        newMarket.creator = msg.sender;
        newMarket.totalPool = 0;
        
        userMarkets[msg.sender].push(marketId);
        
        emit MarketCreated(marketId, msg.sender, _question, newMarket.endTime);
        
        return marketId;
    }
    
    /**
     * @dev Places a bet on a specific option in a market
     * @param _marketId The ID of the market
     * @param _optionIndex The index of the option to bet on
     */
    function placeBet(uint256 _marketId, uint256 _optionIndex) 
        external 
        payable 
        marketExists(_marketId)
        marketActive(_marketId)
    {
        require(msg.value > 0, "Bet amount must be greater than 0");
        require(_optionIndex < markets[_marketId].options.length, "Invalid option");
        
        Market storage market = markets[_marketId];
        
        market.userBets[msg.sender][_optionIndex] += msg.value;
        market.optionPools[_optionIndex] += msg.value;
        market.totalPool += msg.value;
        
        emit BetPlaced(_marketId, msg.sender, _optionIndex, msg.value);
    }
    
    /**
     * @dev Resolves a market by setting the winning option
     * @param _marketId The ID of the market to resolve
     * @param _winningOption The index of the winning option
     */
    function resolveMarket(uint256 _marketId, uint256 _winningOption)
        external
        marketExists(_marketId)
        onlyCreator(_marketId)
    {
        Market storage market = markets[_marketId];
        require(block.timestamp >= market.endTime, "Market has not ended yet");
        require(!market.resolved, "Market already resolved");
        require(_winningOption < market.options.length, "Invalid winning option");
        
        market.resolved = true;
        market.winningOption = _winningOption;
        
        emit MarketResolved(_marketId, _winningOption, market.totalPool);
    }
    
    /**
     * @dev Allows users to withdraw their winnings from resolved markets
     * @param _marketId The ID of the resolved market
     */
    function withdrawWinnings(uint256 _marketId)
        external
        marketExists(_marketId)
    {
        Market storage market = markets[_marketId];
        require(market.resolved, "Market not resolved yet");
        
        uint256 userBetOnWinning = market.userBets[msg.sender][market.winningOption];
        require(userBetOnWinning > 0, "No winning bet found");
        
        // Calculate winnings: (user's bet on winning option / total bets on winning option) * total pool
        uint256 winningPool = market.optionPools[market.winningOption];
        require(winningPool > 0, "No bets on winning option");
        
        uint256 winnings = (userBetOnWinning * market.totalPool) / winningPool;
        
        // Reset user's bet to prevent double withdrawal
        market.userBets[msg.sender][market.winningOption] = 0;
        
        // Transfer winnings
        payable(msg.sender).transfer(winnings);
        
        emit WinningsWithdrawn(_marketId, msg.sender, winnings);
    }
    
    // View functions
    function getMarket(uint256 _marketId) 
        external 
        view 
        marketExists(_marketId)
        returns (
            uint256 id,
            string memory question,
            string[] memory options,
            uint256 endTime,
            bool resolved,
            uint256 winningOption,
            address creator,
            uint256 totalPool
        )
    {
        Market storage market = markets[_marketId];
        return (
            market.id,
            market.question,
            market.options,
            market.endTime,
            market.resolved,
            market.winningOption,
            market.creator,
            market.totalPool
        );
    }
    
    function getUserBet(uint256 _marketId, address _user, uint256 _optionIndex)
        external
        view
        marketExists(_marketId)
        returns (uint256)
    {
        return markets[_marketId].userBets[_user][_optionIndex];
    }
    
    function getOptionPool(uint256 _marketId, uint256 _optionIndex)
        external
        view
        marketExists(_marketId)
        returns (uint256)
    {
        return markets[_marketId].optionPools[_optionIndex];
    }
    
    function getUserMarkets(address _user) external view returns (uint256[] memory) {
        return userMarkets[_user];
    }
}
