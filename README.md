# BudgetCountdown

An iOS home screen widget that shows how much money you have left to spend this billing cycle. Connects to your bank account via Plaid, does the math, and displays a single number. That's it.

## Why

Budgeting apps are overkill if your finances are simple. This widget gives you one glanceable number so you don't have to open anything or think about categories.

## Architecture

```
┌─────────────────┐       ┌──────────────┐       ┌───────┐
│  iOS Widget     │──────▶│  Express API │──────▶│ Plaid │
│  (WidgetKit)    │◀──────│  (Node.js)   │◀──────│       │
└─────────────────┘       └──────────────┘       └───────┘
```

- **iOS app + widget** — SwiftUI app with a WidgetKit home screen widget (small and medium sizes). Shows remaining budget, a progress gauge, and the current billing cycle dates.
- **Backend** — Node/Express server that authenticates with Plaid and returns spending totals for the current cycle. Works with any bank or credit card that Plaid supports.
- **Planned spends** — You can manually add upcoming expenses (stored locally via SwiftData) so they count against your budget before they hit your card.

## Features

- Glanceable widget with remaining budget in large text
- Color-coded: green (fine), orange (getting low), red (over budget)
- Configurable billing cycle start day (defaults to the 24th)
- Manual "planned spend" entries for expenses you know are coming
- Refreshes hourly

## Setup

### Backend

1. Copy `.env.example` to `.env` and fill in your Plaid credentials
2. `npm install`
3. `npm start`

You'll need a [Plaid account](https://plaid.com/) and an access token linked to whichever bank account you want to track. See Plaid's quickstart guide for the link flow.

### iOS

1. Open the Xcode project in `ios/BudgetCountdown`
2. Update the API URL to point to your backend
3. Build and run on your device
4. Add the widget to your home screen

## Requirements

- iOS 17+
- A Plaid account with access to your bank
- Node.js 18+
