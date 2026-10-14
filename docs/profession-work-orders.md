# Profession work-order system

## Goal

Build a small guild commerce workflow rather than a request board that disappears when the craft is done. A work order records the agreement, an invoice records what was delivered and charged, and a confirmed payment produces a permanent bookkeeping entry.

## Data model

```lua
WorkOrder = {
    id, revision, guildKey, issuer, crafter, createdAt, status,
    rows = {
        { id, type, itemID, description, quantity, fulfilledQuantity,
          agreedUnitCostCopper, materialOwner }
    }
}

Invoice = {
    id, revision, workOrderID, issuer, recipient, issuedAt, status,
    rows = {
        { id, workOrderRowID, type, quantity, unitCostCopper, amountCopper }
    },
    totalCopper, paidCopper
}

Payment = {
    id, invoiceID, amountCopper, method, receivedAt, confirmedBy
}
```

Work-order rows can be fulfilled independently. For example, ten requested items might be delivered in two batches and result in two invoices. Each invoice copies the agreed prices and delivered quantities into its own rows; later changes to the work order must not alter an issued invoice.

Store currency as integer copper, not floating-point gold. Calculate each invoice row's `amountCopper` from its quantity and unit cost.

## Workflow

Work order:

`Open → Accepted → In progress → Partially fulfilled / Fulfilled → Invoiced → Closed`

Invoice:

`Draft → Sent → Partially paid / Paid → Booked`

“Paid” means the crafter has confirmed receiving the money, not merely that an invoice mail was sent. “Booked” creates a permanent bookkeeping entry linked to the payment. Booking must be idempotent so the same payment cannot be booked twice.

## Mailbox integration

When the crafter opens a mailbox, show completed-but-uninvoiced work orders with a **Prepare invoice mail** action. The addon prepares a readable breakdown and invoice ID; the player confirms the actual send. Do not depend on unattended mail sending, because client API and security restrictions may vary.

Incoming payment mail can be matched using the invoice ID, sender, and amount. If the match is uncertain, ask for confirmation instead of automatically marking an invoice paid. Cash on delivery (COD) can be an optional payment path when an item is attached, but should not be the only path.

## Sharing and persistence

- Broadcast work-order changes to the guild.
- Keep invoice and payment details between the two parties.
- Use mail as the durable invoice copy; addon messages update the UI when both players are online.
- Give every record a unique ID and revision. Deduplicate messages and reject older revisions so reconnects and refreshes cannot create duplicate invoices or bookings.
- Cache records locally so the UI remains useful when the other party is offline, while showing when cached information was last updated.

## UI

Add a **Work Orders** tab with views for **Open Orders**, **My Jobs**, **Invoices**, and **Ledger**. The profession roster can help identify possible crafters, but profession skill alone does not prove a character knows a particular recipe; the crafter must confirm capability.

## Decision before implementation

Decide whether work-order prices should be visible to the whole guild. Invoice and payment details should remain private to the two parties regardless.
