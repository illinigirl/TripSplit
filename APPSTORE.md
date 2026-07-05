# App Store Connect Metadata — TripSplit 1.0

Working draft of everything to paste into App Store Connect. Character
limits noted per field.

## App name (30 chars max — must be globally unique)

Preferred, in order (check availability when creating the version):

1. `TripSplit: Trip Expense Split` (29)
2. `TripSplit — Settle Up Easy` (26)
3. `TripSplit: Group Trip Costs` (27)

## Subtitle (30 chars max)

`Group trip expenses, settled` (28)

## Category

- Primary: Finance
- Secondary: Travel

## Keywords (100 chars max, comma-separated)

`vacation,group,travel,settle,receipt,friends,bill,share,tab,owe,itemize,cost,weekend,cabin` (90)

Words already in the name/subtitle (trip, split, expenses, settled) are
indexed automatically — not repeated here.

## Promotional text (170 chars max, editable without review)

`Track shared costs, split restaurant bills item by item, and settle up
with the fewest payments possible — all private, on your device, no
accounts needed.` (154)

## Description (4000 chars max)

```
Splitting expenses on a group trip shouldn't require a spreadsheet — or
an account, or anyone's email address. TripSplit keeps a running tally
of who paid for what and works out the simplest way to settle up, right
on your phone.

SPLIT ANY WAY THE GROUP ACTUALLY PAYS
• Even splits for shared costs like lodging and lift tickets
• Ratio splits when someone should cover more (or less)
• Itemized bills: assign each dish to its person, then split shared
  appetizers or a bottle of wine — evenly or by custom shares

SETTLE UP IN AS FEW PAYMENTS AS POSSIBLE
TripSplit computes the minimum set of transfers to zero everyone out —
no chains of "you pay me, I pay her." Record payments as they happen
and send a friendly settle-up text straight from the app.

EVERYTHING ELSE A TRIP NEEDS
• Snap receipt photos and keep them attached to expenses
• Balances update live as expenses are added
• A friends list so recurring travel buddies are one tap away
• Export a polished PDF trip report to share with the group

PRIVATE BY DESIGN
No accounts. No ads. No analytics. Your data never leaves your device —
TripSplit doesn't even have a server to send it to.

Perfect for ski cabins, beach houses, bachelorette weekends, road
trips, and any adventure where "I'll get this one" needs a scoreboard.
```

## URLs

- Support URL: `https://illinigirl.github.io/TripSplit/`
- Privacy Policy URL: `https://illinigirl.github.io/TripSplit/privacy.html`
- Marketing URL: (optional — can reuse support URL)

## App Privacy section

- Data collection: **Data Not Collected** (answer "No" to all
  collection questions — the app has no networking)

## Age rating questionnaire

All content questions: None/No → expected rating **4+**

## Screenshots (already captured, in `screenshots/appstore/`)

Upload order suggestion (lead with the strongest):

1. `settlement.png` — the headline feature
2. `expenseDetail.png` — itemized split with shared items
3. `tripDetail.png` — balances at a glance
4. `home.png` — trip list

Same order for the iPhone 6.9" and iPad 13" sets.

## What's New (version 1.0)

`Initial release.`

## Export compliance

Already answered in the binary (`ITSAppUsesNonExemptEncryption = NO`)
— App Store Connect won't ask.
