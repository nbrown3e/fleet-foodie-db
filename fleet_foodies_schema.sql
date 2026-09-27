-- ============================================================================
-- FLEET FOODIES DATABASE SCHEMA & BUSINESS RULES ENGINE
-- Engine: PostgreSQL (Supabase)
-- Author: Fleet Foodies Engineering
-- Description: Core schema, data imports, constraint configurations, and 
--              automated business rules (Variety Shield, 3-Strike Rule, & Document Compliance).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. SCHEMA INITIALIZATION & TABLES
-- ----------------------------------------------------------------------------

-- Table 1: Communities (Property / Location Entity)
CREATE TABLE IF NOT EXISTS communities (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    community_name VARCHAR(100) NOT NULL,
    address VARCHAR(255),
    city_state_zip VARCHAR(100),
    zone VARCHAR(20) NOT NULL
);

-- Table 2: Food Trucks (Vendor Entity with Compliance Tracking)
CREATE TABLE IF NOT EXISTS food_trucks (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    truck_name VARCHAR(100) NOT NULL,
    cuisine_type VARCHAR(50) DEFAULT 'Unassigned',
    tier VARCHAR(20) DEFAULT 'Tier 1',
    fto_status VARCHAR(20) DEFAULT 'Active',
    strikes INT DEFAULT 0,
    coi_expires_at DATE,
    health_permit_expires_at DATE,
    documents_verified BOOLEAN DEFAULT FALSE
);

-- Table 3: Schedules (Junction / Bridge Entity)
CREATE TABLE IF NOT EXISTS schedules (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    community_id BIGINT REFERENCES communities(id) ON DELETE CASCADE,
    food_truck_id BIGINT REFERENCES food_trucks(id) ON DELETE CASCADE,
    service_date DATE NOT NULL,
    booking_status VARCHAR(20) DEFAULT 'Scheduled'
);

-- ----------------------------------------------------------------------------
-- 2. SAMPLE DATA INSERTION
-- ----------------------------------------------------------------------------

-- Insert Communities
INSERT INTO communities (community_name, address, city_state_zip, zone)
VALUES 
    ('Abrazo at Rice Hope', '100 Rice Hope Loop', 'Port Wentworth, GA 31407', 'Zone 1'),
    ('Savannah Quarters', '200 Blue Moon Crossing', 'Pooler, GA 31322', 'Zone 2');

-- Insert Food Trucks (Demonstrating Compliance States)
INSERT INTO food_trucks (truck_name, cuisine_type, tier, fto_status, strikes, coi_expires_at, health_permit_expires_at, documents_verified)
VALUES 
    ('Pie Society / British Pie Co.', 'British / Bakery', 'Tier 1', 'Active', 0, '2027-12-31', '2027-12-31', TRUE),
    ('BowTie Barbecue Co.', 'BBQ', 'Tier 1', 'Active', 0, '2025-01-01', '2027-12-31', TRUE), -- Expired COI
    ('Def Burger', 'American / Burgers', 'Tier 1', 'Suspended', 3, '2027-12-31', '2027-12-31', TRUE);

-- Insert Historical & Active Schedules
INSERT INTO schedules (community_id, food_truck_id, service_date, booking_status)
VALUES 
    (1, 1, CURRENT_DATE - INTERVAL '7 days', 'Completed'),   -- Triggered Variety Shield
    (1, 2, CURRENT_DATE - INTERVAL '26 days', 'Completed'),  -- Cooldown Expired
    (2, 1, CURRENT_DATE + INTERVAL '14 days', 'Scheduled');

-- ----------------------------------------------------------------------------
-- 3. BUSINESS RULES ENGINE (FULL GOVERNANCE AUDIT)
-- ----------------------------------------------------------------------------

-- Unified Vendor Eligibility Audit
-- Enforces: 1) Strike Penalties, 2) Document Compliance, 3) Variety Shield (14-Day Cooldown)
SELECT 
    ft.id AS truck_id,
    ft.truck_name,
    ft.cuisine_type,
    ft.strikes,
    ft.fto_status,
    ft.coi_expires_at,
    ft.documents_verified,
    CASE 
        -- Guardrail 1: Strike Suspension Check
        WHEN ft.fto_status = 'Suspended' OR ft.strikes >= 3 
            THEN 'REJECTED: Account Suspended (3+ Strikes)'
        
        -- Guardrail 2: Document Verification & COI Expiration Check
        WHEN ft.documents_verified = FALSE 
            THEN 'REJECTED: Compliance Documents Pending Verification'
        
        WHEN ft.coi_expires_at IS NULL OR ft.coi_expires_at < CURRENT_DATE 
            THEN 'REJECTED: Certificate of Insurance (COI) Expired or Missing'
        
        WHEN ft.health_permit_expires_at IS NULL OR ft.health_permit_expires_at < CURRENT_DATE 
            THEN 'REJECTED: Health Permit Expired or Missing'

        -- Guardrail 3: Variety Shield Check (14-Day Cooldown)
        WHEN EXISTS (
            SELECT 1 
            FROM schedules s 
            WHERE s.food_truck_id = ft.id 
              AND s.community_id = 1 
              AND s.service_date >= (CURRENT_DATE - INTERVAL '14 days')
        ) THEN 'REJECTED: Variety Shield Active (Served within 14 Days)'
        
        -- Default: Cleared for Booking
        ELSE 'APPROVED: Eligible for Booking'
    END AS booking_decision
FROM food_trucks ft
ORDER BY ft.id ASC;    service_date DATE NOT NULL,
    booking_status VARCHAR(20) DEFAULT 'Scheduled'
);

-- ----------------------------------------------------------------------------
-- 2. SAMPLE DATA INSERTION
-- ----------------------------------------------------------------------------

-- Insert Communities
INSERT INTO communities (community_name, address, city_state_zip, zone)
VALUES 
    ('Abrazo at Rice Hope', '100 Rice Hope Loop', 'Port Wentworth, GA 31407', 'Zone 1'),
    ('Savannah Quarters', '200 Blue Moon Crossing', 'Pooler, GA 31322', 'Zone 2');

-- Insert Food Trucks
INSERT INTO food_trucks (truck_name, cuisine_type, tier, fto_status, strikes)
VALUES 
    ('Pie Society / British Pie Co.', 'British / Bakery', 'Tier 1', 'Active', 0),
    ('BowTie Barbecue Co.', 'BBQ', 'Tier 1', 'Active', 0),
    ('Def Burger', 'American / Burgers', 'Tier 1', 'Suspended', 3);

-- Insert Historical & Active Schedules
INSERT INTO schedules (community_id, food_truck_id, service_date, booking_status)
VALUES 
    (1, 1, CURRENT_DATE - INTERVAL '7 days', 'Completed'),   -- Served 7 days ago (Shield Trigger)
    (1, 2, CURRENT_DATE - INTERVAL '26 days', 'Completed'),  -- Served 26 days ago (Cooldown Expired)
    (2, 1, CURRENT_DATE + INTERVAL '14 days', 'Scheduled');

-- ----------------------------------------------------------------------------
-- 3. CORE ANALYTICAL QUERIES
-- ----------------------------------------------------------------------------

-- Query A: Communities per Zone Breakdown
SELECT 
    zone, 
    COUNT(*) AS total_communities 
FROM communities 
GROUP BY zone 
ORDER BY total_communities DESC;

-- Query B: Cuisine Distribution
SELECT 
    cuisine_type, 
    COUNT(*) AS total_trucks 
FROM food_trucks 
GROUP BY cuisine_type 
ORDER BY total_trucks DESC;

-- ----------------------------------------------------------------------------
-- 4. BUSINESS RULES ENGINE (VARIETY SHIELD & 3-STRIKE GOVERNANCE)
-- ----------------------------------------------------------------------------

-- Unified Vendor Eligibility Audit
-- Evaluates both the 14-Day Cooldown (Variety Shield) and Strike Penalties
SELECT 
    ft.id AS truck_id,
    ft.truck_name,
    ft.cuisine_type,
    ft.strikes,
    ft.fto_status,
    CASE 
        -- Rule 1: Account Suspension Check
        WHEN ft.fto_status = 'Suspended' OR ft.strikes >= 3 
            THEN 'REJECTED: Account Suspended (3+ Strikes)'
        
        -- Rule 2: Variety Shield Check (14-Day Cooldown)
        WHEN EXISTS (
            SELECT 1 
            FROM schedules s 
            WHERE s.food_truck_id = ft.id 
              AND s.community_id = 1 
              AND s.service_date >= (CURRENT_DATE - INTERVAL '14 days')
        ) THEN 'REJECTED: Variety Shield Active (Served within 14 Days)'
        
        -- Rule 3: Approved Status
        ELSE 'APPROVED: Eligible for Booking'
    END AS booking_decision
FROM food_trucks ft
ORDER BY ft.id ASC;
