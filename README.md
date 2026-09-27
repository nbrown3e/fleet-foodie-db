# Fleet Foodies — Relational Database & Business Rules Engine

## Overview
Engineered a production-grade relational database schema on PostgreSQL (Supabase) to govern property zones, vendor operations, and automated booking governance for **Fleet Foodies**.

## Architecture & Schema
* **`communities`**: Tracks property locations, addresses, and zone designations.
* **`food_trucks`**: Stores vendor profiles, cuisine types, strike penalties, operational statuses (`Active`, `Suspended`), and compliance verification audit trails.
* **`schedules`**: Serves as a junction table connecting communities and vendors with specific service dates and statuses.

## Key Business Logic & Guardrails
* **Human-in-the-Loop (HITL) Compliance Engine**: Enforces manual Ops review (`verified_by_user_id`, `verified_at`, `documents_verified`) before a vendor can be booked.
* **Document Compliance Guardrails**: Automatically blocks scheduling if a vendor's Certificate of Insurance (`coi_expires_at`) or Health Permit is expired or unverified.
* **Variety Shield (14-Day Cooldown)**: Uses date arithmetic (`INTERVAL '14 days'`) to block vendors from repeat bookings at the same community within 14 days, preventing menu burnout.
* **Three-Strike Governance**: Automatically flags and suspends vendors (`fto_status = 'Suspended'`) when operational infractions hit 3 strikes.
* **Unified Eligibility Audit**: Executes complex multi-table JOINs, subqueries, and conditional `CASE` logic to output real-time `APPROVED` vs `REJECTED` booking decisions.
