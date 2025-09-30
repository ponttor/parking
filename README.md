# Parking Lot Backend Challenge

Platogo Backend Developer Challenge 2025.

## Tech stack

- Ruby 3.3.x
- Rails 7.x
- SQLite
- Minitest

## Setup

```bash
git clone <repo>
cd <repo>
bundle install
bin/rails db:create db:migrate
bin/rails db:seed
bin/rails s
```

## Tests

Run all tests with:

```bash
bin/rails test
```

## Business rules

### States

```unpaid – ticket just issued, not paid yet.
paid – ticket paid, valid for 15 minutes (grace period).
used – ticket consumed at exit.
```

### Grace period

```15 minutes after payment, ticket can be used to exit.
After the grace period expires, ticket is considered invalid for exit.
```

### Payment

```Ticket can only be paid if it is unpaid or its grace period has expired.
Re-payment after grace expiry resets paid_at and valid_until.
```

### Exit

```Ticket can only be used (paid → used) within the grace period.
Exit is idempotent: calling /use multiple times keeps the ticket used.
```

### Capacity

```Total parking spaces are limited (Parking::CAPACITY, default 54).
New tickets cannot be issued when the parking is full.
Occupied = all tickets not yet used.
```

## API Endpoints

### Tickets

```Create ticket
POST /api/tickets
Issue a new parking ticket.

201 Created – returns new ticket.
422 Unprocessable Entity – if parking is full.

Example response:
{
  "barcode": "4b55c538ea4c1538",
  "issued_at": "2025-09-28T09:00:00Z"
}
```

```Show ticket
GET /api/tickets/:barcode
Return ticket details and current price snapshot.

Example response:
{
  "barcode": "4b55c538ea4c1538",
  "issued_at": "2025-09-28T09:00:00Z",
  "hours_started": 2,
  "price": 4
}
```

```Pay ticket
POST /api/tickets/:barcode/payments
Pay for a ticket.

Body:
{ "payment": { "payment_option": "card" } }

200 OK – payment accepted.
422 Unprocessable Entity – invalid state.

Example response:
{
  "barcode": "4b55c538ea4c1538",
  "state": "paid",
  "payment_option": "card",
  "price": 4,
  "paid_at": "2025-09-28T09:06:11Z",
  "valid_until": "2025-09-28T09:21:11Z"
}
```

```Ticket state for gate
GET /api/tickets/:barcode/state
Logical state used by the gate.

Example response:
{ "state": "paid" }
```

```Use ticket (exit)
POST /api/tickets/:barcode/use
Mark ticket as used when vehicle exits.

200 OK – success (idempotent, returns 200 if already used).
422 Unprocessable Entity – invalid state or grace period expired.

Example response:
{
  "barcode": "4b55c538ea4c1538",
  "state": "used",
  "paid_at": "2025-09-28T09:06:11Z",
  "valid_until": "2025-09-28T09:21:11Z",
  "used_at": "2025-09-28T09:12:05Z"
}
```

### Parking

```Free spaces
GET /api/free-spaces
Return parking occupancy snapshot.
Example response:
{
  "capacity": 54,
  "occupied": 10,
  "free_spots": 44,
  "as_of": "2025-09-28T09:06:11Z"
}
```

Each physical parking place is represented by a row in the parking_slots table.
A total of Parking::CAPACITY slots are created (default: 54).
Each slot has a foreign key ticket_id.

When a new ticket is issued (POST /api/tickets), the issuance service atomically assigns a free slot to that ticket.
When a ticket is used (POST /api/tickets/:barcode/use), the slot is released (ticket_id is set back to NULL).
A unique partial index on parking_slots.ticket_id ensures that a ticket can never occupy more than one slot.

This means:
capacity = total number of slots,
occupied = count of slots with a non-null ticket_id,
free_spots = count of slots without a ticket.
