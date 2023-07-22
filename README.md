# srj-stable-coin (SSC)

Srj stablecoin project built on the Ethereum blockchain using the Hardhat development environment. The stablecoin aims to provide a stable value pegged to USD ($), making it suitable for various use cases in the blockchain ecosystem. You can put ETH/BTC as collateral to mint SSC.

## Features

-   Stability:
    -   Value of SSC will always depend on USD
    -   only 50% of collateral value can be used to mint SSC
-   Decentralization:
    -   No central Authority to mint, minting is completely depending on the collateral value
-   Liquidation:
    -   anyone can liquidate under collateralized account by paying minted amount for that collateral
    -   liquidation Benefit: liquidator will get 10% bonus
-   Transparency

## Getting Started

### Prerequisites

-   Node.js: Install the latest version of Node.js from [Node.js official website](https://nodejs.org/).
-   Yarn

### Installation

1. Clone the repository:

```bash
git clone https://github.com/surajgjadhav/srj-stable-coin.git
cd srj-stable-coin
```

2. Install project dependencies:

```bash
yarn
```

### Usage

1. Compile smart contracts:

```bash
yarn hardhat compile
```

2. Run tests:

```bash
yarn hardhat test
```

3. Run Coverage:

```bash
yarn hardhat coverage
```

4. Deploy contracts to the Ethereum network:

```bash
yarn hardhat deploy
```
