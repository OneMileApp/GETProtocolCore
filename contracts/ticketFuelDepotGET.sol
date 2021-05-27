pragma solidity ^0.6.2;
pragma experimental ABIEncoderV2;

import "./utils/Initializable.sol";

import "./interfaces/IERC20.sol";
import "./interfaces/IGETAccessControl.sol";
import "./interfaces/IEconomicsGET.sol";
import "./utils/SafeMathUpgradeable.sol";

contract ticketFuelDepot is Initializable  {
    IGETAccessControl public GET_BOUNCER;
    IERC20 public FUELTOKEN;
    IEconomicsGET public ECONOMICS;

    using SafeMathUpgradeable for uint256;

    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");
    bytes32 public constant GET_ADMIN = keccak256("GET_ADMIN");
    bytes32 public constant GET_GOVERNANCE = keccak256("GET_GOVERNANCE");

    // Add uniswap logic to fetch price of pool
    // Requires Polygon uniswap pool to work, something for later
    // uint256 public priceGETETH;

    // address of the economics contract
    address private economicGETAddress;

    // total amount of GET that is held by all NFTs
    uint256 public balanceDepotTanks;

    // total amount of GET that has been collected by the depot
    uint256 public GETCollectedDepot;
    
    // address that will receive all the sweeped GET, either a contract (like feeCollector) or it could be 
    address public collectAddress;
    
    uint256 public priceGETUSD;

    // 
    uint256 public globalGET;

    // data struct that stores the amount of GET that is in the rucksack of an NFT
    // NFTINDEX 23111 => 33432 wei GET in tank etc
    // NFTINDEX 99122 => 943 wei GET in tank etc
    mapping (uint256 => uint256) private nftBackpackMap;

    // used to store if an NFT exsits
    mapping (uint256 => bool) private NFTIndexBool;

    event depotSwiped(
        uint256 totalAmountSwiped
    );

    event NewFeeCollecterAddressSet(
        address newCollectorAddress
    );

    event statechangeTaxed(
        uint256 nftIndex,
        uint256 GETTaxedAmount
    );

    event fuelAddressChanged(
        address newFuelAddress
    );

    event BackPackFueled(
        uint256 nftIndexFueled,
        uint256 amountToBackpack
    );

  function initialize_backpack(
        address address_bouncer,
        address fueltoken_address,
        address new_collectAddress,
        uint256 price_getusd
        ) public initializer {
            GET_BOUNCER = IGETAccessControl(address_bouncer);
            FUELTOKEN = IERC20(fueltoken_address);
            collectAddress = new_collectAddress;
            priceGETUSD = price_getusd;
        }

    function editFuelAddress(
        address newFuelToken
    ) external onlyAdmin {
        FUELTOKEN = IERC20(newFuelToken);

        emit fuelAddressChanged(
            newFuelToken
        );
    }
    
    /**
     * @dev Throws if called by any account other than the GET Protocol admin account.
     */
    modifier onlyAdmin() {
        require(
            GET_BOUNCER.hasRole(GET_ADMIN, msg.sender), "CALLER_NOT_ADMIN");
        _;
    }

    /**
     * @dev Throws if called by any account other than the GET Protocol admin account.
     */
    modifier onlyRelayer() {
        require(
            GET_BOUNCER.hasRole(RELAYER_ROLE, msg.sender), "CALLER_NOT_RELAYER");
        _;
    }

    /**
     * @dev Throws if called by any account other than a GET Protocol governance address.
     */
    modifier onlyGovernance() {
        require(
            GET_BOUNCER.hasRole(GET_GOVERNANCE, msg.sender), "CALLER_NOT_GOVERNANCE");
        _;
    }

    /**
     * @dev Throws if called by any account other than a GET Protocol governance address.
     */
    modifier onlyFactory() {
        require(
            GET_BOUNCER.hasRole(FACTORY_ROLE, msg.sender), "CALLER_NOT_FACTORY");
        _;
    }


    // /**
    //  * @dev Throws if called by a relayer/ticketeer that has not been registered.
    //  */
    // modifier onlyKnownRelayer() {
    //     require(
    //         relayerRegistry[msg.sender] == true, "RELAYER_NOT_REGISTERED");
    //     _;
    // }

    // GET PROTOCOL ADMINSTATION FUNCTIONS 

    /**
    @notice can only be called by goverance
    @param new_collectAddress EOA or contract address that is the only possibile recipient of the collected fees
    
     */
    function setCollectAddress(
        address new_collectAddress
    ) public onlyAdmin {

        collectAddress = new_collectAddress;

        emit NewFeeCollecterAddressSet(new_collectAddress);

    }

    // GET PROTOCOL FUNCTIONs

    /** moves all the collected tokens to the collectAddress
    @notice anybody can call this function
     */
    function swipeCollected() public {

        uint256 _depotbal = FUELTOKEN.balanceOf(address(this));

        require(_depotbal >= 0, "NOTHING_TO_SWIPE");

        require(
            FUELTOKEN.transfer(
                collectAddress,
                _depotbal),
            "SWIPE_FAILED"
        );

        // set balance to zero
        GETCollectedDepot = 0; 

        emit depotSwiped(_depotbal);

    }


    /** 
    @notice this function is called exclusively from the economics contract
    @param nftIndex index of the NFT that is being fueled up 
    @param amountBackpack amount of GET that needs to be charged onto the nftIndex in the depot
     */
    function fuelBackpack(
        uint256 nftIndex,
        uint256 amountBackpack
    ) external onlyFactory returns (bool) {

        require(nftBackpackMap[nftIndex] == 0, "NFT_ALREADY_FUELED");

        require(msg.sender == economicGETAddress, "SENDER_NOT_ECONOMIC");

        require(
            FUELTOKEN.transferFrom(
                economicGETAddress, 
                address(this),
                amountBackpack),
            "FUELBACKPACK_FAILED"
        );

        // add amount transferred to NFT
        nftBackpackMap[nftIndex] = amountBackpack;

        // register that the NFT exists
        NFTIndexBool[nftIndex] = true;

        // add amount transferred to total collected
        balanceDepotTanks += amountBackpack;

        emit BackPackFueled(
            nftIndex,
            amountBackpack
        );

        return true;

    }

    // /** set balance of NFT to zero
    // @param nftIndex unique Id of NFT that needs to have its balance wiped
    //  */
    // function whipeNFTTank(
    //     uint256 nftIndex
    // ) onlyAdmin {

    //     // fetch current balance
    //     uint256 _current = nftBackpackMap[nftIndex];

    //     // set NFT balance to 0
    //     nftBackpackMap[nftIndex] = 0;

    //     GETCollectedDepot += _deduct;        
    //     balanceDepotTanks -= _deduct;

    //     emit nftTankWiped(
    //         nftIndex,
    //         _current
    //     );

    // }

    // /**
    // @param nftIndex unique NFT id of the ticket that needs to be refueled
    // @param fuelAmount total balance of GET that is 'correct
    //  */
    // function topUpBackpackTo(  
    //     uint256 nftIndex,
    //     uint256 newBalance
    // ) public onlyAdmin {

    //     // what is the current balance

    //     // what is the difference between current and target

    //     // if is more than target, deduct and send to contract

    //     // else, less than target, add if possible from collected fee balances

    //     // return amount added or deducted in event

    // }

    // /** charges a certain cut of the backpack balance of an NFT and moves it to the collected state/address
    // @notice the charging of the GET is an internal accounting trick. In order to optimize for gas usage the sweeping of the collected GET will be done with the 'sweepGETToTreasury' function.
    // @param nftIndex unique indentifier of getNFT in the base contract
    // @param stateRate percentage that will be removed from the balance of the backpack
    //  */
    // function _taxBackpack(
    //     uint256 nftIndex,
    //     uint256 amountReduced
    // ) internal {

    //     // check if NFTIndex exists
    //     require(NFTIndexBool[nftIndex] == true, "NFT_DOESNT_EXIST");

    //     // check if there is any balance
    //     require(nftBackpackMap[nftIndex] > amountReduced, "BALANCE_TOO_LOW_BACKPACK");

    //     nftBackpackMap[nftIndex] -= amountReduced;

    //     // recalculate total
    //     GETCollectedDepot += amountReduced;

    // }

    /**
    @dev this function charges the globalGET rate as set in the contract
    @param nftIndex uniqe id of NFT that needs to be taxed
     */
    function chargeProtocolTax(
        uint256 nftIndex
    ) external onlyFactory returns(uint256) {

        // fetch balance of NFT by nftIndex
        uint256 _current = nftBackpackMap[nftIndex];

        // multiply tax rate by GET left in tank
        uint256 _deduct = _current.mul(globalGET);

        // TOOD look into if there is a better way
        nftBackpackMap[nftIndex] = _current - _deduct;
        
        // add to the total fee fount
        GETCollectedDepot += _deduct;
        
        // deduct from the total balance left
        balanceDepotTanks -= _deduct;

        emit statechangeTaxed(
            nftIndex,
            _deduct
        );

        return _deduct;

    }

}