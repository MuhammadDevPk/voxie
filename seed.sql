-- ============================================================
-- Voxie Platform — Complete Schema + Seed Data
-- Run this entire script in Supabase SQL Editor (one shot)
-- ============================================================

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 0. DROP OLD TABLES (safe — they are empty / incorrect schema)
-- ============================================================
-- Drop views first (they depend on the tables)
DROP VIEW IF EXISTS agent_performance CASCADE;
DROP VIEW IF EXISTS active_calls CASCADE;
DROP VIEW IF EXISTS daily_cost_summary CASCADE;

-- Drop old indexes (some may not exist, IF EXISTS handles that)
DROP INDEX IF EXISTS idx_call_sessions_agent_id;
DROP INDEX IF EXISTS idx_call_sessions_started_at;
DROP INDEX IF EXISTS idx_call_sessions_status;
DROP INDEX IF EXISTS idx_conversation_turns_call_session_id;
DROP INDEX IF EXISTS idx_conversation_turns_session;
DROP INDEX IF EXISTS idx_token_usage_call_session_id;
DROP INDEX IF EXISTS idx_token_usage_session;
DROP INDEX IF EXISTS idx_call_summaries_call_session_id;
DROP INDEX IF EXISTS idx_call_summaries_session;
DROP INDEX IF EXISTS idx_call_records_room;

-- Drop tables in dependency order (children first, then parents)
DROP TABLE IF EXISTS call_records CASCADE;
DROP TABLE IF EXISTS pricing_config CASCADE;
DROP TABLE IF EXISTS call_summaries CASCADE;
DROP TABLE IF EXISTS token_usage CASCADE;
DROP TABLE IF EXISTS conversation_turns CASCADE;
DROP TABLE IF EXISTS call_sessions CASCADE;
DROP TABLE IF EXISTS agents CASCADE;

-- ============================================================
-- 1. AGENTS TABLE (matches agent_persistence.py fields)
-- ============================================================
CREATE TABLE IF NOT EXISTS agents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT,
    avatar_url TEXT,
    tagline TEXT,
    category TEXT,
    language JSONB DEFAULT '["EN"]'::jsonb,
    prompt_source TEXT DEFAULT 'text',
    prompt_text TEXT,
    prompt_variables JSONB DEFAULT '{}'::jsonb,
    voice TEXT DEFAULT 'alloy',
    model TEXT DEFAULT 'gpt-realtime',
    provider TEXT DEFAULT 'openai_realtime',
    provider_config JSONB DEFAULT '{}'::jsonb,
    settings JSONB DEFAULT '{}'::jsonb,
    status TEXT DEFAULT 'draft',
    status_type TEXT DEFAULT 'testing',
    visibility TEXT DEFAULT 'listed',
    access_mode TEXT DEFAULT 'open',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 2. CALL SESSIONS TABLE (matches call_analytics.py fields)
-- ============================================================
CREATE TABLE IF NOT EXISTS call_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id TEXT NOT NULL,
    agent_id UUID REFERENCES agents(id) ON DELETE SET NULL,
    room_name TEXT NOT NULL,
    primary_agent_type TEXT,
    customer_name TEXT,
    customer_phone TEXT,
    customer_id TEXT,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    ended_at TIMESTAMPTZ,
    duration_seconds INTEGER,
    call_status TEXT DEFAULT 'active',
    call_rating INTEGER,
    call_rating_reason TEXT,
    customer_sentiment TEXT,
    issue_resolved BOOLEAN,
    agent_transitions JSONB DEFAULT '[]'::jsonb,
    full_transcript TEXT,
    recording_url TEXT,
    audio_quality_score NUMERIC(5,2),
    latency_avg_ms INTEGER,
    errors_count INTEGER DEFAULT 0,
    notes TEXT
);

-- ============================================================
-- 3. CONVERSATION TURNS TABLE (matches call_analytics.py)
-- ============================================================
CREATE TABLE IF NOT EXISTS conversation_turns (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    call_session_id UUID REFERENCES call_sessions(id) ON DELETE CASCADE,
    turn_number INTEGER NOT NULL,
    speaker TEXT NOT NULL,
    transcript TEXT NOT NULL,
    agent_name TEXT,
    audio_duration_ms INTEGER,
    intent TEXT,
    sentiment TEXT,
    entities JSONB DEFAULT '{}'::jsonb,
    function_called TEXT,
    function_params JSONB,
    function_result JSONB,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 4. TOKEN USAGE TABLE (matches call_analytics.py)
-- ============================================================
CREATE TABLE IF NOT EXISTS token_usage (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    call_session_id UUID REFERENCES call_sessions(id) ON DELETE CASCADE,
    model TEXT NOT NULL,
    input_tokens INTEGER DEFAULT 0,
    output_tokens INTEGER DEFAULT 0,
    total_tokens INTEGER GENERATED ALWAYS AS (input_tokens + output_tokens) STORED,
    input_audio_tokens INTEGER DEFAULT 0,
    output_audio_tokens INTEGER DEFAULT 0,
    input_cost_usd NUMERIC(10, 6) DEFAULT 0,
    output_cost_usd NUMERIC(10, 6) DEFAULT 0,
    total_cost_usd NUMERIC(10, 4) GENERATED ALWAYS AS (
        ROUND(COALESCE(input_cost_usd, 0) + COALESCE(output_cost_usd, 0), 4)
    ) STORED,
    interaction_type TEXT DEFAULT 'conversation',
    function_name TEXT,
    agent_state TEXT,
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 5. CALL SUMMARIES TABLE (matches call_analytics.py)
-- ============================================================
CREATE TABLE IF NOT EXISTS call_summaries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    call_session_id UUID REFERENCES call_sessions(id) ON DELETE CASCADE UNIQUE,
    summary_text TEXT NOT NULL,
    key_points TEXT[],
    action_items TEXT[],
    call_category TEXT,
    business_outcome TEXT,
    sales_value_usd NUMERIC(10, 2),
    generated_by TEXT DEFAULT 'gpt-4o',
    tokens_used INTEGER,
    generated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 6. PRICING CONFIG TABLE (used by call_analytics.py)
-- ============================================================
CREATE TABLE IF NOT EXISTS pricing_config (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    model TEXT NOT NULL,
    input_price_per_1m NUMERIC(10, 4) NOT NULL,
    output_price_per_1m NUMERIC(10, 4) NOT NULL,
    audio_input_price_per_1m NUMERIC(10, 4) DEFAULT 0,
    audio_output_price_per_1m NUMERIC(10, 4) DEFAULT 0,
    effective_from TIMESTAMPTZ DEFAULT NOW(),
    effective_to TIMESTAMPTZ DEFAULT NULL
);

-- ============================================================
-- 7. CALL RECORDS TABLE (used by call_records_manager.py)
-- ============================================================
CREATE TABLE IF NOT EXISTS call_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id TEXT NOT NULL,
    session_id TEXT NOT NULL,
    call_session_id TEXT,
    agent_id UUID REFERENCES agents(id) ON DELETE SET NULL,
    agent_name TEXT,
    customer_phone TEXT,
    customer_name TEXT,
    transcript JSONB DEFAULT '{}'::jsonb,
    audio_url TEXT,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    duration_seconds INTEGER,
    call_status TEXT DEFAULT 'completed',
    token_usage INTEGER,
    sentiment TEXT,
    summary TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 8. INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_call_sessions_agent_id ON call_sessions(agent_id);
CREATE INDEX IF NOT EXISTS idx_call_sessions_started_at ON call_sessions(started_at);
CREATE INDEX IF NOT EXISTS idx_call_sessions_status ON call_sessions(call_status);
CREATE INDEX IF NOT EXISTS idx_conversation_turns_session ON conversation_turns(call_session_id);
CREATE INDEX IF NOT EXISTS idx_token_usage_session ON token_usage(call_session_id);
CREATE INDEX IF NOT EXISTS idx_call_summaries_session ON call_summaries(call_session_id);
CREATE INDEX IF NOT EXISTS idx_call_records_room ON call_records(room_id);

-- ============================================================
-- 9. DATABASE VIEWS (used by analytics_dashboard.py)
-- ============================================================

-- Daily cost summary view
CREATE OR REPLACE VIEW daily_cost_summary AS
SELECT
    DATE(cs.started_at) AS date,
    COUNT(cs.id) AS total_calls,
    COUNT(CASE WHEN cs.call_status = 'completed' THEN 1 END) AS completed_calls,
    COALESCE(SUM(tu.total_tokens), 0) AS total_tokens,
    COALESCE(SUM(tu.total_cost_usd), 0)::NUMERIC(10,2) AS total_cost_usd,
    ROUND(AVG(cs.call_rating)::NUMERIC, 1) AS avg_rating
FROM call_sessions cs
LEFT JOIN token_usage tu ON tu.call_session_id = cs.id
GROUP BY DATE(cs.started_at)
ORDER BY date DESC;

-- Active calls view
CREATE OR REPLACE VIEW active_calls AS
SELECT
    cs.id,
    cs.session_id,
    cs.room_name,
    a.name AS agent_name,
    cs.started_at,
    EXTRACT(EPOCH FROM (NOW() - cs.started_at))::INTEGER AS duration_so_far_seconds,
    COALESCE(SUM(tu.total_cost_usd), 0)::NUMERIC(10,4) AS cost_so_far_usd
FROM call_sessions cs
LEFT JOIN agents a ON cs.agent_id = a.id
LEFT JOIN token_usage tu ON tu.call_session_id = cs.id
WHERE cs.call_status = 'active'
GROUP BY cs.id, a.name;

-- Agent performance view
CREATE OR REPLACE VIEW agent_performance AS
SELECT
    a.id,
    a.name,
    COUNT(cs.id) AS total_calls,
    ROUND(AVG(cs.call_rating)::NUMERIC, 1) AS avg_rating,
    COALESCE(SUM(tu.total_cost_usd), 0)::NUMERIC(10,2) AS total_cost,
    CASE WHEN COUNT(cs.id) > 0
         THEN ROUND((COALESCE(SUM(tu.total_cost_usd), 0) / COUNT(cs.id))::NUMERIC, 2)
         ELSE 0 END AS avg_cost_per_call,
    COUNT(CASE WHEN csm.business_outcome = 'sale' THEN 1 END) AS sales_count
FROM agents a
LEFT JOIN call_sessions cs ON cs.agent_id = a.id
    AND cs.started_at >= NOW() - INTERVAL '30 days'
LEFT JOIN token_usage tu ON tu.call_session_id = cs.id
LEFT JOIN call_summaries csm ON csm.call_session_id = cs.id
GROUP BY a.id, a.name
ORDER BY total_calls DESC;


-- ============================================================
-- 10. SEED DATA
-- ============================================================

-- 10.1 Pricing Config (OpenAI model pricing)
INSERT INTO pricing_config (model, input_price_per_1m, output_price_per_1m, audio_input_price_per_1m, audio_output_price_per_1m)
VALUES
    ('gpt-4o-realtime', 5.00, 20.00, 100.00, 200.00),
    ('gpt-4o', 2.50, 10.00, 0, 0),
    ('gpt-4o-mini', 0.15, 0.60, 0, 0)
ON CONFLICT DO NOTHING;

-- 10.2 Sample Agents
INSERT INTO agents (id, name, avatar_url, tagline, category, language, prompt_source, prompt_text, prompt_variables, voice, model, provider, provider_config, settings, status, status_type, visibility, access_mode) VALUES
(
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'Kensington Car Dealership Agent',
    'https://picsum.photos/seed/kensington/200',
    'AI assistant for Kensington Car Dealership',
    'Car Dealership',
    '["EN"]',
    'text',
    'You are Charlie, a friendly and knowledgeable AI assistant for the Kensington Car Dealership. You help customers with test drives, vehicle information, financing questions, and service appointments. Maintain a warm, friendly tone with a touch of humor while staying professional.',
    '{"business_name": "Kensington Car Dealership", "business_type": "Car Dealership", "target_audience": "Prospective car buyers and service customers", "main_functions": ["Schedule test drives and service appointments", "Answer vehicle availability and feature questions", "Guide customers through financing and purchasing steps"], "tone": "Warm, friendly with a touch of humor"}',
    'echo',
    'gpt-realtime',
    'openai_realtime',
    '{"voice": "echo", "business_type": "Car Dealership"}',
    '{"business_context": {"business_name": "Kensington Car Dealership", "business_type": "Car Dealership", "agent_name": "Charlie"}, "functions": [{"name": "search_knowledge_base", "description": "Search the dealership knowledge base"}], "created_via": "voxie_transfer"}',
    'active',
    'production',
    'listed',
    'open'
),
(
    'b2c3d4e5-f6a7-8901-bcde-f12345678901',
    'Bella''s Pizzeria Agent',
    'https://picsum.photos/seed/bellas-pizzeria/200',
    'AI assistant for Bella''s Pizzeria',
    'Restaurant',
    '["EN"]',
    'text',
    'You are a friendly AI assistant for Bella''s Pizzeria. You help customers place orders, check menu items, provide information about ingredients and allergens, and handle delivery inquiries. Be warm, enthusiastic about food, and always make customers feel welcome.',
    '{"business_name": "Bella''s Pizzeria", "business_type": "Italian Restaurant", "target_audience": "Food lovers and hungry customers", "main_functions": ["Take food orders", "Provide menu information", "Handle delivery and pickup inquiries"], "tone": "Warm, enthusiastic, food-loving"}',
    'alloy',
    'gpt-realtime',
    'openai_realtime',
    '{"voice": "alloy", "business_type": "Restaurant"}',
    '{"business_context": {"business_name": "Bella''s Pizzeria", "business_type": "Italian Restaurant"}, "functions": [{"name": "general_inquiry", "description": "Handle general questions"}], "created_via": "voxie_transfer"}',
    'active',
    'production',
    'listed',
    'open'
),
(
    'c3d4e5f6-a7b8-9012-cdef-123456789012',
    'TechSupport Pro Agent',
    'https://picsum.photos/seed/techsupport/200',
    'AI assistant for TechSupport Pro',
    'Technology',
    '["EN"]',
    'text',
    'You are a knowledgeable and patient IT support agent for TechSupport Pro. You help users troubleshoot software issues, guide them through setup processes, and escalate complex problems to human technicians when needed. Be clear, concise, and reassuring.',
    '{"business_name": "TechSupport Pro", "business_type": "IT Support", "target_audience": "Business users needing technical help", "main_functions": ["Troubleshoot software issues", "Guide through setup processes", "Escalate complex problems"], "tone": "Patient, knowledgeable, reassuring"}',
    'shimmer',
    'gpt-realtime',
    'openai_realtime',
    '{"voice": "shimmer", "business_type": "IT Support"}',
    '{"business_context": {"business_name": "TechSupport Pro", "business_type": "IT Support"}, "functions": [{"name": "general_inquiry", "description": "Handle support tickets"}], "created_via": "voxie_transfer"}',
    'draft',
    'testing',
    'listed',
    'open'
);

-- 10.3 Sample Call Sessions
INSERT INTO call_sessions (id, session_id, agent_id, room_name, primary_agent_type, customer_name, customer_phone, started_at, ended_at, duration_seconds, call_status, call_rating, customer_sentiment, issue_resolved) VALUES
(
    'd4e5f6a7-b8c9-0123-defa-234567890123',
    'session-kensington-001',
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'call_a1b2c3d4_abc12345',
    'Car Dealership Agent',
    'John Smith',
    '+1-555-0101',
    NOW() - INTERVAL '2 hours',
    NOW() - INTERVAL '1 hour 45 minutes',
    900,
    'completed',
    9,
    'positive',
    TRUE
),
(
    'e5f6a7b8-c9d0-1234-efab-345678901234',
    'session-bellas-001',
    'b2c3d4e5-f6a7-8901-bcde-f12345678901',
    'call_b2c3d4e5_def67890',
    'Restaurant Agent',
    'Sarah Johnson',
    '+1-555-0102',
    NOW() - INTERVAL '1 hour',
    NOW() - INTERVAL '50 minutes',
    600,
    'completed',
    8,
    'positive',
    TRUE
),
(
    'f6a7b8c9-d0e1-2345-fabc-456789012345',
    'session-kensington-002',
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'call_a1b2c3d4_ghi11111',
    'Car Dealership Agent',
    'Mike Davis',
    '+1-555-0103',
    NOW() - INTERVAL '30 minutes',
    NOW() - INTERVAL '20 minutes',
    600,
    'completed',
    7,
    'neutral',
    FALSE
),
(
    'a7b8c9d0-e1f2-3456-abcd-567890123456',
    'session-tech-001',
    'c3d4e5f6-a7b8-9012-cdef-123456789012',
    'call_c3d4e5f6_jkl22222',
    'IT Support Agent',
    'Emily Chen',
    '+1-555-0104',
    NOW() - INTERVAL '3 hours',
    NOW() - INTERVAL '2 hours 40 minutes',
    1200,
    'completed',
    10,
    'positive',
    TRUE
);

-- 10.4 Sample Conversation Turns
-- Call 1: Kensington Car Dealership (John Smith)
INSERT INTO conversation_turns (call_session_id, turn_number, speaker, transcript, agent_name, sentiment, timestamp) VALUES
('d4e5f6a7-b8c9-0123-defa-234567890123', 1, 'agent', 'Hello! I''m Charlie, a representative of the Kensington Car Dealership team. How may I assist you today?', 'Charlie', 'positive', NOW() - INTERVAL '2 hours'),
('d4e5f6a7-b8c9-0123-defa-234567890123', 2, 'user', 'Hi Charlie! I''m interested in the new SUV models you have available. Can you tell me about the latest options?', NULL, 'positive', NOW() - INTERVAL '1 hour 59 minutes'),
('d4e5f6a7-b8c9-0123-defa-234567890123', 3, 'agent', 'Great choice! We have several fantastic SUV options right now. Our most popular models include the 2024 Explorer and the Tucson Hybrid. Would you like me to go into details on either of these, or are you looking for something specific?', 'Charlie', 'positive', NOW() - INTERVAL '1 hour 58 minutes'),
('d4e5f6a7-b8c9-0123-defa-234567890123', 4, 'user', 'The Tucson Hybrid sounds interesting. What''s the price range and key features?', NULL, 'positive', NOW() - INTERVAL '1 hour 57 minutes'),
('d4e5f6a7-b8c9-0123-defa-234567890123', 5, 'agent', 'The Tucson Hybrid starts at around $34,000 and comes loaded with features — hybrid powertrain getting up to 38 MPG, a 10.25-inch touchscreen, wireless Apple CarPlay, and advanced safety features. Would you like to schedule a test drive?', 'Charlie', 'positive', NOW() - INTERVAL '1 hour 56 minutes'),
('d4e5f6a7-b8c9-0123-defa-234567890123', 6, 'user', 'That sounds great! Yes, I''d love to book a test drive for this Saturday if possible.', NULL, 'positive', NOW() - INTERVAL '1 hour 55 minutes'),
('d4e5f6a7-b8c9-0123-defa-234567890123', 7, 'agent', 'Perfect! I''ve got Saturday available. How does 10 AM work for you? I''ll reserve the Tucson Hybrid and have it ready for you at the dealership.', 'Charlie', 'positive', NOW() - INTERVAL '1 hour 54 minutes'),
('d4e5f6a7-b8c9-0123-defa-234567890123', 8, 'user', '10 AM is perfect. Thank you, Charlie!', NULL, 'positive', NOW() - INTERVAL '1 hour 53 minutes');

-- Call 2: Bella's Pizzeria (Sarah Johnson)
INSERT INTO conversation_turns (call_session_id, turn_number, speaker, transcript, agent_name, sentiment, timestamp) VALUES
('e5f6a7b8-c9d0-1234-efab-345678901234', 1, 'agent', 'Welcome to Bella''s Pizzeria! I''m here to help you with your order. What can I get for you today?', 'Bella Agent', 'positive', NOW() - INTERVAL '1 hour'),
('e5f6a7b8-c9d0-1234-efab-345678901234', 2, 'user', 'Hi! I''d like to order a large pepperoni pizza and a Caesar salad please.', NULL, 'positive', NOW() - INTERVAL '59 minutes'),
('e5f6a7b8-c9d0-1234-efab-345678901234', 3, 'agent', 'Excellent choices! A large pepperoni pizza — that''s $18.99 — and a Caesar salad at $8.99. Would you like to add any drinks or desserts? Our tiramisu is heavenly today!', 'Bella Agent', 'positive', NOW() - INTERVAL '58 minutes'),
('e5f6a7b8-c9d0-1234-efab-345678901234', 4, 'user', 'Sure, add a tiramisu and two Cokes please. Is delivery available to 123 Main Street?', NULL, 'positive', NOW() - INTERVAL '57 minutes'),
('e5f6a7b8-c9d0-1234-efab-345678901234', 5, 'agent', 'Absolutely! Your total comes to $37.97. Delivery to 123 Main Street should take about 30-40 minutes. I''ve placed your order! Is there anything else I can help with?', 'Bella Agent', 'positive', NOW() - INTERVAL '56 minutes'),
('e5f6a7b8-c9d0-1234-efab-345678901234', 6, 'user', 'That''s everything, thank you!', NULL, 'positive', NOW() - INTERVAL '55 minutes');

-- 10.5 Sample Token Usage
INSERT INTO token_usage (call_session_id, model, input_tokens, output_tokens, input_audio_tokens, output_audio_tokens, input_cost_usd, output_cost_usd, interaction_type, agent_state, recorded_at) VALUES
('d4e5f6a7-b8c9-0123-defa-234567890123', 'gpt-4o-realtime', 420, 680, 1200, 1800, 0.1221, 0.3736, 'conversation', 'realtime_conversation', NOW() - INTERVAL '2 hours'),
('d4e5f6a7-b8c9-0123-defa-234567890123', 'gpt-4o', 850, 320, 0, 0, 0.002125, 0.0032, 'processing', 'summary_generation', NOW() - INTERVAL '1 hour 45 minutes'),
('e5f6a7b8-c9d0-1234-efab-345678901234', 'gpt-4o-realtime', 310, 520, 900, 1400, 0.0916, 0.2904, 'conversation', 'realtime_conversation', NOW() - INTERVAL '1 hour'),
('e5f6a7b8-c9d0-1234-efab-345678901234', 'gpt-4o', 680, 280, 0, 0, 0.0017, 0.0028, 'processing', 'summary_generation', NOW() - INTERVAL '50 minutes'),
('f6a7b8c9-d0e1-2345-fabc-456789012345', 'gpt-4o-realtime', 380, 610, 1100, 1600, 0.1119, 0.3322, 'conversation', 'realtime_conversation', NOW() - INTERVAL '30 minutes'),
('a7b8c9d0-e1f2-3456-abcd-567890123456', 'gpt-4o-realtime', 550, 890, 1500, 2200, 0.1528, 0.4578, 'conversation', 'realtime_conversation', NOW() - INTERVAL '3 hours'),
('a7b8c9d0-e1f2-3456-abcd-567890123456', 'gpt-4o', 920, 350, 0, 0, 0.0023, 0.0035, 'processing', 'summary_generation', NOW() - INTERVAL '2 hours 40 minutes');

-- 10.6 Sample Call Summaries
INSERT INTO call_summaries (call_session_id, summary_text, key_points, action_items, call_category, business_outcome, sales_value_usd, tokens_used) VALUES
(
    'd4e5f6a7-b8c9-0123-defa-234567890123',
    'Customer John Smith called inquiring about SUV options. He was interested in the Tucson Hybrid and booked a test drive for Saturday at 10 AM.',
    ARRAY['Customer interested in SUV models', 'Discussed Tucson Hybrid features and pricing', 'Test drive scheduled for Saturday 10 AM'],
    ARRAY['Prepare Tucson Hybrid for Saturday test drive', 'Follow up with John after test drive'],
    'booking',
    'lead',
    NULL,
    1170
),
(
    'e5f6a7b8-c9d0-1234-efab-345678901234',
    'Customer Sarah Johnson placed a delivery order: large pepperoni pizza, Caesar salad, tiramisu, and two Cokes. Total $37.97 delivered to 123 Main Street.',
    ARRAY['Large pepperoni pizza ordered', 'Added Caesar salad, tiramisu, and drinks', 'Delivery to 123 Main Street'],
    ARRAY['Prepare order for delivery', 'Estimated delivery 30-40 minutes'],
    'new_order',
    'sale',
    37.97,
    960
),
(
    'a7b8c9d0-e1f2-3456-abcd-567890123456',
    'Customer Emily Chen called with a software installation issue. The agent guided her through troubleshooting steps and successfully resolved the problem remotely.',
    ARRAY['Software installation error reported', 'Guided through troubleshooting steps', 'Issue resolved without escalation'],
    ARRAY['Send follow-up email with documentation link'],
    'support',
    'resolution',
    NULL,
    1270
);

-- ============================================================
-- 11. ROW LEVEL SECURITY (RLS) POLICIES
-- Supabase uses the anon key, which requires explicit RLS
-- policies to read/write data. Without these, queries return
-- empty results even though the data exists in the table.
-- ============================================================

-- AGENTS: full access via anon key
ALTER TABLE agents ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow full access to agents" ON agents;
CREATE POLICY "Allow full access to agents" ON agents
    FOR ALL USING (true) WITH CHECK (true);

-- CALL SESSIONS: full access
ALTER TABLE call_sessions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow full access to call_sessions" ON call_sessions;
CREATE POLICY "Allow full access to call_sessions" ON call_sessions
    FOR ALL USING (true) WITH CHECK (true);

-- CONVERSATION TURNS: full access
ALTER TABLE conversation_turns ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow full access to conversation_turns" ON conversation_turns;
CREATE POLICY "Allow full access to conversation_turns" ON conversation_turns
    FOR ALL USING (true) WITH CHECK (true);

-- TOKEN USAGE: full access
ALTER TABLE token_usage ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow full access to token_usage" ON token_usage;
CREATE POLICY "Allow full access to token_usage" ON token_usage
    FOR ALL USING (true) WITH CHECK (true);

-- CALL SUMMARIES: full access
ALTER TABLE call_summaries ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow full access to call_summaries" ON call_summaries;
CREATE POLICY "Allow full access to call_summaries" ON call_summaries
    FOR ALL USING (true) WITH CHECK (true);

-- PRICING CONFIG: full access
ALTER TABLE pricing_config ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow full access to pricing_config" ON pricing_config;
CREATE POLICY "Allow full access to pricing_config" ON pricing_config
    FOR ALL USING (true) WITH CHECK (true);

-- CALL RECORDS: full access
ALTER TABLE call_records ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow full access to call_records" ON call_records;
CREATE POLICY "Allow full access to call_records" ON call_records
    FOR ALL USING (true) WITH CHECK (true);

-- ============================================================
-- Done! 🎉
-- Your database now has:
--   • 3 sample agents (Car Dealership, Pizzeria, Tech Support)
--   • 4 call sessions with transcripts
--   • Token usage records with cost tracking
--   • Call summaries with business outcomes
--   • Pricing configuration for OpenAI models
--   • Dashboard views (daily_cost_summary, active_calls, agent_performance)
--   • RLS policies allowing API access via anon key
-- ============================================================
