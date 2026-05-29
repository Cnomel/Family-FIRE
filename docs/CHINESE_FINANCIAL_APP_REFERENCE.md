# Chinese Financial App UI/UX Reference Guide

> A comprehensive reference for Family Fire app development, based on patterns from leading Chinese financial applications.

## Table of Contents
1. [Overview of Key Apps](#1-overview-of-key-apps)
2. [UI Layout Patterns](#2-ui-layout-patterns)
3. [Color Schemes & Visual Design](#3-color-schemes--visual-design)
4. [Data Display Formats](#4-data-display-formats)
5. [Chinese-Specific UX Patterns](#5-chinese-specific-ux-patterns)
6. [Asset Categorization](#6-asset-categorization)
7. [Account Type Handling](#7-account-type-handling)
8. [Stock Market (A股) Display Conventions](#8-stock-market-a股-display-conventions)
9. [Common Chinese App UI Patterns](#9-common-chinese-app-ui-patterns)
10. [User Expectations](#10-user-expectations)
11. [Implementation Recommendations](#11-implementation-recommendations)

---

## 1. Overview of Key Apps

### 1.1 招商银行App (CMB - China Merchants Bank)

**App Category:** Banking / Full-service Financial Platform

**Core Features:**
- **Account Overview:** Multi-account aggregation (savings, credit card, loans, investments)
- **Asset Display:** Total assets (总资产) prominently displayed with privacy toggle
- **Card-based UI:** Physical card visualization with tap-to-reveal details
- **Transaction History:** Categorized by type with search/filter
- **Security:** Biometric login (Face ID, fingerprint), gesture password, SMS OTP
- **Login Flow:** Phone number + password → Biometric quick login

**UI Layout:**
- Bottom tab navigation: 首页 (Home), 理财 (Finance), 生活 (Life), 我的 (My)
- Hero card showing total assets with expandable details
- Quick action grid (8-10 icons) below hero card
- Scrollable content sections with cards

**Design Language:**
- Primary color: Red (#E60012) - CMB brand color
- Clean white backgrounds with subtle shadows
- Card-based layout with 12px border radius
- Generous padding (16-20px)

### 1.2 支付宝App (Alipay)

**App Category:** Payment / Lifestyle / Financial Platform

**Core Features:**
- **Asset Overview:** 余额宝 (Yu'ebao), 基金 (Funds), 股票 (Stocks), 余额 (Balance)
- **Income/Expense Tracking:** Monthly summary with category breakdown
- **Bill Management:** Utility bills, credit card bills, loan payments
- **Investment Tracking:** Fund performance, stock portfolio

**UI Layout:**
- Bottom tab: 首页 (Home), 理财 (Finance), 生活 (Life), 消息 (Messages), 我的 (My)
- Home page: Scan button (prominent), Quick apps grid, Scrollable services
- "我的" page: Total assets at top, account list below

**Design Language:**
- Primary color: Blue (#1677FF) - Alipay brand
- Gradient backgrounds for financial sections
- Rounded cards with subtle shadows
- Icon-heavy navigation

### 1.3 东方财富App (East Money)

**App Category:** Stock Trading / Financial Data

**Core Features:**
- **Stock Market Data:** Real-time A股 quotes, indices, market overview
- **Portfolio Tracking:** Holdings, profit/loss, asset allocation
- **K-line Charts:** Candlestick charts with technical indicators
- **Financial Analysis:** Fundamentals, news, research reports

**UI Layout:**
- Bottom tab: 首页 (Home), 行情 (Market), 交易 (Trade), 资讯 (News), 我的 (My)
- Market page: Index overview → Stock lists → Individual stock detail
- Dense data presentation for traders

**Design Language:**
- Primary color: Red (#FF4D4F) for brand and positive values
- Data-dense layouts with smaller fonts
- Monospace numbers for alignment
- Dark mode option for traders

### 1.4 随手记 (Sui Shou Ji / Random Notes)

**App Category:** Personal Finance / Expense Tracking

**Core Features:**
- **Expense Categorization:** Hierarchical categories (大类/小类)
- **Budgeting:** Monthly budgets by category with progress bars
- **Reports:** Pie charts, bar charts, trend lines
- **Multi-account:** Cash, bank cards, Alipay, WeChat Pay

**UI Layout:**
- Bottom tab: 记账 (Record), 报表 (Reports), 发现 (Discover), 我的 (My)
- Quick expense entry with category icons
- Visual reports with charts

**Design Language:**
- Primary color: Green (#00B578) - friendly, approachable
- Soft colors, rounded elements
- Icon-based category system
- Card-based reports

### 1.5 挖财 (Wacai)

**App Category:** Personal Finance / Asset Management

**Core Features:**
- **Asset Management:** Net worth tracking across all accounts
- **Investment Tracking:** Stocks, funds, P2P (historical), deposits
- **Net Worth Calculation:** Assets - Liabilities
- **Bill Management:** Credit card bills, loan tracking

**UI Layout:**
- Bottom tab: 首页 (Home), 记账 (Record), 理财 (Finance), 我的 (My)
- Home: Net worth display with trend chart
- Asset breakdown by category

**Design Language:**
- Primary color: Orange (#FF6B35)
- Warm, friendly aesthetic
- Clear hierarchy with cards
- Progress indicators for goals

---

## 2. UI Layout Patterns

### 2.1 Navigation Structure

**Bottom Navigation (Most Common)**
```
┌─────────────────────────────────────────────┐
│                                             │
│              [Content Area]                 │
│                                             │
├─────────────────────────────────────────────┤
│  🏠首页    📊理财    ➕记账    📋账单    👤我的  │
│  Home    Finance   Record   Bills    My    │
└─────────────────────────────────────────────┘
```

**Tab Count:** 4-5 tabs (standard), never more than 5
**Active State:** Color fill + bold text
**Inactive State:** Gray outline + gray text

### 2.2 Page Layout Patterns

**Home Page Structure:**
```
┌─────────────────────────────────────────────┐
│  Logo          [Search]        [Avatar]     │
├─────────────────────────────────────────────┤
│  ┌─────────────────────────────────────┐    │
│  │        Hero Card (总资产)            │    │
│  │     ¥1,234,567.89                   │    │
│  │     昨日收益 +¥1,234.56              │    │
│  └─────────────────────────────────────┘    │
├─────────────────────────────────────────────┤
│  [💰] [📈] [🏦] [📱] [💳] [🎯] [📊] [⚡]  │
│  余额  理财  银行  生活  卡片  目标  报表  更多  │
├─────────────────────────────────────────────┤
│  ┌─────────────────────────────────────┐    │
│  │  📊 资产配置                         │    │
│  │  [Chart] [Legend]                    │    │
│  └─────────────────────────────────────┘    │
│  ┌─────────────────────────────────────┐    │
│  │  📋 最近交易                         │    │
│  │  • 水电费    -¥234.56               │    │
│  │  • 工资      +¥15,000.00            │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

**Card Design Standards:**
- Border radius: 12-16px
- Shadow: `0 2px 8px rgba(0,0,0,0.06)`
- Padding: 16-20px
- Margin between cards: 12-16px
- Background: White (#FFFFFF) or subtle gradient

### 2.3 List Patterns

**Transaction List:**
```
┌─────────────────────────────────────────────┐
│  2024年1月15日 周一                          │
├─────────────────────────────────────────────┤
│  🛒 超市购物          │        -¥156.78    │
│     招商银行储蓄卡      │                    │
├─────────────────────────────────────────────┤
│  💰 工资收入          │     +¥15,000.00    │
│     工商银行工资卡      │                    │
└─────────────────────────────────────────────┘
```

**Key Patterns:**
- Category icon (left) + Description + Amount (right)
- Secondary info in gray (account, time)
- Date headers for grouping
- Swipe actions for edit/delete

---

## 3. Color Schemes & Visual Design

### 3.1 Chinese Financial Color Conventions

**CRITICAL: Red/Green Meaning (Opposite to Western)**

| Color | Chinese Meaning | Western Equivalent |
|-------|-----------------|-------------------|
| 🔴 Red (红) | Profit, Gain, Positive, Up | Green |
| 🟢 Green (绿) | Loss, Negative, Down | Red |
| ⚫ Gray (灰) | Neutral, Unchanged | Gray |
| 🟡 Yellow/Gold | Premium, VIP, Important | - |

**Color Values:**
```javascript
// Profit/Loss Colors (Chinese Standard)
const COLORS = {
  profit: '#FF4D4F',      // Red - 涨, 盈利, 正收益
  loss: '#00B578',        // Green - 跌, 亏损, 负收益
  neutral: '#8C8C8C',     // Gray - 持平
  warning: '#FAAD14',     // Yellow/Gold - Warning
  primary: '#1677FF',     // Blue - Primary action
  background: '#F5F5F5',  // Light gray background
  cardBg: '#FFFFFF',      // White card background
};
```

### 3.2 App-Specific Color Palettes

**CMB (招商银行):**
- Primary: #E60012 (Red)
- Secondary: #333333 (Dark gray)
- Background: #F5F5F5
- Accent: Gold for VIP

**Alipay (支付宝):**
- Primary: #1677FF (Blue)
- Secondary: #00B578 (Green for success)
- Background: #F7F8FA
- Financial: #FF4D4F (Red for positive)

**East Money (东方财富):**
- Primary: #FF4D4F (Red)
- Up: #FF4D4F (Red)
- Down: #00B578 (Green)
- Background: #F5F5F5

### 3.3 Typography

**Number Display:**
- Large numbers: 28-36px, Bold
- Medium numbers: 20-24px, Medium
- Small numbers: 14-16px, Regular
- Tabular alignment for columns
- Use monospace or tabular-nums for financial data

**Font Stack:**
```css
font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", 
  "Hiragino Sans GB", "Microsoft YaHei", "Helvetica Neue", 
  Helvetica, Arial, sans-serif;
```

**Number Font:**
```css
font-variant-numeric: tabular-nums;
font-feature-settings: "tnum";
```

---

## 4. Data Display Formats

### 4.1 Currency Display

**Chinese Yuan (RMB) Format:**
```
¥1,234,567.89    # Standard format with comma separators
¥1,234,567       # No decimals for whole numbers
+¥1,234.56       # Positive with plus sign
-¥1,234.56       # Negative with minus sign
```

**Large Number Formatting:**
```
¥1.23万          # 12,300 → 1.23万 (10K)
¥1.23亿          # 123,000,000 → 1.23亿 (100M)
¥1,234.56万      # 12,345,600 → 1,234.56万
```

**Units:**
- 万 (wàn) = 10,000
- 亿 (yì) = 100,000,000

### 4.2 Percentage Display

```
+2.34%           # Positive change
-1.56%           # Negative change
+0.00%           # No change (rare)
```

**Color Coding:**
- Positive: Red (#FF4D4F)
- Negative: Green (#00B578)
- Neutral: Gray (#8C8C8C)

### 4.3 Date/Time Formats

**Date:**
```
2024年1月15日         # Full date
2024-01-15            # ISO format
01-15                 # Short date
1月15日 周一           # With weekday
今天 14:30            # Today with time
昨天                   # Yesterday
```

**Relative Time:**
```
刚刚                    # Just now
5分钟前                 # 5 minutes ago
1小时前                 # 1 hour ago
3天前                   # 3 days ago
```

### 4.4 Number Precision

| Data Type | Precision | Example |
|-----------|-----------|---------|
| Balance | 2 decimals | ¥1,234.56 |
| Stock Price | 2 decimals | 19.34 |
| Fund NAV | 4 decimals | 1.2345 |
| Percentage | 2 decimals | +2.34% |
| Shares | 2 decimals | 100.00股 |

---

## 5. Chinese-Specific UX Patterns

### 5.1 Privacy Toggle (隐私保护)

**Pattern:** Eye icon to show/hide sensitive financial data
```
┌─────────────────────────────────────────────┐
│  总资产                        [👁️]         │
│  ****                            [Show]     │
│  或                                     [Hide]│
│  ¥1,234,567.89                              │
└─────────────────────────────────────────────┘
```

**Implementation:**
- Default: Hidden (masked with ****)
- Tap to reveal (temporary or toggle)
- Remember preference in local storage
- Use for all monetary values

### 5.2 Red Envelope / Lucky Money (红包)

- Special UI for transfers during Chinese New Year
- Red/gold color scheme
- Animation effects
- Lucky numbers display

### 5.3 Quick Actions Grid (快捷功能)

**Standard Grid Layout:**
```
┌────┬────┬────┬────┐
│ 转账 │ 扫一扫│ 理财 │ 信用卡│
│Transfer│Scan│Finance│ Credit│
├────┼────┼────┼────┤
│ 贷款 │ 生活 │ 保险 │ 更多 │
│ Loan │ Life │Insurance│More│
└────┴────┴────┴────┘
```

**Customizable:** Users can reorder/add/remove shortcuts

### 5.4 Banner/Carousel (轮播图)

- Position: Top of page, below header
- Auto-scroll: 3-5 second intervals
- Dots indicator at bottom
- Promotions, announcements, seasonal content

### 5.5 Pull-to-Refresh (下拉刷新)

- Standard pattern across all Chinese apps
- Custom animations (brand mascots, loading spinners)
- "松开刷新" (Release to refresh)
- "正在刷新" (Refreshing...)
- "更新于 HH:mm" (Updated at HH:mm)

### 5.6 Loading States

**Skeleton Screens (骨架屏):**
- Gray placeholder blocks
- Shimmer animation
- Matches final layout structure

**Progress Indicators:**
- Circular progress for investments
- Linear progress for goals/budgets
- Percentage completion

### 5.7 Empty States

**Pattern:**
```
┌─────────────────────────────────────────────┐
│                                             │
│           [Illustration]                    │
│                                             │
│         暂无交易记录                          │
│         No transaction records              │
│                                             │
│           [开始记账]                         │
│           Start Recording                   │
└─────────────────────────────────────────────┘
```

---

## 6. Asset Categorization

### 6.1 Standard Chinese Asset Categories

**Assets (资产):**
```
资产 (Assets)
├── 现金及等价物 (Cash & Equivalents)
│   ├── 现金 (Cash)
│   ├── 银行活期 (Bank Demand Deposits)
│   ├── 银行定期 (Bank Time Deposits)
│   ├── 货币基金 (Money Market Funds)
│   └── 余额宝/零钱通 (Yu'ebao/Lingqiantong)
│
├── 投资 (Investments)
│   ├── 股票 (Stocks)
│   ├── 基金 (Funds)
│   │   ├── 股票基金 (Stock Funds)
│   │   ├── 债券基金 (Bond Funds)
│   │   ├── 混合基金 (Mixed Funds)
│   │   ├── 指数基金 (Index Funds)
│   │   └── 货币基金 (Money Market Funds)
│   ├── 债券 (Bonds)
│   ├── 期货 (Futures)
│   ├── 期权 (Options)
│   └── 数字资产 (Digital Assets)
│
├── 固定资产 (Fixed Assets)
│   ├── 房产 (Real Estate)
│   ├── 车辆 (Vehicles)
│   └── 其他固定资产 (Other Fixed Assets)
│
├── 保险 (Insurance)
│   ├── 人寿保险 (Life Insurance)
│   ├── 健康保险 (Health Insurance)
│   └── 财产保险 (Property Insurance)
│
└── 其他资产 (Other Assets)
    ├── 公积金 (Housing Fund)
    ├── 社保 (Social Security)
    └── 其他 (Others)
```

**Liabilities (负债):**
```
负债 (Liabilities)
├── 信用卡 (Credit Cards)
│   ├── 招商银行信用卡 (CMB Credit Card)
│   └── 工商银行信用卡 (ICBC Credit Card)
│
├── 贷款 (Loans)
│   ├── 房贷 (Mortgage)
│   ├── 车贷 (Auto Loan)
│   ├── 消费贷 (Consumer Loan)
│   └── 经营贷 (Business Loan)
│
└── 其他负债 (Other Liabilities)
    ├── 亲友借款 (Personal Loans)
    └── 花呗/借呗 (Huabei/Jiebei)
```

### 6.2 Income Categories (收入分类)

```
收入 (Income)
├── 工资薪金 (Salary & Wages)
├── 奖金 (Bonus)
├── 投资收益 (Investment Returns)
│   ├── 利息收入 (Interest)
│   ├── 股息分红 (Dividends)
│   └── 资本利得 (Capital Gains)
├── 副业收入 (Side Income)
├── 租金收入 (Rental Income)
└── 其他收入 (Other Income)
```

### 6.3 Expense Categories (支出分类)

```
支出 (Expenses)
├── 餐饮美食 (Food & Dining)
│   ├── 早餐 (Breakfast)
│   ├── 午餐 (Lunch)
│   ├── 晚餐 (Dinner)
│   └── 零食饮料 (Snacks & Drinks)
│
├── 交通出行 (Transportation)
│   ├── 公共交通 (Public Transit)
│   ├── 打车 (Taxi/Rideshare)
│   ├── 加油 (Gas)
│   └── 停车 (Parking)
│
├── 购物消费 (Shopping)
│   ├── 日用品 (Daily necessities)
│   ├── 服装 (Clothing)
│   └── 电子产品 (Electronics)
│
├── 居住生活 (Housing)
│   ├── 房租/房贷 (Rent/Mortgage)
│   ├── 水电燃气 (Utilities)
│   └── 物业费 (Property Management)
│
├── 医疗健康 (Healthcare)
├── 教育培训 (Education)
├── 休闲娱乐 (Entertainment)
├── 人情往来 (Social/Gifts)
└── 其他支出 (Other Expenses)
```

---

## 7. Account Type Handling

### 7.1 Account Type Icons

| Account Type | Icon | Color | Description |
|--------------|------|-------|-------------|
| 储蓄卡 (Savings) | 🏦 | Blue | Bank debit card |
| 信用卡 (Credit) | 💳 | Gold/Purple | Credit card |
| 现金 (Cash) | 💵 | Green | Physical cash |
| 支付宝 (Alipay) | 📱 | Blue | Alipay balance |
| 微信 (WeChat) | 💬 | Green | WeChat Pay |
| 基金 (Fund) | 📈 | Orange | Investment fund |
| 股票 (Stock) | 📊 | Red | Stock holdings |
| 公积金 (Housing Fund) | 🏠 | Blue | Housing provident fund |
| 社保 (Social Security) | 🛡️ | Green | Social insurance |

### 7.2 Account Grouping Pattern

```
┌─────────────────────────────────────────────┐
│  银行账户 (Bank Accounts)                    │
├─────────────────────────────────────────────┤
│  🏦 招商银行储蓄卡    尾号1234    ¥50,000.00 │
│  🏦 工商银行工资卡    尾号5678    ¥12,345.67 │
├─────────────────────────────────────────────┤
│  电子账户 (E-wallets)                        │
├─────────────────────────────────────────────┤
│  📱 支付宝余额                   ¥2,345.67  │
│  💬 微信零钱                     ¥1,234.56  │
├─────────────────────────────────────────────┤
│  投资账户 (Investment Accounts)              │
├─────────────────────────────────────────────┤
│  📈 天天基金                   ¥100,000.00  │
│  📊 东方财富证券                 ¥50,000.00  │
└─────────────────────────────────────────────┘
```

---

## 8. Stock Market (A股) Display Conventions

### 8.1 Index Display

**Major Indices:**
- 上证指数 (Shanghai Composite): 000001.SH
- 深证成指 (Shenzhen Component): 399001.SZ
- 创业板指 (ChiNext): 399006.SZ
- 沪深300 (CSI 300): 000300.SH

**Display Format:**
```
┌─────────────────────────────────────────────┐
│  上证指数         3,234.56    +23.45 (+0.73%)│
│  [Mini Chart]                                │
├─────────────────────────────────────────────┤
│  深证成指        10,567.89    -45.67 (-0.43%)│
│  [Mini Chart]                                │
└─────────────────────────────────────────────┘
```

### 8.2 Individual Stock Display

**Stock Card:**
```
┌─────────────────────────────────────────────┐
│  贵州茅台 600519.SH           1,888.00      │
│                               +23.45 (+1.26%)│
│  今开 1,870.00  最高 1,895.00                │
│  昨收 1,864.55  最低 1,865.00                │
│  成交量 12,345手  成交额 23.45亿             │
└─────────────────────────────────────────────┘
```

**Key Metrics:**
- 最新价 (Current Price)
- 涨跌幅 (Change %)
- 涨跌额 (Change Amount)
- 今开/昨收 (Open/Previous Close)
- 最高/最低 (High/Low)
- 成交量 (Volume)
- 成交额 (Turnover)
- 换手率 (Turnover Rate)
- 市盈率 (P/E Ratio)
- 市净率 (P/B Ratio)
- 总市值 (Market Cap)
- 流通市值 (Float Market Cap)

### 8.3 K-line (Candlestick) Chart Conventions

**Color Scheme:**
- 阳线 (Bullish/Up): Red fill or Red hollow
- 阴线 (Bearish/Down): Green fill
- Doji: Gray or same as previous

**Technical Indicators:**
- MA (Moving Average): MA5, MA10, MA20, MA60
- MACD: DIF, DEA, MACD bar
- KDJ: K, D, J lines
- RSI: 6, 12, 24 periods
- BOLL: Upper, Middle, Lower bands

**Time Periods:**
- 分时 (Intraday)
- 日K (Daily)
- 周K (Weekly)
- 月K (Monthly)
- 5分/15分/30分/60分 (5/15/30/60 min)

### 8.4 Stock List Display

**Table Format:**
```
┌─────────────────────────────────────────────┐
│  代码    名称      最新价    涨跌幅   涨跌额  │
├─────────────────────────────────────────────┤
│  600519  贵州茅台  1,888.00  +1.26%  +23.45 │
│  000858  五粮液    188.50    -0.53%  -1.00  │
│  601318  中国平安  48.90     +0.82%  +0.40  │
└─────────────────────────────────────────────┘
```

**Sorting Options:**
- 涨跌幅 (Change %)
- 成交量 (Volume)
- 成交额 (Turnover)
- 换手率 (Turnover Rate)
- 市盈率 (P/E)

### 8.5 Trading Session Times

```
09:15-09:25  集合竞价 (Call Auction)
09:25-09:30  不接受撤单 (No Cancellation)
09:30-11:30  上午连续竞价 (Morning Continuous)
13:00-14:57  下午连续竞价 (Afternoon Continuous)
14:57-15:00  收盘集合竞价 (Closing Auction)
```

**Display Convention:**
- Show "交易中" (Trading) during sessions
- Show "已收盘" (Closed) after 15:00
- Show "休市" (Holiday) on non-trading days

---

## 9. Common Chinese App UI Patterns

### 9.1 Bottom Navigation (底部导航)

**Standard Implementation:**
- 4-5 tabs maximum
- Icon + Text label
- Active state: Filled icon + Brand color
- Inactive state: Outline icon + Gray text
- Safe area handling for iPhone X+

### 9.2 Header Patterns

**Standard Header:**
```
┌─────────────────────────────────────────────┐
│  [Back]    Page Title            [Action]   │
└─────────────────────────────────────────────┘
```

**Home Header:**
```
┌─────────────────────────────────────────────┐
│  Logo      [Search Bar]       [Avatar/Msg]  │
└─────────────────────────────────────────────┘
```

### 9.3 Card Patterns

**Information Card:**
```css
.card {
  background: #FFFFFF;
  border-radius: 12px;
  padding: 16px;
  margin: 0 16px 12px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
}
```

**Interactive Card:**
- Tap feedback: Scale down slightly (0.98)
- Active opacity: 0.7
- Ripple effect (Android)

### 9.4 Form Patterns

**Input Fields:**
- Large touch targets (44px minimum height)
- Clear labels above inputs
- Error states with red border + message
- Success states with green checkmark

**Picker/Selector:**
- Bottom sheet for options
- Scroll picker for dates/numbers
- Search filter for long lists

### 9.5 Modal/Dialog Patterns

**Bottom Sheet (最常用):**
- Rounded top corners (16-20px)
- Drag handle at top
- Semi-transparent backdrop
- Swipe down to dismiss

**Alert Dialog:**
- Centered popup
- Title + Content + Buttons
- Cancel (left) + Confirm (right)
- Red for destructive actions

### 9.6 Tab Patterns

**Segmented Control:**
```
┌─────────────────────────────────────────────┐
│  [  周  ] [  月  ] [  年  ] [  全部  ]       │
└─────────────────────────────────────────────┘
```

**Scrollable Tabs:**
- For many options (5+)
- Horizontal scroll
- Active indicator (underline)

### 9.7 Search Patterns

**Search Bar:**
- Magnifying glass icon
- Placeholder: "搜索" (Search)
- Recent searches below
- Hot searches/recommendations
- Voice search option

---

## 10. User Expectations

### 10.1 Performance Expectations

- **Load Time:** < 2 seconds for main content
- **Animation:** 60fps, smooth transitions
- **Offline:** Basic viewing without network
- **Refresh:** Pull-to-refresh with feedback

### 10.2 Security Expectations

- **Biometric Login:** Face ID / Fingerprint
- **Session Timeout:** Auto-lock after inactivity
- **Privacy Mode:** Hide sensitive data by default
- **Transaction Confirmation:** Password/biometric for transfers

### 10.3 Data Accuracy

- **Real-time Updates:** Stock prices, balances
- **Precise Numbers:** Always 2 decimal places for currency
- **Consistent Formatting:** Same format throughout app
- **Clear Labels:** Units (元, 万, 亿) always shown

### 10.4 Localization Details

**Number Formatting:**
```javascript
// Chinese number formatting
const formatCurrency = (amount) => {
  return new Intl.NumberFormat('zh-CN', {
    style: 'currency',
    currency: 'CNY',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2
  }).format(amount);
};
// Output: ¥1,234.56
```

**Large Number Formatting:**
```javascript
const formatLargeNumber = (num) => {
  if (num >= 100000000) {
    return (num / 100000000).toFixed(2) + '亿';
  } else if (num >= 10000) {
    return (num / 10000).toFixed(2) + '万';
  }
  return num.toFixed(2);
};
```

**Date Formatting:**
```javascript
const formatDate = (date) => {
  return new Intl.DateTimeFormat('zh-CN', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    weekday: 'long'
  }).format(date);
};
// Output: 2024年1月15日星期一
```

### 10.5 Common Gestures

- **Pull-down:** Refresh content
- **Swipe left:** Delete/Edit actions
- **Long press:** Context menu
- **Pinch zoom:** Charts
- **Double tap:** Quick action (like, favorite)

### 10.6 Feedback Patterns

**Success:**
- Toast message: "操作成功" (Operation successful)
- Green checkmark icon
- Haptic feedback (vibration)

**Error:**
- Toast message: "操作失败，请重试" (Failed, please retry)
- Red X icon
- Shake animation

**Loading:**
- Spinner with "加载中..." (Loading...)
- Progress bar for determinate operations
- Skeleton screens for content

---

## 11. Implementation Recommendations

### 11.1 Component Library Suggestions

**Essential Components:**
1. **AssetCard** - Hero card with total assets, privacy toggle
2. **TransactionItem** - List item with icon, description, amount
3. **AccountCard** - Account display with type icon and balance
4. **StockQuote** - Real-time stock price display
5. **FundCard** - Fund name, NAV, return rate
6. **CategoryIcon** - Expense/income category icons
7. **AmountText** - Formatted currency display with color
8. **PercentBadge** - Percentage with color coding
9. **ProgressRing** - Circular progress for goals
10. **DateHeader** - Date group header for lists

### 11.2 State Management

**Key States to Track:**
- User authentication status
- Privacy mode (show/hide amounts)
- Selected time period (daily/weekly/monthly/yearly)
- Sort preferences
- Filter selections
- Refresh timestamp

### 11.3 Data Formatting Utilities

```typescript
// Amount formatting
formatCNY(amount: number): string
formatLargeAmount(amount: number): string  // 万/亿
formatPercent(value: number): string
formatDate(date: Date, format: 'full' | 'short' | 'relative'): string

// Color utilities
getProfitLossColor(value: number): string  // Red for positive, Green for negative
getAccountTypeColor(type: AccountType): string
```

### 11.4 Accessibility Considerations

- **Font Scaling:** Support system font size preferences
- **Color Blindness:** Don't rely solely on red/green; use icons (+/-) too
- **Screen Reader:** Proper labels for all interactive elements
- **Touch Targets:** Minimum 44x44px for all interactive elements

### 11.5 Performance Optimization

- **Lazy Loading:** Load data as user scrolls
- **Image Optimization:** WebP format, lazy load images
- **Caching:** Cache frequently accessed data
- **Pagination:** Load transactions in pages (20-50 items)
- **Debounce:** Debounce search input (300ms)

---

## Appendix A: Common Chinese Financial Terms

| Chinese | English | Context |
|---------|---------|---------|
| 总资产 | Total Assets | Net worth display |
| 净资产 | Net Worth | Assets - Liabilities |
| 余额 | Balance | Account balance |
| 收益 | Return/Income | Investment returns |
| 本金 | Principal | Original investment |
| 浮动盈亏 | Floating P&L | Unrealized gains/losses |
| 已实现盈亏 | Realized P&L | Sold positions |
| 涨幅 | Gain % | Price increase |
| 跌幅 | Loss % | Price decrease |
| 买入 | Buy | Purchase action |
| 卖出 | Sell | Sale action |
| 持仓 | Position | Current holdings |
| 自选 | Favorites | Watchlist |
| 账单 | Bill/Statement | Payment due |
| 还款 | Repayment | Loan/credit payment |
| 转账 | Transfer | Money transfer |
| 充值 | Top-up | Add funds |
| 提现 | Withdraw | Cash out |

## Appendix B: Recommended Libraries

**For React Native / Expo:**
- `react-native-reanimated` - Smooth animations
- `react-native-chart-kit` or `victory-native` - Charts
- `react-native-gesture-handler` - Gestures
- `expo-local-authentication` - Biometrics
- `react-native-svg` - SVG icons and charts
- `dayjs` or `date-fns` - Date formatting
- `numeral` or `Intl.NumberFormat` - Number formatting

## Appendix C: Design Tokens

```typescript
// Color tokens for Chinese financial app
export const colors = {
  // Brand
  primary: '#1677FF',
  primaryDark: '#0958D9',
  primaryLight: '#E6F4FF',
  
  // Semantic - CHINESE CONVENTION
  profit: '#FF4D4F',      // Red = positive/gain
  loss: '#00B578',         // Green = negative/loss
  neutral: '#8C8C8C',      // Gray = unchanged
  
  // Neutral
  text: '#1F1F1F',
  textSecondary: '#8C8C8C',
  textTertiary: '#BFBFBF',
  background: '#F5F5F5',
  card: '#FFFFFF',
  border: '#E8E8E8',
  
  // Category icons
  food: '#FF6B35',
  transport: '#1677FF',
  shopping: '#722ED1',
  housing: '#13C2C2',
  entertainment: '#EB2F96',
  healthcare: '#52C41A',
  education: '#FAAD14',
  social: '#2F54EB',
};

// Spacing
export const spacing = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  xxl: 24,
};

// Border radius
export const borderRadius = {
  sm: 4,
  md: 8,
  lg: 12,
  xl: 16,
  full: 9999,
};

// Typography
export const typography = {
  amountLarge: {
    fontSize: 32,
    fontWeight: '700',
    fontVariantNumeric: ['tabular-nums'],
  },
  amountMedium: {
    fontSize: 24,
    fontWeight: '600',
    fontVariantNumeric: ['tabular-nums'],
  },
  amountSmall: {
    fontSize: 16,
    fontWeight: '500',
    fontVariantNumeric: ['tabular-nums'],
  },
  body: {
    fontSize: 14,
    fontWeight: '400',
  },
  caption: {
    fontSize: 12,
    fontWeight: '400',
  },
};
```

---

*Document generated for Family Fire app development reference.*
*Last updated: 2026*
