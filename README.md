# Fleet Foodies — Relational Database & Business Rules Engine

## Overview
Engineered a production-grade relational database schema on PostgreSQL (Supabase) to manage property zones, food truck vendor operations, and automated booking governance for **Fleet Foodies**.

## Architecture & Schema
* **`communities`**: Tracks property locations, addresses, and zone designations.
* **`food_trucks`**: Stores vendor profiles, cuisine types, strike penalties, and operational statuses (`Active`, `Suspended`).
* **`schedules`**: Serves as a junction table connecting communities and vendors with specific dates and service statuses.

## Key Business Logic
* **Document Compliance Guardrails**: Automatically blocks booking requests if a vendor's Certificate of Insurance (`coi_expires_at`) or Health Permit is expired or if required documents are unverified (`documents_verified = FALSE`).
* **Variety Shield (14-Day Cooldown)**: Uses date arithmetic (`INTERVAL '14 days'`) to block vendors from repeat bookings at the same community within 14 days.
* **Three-Strike Governance**: Automatically flags and suspends vendors (`fto_status = 'Suspended'`) when operational infractions hit 3 strikes.
* **Unified Eligibility Audit**: Evaluates multi-table joins, subqueries, and conditional `CASE` statements to output real-time booking decisions (`APPROVED` vs `REJECTED`).
