// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {SrjStableCoin} from "./token/SrjStableCoin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract SSCEngine {
    error SSCEngine__TokenAddressAndPriceFeedMustBeSame();
    error SSCEngine__AmountMustBeGreaterThanZero();
    error SSCEngine__PriceFeedNotAllowded();
    error SSCEngine__Transferfailed();
    error SSCEngine__BadHealthFactor();
    error SSCEngine__MintingFailed();
    error SSCEngine__TransferFailed();
    error SSCEngine__HealthFactorOk();
    error SSCEngine__HealthFactorNotImproved();

    /**
     * State Variables
     */
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HELATH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10;

    address[] private s_collateralTokens;
    SrjStableCoin private immutable i_ssc;

    mapping(address token => address priceFeed) private s_tokenToPriceFeed;
    mapping(address user => mapping(address token => uint256 balance)) s_usersCollateralInfo;
    mapping(address user => uint256 collateralAmt) s_mintedSSC;

    /**
     * Modifiers
     */
    modifier isValidToken(address _token) {
        if (s_tokenToPriceFeed[_token] == address(0)) {
            revert SSCEngine__PriceFeedNotAllowded();
        }
        _;
    }

    modifier isMoreThanZero(uint256 _amount) {
        if (_amount <= 0) {
            revert SSCEngine__AmountMustBeGreaterThanZero();
        }
        _;
    }

    constructor(
        address[] memory tokens,
        address[] memory priceFeeds,
        address ssc
    ) {
        if (tokens.length != priceFeeds.length) {
            revert SSCEngine__TokenAddressAndPriceFeedMustBeSame();
        }

        for (uint index = 0; index < tokens.length; index++) {
            address tokenAddress = tokens[index];
            address priceFeedAddress = priceFeeds[index];
            s_tokenToPriceFeed[tokenAddress] = priceFeedAddress;
            s_collateralTokens.push(tokenAddress);
        }

        i_ssc = SrjStableCoin(ssc);
    }

    /**
     *
     * @param _tokenAddress address of the collateral like WETH EBTC
     * @param _amount amount of collateral to be deposited
     * @dev function used to deposite collateral (WETH, WBTC)
     */
    function depositCollateral(
        address _tokenAddress,
        uint256 _amount
    ) public isMoreThanZero(_amount) isValidToken(_tokenAddress) {
        s_usersCollateralInfo[msg.sender][_tokenAddress] += _amount;

        bool success = IERC20(_tokenAddress).transferFrom(
            msg.sender,
            address(this),
            _amount
        );

        if (!success) {
            revert SSCEngine__Transferfailed();
        }
    }

    /**
     *
     * @param _tokenAddress address of the collateral like WETH EBTC
     * @param _amountToDeposit amout of collateral to be deposited
     * @param _amountSscToMint amout of SSC to be minted
     * @dev function to deposite collateral and mint some SSC as well
     */
    function depositAndMintSsc(
        address _tokenAddress,
        uint256 _amountToDeposit,
        uint256 _amountSscToMint
    ) public {
        depositCollateral(_tokenAddress, _amountToDeposit);
        mintSsc(_amountSscToMint);
    }

    /**
     *
     * @param _tokenAddress address of the collateral like WETH EBTC
     * @param _amount amount of collateral to be deposited
     * @dev function to redeem collateral if it is not impacting helath factor
     */
    function redeemCollateral(
        address _tokenAddress,
        uint256 _amount
    ) public isMoreThanZero(_amount) {
        _redeemCollateral(_tokenAddress, msg.sender, msg.sender, _amount);
        _revertIfBadHealthFactor(msg.sender);
    }

    /**
     *
     * @param _tokenAddress address of the collateral like WETH EBTC
     * @param _amountToRedeem amount of collateral to be redeem
     * @param _amountSscToBurn amount of SSC to be burn
     * @dev function to burn SSC and redeem collateral
     */
    function redeemCollateralForSsc(
        address _tokenAddress,
        uint256 _amountToRedeem,
        uint256 _amountSscToBurn
    ) public {
        burnSsc(_amountSscToBurn);
        redeemCollateral(_tokenAddress, _amountToRedeem);
    }

    /**
     *
     * @param _amountToMint amount of SSC to mint
     * @dev function to mint SSC
     */
    function mintSsc(uint256 _amountToMint) public {
        s_mintedSSC[msg.sender] += _amountToMint;

        _revertIfBadHealthFactor(msg.sender);

        bool success = i_ssc.mint(msg.sender, _amountToMint);
        if (!success) {
            revert SSCEngine__MintingFailed();
        }
    }

    /**
     *
     * @param _amountToBurn amount of SSC to burn
     * @dev function to burn SSC
     */
    function burnSsc(
        uint256 _amountToBurn
    ) public isMoreThanZero(_amountToBurn) {
        _burnSsc(msg.sender, msg.sender, _amountToBurn);
    }

    /**
     *
     * @param _collateral address of collateral
     * @param _user address of user whos account to be liquidated
     * @param _debtToCover amount of debt to cover
     * @dev function to liquidate account and redeem its collateral
     */
    function liquidate(
        address _collateral,
        address _user,
        uint256 _debtToCover
    ) public {
        uint256 startingUserHealthFactor = getHelathFactor(_user);
        if (startingUserHealthFactor > MIN_HELATH_FACTOR) {
            revert SSCEngine__HealthFactorOk();
        }

        uint256 tokenAmountToCover = getTokenAmountFromUsd(
            _collateral,
            _debtToCover
        );

        uint256 liquidationBonus = (tokenAmountToCover * LIQUIDATION_BONUS) /
            LIQUIDATION_PRECISION;

        _redeemCollateral(
            _collateral,
            _user,
            msg.sender,
            tokenAmountToCover + liquidationBonus
        );
        _burnSsc(msg.sender, _user, _debtToCover);

        uint256 endingUserHelathFactor = getHelathFactor(_user);

        if (endingUserHelathFactor <= startingUserHealthFactor) {
            revert SSCEngine__HealthFactorNotImproved();
        }

        _revertIfBadHealthFactor(msg.sender);
    }

    /**
     *
     * @param _collateralAmountInUsd amount of collateral in USD
     * @param _mintedAmount amount of SSC minted
     * @dev function to calculate helath factor based on collaterl Amount and SSC amount
     */
    function calculateHelathFactor(
        uint256 _collateralAmountInUsd,
        uint256 _mintedAmount
    ) public pure returns (uint256 helathfactor) {
        helathfactor = _calculateHealthFactor(
            _collateralAmountInUsd,
            _mintedAmount
        );
    }

    /**
     *
     * @param _token address of token / collateral
     * @param _amountInUsd amount in USD
     * @dev function to get token amount for given USD amount based on current token value
     */
    function getTokenAmountFromUsd(
        address _token,
        uint256 _amountInUsd
    ) public view isValidToken(_token) returns (uint256 tokenAmount) {
        address priceFeedAddress = s_tokenToPriceFeed[_token];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            priceFeedAddress
        );

        (, int price, , , ) = priceFeed.latestRoundData();

        tokenAmount =
            (_amountInUsd * PRECISION) /
            (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    /**
     *
     * @param _token address of token / collateral
     * @param _amount amount of token
     * @dev function to get USD price of given token amount
     */
    function getUsdAmountFromToken(
        address _token,
        uint256 _amount
    ) public view returns (uint256 usdAmount) {
        address priceFeedAddress = s_tokenToPriceFeed[_token];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            priceFeedAddress
        );

        (, int price, , , ) = priceFeed.latestRoundData();

        usdAmount =
            (_amount * (uint256(price) * ADDITIONAL_FEED_PRECISION)) /
            PRECISION;
    }

    /**
     *
     * @param _user address of user
     * @dev function to get curent USD values of collateral
     */
    function getCollateralAmountInUsd(
        address _user
    ) public view returns (uint256 collateralAmountInUsd) {
        for (uint i = 0; i < s_collateralTokens.length; i++) {
            address collateralToken = s_collateralTokens[i];
            uint256 collateralValue = s_usersCollateralInfo[_user][
                collateralToken
            ];
            collateralAmountInUsd += getUsdAmountFromToken(
                collateralToken,
                collateralValue
            );
        }
    }

    /**
     *
     * @param _user address of user
     * @dev function to get health factor of given user
     */
    function getHelathFactor(
        address _user
    ) public view returns (uint256 healthFactor) {
        uint256 mintedAmount = s_mintedSSC[_user];
        uint256 collateralAmountInUsd = getCollateralAmountInUsd(_user);

        uint256 adjustedCollateralAmountInUsd = (collateralAmountInUsd *
            LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

        healthFactor =
            (adjustedCollateralAmountInUsd * PRECISION) /
            mintedAmount;
    }

    /**
     * Internal Functions
     */

    function _revertIfBadHealthFactor(address _user) internal view {
        uint256 healthFactor = getHelathFactor(_user);

        if (healthFactor < MIN_HELATH_FACTOR) {
            revert SSCEngine__BadHealthFactor();
        }
    }

    function _calculateHealthFactor(
        uint256 collateralAmountInUsd,
        uint256 mintedAmount
    ) internal pure returns (uint256 healthFactor) {
        uint256 adjustedCollateralAmountInUsd = (collateralAmountInUsd *
            LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

        healthFactor =
            (adjustedCollateralAmountInUsd * PRECISION) /
            mintedAmount;
    }

    function _redeemCollateral(
        address _tokenCollateralAddress,
        address _from,
        address _to,
        uint256 _amountCollateral
    ) private {
        s_usersCollateralInfo[_from][
            _tokenCollateralAddress
        ] -= _amountCollateral;

        bool success = IERC20(_tokenCollateralAddress).transfer(
            _to,
            _amountCollateral
        );

        if (!success) {
            revert SSCEngine__TransferFailed();
        }
    }

    function _burnSsc(
        address _from,
        address _onBehalfOf,
        uint256 _amountToBurn
    ) private {
        s_mintedSSC[_onBehalfOf] -= _amountToBurn;
        bool success = i_ssc.transferFrom(_from, address(this), _amountToBurn);
        if (!success) {
            revert SSCEngine__TransferFailed();
        }
        i_ssc.burn(_amountToBurn);
    }

    /**
     * external View / pure functions
     */
    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getTokenPriceFeed(address token) external view returns (address) {
        return s_tokenToPriceFeed[token];
    }

    function getSscAddress() external view returns (address) {
        return address(i_ssc);
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationPrecision() external pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HELATH_FACTOR;
    }

    function getLiquidationBonus() external pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    function getCollateralBalanceOfUser(
        address user,
        address token
    ) external view returns (uint256) {
        return s_usersCollateralInfo[user][token];
    }

    function getMintedSscCount(address user) external view returns (uint256) {
        return s_mintedSSC[user];
    }
}
