# Asset Classification System — Technical Design

## 1. Design Philosophy

This system models **every thing of value** a household owns or uses, using **multi-dimensional tagging** instead of rigid taxonomies. Each asset carries independent attributes that describe its nature, lifecycle, liquidity, and utility. This enables FIRE-specific queries like:

- "What is my total liquid net worth right now?"
- "What recurring expenses drain my savings rate?"
- "Which depreciating assets should I stop buying?"
- "Am I insured against the right risks?"

---

## 2. Multi-Dimensional Classification

Instead of a single category tree, every asset is described by **four independent dimensions**:

```
┌─────────────────────────────────────────────────────┐
│                     ASSET                           │
│                                                     │
│  ┌───────────┐ ┌───────────┐ ┌──────────┐ ┌──────┐ │
│  │  Nature   │ │  Utility  │ │Ownership │ │Liqui-│ │
│  │           │ │           │ │          │ │dity  │ │
│  └───────────┘ └───────────┘ └──────────┘ └──────┘ │
└─────────────────────────────────────────────────────┘
```

### 2.1 Nature — What it fundamentally is

| Value         | Examples                          |
|---------------|-----------------------------------|
| `tangible`    | Car, house, furniture, laptop     |
| `digital`     | Crypto wallet, domain, software   |
| `financial`   | Stock, fund, bond, bank account   |
| `intangible`  | Insurance policy, warranty, IP    |
| `service`     | Netflix, gym, cloud hosting       |

### 2.2 Utility — What role it plays in your life

| Value         | Examples                              |
|---------------|---------------------------------------|
| `productive`  | Rental property, business equipment   |
| `consumable`  | Tissues, food, hygiene products       |
| `protective`  | Insurance, emergency fund             |
| `speculative` | Crypto, collectibles, options         |
| `lifestyle`   | TV, furniture, hobbies                |
| `essential`   | Primary home, primary car             |

### 2.3 Ownership — How you hold it

| Value         | Examples                                  |
|---------------|-------------------------------------------|
| `owned`       | Paid-off house, bought laptop             |
| `mortgaged`   | House with mortgage, financed car         |
| `leased`      | Leased vehicle, rented apartment          |
| `subscribed`  | SaaS, streaming, gym membership           |
| `licensed`    | Software license, domain registration     |
| `custodied`   | Stocks at broker, crypto at exchange      |

### 2.4 Liquidity — How fast can you convert to cash

| Value         | Examples                                  |
|---------------|-------------------------------------------|
| `instant`     | Cash, checking account, money market      |
| `high`        | Stocks, ETFs, liquid crypto               |
| `medium`      | Mutual funds, bonds, P2P lending          |
| `low`         | Real estate, private equity               |
| `fixed`       | Pension, locked retirement account        |

---

## 3. Lifecycle Model

Every asset has a **value trajectory** — a function that describes how its economic value changes over time. This is the single most important concept for FIRE planning.

### 3.1 Trajectory Types

```
Value                              Value
  │                                  │
  │ ████                             │         ████████
  │   ████                           │     ████
  │     ████                         │ ████
  │       ████                       │
  └────────────── time               └────────────── time
     DEPRECIATING                        APPRECIATING

Value                              Value
  │                                  │
  │ ██████████████                   │ ██████
  │              █                   │       █
  │               █                  │        █
  │                ▼ 0               │         ▼ 0
  └────────────── time               └────────────── time
     CONSUMABLE                         EXPIRING (insurance)

Value                              Value
  │                                  │
  │    █      █                      │
  │   █ █    █ █     █              │ ████████████████████
  │  █   █  █   █   █ █             │
  │ █     ██     █ █   █            │
  └────────────── time               └────────────── time
     VOLATILE (crypto)                  STABLE (cash/bond)
```

### 3.2 Lifecycle Metadata Fields

```typescript
interface AssetLifecycle {
  // Core lifecycle classification
  trajectory: 'appreciating' | 'depreciating' | 'consumable' | 'expiring' | 'volatile' | 'stable';

  // Depreciation method (for depreciating assets)
  depreciation?: {
    method: 'straight-line' | 'declining-balance' | 'custom';
    rate?: number;           // Annual percentage (e.g., 0.20 = 20%/year)
    salvageValue?: number;   // Minimum floor value
    usefulLifeYears?: number;
    customSchedule?: { date: string; value: number }[];
  };

  // Expiration tracking (for insurance, subscriptions, warranties)
  expiration?: {
    startDate: string;       // ISO date
    endDate: string;         // ISO date
    autoRenew: boolean;
    renewalCost?: number;    // Cost per renewal period
    renewalPeriod?: 'monthly' | 'quarterly' | 'annual';
    noticeDays?: number;     // Days before expiry to alert
  };

  // Consumption tracking (for consumables)
  consumption?: {
    initialQuantity: number;
    currentQuantity: number;
    unit: string;            // 'rolls', 'ml', 'units', 'loads'
    consumptionRate?: number; // Units per day (for forecasting)
    reorderThreshold?: number;
    reorderUrl?: string;
  };

  // Market value tracking (for financial & volatile assets)
  marketValue?: {
    provider: string;        // 'manual', 'coingecko', 'alphavantage', 'plaid'
    ticker?: string;         // 'AAPL', 'BTC', 'VTSAX'
    currency: string;        // 'USD', 'EUR'
    lastUpdated: string;     // ISO datetime
    priceHistory?: { date: string; price: number }[];
  };

  // Appreciation model (for real estate, collectibles)
  appreciation?: {
    method: 'fixed-rate' | 'market-index' | 'manual';
    annualRate?: number;     // e.g., 0.03 = 3%/year
    lastAppraisalDate?: string;
    lastAppraisalValue?: number;
  };
}
```

### 3.3 Value Computation by Trajectory

```typescript
function computeCurrentValue(asset: Asset, today: Date): number {
  switch (asset.lifecycle.trajectory) {
    case 'depreciating':
      return computeDepreciation(asset, today);
    case 'consumable':
      return asset.purchasePrice * (asset.consumption.currentQuantity / asset.consumption.initialQuantity);
    case 'expiring':
      return computeRemainingValue(asset, today);
    case 'volatile':
      return asset.marketValue?.lastPrice ?? asset.purchasePrice;
    case 'appreciating':
      return computeAppreciation(asset, today);
    case 'stable':
      return asset.purchasePrice; // or face value for bonds
  }
}
```

---

## 4. Asset Relationship Model

Assets exist in a web of relationships. Modeling these is essential for understanding true cost of ownership, insurance needs, and replacement planning.

### 4.1 Relationship Types

| Type            | Cardinality | Examples                                  |
|-----------------|-------------|-------------------------------------------|
| `component-of`  | N:1         | Engine → Car, SSD → Laptop                |
| `contains`      | 1:N         | House → Rooms → Furniture                 |
| `requires`      | N:N         | TV ← Remote, Car ← Key Fob               |
| `manages`       | 1:N         | Password Manager → Accounts               |
| `provides`      | 1:N         | Subscription → Services (Netflix → streaming) |
| `protects`      | 1:N         | Insurance → Assets (car insurance → car)  |
| `funds`         | N:N         | Bank Account → Investments                |
| `secures`       | 1:N         | Mortgage → House, Car Loan → Car          |
| `accesses`      | 1:N         | Account → Services, API Key → Platform    |
| `substitutes`   | N:N         | Old Car ↔ New Car (replaced by)           |

### 4.2 Relationship Schema

```typescript
interface AssetRelationship {
  id: string;
  type: RelationshipType;

  sourceAssetId: string;
  targetAssetId: string;

  // Cardinality hints
  isOptional: boolean;       // Can the asset function without this relationship?
  isReplaceable: boolean;    // Can the linked asset be swapped?

  // Financial impact
  sharedCost?: number;       // If cost is split across related assets

  // Lifecycle coupling
  lifecycleLinked: boolean;  // If true, target's expiry affects source's utility

  metadata?: Record<string, unknown>;
}
```

### 4.3 Practical Relationship Graph

```
                    ┌──────────────┐
                    │   Mortgage   │
                    │  (secures)   │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │    House     │
                    │  (contains)  │
                    └──┬───┬───┬───┘
                       │   │   │
              ┌────────┘   │   └────────┐
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │  Living  │ │ Bedroom  │ │  Garage  │
        │  Room    │ │          │ │          │
        └────┬─────┘ └────┬─────┘ └────┬─────┘
             │             │             │
        ┌────▼─────┐ ┌────▼─────┐ ┌────▼─────┐
        │   TV     │ │   Bed    │ │   Car    │
        └──┬───────┘ └──────────┘ └──┬───────┘
           │                         │
     ┌─────┴──────┐           ┌──────┴──────┐
     ▼            ▼           ▼             ▼
┌─────────┐ ┌─────────┐ ┌──────────┐ ┌──────────┐
│ Remote  │ │Soundbar │ │Car Insur.│ │ Car Loan │
│(requires)│ │(requires)│ │(protects)│ │(secures) │
└─────────┘ └─────────┘ └──────────┘ └──────────┘

                    ┌──────────────┐
                    │  1Password  │
                    │  (manages)   │
                    └──┬───┬───┬───┘
                       │   │   │
              ┌────────┘   │   └────────┐
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │ Netflix  │ │  Bank    │ │  Binance │
        │ Account  │ │ Account  │ │ Account  │
        └────┬─────┘ └────┬─────┘ └────┬─────┘
             │             │             │
             ▼             ▼             ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │Netflix   │ │ Savings  │ │  BTC +   │
        │Subscript.│ │  Fund    │ │  ETH     │
        └──────────┘ └──────────┘ └──────────┘
```

---

## 5. Unified Asset Schema

### 5.1 Core Asset Record

Every asset in the system has this base structure:

```typescript
interface Asset {
  // Identity
  id: string;                    // UUID
  name: string;                  // "2024 Toyota Camry"
  description?: string;

  // === MULTI-DIMENSIONAL CLASSIFICATION ===
  classification: {
    nature: 'tangible' | 'digital' | 'financial' | 'intangible' | 'service';
    utility: 'productive' | 'consumable' | 'protective' | 'speculative' | 'lifestyle' | 'essential';
    ownership: 'owned' | 'mortgaged' | 'leased' | 'subscribed' | 'licensed' | 'custodied';
    liquidity: 'instant' | 'high' | 'medium' | 'low' | 'fixed';
  };

  // Tags for free-form categorization (replaces rigid categories)
  tags: string[];                // ['vehicle', 'commute', 'depreciating']

  // === FINANCIAL ===
  financial: {
    purchasePrice: number;
    purchaseDate: string;        // ISO date
    currency: string;            // ISO 4217
    currentValue: number;        // Computed or fetched
    lastValuationDate: string;
    totalCostOfOwnership: number; // Includes maintenance, insurance, etc.
    monthlyCarryingCost?: number; // Subscription/maintenance/loan payment
  };

  // === LIFECYCLE ===
  lifecycle: AssetLifecycle;     // See §3.2

  // === RELATIONSHIPS ===
  relationships: string[];       // IDs of AssetRelationship records

  // === LOCATION & CUSTODY ===
  location?: {
    physical?: string;           // "Home garage", "Bank safe deposit"
    digital?: string;            // "Coinbase", "Schwab brokerage"
    url?: string;                // Link to account or platform
  };

  // === OWNERSHIP & ACCESS ===
  access?: {
    owner: string;               // Person or entity
    custodian?: string;          // Broker, bank, exchange
    credentialsRef?: string;     // Reference to credential vault entry
    beneficiaries?: string[];
  };

  // === ATTACHMENTS & DOCUMENTS ===
  documents?: {
    id: string;
    type: 'receipt' | 'warranty' | 'policy' | 'contract' | 'manual' | 'photo' | 'appraisal';
    url: string;
    expiryDate?: string;
  }[];

  // === METADATA (asset-type specific) ===
  metadata: AssetTypeMetadata;   // See §5.2

  // === AUDIT ===
  createdAt: string;
  updatedAt: string;
  archivedAt?: string;           // Soft delete / disposed asset
}
```

### 5.2 Asset-Type Specific Metadata

Each `nature` + `utility` combination maps to a specific metadata shape:

#### 5.2.1 Vehicles (`tangible` + `essential`)

```typescript
interface VehicleMetadata {
  type: 'car' | 'motorcycle' | 'bicycle' | 'boat' | 'rv';
  make: string;
  model: string;
  year: number;
  vin?: string;
  licensePlate?: string;
  mileage?: number;
  fuelType: 'gasoline' | 'diesel' | 'electric' | 'hybrid';
  insurancePolicyId?: string;    // Reference to insurance asset
  registrationExpiry?: string;
  maintenanceLog?: {
    date: string;
    type: string;
    cost: number;
    mileage?: number;
    provider?: string;
  }[];
}
```

#### 5.2.2 Real Estate (`tangible` + `essential` or `productive`)

```typescript
interface RealEstateMetadata {
  type: 'primary-residence' | 'rental' | 'vacation' | 'land' | 'commercial';
  address: string;
  coordinates?: { lat: number; lng: number };
  squareFootage: number;
  lotSize?: number;
  bedrooms?: number;
  bathrooms?: number;
  yearBuilt?: number;
  propertyTaxAnnual?: number;
  hoaMonthly?: number;
  rentalIncome?: number;
  mortgageId?: string;
  insurancePolicyId?: string;
  lastAppraisal?: {
    date: string;
    value: number;
    appraiser: string;
  };
  improvements?: {
    date: string;
    description: string;
    cost: number;
    valueAdd?: number;
  }[];
}
```

#### 5.2.3 Electronics (`tangible` + `lifestyle`)

```typescript
interface ElectronicsMetadata {
  type: 'phone' | 'laptop' | 'tablet' | 'tv' | 'audio' | 'gaming' | 'camera' | 'appliance' | 'networking';
  brand: string;
  model: string;
  serialNumber?: string;
  specs?: Record<string, string>;  // {'ram': '16GB', 'storage': '512GB'}
  warrantyExpiration?: string;
  osFirmware?: string;
  repairHistory?: {
    date: string;
    issue: string;
    cost: number;
  }[];
}
```

#### 5.2.4 Furniture (`tangible` + `lifestyle`)

```typescript
interface FurnitureMetadata {
  type: 'seating' | 'table' | 'storage' | 'bed' | 'lighting' | 'decor' | 'outdoor';
  brand?: string;
  material?: string;
  room: string;
  dimensions?: { width: number; depth: number; height: number; unit: string };
  condition: 'new' | 'good' | 'fair' | 'poor';
}
```

#### 5.2.5 Insurance Policies (`intangible` + `protective`)

```typescript
interface InsuranceMetadata {
  type: 'car' | 'home' | 'life' | 'health' | 'liability' | 'disability' | 'umbrella';
  provider: string;
  policyNumber: string;
  coverageAmount: number;
  deductible?: number;
  premium: number;
  premiumFrequency: 'monthly' | 'quarterly' | 'annual';
  beneficiaries?: string[];
  coveredAssets?: string[];       // References to asset IDs
  coverageDetails?: {
    bodily?: number;
    property?: number;
    uninsured?: number;
    collision?: boolean;
    comprehensive?: boolean;
  };
  claimsHistory?: {
    date: string;
    description: string;
    amount: number;
    status: 'filed' | 'approved' | 'denied' | 'paid';
  }[];
}
```

#### 5.2.6 Financial Investments (`financial` + `speculative` or `productive`)

```typescript
interface FinancialMetadata {
  instrumentType: 'stock' | 'etf' | 'mutual-fund' | 'bond' | 'crypto' | 'reit' | 'option' | 'cd' | 'money-market';
  ticker?: string;              // 'AAPL', 'VTI', 'BTC'
  exchange?: string;            // 'NASDAQ', 'NYSE', 'BINANCE'
  isin?: string;
  cusip?: string;

  // For securities
  shares?: number;
  averageCostBasis?: number;
  currentPrice?: number;
  priceCurrency: string;

  // For crypto
  walletAddress?: string;
  blockchain?: string;          // 'bitcoin', 'ethereum', 'solana'
  isSelfCustodied?: boolean;

  // For bonds / CDs
  faceValue?: number;
  couponRate?: number;
  maturityDate?: string;
  yieldToMaturity?: number;

  // For funds
  expenseRatio?: number;
  dividendYield?: number;
  fundFamily?: string;          // 'Vanguard', 'Fidelity'

  // Tax
  taxAdvantaged: boolean;
  accountType?: 'taxable' | 'traditional-ira' | 'roth-ira' | '401k' | 'hsa' | '529';

  // Price feed config
  priceSource: {
    provider: 'manual' | 'alphavantage' | 'coingecko' | 'yfinance' | 'plaid' | 'yahoo';
    symbol: string;
    refreshIntervalMinutes: number;
    lastFetch?: string;
    lastPrice?: number;
  };

  // Transaction history
  transactions?: {
    date: string;
    type: 'buy' | 'sell' | 'dividend' | 'split' | 'transfer' | 'fee';
    quantity?: number;
    price?: number;
    total?: number;
    fees?: number;
    notes?: string;
  }[];
}
```

#### 5.2.7 Subscriptions (`service` + various)

```typescript
interface SubscriptionMetadata {
  type: 'streaming' | 'software' | 'cloud' | 'news' | 'fitness' | 'meal-delivery' | 'other';
  provider: string;
  plan: string;
  billingCycle: 'monthly' | 'quarterly' | 'annual' | 'lifetime';
  billingAmount: number;
  nextBillingDate: string;
  autoRenew: boolean;
  cancelUrl?: string;
  usageLevel: 'essential' | 'important' | 'nice-to-have' | 'unused';
  sharedWith?: string[];         // Family members, etc.
  annualCost: number;            // Computed
  costPerUse?: number;           // If usage is tracked
}
```

#### 5.2.8 Accounts & Keys (`digital` + various)

```typescript
interface AccountMetadata {
  type: 'bank' | 'brokerage' | 'crypto-exchange' | 'email' | 'social' | 'utility' | 'government' | 'other';
  provider: string;
  username?: string;
  email?: string;
  url?: string;
  mfaEnabled: boolean;
  credentialVaultRef?: string;   // Reference to 1Password/Bitwarden entry
  apiKeyRef?: string;            // For API-driven assets (crypto exchanges)
  linkedPaymentMethods?: string[];
  accountNumber?: string;        // Masked
  balance?: number;              // If tracked externally
}
```

#### 5.2.9 Consumables (`tangible` + `consumable`)

```typescript
interface ConsumableMetadata {
  type: 'hygiene' | 'cleaning' | 'food' | 'office-supply' | 'medical';
  brand?: string;
  initialQuantity: number;
  currentQuantity: number;
  unit: string;                 // 'rolls', 'bottles', 'ml', 'loads', 'pads'
  purchaseLocation?: string;
  reorderUrl?: string;
  costPerUnit?: number;
  averageLifespan?: number;     // Days until consumed
  bulkDiscount?: {
    quantity: number;
    price: number;
  };
}
```

#### 5.2.10 Shared/Common Fields

```typescript
// All metadata types extend this
interface BaseMetadata {
  notes?: string;
  customFields?: Record<string, string | number | boolean>;
}
```

---

## 6. Financial Asset Model (Stocks, Funds, Crypto)

Financial assets require special treatment because their value changes in real-time and they are the core of FIRE net worth calculations.

### 6.1 Price Feed Architecture

```
┌──────────────────────────────────────────────────────┐
│                    PRICE FEED SERVICE                │
│                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │ Alpha Vantage│  │  CoinGecko  │  │   Yahoo     │  │
│  │  (stocks)   │  │  (crypto)   │  │  Finance    │  │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  │
│         │                │                │         │
│         └────────────────┼────────────────┘         │
│                          ▼                           │
│                   ┌─────────────┐                    │
│                   │ Price Cache │                    │
│                   │  (per asset)│                    │
│                   └──────┬──────┘                    │
│                          │                           │
│              ┌───────────┼───────────┐               │
│              ▼           ▼           ▼               │
│        ┌──────────┐ ┌──────────┐ ┌──────────┐       │
│        │ Snapshot │ │  Daily   │ │  History │       │
│        │  (now)   │ │  Close   │ │  (OHLCV) │       │
│        └──────────┘ └──────────┘ └──────────┘       │
└──────────────────────────────────────────────────────┘
```

### 6.2 Price Provider Configuration

```typescript
interface PriceProviderConfig {
  // Provider priority per asset type
  providers: {
    stock: ['alphavantage', 'yahoo', 'manual'];
    etf: ['alphavantage', 'yahoo', 'manual'];
    mutualFund: ['yahoo', 'alphavantage', 'manual'];
    crypto: ['coingecko', 'binance', 'manual'];
    bond: ['manual'];  // Bonds rarely have free APIs
    cd: ['manual'];
  };

  // API keys (stored in environment/secrets)
  apiKeys: {
    alphavantage?: string;
    coingecko?: string;
    plaid?: string;
  };

  // Rate limiting
  rateLimits: {
    alphavantage: { requestsPerMinute: 5 };
    coingecko: { requestsPerMinute: 30 };
    yahoo: { requestsPerMinute: 100 };
  };

  // Staleness thresholds
  staleness: {
    stock: number;      // Minutes before price is considered stale (e.g., 15)
    crypto: number;     // Crypto is 24/7, tighter thresholds (e.g., 5)
    mutualFund: number; // NAV updates once daily (e.g., 1440)
  };
}
```

### 6.3 Portfolio Calculations

```typescript
interface PortfolioSnapshot {
  timestamp: string;

  // Net worth breakdown
  netWorth: {
    total: number;
    liquid: number;           // instant + high liquidity
    semiLiquid: number;       // medium liquidity
    illiquid: number;         // low + fixed liquidity
  };

  // Asset allocation
  allocation: {
    stocks: number;
    bonds: number;
    realEstate: number;
    crypto: number;
    cash: number;
    other: number;
  };

  // FIRE metrics
  fire: {
    annualExpenses: number;
    withdrawalRate: number;       // 4% rule
    fireNumber: number;           // annualExpenses / withdrawalRate
    yearsToFire: number;          // Based on savings rate & growth
    savingsRate: number;          // (income - expenses) / income
    financialIndependenceRatio: number; // netWorth / fireNumber
  };

  // Income-generating assets
  passiveIncome: {
    annual: number;
    sources: { assetId: string; type: string; annualIncome: number }[];
  };
}
```

### 6.4 Cost Basis & Tax Tracking

```typescript
interface CostBasisTracker {
  method: 'fifo' | 'lifo' | 'specific-id' | 'average-cost';
  lots: {
    purchaseDate: string;
    quantity: number;
    costPerUnit: number;
    totalCost: number;
    fees: number;
  }[];
  realizedGains: {
    saleDate: string;
    quantity: number;
    salePrice: number;
    costBasis: number;
    gain: number;
    holdingPeriod: 'short' | 'long';
  }[];
  unrealizedGain: number;
  taxLotHarvestOpportunities?: {
    lotId: string;
    unrealizedLoss: number;
    suggestion: string;
  }[];
}
```

---

## 7. FIRE-Specific Views & Queries

The classification system enables these critical FIRE calculations:

### 7.1 Net Worth Calculation

```sql
-- True net worth: current value minus liabilities
SELECT SUM(
  CASE
    WHEN c.ownership IN ('owned', 'custodied', 'licensed') THEN f.currentValue
    WHEN c.ownership = 'mortgaged' THEN f.currentValue - li.balance
    WHEN c.ownership = 'leased' THEN 0  -- No equity
    WHEN c.ownership = 'subscribed' THEN 0
  END
) AS net_worth
FROM assets a
JOIN classification c ON a.id = c.asset_id
JOIN financial f ON a.id = f.asset_id
LEFT JOIN liabilities li ON a.id = li.asset_id
WHERE a.archived_at IS NULL;
```

### 7.2 Expense Tracking

```sql
-- Monthly recurring expenses (subscriptions + insurance + loan payments)
SELECT
  a.name,
  f.monthlyCarryingCost,
  CASE
    WHEN l.trajectory = 'expiring' THEN l.expiration.endDate
    WHEN s.billingCycle = 'monthly' THEN s.nextBillingDate
  END AS next_due
FROM assets a
JOIN financial f ON a.id = f.asset_id
JOIN lifecycle l ON a.id = l.asset_id
LEFT JOIN subscription_metadata s ON a.id = s.asset_id
WHERE f.monthlyCarryingCost > 0
  AND a.archived_at IS NULL
ORDER BY f.monthlyCarryingCost DESC;
```

### 7.3 Depreciation Impact

```sql
-- Assets losing the most value annually
SELECT
  a.name,
  f.purchasePrice,
  f.currentValue,
  (f.purchasePrice - f.currentValue) AS total_depreciation,
  d.rate AS annual_rate
FROM assets a
JOIN financial f ON a.id = f.asset_id
JOIN lifecycle l ON a.id = l.asset_id
JOIN depreciation d ON a.id = d.asset_id
WHERE l.trajectory = 'depreciating'
ORDER BY total_depreciation DESC;
```

### 7.4 Insurance Coverage Gaps

```sql
-- High-value tangible assets without insurance
SELECT a.name, f.currentValue
FROM assets a
JOIN financial f ON a.id = f.asset_id
WHERE a.classification_nature = 'tangible'
  AND f.currentValue > 5000
  AND NOT EXISTS (
    SELECT 1 FROM asset_relationships r
    JOIN insurance_metadata i ON r.source_asset_id = i.asset_id
    WHERE r.target_asset_id = a.id
      AND r.type = 'protects'
  );
```

---

## 8. Data Storage Recommendation

### 8.1 Hybrid Approach

| Data Type           | Storage           | Rationale                           |
|---------------------|-------------------|-------------------------------------|
| Core asset records  | SQLite / Postgres | Relational queries, ACID            |
| Price history       | TimescaleDB / InfluxDB | Time-series optimized         |
| Documents/photos    | S3 / local FS     | Binary blob storage                 |
| Credentials         | Vault / 1Password | Never store in app DB               |
| Real-time prices    | Redis / memory    | Ephemeral cache, fast reads         |

### 8.2 Recommended Schema Split

```
assets                    -- Core record (§5.1)
asset_classifications     -- 4-dimensional classification
asset_lifecycles          -- Lifecycle config (§3.2)
asset_metadata_*          -- Per-type metadata (§5.2) - one table per type
asset_relationships       -- Relationship graph (§4.2)
asset_documents           -- Attached files
price_snapshots           -- Historical prices (time-series)
price_cache               -- Latest known prices
transactions              -- Buy/sell/dividend events
fire_snapshots            -- Periodic FIRE metric calculations
```

---

## 9. Example Asset Records

### 9.1 Car

```json
{
  "id": "a1b2c3d4",
  "name": "2024 Toyota Camry",
  "classification": {
    "nature": "tangible",
    "utility": "essential",
    "ownership": "mortgaged",
    "liquidity": "low"
  },
  "tags": ["vehicle", "commute", "family"],
  "financial": {
    "purchasePrice": 32000,
    "purchaseDate": "2024-03-15",
    "currency": "USD",
    "currentValue": 28800,
    "lastValuationDate": "2026-01-15",
    "totalCostOfOwnership": 38500,
    "monthlyCarryingCost": 620
  },
  "lifecycle": {
    "trajectory": "depreciating",
    "depreciation": {
      "method": "straight-line",
      "rate": 0.15,
      "salvageValue": 8000,
      "usefulLifeYears": 12
    }
  },
  "metadata": {
    "type": "car",
    "make": "Toyota",
    "model": "Camry",
    "year": 2024,
    "vin": "4T1BZ1HK5RU123456",
    "mileage": 12400,
    "fuelType": "hybrid"
  }
}
```

### 9.2 Index Fund

```json
{
  "id": "e5f6g7h8",
  "name": "Vanguard Total Stock Market ETF",
  "classification": {
    "nature": "financial",
    "utility": "productive",
    "ownership": "custodied",
    "liquidity": "high"
  },
  "tags": ["investment", "index-fund", "us-equity", "fire-core"],
  "financial": {
    "purchasePrice": 50000,
    "purchaseDate": "2022-06-01",
    "currency": "USD",
    "currentValue": 62500,
    "lastValuationDate": "2026-05-29",
    "totalCostOfOwnership": 15,
    "monthlyCarryingCost": 0
  },
  "lifecycle": {
    "trajectory": "volatile",
    "marketValue": {
      "provider": "alphavantage",
      "ticker": "VTI",
      "currency": "USD",
      "lastUpdated": "2026-05-29T16:00:00Z"
    }
  },
  "metadata": {
    "instrumentType": "etf",
    "ticker": "VTI",
    "exchange": "NYSE",
    "shares": 250,
    "averageCostBasis": 200,
    "currentPrice": 250,
    "priceCurrency": "USD",
    "expenseRatio": 0.0003,
    "dividendYield": 0.014,
    "taxAdvantaged": false,
    "accountType": "taxable",
    "priceSource": {
      "provider": "alphavantage",
      "symbol": "VTI",
      "refreshIntervalMinutes": 15,
      "lastFetch": "2026-05-29T16:00:00Z",
      "lastPrice": 250
    }
  }
}
```

### 9.3 Netflix Subscription

```json
{
  "id": "i9j0k1l2",
  "name": "Netflix Premium",
  "classification": {
    "nature": "service",
    "utility": "lifestyle",
    "ownership": "subscribed",
    "liquidity": "instant"
  },
  "tags": ["entertainment", "streaming", "monthly-expense"],
  "financial": {
    "purchasePrice": 0,
    "purchaseDate": "2020-01-15",
    "currency": "USD",
    "currentValue": 0,
    "lastValuationDate": "2026-05-29",
    "totalCostOfOwnership": 1320,
    "monthlyCarryingCost": 22.99
  },
  "lifecycle": {
    "trajectory": "expiring",
    "expiration": {
      "startDate": "2026-05-15",
      "endDate": "2026-06-15",
      "autoRenew": true,
      "renewalCost": 22.99,
      "renewalPeriod": "monthly",
      "noticeDays": 3
    }
  },
  "metadata": {
    "type": "streaming",
    "provider": "Netflix",
    "plan": "Premium",
    "billingCycle": "monthly",
    "billingAmount": 22.99,
    "nextBillingDate": "2026-06-15",
    "autoRenew": true,
    "usageLevel": "important",
    "sharedWith": ["partner"],
    "annualCost": 275.88
  }
}
```

---

## 10. Implementation Priorities

| Phase | Scope | FIRE Value |
|-------|-------|------------|
| 1     | Core schema + financial assets + manual price entry | Net worth tracking |
| 2     | Subscriptions + insurance + recurring expenses | Expense ratio & savings rate |
| 3     | Real-time price feeds (stocks, crypto) | Accurate net worth |
| 4     | Tangible assets + depreciation | True cost of lifestyle |
| 5     | Relationship graph + insurance gap analysis | Risk management |
| 6     | FIRE projections + Monte Carlo simulation | Path to FI |

---

## 11. API Design Sketch

```
GET    /api/assets                          — List all assets (filterable)
POST   /api/assets                          — Create asset
GET    /api/assets/:id                      — Get asset detail
PATCH  /api/assets/:id                      — Update asset
DELETE /api/assets/:id                      — Archive (soft delete)

GET    /api/assets/:id/relationships        — Get related assets
POST   /api/assets/:id/relationships        — Create relationship

GET    /api/assets/:id/price-history        — Price history for financial assets
POST   /api/assets/:id/price/refresh        — Force price refresh

GET    /api/portfolio/snapshot              — Current FIRE metrics
GET    /api/portfolio/allocation            — Asset allocation breakdown
GET    /api/portfolio/net-worth             — Net worth time series
GET    /api/portfolio/expenses              — Recurring expense summary

GET    /api/reports/depreciation            — Depreciation schedule
GET    /api/reports/insurance-gaps          — Uncovered high-value assets
GET    /api/reports/tax-lots                — Cost basis & gain/loss
GET    /api/reports/fire-projection         — Years to FI forecast
```
