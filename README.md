# Climate-Disaster-Insurance-Contract 🌪️🛡️

Minimal on-chain parametric insurance for climate disasters on Stacks. Users buy time-bound coverage for a region; approved oracles report disasters; eligible policyholders trigger payouts held in the contract.

## Features
- Admin-managed oracle allowlist
- Buy policies with STX; premiums credited to reserves
- Oracle disaster reporting by region
- Self-service claim trigger within coverage window
- Reserve funding by admin
- Policy extension and payout update (admin-controlled)

## Contract
- Path: `contracts/climate-disaster-insurance.clar`
- Language: Clarity

## Quick start
1) Install Clarinet: https://docs.hiro.so/stacks/clarinet
2) Check compilation:
   - `clarinet check`
3) Normalize line endings (Windows PowerShell):
   - `(Get-Content "contracts/climate-disaster-insurance.clar" -Raw).Replace("`r`n", "`n") | Set-Content "contracts/climate-disaster-insurance.clar" -NoNewline`

## Usage (Devnet)
- Start console: `clarinet console`
- Replace `SPXXXX...` with real principals.

### Admin setup
```
(contract-call? .climate-disaster-insurance add-oracle 'SPXXXX...)
(contract-call? .climate-disaster-insurance fund-reserve u1000000)
```

### Buy policy
```
(contract-call? .climate-disaster-insurance buy-policy u1 u144 u100000)
```

### Report disaster (oracle)
```
(contract-call? .climate-disaster-insurance report-disaster u1)
```

### Trigger claim (policyholder)
```
(contract-call? .climate-disaster-insurance trigger-claim u1)
```

### Read-only helpers
```
(contract-call? .climate-disaster-insurance get-reserves)
(contract-call? .climate-disaster-insurance get-policy u1)
(contract-call? .climate-disaster-insurance can-claim u1)
```

## Notes
- Uses `stacks-block-height` and avoids `block-height`
- Uses simple premium rule: payout / 10, minimum 1 µSTX
- All amounts are in µSTX

## Testing
- `npm install`
- `npm test`

## Deployment
- Integrate with your preferred deployment flow; this repo focuses on contract logic and local compilation.
