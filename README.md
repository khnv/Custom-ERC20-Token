# MyToken - Advanced ERC20 Access Control

A feature-rich ERC20 token implementation built with Solidity and Foundry, featuring role-based access control, transfer fees, blacklist functionality, and pausable operations.

## 📋 Contract Addresses

### Sepolia Testnet
- **MyToken**: [`0x36330bfB3Ea893CbDCaB077A5ef8aCD7C0fb3430`](https://sepolia.etherscan.io/address/0x36330bfB3Ea893CbDCaB077A5ef8aCD7C0fb3430)
  - **Name**: MyToken
  - **Symbol**: MTK
  - **Transfer Fee**: 2.5% (250 basis points)
  - **Status**: Deployed ✅

## Features

### Core Functionality
- **Standard ERC20 Compliance** - Full ERC20 token implementation
- **Role-Based Access Control** - Granular permissions for different operations
- **Transfer Fee System** - Configurable percentage-based transfer fees
- **Blacklist Management** - Prevent transfers from/to specific addresses
- **Pausable Operations** - Emergency pause/unpause functionality
- **Comprehensive Testing** - 100% test coverage with 60+ test cases

### Security Features
- **AccessControl Integration** - Secure role management using OpenZeppelin
- **Maximum Fee Limits** - Prevents excessive fee percentages (max 10%)
- **Input Validation** - Comprehensive parameter validation
- **Event Logging** - Full audit trail for all operations

## Architecture

### Roles
- **DEFAULT_ADMIN_ROLE** - Super admin with all permissions
- **ADMIN_ROLE** - Can manage other roles (except DEFAULT_ADMIN_ROLE)
- **MINTER_ROLE** - Can mint new tokens
- **BURNER_ROLE** - Can burn tokens
- **BLACKLIST_MANAGER_ROLE** - Can manage blacklist
- **PAUSER_ROLE** - Can pause/unpause the contract
- **FEE_MANAGER_ROLE** - Can manage transfer fees

### Key Components
```
MyToken
├── ERC20 (OpenZeppelin)
├── ERC20Pausable (OpenZeppelin)
├── AccessControl (OpenZeppelin)
├── Transfer Fee System
├── Blacklist Management
└── Role Management
```

## Prerequisites

- [Foundry](https://getfoundry.sh/) - Ethereum development toolkit
- [Git](https://git-scm.com/) - Version control
- [Node.js](https://nodejs.org/) (optional) - For additional tooling

## Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/khnv/MyToken.git
   cd MyToken
   ```

2. **Install dependencies**
   ```bash
   forge install
   ```

3. **Build the project**
   ```bash
   forge build
   ```

## Testing

### Run all tests
```bash
forge test
```

### Run tests with coverage
```bash
forge test --coverage
```

### Run specific test
```bash
forge test --match-test test_mint
```

### Run tests with verbose output
```bash
forge test -vvv
```

## Deployment

### Local Development
```bash
# Start local blockchain
anvil

# Deploy to local network
forge script script/Token.s.sol --rpc-url http://localhost:8545 --private-key $PRIVATE_KEY --broadcast
```

### Testnet Deployment
```bash
# Deploy to Sepolia
forge script script/Token.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify
```

### Mainnet Deployment
```bash
# Deploy to Ethereum mainnet
forge script script/Token.s.sol --rpc-url $MAINNET_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify
```

## Usage

### Contract Deployment
```solidity
// Deploy with 2.5% transfer fee
MyToken token = new MyToken(
    "MyToken",           // name
    "MTK",              // symbol
    250,                // fee percentage (2.5% = 250 basis points)
    feeCollectorAddress // address to receive fees
);
```

### Basic Operations

#### Minting Tokens
```solidity
// Mint to self (requires MINTER_ROLE)
token.mint(1000 * 10**18);

// Mint to specific address (requires MINTER_ROLE)
token.mintTo(recipient, 1000 * 10**18);
```

#### Burning Tokens
```solidity
// Burn from self (requires BURNER_ROLE)
token.burn(100 * 10**18);

// Burn from specific address (requires BURNER_ROLE)
token.burnFrom(address, 100 * 10**18);
```

#### Transfer with Fees
```solidity
// Transfer tokens (fees automatically deducted)
token.transfer(recipient, 1000 * 10**18);
// Recipient gets: 975 tokens (1000 - 2.5% fee)
// Fee collector gets: 25 tokens
```

#### Blacklist Management
```solidity
// Add to blacklist (requires BLACKLIST_MANAGER_ROLE)
token.addToBlacklist(address);

// Remove from blacklist (requires BLACKLIST_MANAGER_ROLE)
token.removeFromBlacklist(address);

// Check if blacklisted
bool isBlacklisted = token.isBlacklisted(address);
```

#### Pause/Unpause
```solidity
// Pause all transfers (requires PAUSER_ROLE)
token.pause();

// Unpause all transfers (requires PAUSER_ROLE)
token.unpause();
```

#### Fee Management
```solidity
// Update transfer fee (requires FEE_MANAGER_ROLE)
token.setTransferFeePercentage(500); // 5%

// Update fee collector (requires FEE_MANAGER_ROLE)
token.setFeeCollector(newCollector);

// Calculate fees
(uint256 fee, uint256 net) = token.calculateTransferFee(1000 * 10**18);
```

#### Role Management
```solidity
// Grant roles (requires ADMIN_ROLE)
token.grantMinterRole(address);
token.grantBurnerRole(address);
token.grantBlacklistManagerRole(address);
token.grantPauserRole(address);
token.grantFeeManagerRole(address);

// Revoke roles (requires ADMIN_ROLE)
token.revokeMinterRole(address);
token.revokeBurnerRole(address);
// ... etc
```

## Configuration

### Environment Variables
Create a `.env` file:
```env
PRIVATE_KEY=your_private_key_here
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/your_project_id
MAINNET_RPC_URL=https://mainnet.infura.io/v3/your_project_id
ETHERSCAN_API_KEY=your_etherscan_api_key
```

### Foundry Configuration
The project uses the default Foundry configuration. Key settings in `foundry.toml`:
```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc = "0.8.28"
optimizer = true
optimizer_runs = 200
```

## Test Coverage

The project maintains 100% test coverage across all functions:

- ✅ **60+ Test Cases** covering all functionality
- ✅ **Constructor Tests** - Parameter validation and initialization
- ✅ **Minting Tests** - Role-based access and edge cases
- ✅ **Burning Tests** - Role-based access and insufficient balance
- ✅ **Transfer Tests** - Fee calculation, blacklist, and pause logic
- ✅ **Role Management Tests** - Grant/revoke operations
- ✅ **Blacklist Tests** - Add/remove and transfer restrictions
- ✅ **Pause Tests** - Pause/unpause functionality
- ✅ **Fee Management Tests** - Fee calculation and updates
- ✅ **Event Tests** - All custom event emissions
- ✅ **Integration Tests** - Complete workflow scenarios
- ✅ **Edge Case Tests** - Zero amounts, self-transfers, etc.

## Security Considerations

### Access Control
- All sensitive operations require specific roles
- Role hierarchy prevents privilege escalation
- DEFAULT_ADMIN_ROLE has ultimate control

### Fee System
- Maximum fee limit prevents abuse (10%)
- Fee calculations use basis points for precision
- No fees on minting/burning operations

### Blacklist System
- Prevents transfers from/to blacklisted addresses
- Only BLACKLIST_MANAGER_ROLE can modify blacklist
- Events logged for all blacklist operations

### Pause Mechanism
- Emergency pause functionality
- Only PAUSER_ROLE can pause/unpause
- Prevents all transfers when paused


## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines
- Maintain 100% test coverage
- Follow Solidity best practices
- Add comprehensive documentation
- Include gas optimization considerations

## Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/MyToken/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/MyToken/discussions)
- **Documentation**: [Wiki](https://github.com/yourusername/MyToken/wiki)

## Acknowledgments

- [OpenZeppelin](https://openzeppelin.com/) - For secure contract libraries
- [Foundry](https://getfoundry.sh/) - For the development framework
- [Ethereum](https://ethereum.org/) - For the blockchain platform

---

** Disclaimer**: This software is provided "as is" without warranty. Use at your own risk. Always audit smart contracts before deploying to mainnet.
