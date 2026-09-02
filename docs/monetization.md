# Monetization design

The MVP defines six optional offers. All IDs are disabled by default and must be created in Roblox Creator Hub before use.

| Key | Roblox type | Player benefit |
|---|---|---|
| `FounderClub` | Subscription | 10% higher cycle and mission rewards while subscribed |
| `AutomationPro` | Game pass | Auto-run plus a shorter cycle cooldown |
| `ExecutiveDashboard` | Game pass | Advanced company-efficiency metrics |
| `StarterCapital` | Developer product | 1,500 units of in-game company cash |
| `FocusBoost` | Developer product | Five focused revenue cycles |
| `RevenueSprint` | Developer product | Two-times cycle revenue for 15 minutes |

No price is hard-coded into the user interface. Roblox shows the current official price in its purchase UI.

## Revenue truth

`PurchaseGranted`, pass confirmation, and subscription-status events are operational signals. They are not proof of a specific Robux amount or payout. Use Creator Hub's official revenue and payout reporting for booked revenue.

## Prohibited routes in this project

- external checkout for Roblox benefits;
- exchanging Robux or Roblox items outside official systems;
- hidden charges or misleading scarcity;
- paid randomized rewards;
- autonomous price changes;
- guaranteed-income claims.

## Initial commercial sequence

1. Validate that players understand and enjoy the core cycle.
2. Improve D1 and D7 retention.
3. Demonstrate the real utility of automation and dashboard benefits.
4. Activate only the smallest offer set needed for measurement.
5. Use Creator Hub figures to evaluate actual revenue; do not infer it from prompts or receipts alone.
