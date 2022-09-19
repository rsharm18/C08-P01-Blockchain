// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.6;

contract RPSGame {

    modifier gameResultReady(){
        string memory errorMsg = string(abi.encodePacked("NOT ALLOWED! Game State must be in Draw/Win state."," Current state is ",_gameData.state ));
        require((_gameData.state == RPSGameState.DRAW ||_gameData.state == RPSGameState.WIN), errorMsg);
        _;
    }

    // GameState - INITIATED after inital game setup, RESPONDED after responder adds hash choice, WIN or DRAW after final scoring
    enum RPSGameState {INITIATED, RESPONDED, WIN, DRAW}
    
    // PlayerState - PENDING until they add hashed choice, PLAYED after adding hash choice, CHOICE_STORED once raw choice and random string are stored
    enum PlayerState {PENDING, PLAYED, CHOICE_STORED}
    
    // 0 before choices are stored, 1 for Rock, 2 for Paper, 3 for Scissors. Strings are stored only to generate comment with choice names
    string[4] choiceMap = ['None', 'Rock', 'Paper', 'Scissors'];
    
    struct RPSGameData {
        address initiator; // Address of the initiator
        PlayerState initiator_state; // State of the initiator
        bytes32 initiator_hash; // Hashed choice of the initiator
        uint8 initiator_choice; // Raw number of initiator's choice - 1 for Rock, 2 for Paper, 3 for Scissors
        string initiator_random_str; // Random string chosen by the initiator
        
	address responder; // Address of the responder
        PlayerState responder_state; // State of the responder
        bytes32 responder_hash; // Hashed choice of the responder
        uint8 responder_choice; // Raw number of responder's choice - 1 for Rock, 2 for Paper, 3 for Scissors
        string responder_random_str; // Random string chosen by the responder
                
        RPSGameState state; // Game State
        address winner; // Address of winner after completion. addresss(0) in case of draw
        string comment; // Comment specifying what happened in the game after completion
    }
    
    RPSGameData _gameData;
    
    
    // Initiator sets up the game and stores its hashed choice in the creation itself. Game and player states are adjusted accordingly
    constructor(address _initiator, address _responder, bytes32 _initiator_hash) {
        _gameData = RPSGameData({
                                    initiator: _initiator,
                                    initiator_state: PlayerState.PLAYED,
                                    initiator_hash: _initiator_hash, 
                                    initiator_choice: 0,
                                    initiator_random_str: '',
                                    responder: _responder, 
                                    responder_state: PlayerState.PENDING,
                                    responder_hash: 0, 
                                    responder_choice: 0,
                                    responder_random_str: '',
                                    state: RPSGameState.INITIATED,
                                    winner: address(0),
                                    comment: ''
                            });
    }
    
    function isValidChoice(uint8 _choice) public view returns(bool){
        return (_choice> 0 && _choice< choiceMap.length);
    }

    function getInvalidChoiceMessage() public pure returns( string memory){
        return "Your input must be between 1 and 3" ;
    }

    // Responder stores their hashed choice. Game and player states are adjusted accordingly.
    function addResponse(bytes32 _responder_hash) public {
        _gameData.responder_hash = _responder_hash;
        _gameData.state = RPSGameState.RESPONDED;
        _gameData.responder_state = PlayerState.PLAYED;
    }
    
    // Initiator adds raw choice number and random string. If responder has already done the same, the game should process the completion execution
    function addInitiatorChoice(uint8 _choice, string memory _randomStr) public returns (bool) {
        _gameData.initiator_choice = _choice;
        _gameData.initiator_random_str = _randomStr;
        _gameData.initiator_state = PlayerState.CHOICE_STORED;
        if (_gameData.responder_state == PlayerState.CHOICE_STORED) {
            __validateAndExecute();
        }
        return true;
    }

    // Responder adds raw choice number and random string. If initiator has already done the same, the game should process the completion execution
    function addResponderChoice(uint8 _choice, string memory _randomStr) public returns (bool) {
        _gameData.responder_choice = _choice;
        _gameData.responder_random_str = _randomStr;
        _gameData.responder_state = PlayerState.CHOICE_STORED;
        if (_gameData.initiator_state == PlayerState.CHOICE_STORED) {
            __validateAndExecute();
        }
        return true;
    }
    
    // Core game logic to check raw choices against stored hashes, and then the actual choice comparison
    // Can be split into multiple functions internally
    function __validateAndExecute() private {
        bytes32 initiatorCalcHash = sha256(abi.encodePacked(choiceMap[_gameData.initiator_choice], '-', _gameData.initiator_random_str));
        bytes32 responderCalcHash = sha256(abi.encodePacked(choiceMap[_gameData.responder_choice], '-', _gameData.responder_random_str));
        bool initiatorAttempt = false;
        bool responderAttempt = false;
        
        if (initiatorCalcHash == _gameData.initiator_hash) {
            initiatorAttempt = true;
        }
        
        if (responderCalcHash == _gameData.responder_hash) {
            responderAttempt = true;
        }
        
        // Add logic to complete the game first based on attempt validation states, and then based on actual game logic if both attempts are validation
        // Comments can be set appropriately like 'Initator attempt invalid', or 'Scissor beats Paper', etc.

        // both initiator and responder attempt are invalid
        if(initiatorAttempt == false && responderAttempt == false){
            __setGameState(RPSGameState.DRAW,address(0),"DRAW. Both Initiator and Responder attempts are invalid");
            return;
        }

        // Only initiator attempt is invlalid 
        if(initiatorAttempt == false){
            __setGameState(RPSGameState.WIN,_gameData.responder,"Initiator attempt invalid. Responder WON!");
            return;
        }
        
        // only responder attempt is invalid
        if(responderAttempt == false){
            __setGameState(RPSGameState.WIN,_gameData.initiator,"Responder attempt invalid. Initiator WON!");
            return;
        }

        //continue the game and identify the winner
        __setWinnerWithComment();
        
        
    }

    //
    function __setWinnerWithComment() private{

        address  winner = address(0);
        string memory comment = "";
        RPSGameState gameState = RPSGameState.WIN;
        // same selection
        if (_gameData.initiator_choice == _gameData.responder_choice) {
            comment = "DRAW. Responder and Initiator made the same choice.";
            gameState = RPSGameState.DRAW;
        }
        // Paper beats Rock
        else if (_gameData.initiator_choice == 2){ //Paper
            if (_gameData.responder_choice == 1){ // Rock
                winner = _gameData.initiator;
                comment = "Paper beats Rock.";
            }
            else{
                winner = _gameData.responder;
                comment = "Scissors beats Paper!";
            }

        }
        //Rock beats Scissors
        else if (_gameData.initiator_choice == 1){ //Rock
            if (_gameData.responder_choice == 3){ // Scissors
                winner = _gameData.initiator;
                comment = "Rock beats Scissors.";
            }
            else{
                winner = _gameData.responder;
                comment = "Paper beats Rock.";
            }

        }
        
        // Scissors beat Paper
        else if (_gameData.initiator_choice == 3){ //Scissors
            if (_gameData.responder_choice == 2){ // Paper
                winner = _gameData.initiator;
                comment = "Scissors beats Paper.";
            }
            else{
                winner = _gameData.responder;
                comment = "Rock beats Scissors.";
            }

        }

         __setGameState(gameState,winner,comment);
    }

    function __setGameState(RPSGameState  state, address  winner, string memory comment) private{
            _gameData.state = state;
            _gameData.winner = winner;
            _gameData.comment = comment;
    }

    

    // Returns the address of the winner, GameState (2 for WIN, 3 for DRAW), and the comment
    function getResult() public view 
    gameResultReady()
    returns (address, RPSGameState, string memory, uint8, uint8) {
        return (_gameData.winner, _gameData.state, _gameData.comment, _gameData.initiator_choice,_gameData.responder_choice);
    } 

    function __getGameState() public view returns (RPSGameState){
        return _gameData.state;
    } 
    
}

contract RPSServer {
    
   
    // Mapping for each game instance with the first address being the initiator and internal key aaddress being the responder
    mapping(address => mapping(address => RPSGame)) _gameList;

    modifier validAddress(address inputAddress) {
        require (inputAddress != address(0), "Input address can't be Zero address");
        require (msg.sender != inputAddress, "You can't compete with yourself");
        _;
    }

    modifier gameInValidState(address _initiator, address _responder, RPSGame.RPSGameState _state){
        RPSGame game = _gameList[_initiator][_responder];
        // enum RPSGameState {INITIATED, RESPONDED, WIN, DRAW}
        require(game.__getGameState() == _state, "Game state does not match");
        _;
    }
    
    modifier validChoice(address _initiator, address _responder, uint8 _choice)
    {
        RPSGame game = _gameList[_initiator][_responder];
        require(game.isValidChoice(_choice),string(abi.encodePacked(" Invalid Selection.", ' ', game.getInvalidChoiceMessage())));
        _;
    }

    // Initiator sets up the game and stores its hashed choice in the creation itself. New game created and appropriate function called    
    function initiateGame(address _responder, bytes32 _initiator_hash) public validAddress(_responder){
        RPSGame game = new RPSGame(msg.sender, _responder, _initiator_hash);
        _gameList[msg.sender][_responder] = game;
    }

    // Responder stores their hashed choice. Appropriate RPSGame function called   
    function respond(address _initiator, bytes32 _responder_hash) public validAddress(_initiator) gameInValidState(_initiator, msg.sender,RPSGame.RPSGameState.INITIATED) {
        RPSGame game = _gameList[_initiator][msg.sender];
        game.addResponse(_responder_hash);
    }

    // Initiator adds raw choice number and random string. Appropriate RPSGame function called  
    function addInitiatorChoice(address _responder, uint8 _choice, string memory _randomStr) public 
        validAddress(_responder) 
        gameInValidState(msg.sender,_responder,RPSGame.RPSGameState.RESPONDED)  
        validChoice(msg.sender,_responder,_choice)
        returns (bool) {
        RPSGame game = _gameList[msg.sender][_responder];
        return game.addInitiatorChoice(_choice, _randomStr);
    }

    // Responder adds raw choice number and random string. Appropriate RPSGame function called
    function addResponderChoice(address _initiator, uint8 _choice, string memory _randomStr) public 
    validAddress(_initiator) 
    gameInValidState(_initiator, msg.sender,RPSGame.RPSGameState.RESPONDED) 
    validChoice(_initiator,msg.sender,_choice)
    returns (bool) {
        RPSGame game = _gameList[_initiator][msg.sender];
        return game.addResponderChoice(_choice, _randomStr);
    }
    
    // Result details request by the initiator
    function getInitiatorResult(address _responder) public view 
    validAddress(_responder) 
    returns (address, RPSGame.RPSGameState, string memory,uint8,uint8) {
        RPSGame game = _gameList[msg.sender][_responder];
        return game.getResult();
    }

    // Result details request by the responder
    function getResponderResult(address _initiator) public view 
    validAddress(_initiator) 
    returns (address, RPSGame.RPSGameState, string memory,uint8,uint8) {
        RPSGame game = _gameList[_initiator][msg.sender];
        return game.getResult();
    }
}
