# Fleet Foodies — Fleet Scheduling & Governance Engine

## Overview
Engineered a relational PostgreSQL database schema, automated PL/pgSQL governance triggers, and scheduling rules in Supabase to manage multi-vendor logistics, enforce location cooldown schedules, and manage vendor compliance.

## Key Features & Operations Logic
* **Logistics & Scheduling Architecture**: Relational models linking vendors, office park / event locations, and recurring meal service allocations.
* **Automated 3-Strike Governance Engine**: PL/pgSQL trigger (`process_vendor_strike_governance()`) automatically calculates strikes upon violation entries and updates vendor statuses (`Active` $\rightarrow$ `Probation` $\rightarrow$ `Suspended`).
* **Variety Shield Cooldown Tracking**: Data structures preventing menu fatigue by tracking vendor location history.
* **Row Level Security (RLS)**: PostgreSQL access policies securing internal vendor contact details and strike audit logs.

## Repository Structure
* `schema.sql` — PostgreSQL DDL scripts, procedural governance triggers, RLS policies, and sample logistics data.
