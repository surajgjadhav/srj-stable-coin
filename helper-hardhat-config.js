const netWorkConfig = {
  11155111: {
    name: 'sepolia',
    ethUsdPriceFeedAddress: '0x694aa1769357215de4fac081bf1f309adc325306',
    btcUsdPriceFeedAddress: '0x1b44f3514812d835eb1bdb0acb33d3fa3351ee43',
    wethAddress: '0xdd13E55209Fd76AfE204dBda4007C227904f0a81',
    wbtcAddress: '0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063',
  },
};

const developmentChains = ['hardhat', 'localhost'];
const DECIMALS = 8;
const ETH_USD_PRICE = 200000000000;
const BTC_USD_PRICE = 100000000000;
const INITIAL_BALANCE = 100000000000;

module.exports = {
  netWorkConfig,
  developmentChains,
  DECIMALS,
  ETH_USD_PRICE,
  BTC_USD_PRICE,
  INITIAL_BALANCE,
};
