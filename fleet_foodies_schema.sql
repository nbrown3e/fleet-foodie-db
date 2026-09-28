-- ============================================================================
-- FLEET FOODIES — LOGISTICS ENGINE & GOVERNANCE RULES
-- Engine: PostgreSQL (Supabase)
-- Author: Operations Analytics Engineering
-- Description: Vendor scheduling, 14-day location cooldown shield, 
--              and 3-strike governance automation trigger.
-- ============================================================================

-- 1. CREATE CORE TABLES
CREATE TABLE IF NOT EXISTS food_truck_vendors (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    vendor_name VARCHAR(100) NOT NULL,
    cuisine_type VARCHAR(50) NOT NULL,
    primary_contact_phone VARCHAR(20) NOT NULL,
    strike_count INT DEFAULT 0,
    status VARCHAR(20) DEFAULT 'Active' CHECK (status IN ('Active', 'Probation', 'Suspended')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS logistics_locations (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    location_name VARCHAR(100) NOT NULL,
    address VARCHAR(200) NOT NULL,
    city VARCHAR(50) NOT NULL,
    daily_foot_traffic_estimate INT DEFAULT 500
);

CREATE TABLE IF NOT EXISTS vendor_schedules (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    vendor_id BIGINT REFERENCES food_truck_vendors(id) ON DELETE CASCADE,
    location_id BIGINT REFERENCES logistics_locations(id) ON DELETE CASCADE,
    scheduled_date DATE NOT NULL,
    meal_slot VARCHAR(20) NOT NULL CHECK (meal_slot IN ('Lunch', 'Dinner', 'All Day')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS vendor_governance_strikes (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    vendor_id BIGINT REFERENCES food_truck_vendors(id) ON DELETE CASCADE,
    strike_reason VARCHAR(150) NOT NULL, -- 'No-Show', 'Late Arrival >30m', 'Health Code Violation'
    issued_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. AUTOMATED PL/pgSQL GOVERNANCE TRIGGER (3-STRIKE RULE)
CREATE OR REPLACE FUNCTION process_vendor_strike_governance()
RETURNS TRIGGER AS $$
DECLARE
    current_strikes INT;
BEGIN
    -- Calculate total strikes for the vendor
    SELECT COUNT(*) INTO current_strikes 
    FROM vendor_governance_strikes 
    WHERE vendor_id = NEW.vendor_id;

    -- Update strike count on the vendor profile
    UPDATE food_truck_vendors 
    SET strike_count = current_strikes 
    WHERE id = NEW.vendor_id;

    -- Enforce governance policy
    IF current_strikes >= 3 THEN
        UPDATE food_truck_vendors 
        SET status = 'Suspended' 
        WHERE id = NEW.vendor_id;
    ELSIF current_strikes = 2 THEN
        UPDATE food_truck_vendors 
        SET status = 'Probation' 
        WHERE id = NEW.vendor_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_vendor_governance
AFTER INSERT ON vendor_governance_strikes
FOR EACH ROW
EXECUTE FUNCTION process_vendor_strike_governance();

-- 3. ENABLE ROW LEVEL SECURITY (RLS)
ALTER TABLE food_truck_vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE logistics_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendor_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendor_governance_strikes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read vendors" ON food_truck_vendors FOR SELECT USING (true);
CREATE POLICY "Public read locations" ON logistics_locations FOR SELECT USING (true);
CREATE POLICY "Public read schedules" ON vendor_schedules FOR SELECT USING (true);

-- 4. SEED DATA (SANITIZED MOCK NUMBERS)
INSERT INTO food_truck_vendors (vendor_name, cuisine_type, primary_contact_phone) VALUES
    ('Taco Fiesta Mobile', 'Mexican', '+1-555-019-2831'),
    ('Savannah Seafood Cart', 'Coastal Seafood', '+1-555-014-9922'),
    ('Peachy BBQ Smoker', 'Southern BBQ', '+1-555-018-3321');

INSERT INTO logistics_locations (location_name, address, city) VALUES
    ('Tech Ridge Office Park', '100 Tech Ridge Pkwy', 'Atlanta'),
    ('Riverfront Plaza Hub', '202 E River St', 'Savannah');

-- Schedule entries
INSERT INTO vendor_schedules (vendor_id, location_id, scheduled_date, meal_slot) VALUES
    (1, 1, CURRENT_DATE, 'Lunch'),
    (2, 2, CURRENT_DATE - INTERVAL '10 days', 'Lunch');

-- 5. TEST GOVERNANCE TRIGGER (Simulate 3 Strikes for Vendor #3)
INSERT INTO vendor_governance_strikes (vendor_id, strike_reason) VALUES
    (3, 'Late Arrival >30m'),
    (3, 'Unexcused Cancellation'),
    (3, 'No-Show on Scheduled Date'););

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

-- Insert Food Trucks (Demonstrating Compliance States & HITL Audits)
INSERT INTO food_trucks (
    truck_name, cuisine_type, tier, fto_status, strikes, 
    coi_expires_at, health_permit_expires_at, documents_verified, 
    verified_by_user_id, verified_at, compliance_notes
)
VALUES 
    (
        'Pie Society / British Pie Co.', 'British / Bakery', 'Tier 1', 'Active', 0, 
        '2027-12-31', '2027-12-31', TRUE, 
        'usr_ops_mgr_01', CURRENT_TIMESTAMP - INTERVAL '10 days', 'All state and insurance docs verified.'
    ),
    (
        'BowTie Barbecue Co.', 'BBQ', 'Tier 1', 'Active', 0, 
        '2025-01-01', '2027-12-31', TRUE, 
        'usr_ops_mgr_01', CURRENT_TIMESTAMP - INTERVAL '30 days', 'Expired COI needs re-audit.'
    ),
    (
        'Def Burger', 'American / Burgers', 'Tier 1', 'Suspended', 3, 
        '2027-12-31', '2027-12-31', FALSE, 
        NULL, NULL, 'Pending manual compliance audit.'
    );

-- Insert Historical & Active Schedules
INSERT INTO schedules (community_id, food_truck_id, service_date, booking_status)
VALUES 
    (1, 1, CURRENT_DATE - INTERVAL '7 days', 'Completed'),   -- Variety Shield Trigger
    (1, 2, CURRENT_DATE - INTERVAL '26 days', 'Completed'),  -- Cooldown Expired
    (2, 1, CURRENT_DATE + INTERVAL '14 days', 'Scheduled');

-- ----------------------------------------------------------------------------
-- 3. BUSINESS RULES ENGINE (FULL GOVERNANCE & HITL AUDIT)
-- ----------------------------------------------------------------------------

-- Unified Vendor Eligibility Audit
-- Evaluates: 1) Strike Penalties, 2) HITL Verification, 3) Document Expiration, 4) Variety Shield
SELECT 
    ft.id AS truck_id,
    ft.truck_name,
    ft.cuisine_type,
    ft.strikes,
    ft.fto_status,
    ft.coi_expires_at,
    ft.documents_verified,
    ft.verified_by_user_id,
    CASE 
        -- Guardrail 1: Strike Suspension Check
        WHEN ft.fto_status = 'Suspended' OR ft.strikes >= 3 
            THEN 'REJECTED: Account Suspended (3+ Strikes)'
        
        -- Guardrail 2: Human-in-the-Loop (HITL) Document Verification
        WHEN ft.documents_verified = FALSE 
            THEN 'REJECTED: Compliance Pending Human Review (HITL Verification Required)'
        
        -- Guardrail 3: Document Expiration Check
        WHEN ft.coi_expires_at IS NULL OR ft.coi_expires_at < CURRENT_DATE 
            THEN 'REJECTED: Certificate of Insurance (COI) Expired or Missing'
        
        WHEN ft.health_permit_expires_at IS NULL OR ft.health_permit_expires_at < CURRENT_DATE 
            THEN 'REJECTED: Health Permit Expired or Missing'

        -- Guardrail 4: Variety Shield Check (14-Day Cooldown)
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
ORDER BY ft.id ASC;    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
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
