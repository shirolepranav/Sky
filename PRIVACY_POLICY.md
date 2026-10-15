# Sky Privacy Policy

**Last updated:** August 7, 2026

This is a draft prepared for hosting at `https://sky.app/privacy` (the URL
declared in `AppBranding.swift`). It is written to match Sky's actual data
handling as implemented in the codebase — not aspirational language. **This is
not legal advice; have a lawyer review it before publishing, especially the
governing-law and liability-adjacent sections.**

---

## The short version

Sky doesn't collect your personal data. Nothing you do in Sky — the apps you
block, the videos you record to unlock them, your location, your screen-time
habits — is uploaded anywhere. It stays on your device, or in your own private
iCloud account that only you can access.

## What Sky does

Every day at a time you choose, Sky pauses the apps you pick, using Apple's
Screen Time (Family Controls) framework. To unlock them for the day you take a
short walk outside and record a 5-second clip of the sky. Sky checks it on your
device, together with your location and recent step count, before removing the
block.

## Information Sky does not collect

Sky has no analytics SDKs, no advertising SDKs, and no servers of its own that
receive data from your device. Specifically:

- **Identifiers.** No name, email, advertising ID, or device identifier is
  collected or transmitted.
- **Screen-time data.** Which apps you block, your daily limits, and how you
  use them never leave your device.
- **Usage or diagnostic data.** No third-party analytics or crash-reporting
  SDK is included in Sky.

## Location

Sky uses your location transiently, on-device, while you're recording a
verification video — to confirm you're actually outside. Before anything is
stored (for badges like "Wanderer"), your coordinates are rounded to 0.01°
(roughly a 1 km / 0.6 mi grid square) and stored only in your own private
iCloud account alongside your streak data (see **iCloud sync** below). Raw,
unrounded location is never stored or transmitted.

## Verification clips and your sky photos

The 5-second clip you record to unlock your apps is analyzed entirely on-device
using Apple's Vision framework, Core Location, and your phone's step counter.
The video file is written to a temporary location and **deleted immediately**
after analysis completes — whether verification passes or fails. It is never
uploaded, never stored permanently, and never leaves your device.

When a verification passes, Sky keeps **one still photo of the sky** from that
clip so you can see and share "today's sky". These photos:

- stay on your device only — they are never uploaded, never synced to iCloud,
  and excluded from device backups;
- carry no location or other metadata;
- are limited to the last 30 days, and older ones are deleted automatically;
- can all be deleted at any time in **Settings → Your skies**.

A photo leaves your device only if you share it yourself.

## iCloud sync

If you're signed into iCloud, Sky syncs your streak and progress data (current
streak, longest streak, verification count, unlocked badges, and similar
counters) to **your own private CloudKit database** — the same private-storage
system used by apps like Notes or Reminders. This data is:

- Accessible only to you, through your own iCloud account.
- Not accessible to Sky's developer, and not stored on any Sky-operated server
  — Sky has none.
- Limited to the counters above. It does not include verification videos,
  raw location, or emergency-unlock reasons (see below).

## Emergency-unlock reasons

If you use Sky's emergency unlock, the reason you select stays in an on-device
App Group container shared only between Sky and its extensions. It is never
synced to iCloud and never leaves your device.

## Purchases

Sky Pro is a one-time, non-consumable purchase handled entirely by Apple
through StoreKit. Sky does not process payments itself and does not store
your payment information, purchase history, or billing details on any server
— Apple retains that as part of your Apple Account.

## Notifications

Sky's reminders (morning check-in, pre-block warning, block-start, and the
Pro streak-risk warning) are scheduled locally on your device. Sky does not
use push notifications and does not register with any remote notification
service, so no notification content or delivery data is transmitted anywhere.

## Photos

Sky requests photo library **add-only** access solely so you can save a
streak-card image you've chosen to share. Sky never reads your existing photo
library.

## Permissions Sky requests, and why

| Permission | Why |
|---|---|
| Screen Time (Family Controls) | To let you select and pause your own apps each day |
| Camera | To record the short outdoor verification clip |
| Location (When In Use) | To confirm you're outdoors during verification |
| Motion & Fitness | To read your recent step count — the short walk verification asks for |
| Notifications | For the local reminders described above |
| Photos (Add Only) | To save a streak card you choose to share |

## Children's privacy

Sky is not directed at children and does not knowingly collect information
from anyone, regardless of age — there is nothing to collect in the first
place.

## Data retention and deletion

Because Sky doesn't operate a server, there's no remote copy of your data to
delete. Deleting the app removes all on-device data. If you've used iCloud
sync, you can remove your synced data by disabling iCloud for Sky in your
device's Settings, or by deleting the app's iCloud data via **Settings →
Apps → iCloud** on your device.

## Changes to this policy

If Sky's data handling changes, this page will be updated and the "Last
updated" date above will change accordingly.

## Contact

Questions about this policy: **support@sky.app**
