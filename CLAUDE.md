# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

TripSplitApp is a native iOS expense-splitting app built with SwiftUI and SwiftData. It helps groups manage shared trip expenses and calculate optimal settlements.

## Build & Run

```bash
# Open in Xcode (primary workflow)
open TripSplitApp.xcodeproj

# Build from command line
xcodebuild -project TripSplitApp.xcodeproj -scheme TripSplitApp -configuration Debug

# Run tests (no test targets currently configured)
xcodebuild test -project TripSplitApp.xcodeproj -scheme TripSplitApp -destination 'platform=iOS Simulator,name=iPhone 16'
```

There is no linting configuration. Xcode's built-in Swift compiler warnings serve as the primary code quality check.

## Architecture

**Stack:** SwiftUI + SwiftData, no external dependencies, iOS 26.2+ target.

**Data models** are in `Models.swift` using `@Model` decorated classes persisted via SwiftData:
- `Trip` → has `participants` (Person[]), `expenses` (Expense[]), `paymentRecords` (PaymentRecord[])
- `Person` → has balance methods: `totalPaid()`, `totalOwed()`, `netBalance()`
- `Expense` → has `shares` (ExpenseShare[]) and `sharedItems` (SharedItem[])
- `SharedItem` → supports `customShares` (Dictionary) and `isCustomSplit` for flexible per-person splitting
- `Friend` → global contact directory separate from trip participants

**Expense split strategies** (SplitType enum):
- `even` — split evenly among all trip participants
- `shares` — custom ratio-based splitting
- `item` — itemized line items, with optional shared items that can use custom share ratios

**Settlement algorithm** in `SettlementView.swift` calculates the minimum number of payment transfers between participants using a graph-based approach.

**Navigation flow:**
```
TripListView → TripDetailView → ExpenseDetailView
                              → SettlementView
                              → AddExpenseView (sheet)
                              → AddPersonToTripView (sheet)
```

**State management:** No ViewModel layer. Views use `@Environment(\.modelContext)` for SwiftData writes and `@Query` for reactive reads. Local UI state uses `@State`.

**Color theming** is centralized in `ColorTheme.swift` — a sunset/ocean palette used for participant color assignment and UI accents.

**Receipt photos** are captured via `ImagePickerHelper.swift` and stored as `Data` directly on the `Expense` model (no external storage).

## Key Files

| File | Purpose |
|------|---------|
| `Models.swift` | All SwiftData models and domain logic |
| `AddExpenseView.swift` | Expense creation with split type selection |
| `EditExpenseView.swift` | Expense editing — mirrors AddExpenseView logic |
| `SettlementView.swift` | Balance calculation and payment optimization |
| `LineItemSheets.swift` | UI for itemized expense line items and shared items |

## Important Patterns

- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` is set project-wide, so all model mutations are on the main actor by default.
- Cascade delete rules are set on relationships — deleting a `Trip` deletes all its `Expense`, `Person`, and `PaymentRecord` children.
- The `SharedItem.customShares` dictionary maps person names (not IDs) to share counts, which must be kept consistent when participants are renamed or removed.
