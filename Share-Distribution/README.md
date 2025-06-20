# Stakeholder Profit Distribution Smart Contract

A comprehensive Clarity smart contract for managing equity-based profit sharing among multiple stakeholders on the Stacks blockchain. This contract enables secure, transparent, and automated distribution of profits based on predefined ownership percentages.

## Features

- **Percentage-based Ownership**: Stakeholder management with basis points precision (0.01% increments)
- **Multi-round Distribution**: Support for multiple profit distribution rounds with comprehensive tracking
- **Claim System**: Secure profit claiming mechanism with duplicate claim prevention
- **Access Control**: Blacklist management and deployer-only administrative functions
- **Emergency Controls**: Emergency withdrawal capabilities for contract deployer
- **Comprehensive Validation**: Extensive input validation and security checks

## Contract Architecture

### Key Components

1. **Stakeholder Management**: Register, update, and remove stakeholders with ownership percentages
2. **Distribution Rounds**: Activate/deactivate distribution periods for profit sharing
3. **Contribution System**: Accept STX contributions during active distribution rounds
4. **Profit Distribution**: Calculate and distribute profits based on ownership stakes
5. **Claim Mechanism**: Allow stakeholders to claim their allocated profits
6. **Blacklist System**: Manage access control for problematic stakeholders

## Installation & Deployment

### Prerequisites
- Stacks CLI installed
- Access to a Stacks testnet or mainnet node
- STX tokens for deployment and testing

### Deployment Steps

1. **Deploy the contract**:
   ```bash
   stx deploy_contract stakeholder-profit-distribution contract.clar
   ```

2. **Initialize the contract**:
   ```clarity
   (contract-call? .stakeholder-profit-distribution initialize-profit-distribution-contract u1000000)
   ```
   *Note: The parameter represents minimum stake amount in microSTX (1 STX = 1,000,000 microSTX)*

## Usage Guide

### 1. Contract Initialization

The contract must be initialized before use:

```clarity
;; Initialize with minimum stake of 1 STX (1,000,000 microSTX)
(contract-call? .stakeholder-profit-distribution initialize-profit-distribution-contract u1000000)
```

### 2. Stakeholder Management

#### Register New Stakeholder
```clarity
;; Register stakeholder with 15% ownership (1500 basis points)
(contract-call? .stakeholder-profit-distribution register-new-stakeholder 'SP1EXAMPLE... u1500)
```

#### Update Stakeholder Ownership
```clarity
;; Update stakeholder to 20% ownership (2000 basis points)
(contract-call? .stakeholder-profit-distribution update-stakeholder-ownership-percentage 'SP1EXAMPLE... u2000)
```

#### Remove Stakeholder
```clarity
(contract-call? .stakeholder-profit-distribution remove-stakeholder-registration 'SP1EXAMPLE...)
```

### 3. Distribution Round Management

#### Activate Distribution Round
```clarity
(contract-call? .stakeholder-profit-distribution activate-new-distribution-round)
```

#### Accept Contributions
```clarity
;; Contribute specific amount
(contract-call? .stakeholder-profit-distribution contribute-specific-stx-amount u5000000)

;; Contribute all available STX
(contract-call? .stakeholder-profit-distribution contribute-all-available-stx)
```

#### Execute Profit Distribution
```clarity
(contract-call? .stakeholder-profit-distribution execute-profit-distribution)
```

### 4. Claiming Profits

Stakeholders can claim their profits from completed distribution rounds:

```clarity
;; Claim profits from distribution round 1
(contract-call? .stakeholder-profit-distribution claim-stakeholder-profits u1)
```

### 5. Blacklist Management

#### Add to Blacklist
```clarity
(contract-call? .stakeholder-profit-distribution add-stakeholder-to-blacklist 'SP1PROBLEMATIC...)
```

#### Remove from Blacklist
```clarity
(contract-call? .stakeholder-profit-distribution remove-stakeholder-from-blacklist 'SP1PROBLEMATIC...)
```

## Read-Only Functions

### Query Stakeholder Information
```clarity
;; Get stakeholder ownership details
(contract-call? .stakeholder-profit-distribution get-stakeholder-ownership-details 'SP1EXAMPLE...)

;; Get accumulated balance
(contract-call? .stakeholder-profit-distribution get-stakeholder-accumulated-balance 'SP1EXAMPLE...)

;; Check blacklist status
(contract-call? .stakeholder-profit-distribution check-stakeholder-blacklist-status 'SP1EXAMPLE...)
```

### Query Distribution Information
```clarity
;; Get distribution round details
(contract-call? .stakeholder-profit-distribution get-distribution-round-details u1)

;; Check if profits were claimed
(contract-call? .stakeholder-profit-distribution check-profits-claimed-status u1 'SP1EXAMPLE...)

;; Calculate claimable amount
(contract-call? .stakeholder-profit-distribution calculate-claimable-profit-amount u1 'SP1EXAMPLE...)
```

### Contract Status
```clarity
;; Get comprehensive contract status
(contract-call? .stakeholder-profit-distribution get-comprehensive-contract-status)
```

## Error Codes

### Access Control (100-199)
- `u100`: Unauthorized access
- `u101`: Blacklisted stakeholder

### Initialization (200-299)
- `u200`: Contract already initialized
- `u201`: Contract not initialized

### Validation (300-399)
- `u300`: Invalid percentage value
- `u301`: Invalid minimum stake
- `u302`: Invalid principal address
- `u303`: Zero amount provided

### Business Logic (400-499)
- `u400`: Percentage limit exceeded
- `u401`: Stakeholder not found
- `u402`: No ownership stake
- `u403`: Distribution round active
- `u404`: Distribution round inactive
- `u405`: Profits already claimed

### Financial (500-599)
- `u500`: Insufficient contract balance
- `u501`: Transfer operation failed

## Security Considerations

### Access Control
- Only the contract deployer can perform administrative functions
- Stakeholders cannot self-register or modify their own stakes
- Blacklisted stakeholders cannot claim profits

### Input Validation
- All percentage values are validated against maximum bounds (10,000 basis points = 100%)
- Principal addresses are validated to prevent self-assignment
- Amounts are checked for zero values

### State Management
- Distribution rounds must be properly activated/deactivated
- Claims are tracked to prevent double-claiming
- Total percentage allocation is monitored to prevent over-allocation

### Financial Security
- Transfer operations include proper error handling
- Emergency withdrawal function available to deployer
- Contract balance checks before distributions

## Example Workflow

```clarity
;; 1. Deploy and initialize contract
(contract-call? .stakeholder-profit-distribution initialize-profit-distribution-contract u1000000)

;; 2. Register stakeholders
(contract-call? .stakeholder-profit-distribution register-new-stakeholder 'SP1ALICE... u3000) ;; 30%
(contract-call? .stakeholder-profit-distribution register-new-stakeholder 'SP1BOB... u2000)   ;; 20%
(contract-call? .stakeholder-profit-distribution register-new-stakeholder 'SP1CAROL... u5000) ;; 50%

;; 3. Start distribution round
(contract-call? .stakeholder-profit-distribution activate-new-distribution-round)

;; 4. Accept contributions (from various sources)
(contract-call? .stakeholder-profit-distribution contribute-specific-stx-amount u10000000) ;; 10 STX

;; 5. Execute distribution
(contract-call? .stakeholder-profit-distribution execute-profit-distribution)

;; 6. Stakeholders claim their profits
;; Alice claims: 30% of 10 STX = 3 STX
(contract-call? .stakeholder-profit-distribution claim-stakeholder-profits u1)
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add comprehensive tests for new functionality
4. Ensure all security checks pass
5. Submit a pull request with detailed description