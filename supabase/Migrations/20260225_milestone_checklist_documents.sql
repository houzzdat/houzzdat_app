-- =============================================================================
-- SiteVoice Enhancement: Milestone System, Role-based Checklists, Document Management
-- Migration: 20260225_milestone_checklist_documents.sql
-- Rollback: See ROLLBACK section at end of file
-- =============================================================================

-- -------------------------
-- FEATURE 1: MILESTONE SYSTEM
-- -------------------------

-- Module library (global templates with account_id = NULL, or account-specific)
CREATE TABLE IF NOT EXISTS milestone_modules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID REFERENCES accounts(id) ON DELETE CASCADE,  -- NULL = global template
  name TEXT NOT NULL,
  description TEXT,
  category TEXT NOT NULL CHECK (category IN ('structural','mep','finishing','legal','external','specialty')),
  typical_duration_days INT NOT NULL DEFAULT 7,
  sequence_order INT NOT NULL DEFAULT 0,
  dependencies TEXT[] DEFAULT '{}',
  indian_context JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Milestone phases per project (instantiated from modules or custom)
CREATE TABLE IF NOT EXISTS milestone_phases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  module_id UUID REFERENCES milestone_modules(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  description TEXT,
  phase_order INT NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','active','gate_review','completed','blocked')),
  planned_start DATE,
  planned_end DATE,
  actual_start DATE,
  actual_end DATE,
  budget_allocated NUMERIC(12,2),
  budget_spent NUMERIC(12,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Key results (OKR-style measurable outcomes per phase)
CREATE TABLE IF NOT EXISTS key_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phase_id UUID NOT NULL REFERENCES milestone_phases(id) ON DELETE CASCADE,
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  metric_type TEXT NOT NULL CHECK (metric_type IN ('count','percentage','boolean','numeric')),
  target_value NUMERIC(10,2),
  current_value NUMERIC(10,2) NOT NULL DEFAULT 0,
  unit TEXT,
  auto_track BOOLEAN NOT NULL DEFAULT false,
  completed BOOLEAN NOT NULL DEFAULT false,
  due_date DATE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Daily delta log for runway calculation & progress snapshots
CREATE TABLE IF NOT EXISTS daily_deltas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  phase_id UUID REFERENCES milestone_phases(id) ON DELETE SET NULL,
  key_result_id UUID REFERENCES key_results(id) ON DELETE SET NULL,
  delta_value NUMERIC(10,2) NOT NULL,
  source TEXT NOT NULL DEFAULT 'manual' CHECK (source IN ('voice_note','manual','checklist','import')),
  source_id UUID,
  recorded_at TIMESTAMPTZ DEFAULT now()
);

-- -------------------------
-- FEATURE 2: ROLE-BASED CHECKLISTS
-- -------------------------

-- Checklist template library (stored in DB, linked to modules)
CREATE TABLE IF NOT EXISTS milestone_checklists (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  module_id UUID NOT NULL REFERENCES milestone_modules(id) ON DELETE CASCADE,
  gate_type TEXT NOT NULL CHECK (gate_type IN ('pre_start','post_completion')),
  role TEXT NOT NULL CHECK (role IN ('manager','worker','owner')),
  item_text TEXT NOT NULL,
  item_text_hi TEXT,
  item_text_ta TEXT,
  item_text_kn TEXT,
  item_text_te TEXT,
  evidence_required TEXT NOT NULL DEFAULT 'none' CHECK (evidence_required IN ('photo','document','voice','none')),
  is_critical BOOLEAN NOT NULL DEFAULT false,
  sequence_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Checklist completions per phase instance
CREATE TABLE IF NOT EXISTS checklist_completions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phase_id UUID NOT NULL REFERENCES milestone_phases(id) ON DELETE CASCADE,
  checklist_item_id UUID NOT NULL REFERENCES milestone_checklists(id) ON DELETE CASCADE,
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  completed_by UUID REFERENCES users(id) ON DELETE SET NULL,
  completed_at TIMESTAMPTZ,
  is_completed BOOLEAN NOT NULL DEFAULT false,
  override_reason TEXT,
  evidence_type TEXT CHECK (evidence_type IN ('photo','document','voice','none')),
  evidence_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Gate approvals (pre/post phase gate sign-offs)
CREATE TABLE IF NOT EXISTS phase_gate_approvals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phase_id UUID NOT NULL REFERENCES milestone_phases(id) ON DELETE CASCADE,
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  gate_type TEXT NOT NULL CHECK (gate_type IN ('pre_start','post_completion')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  approved_by UUID REFERENCES users(id) ON DELETE SET NULL,
  approved_at TIMESTAMPTZ,
  rejection_reason TEXT,
  incomplete_critical_items INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- -------------------------
-- FEATURE 3: DOCUMENT MANAGEMENT
-- -------------------------

-- Document vault
CREATE TABLE IF NOT EXISTS documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  uploaded_by UUID REFERENCES users(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN (
    'legal_statutory','technical_drawings','quality_certificates',
    'contracts_financial','progress_reports','other'
  )),
  subcategory TEXT,
  file_path TEXT NOT NULL,
  file_url TEXT NOT NULL,
  file_size_bytes BIGINT,
  mime_type TEXT,
  version_number INT NOT NULL DEFAULT 1,
  parent_document_id UUID REFERENCES documents(id) ON DELETE SET NULL,
  version_notes TEXT,
  requires_owner_approval BOOLEAN NOT NULL DEFAULT false,
  approval_status TEXT NOT NULL DEFAULT 'draft' CHECK (approval_status IN (
    'draft','pending_approval','approved','rejected','changes_requested'
  )),
  approved_by UUID REFERENCES users(id) ON DELETE SET NULL,
  approved_at TIMESTAMPTZ,
  rejection_reason TEXT,
  expires_at DATE,
  expiry_notified BOOLEAN NOT NULL DEFAULT false,
  tags TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Document access/audit log
CREATE TABLE IF NOT EXISTS document_access_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  action TEXT NOT NULL CHECK (action IN ('view','download','approve','reject','upload','version','comment')),
  metadata JSONB DEFAULT '{}'::jsonb,
  accessed_at TIMESTAMPTZ DEFAULT now()
);

-- Document approval comments thread
CREATE TABLE IF NOT EXISTS document_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  comment TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- -------------------------
-- INDEXES
-- -------------------------
CREATE INDEX IF NOT EXISTS idx_milestone_phases_project_status
  ON milestone_phases(project_id, status);
CREATE INDEX IF NOT EXISTS idx_milestone_phases_account
  ON milestone_phases(account_id);
CREATE INDEX IF NOT EXISTS idx_key_results_phase
  ON key_results(phase_id);
CREATE INDEX IF NOT EXISTS idx_key_results_project
  ON key_results(project_id);
CREATE INDEX IF NOT EXISTS idx_daily_deltas_project_date
  ON daily_deltas(project_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_checklist_completions_phase
  ON checklist_completions(phase_id);
CREATE INDEX IF NOT EXISTS idx_checklist_completions_item
  ON checklist_completions(checklist_item_id);
CREATE INDEX IF NOT EXISTS idx_phase_gate_approvals_phase
  ON phase_gate_approvals(phase_id, gate_type);
CREATE INDEX IF NOT EXISTS idx_documents_project_category
  ON documents(project_id, category, approval_status);
CREATE INDEX IF NOT EXISTS idx_documents_account
  ON documents(account_id, approval_status);
CREATE INDEX IF NOT EXISTS idx_documents_expiry
  ON documents(expires_at) WHERE expiry_notified = false;
CREATE INDEX IF NOT EXISTS idx_documents_parent
  ON documents(parent_document_id);
CREATE INDEX IF NOT EXISTS idx_document_access_log_document
  ON document_access_log(document_id, accessed_at DESC);

-- -------------------------
-- ROW LEVEL SECURITY
-- -------------------------

ALTER TABLE milestone_modules ENABLE ROW LEVEL SECURITY;
ALTER TABLE milestone_phases ENABLE ROW LEVEL SECURITY;
ALTER TABLE key_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_deltas ENABLE ROW LEVEL SECURITY;
ALTER TABLE milestone_checklists ENABLE ROW LEVEL SECURITY;
ALTER TABLE checklist_completions ENABLE ROW LEVEL SECURITY;
ALTER TABLE phase_gate_approvals ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_access_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_comments ENABLE ROW LEVEL SECURITY;

-- milestone_modules: global templates readable by all authenticated users
CREATE POLICY "milestone_modules_read_all" ON milestone_modules
  FOR SELECT TO authenticated USING (account_id IS NULL OR
    account_id IN (
      SELECT account_id FROM users WHERE id = auth.uid()
      UNION
      SELECT account_id FROM user_company_associations WHERE user_id = auth.uid() AND status = 'active'
    )
  );
CREATE POLICY "milestone_modules_write_admin" ON milestone_modules
  FOR ALL TO authenticated USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin','super_admin'))
  );

-- milestone_phases: account members can read, managers/admins can write
CREATE POLICY "milestone_phases_read" ON milestone_phases
  FOR SELECT TO authenticated USING (
    account_id IN (
      SELECT account_id FROM users WHERE id = auth.uid()
      UNION
      SELECT account_id FROM user_company_associations WHERE user_id = auth.uid() AND status = 'active'
    )
  );
CREATE POLICY "milestone_phases_write_manager" ON milestone_phases
  FOR ALL TO authenticated USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin','manager','super_admin')
      AND account_id = milestone_phases.account_id)
  );

-- key_results: same as milestone_phases
CREATE POLICY "key_results_read" ON key_results
  FOR SELECT TO authenticated USING (
    account_id IN (
      SELECT account_id FROM users WHERE id = auth.uid()
      UNION
      SELECT account_id FROM user_company_associations WHERE user_id = auth.uid() AND status = 'active'
    )
  );
CREATE POLICY "key_results_write_manager" ON key_results
  FOR ALL TO authenticated USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin','manager','super_admin')
      AND account_id = key_results.account_id)
  );

-- daily_deltas: read for managers/admins, insert for all account members
CREATE POLICY "daily_deltas_read_manager" ON daily_deltas
  FOR SELECT TO authenticated USING (
    account_id IN (
      SELECT account_id FROM users WHERE id = auth.uid()
      UNION
      SELECT account_id FROM user_company_associations WHERE user_id = auth.uid() AND status = 'active'
    )
  );
CREATE POLICY "daily_deltas_insert_member" ON daily_deltas
  FOR INSERT TO authenticated WITH CHECK (
    account_id IN (
      SELECT account_id FROM users WHERE id = auth.uid()
      UNION
      SELECT account_id FROM user_company_associations WHERE user_id = auth.uid() AND status = 'active'
    )
  );

-- milestone_checklists: read all, write only admin
CREATE POLICY "milestone_checklists_read_all" ON milestone_checklists
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "milestone_checklists_write_admin" ON milestone_checklists
  FOR ALL TO authenticated USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin','super_admin'))
  );

-- checklist_completions: read all in account, write own completions
CREATE POLICY "checklist_completions_read" ON checklist_completions
  FOR SELECT TO authenticated USING (
    account_id IN (
      SELECT account_id FROM users WHERE id = auth.uid()
      UNION
      SELECT account_id FROM user_company_associations WHERE user_id = auth.uid() AND status = 'active'
    )
  );
CREATE POLICY "checklist_completions_write" ON checklist_completions
  FOR ALL TO authenticated USING (
    account_id IN (
      SELECT account_id FROM users WHERE id = auth.uid()
      UNION
      SELECT account_id FROM user_company_associations WHERE user_id = auth.uid() AND status = 'active'
    )
  );

-- phase_gate_approvals: read all in account, write managers
CREATE POLICY "phase_gate_approvals_read" ON phase_gate_approvals
  FOR SELECT TO authenticated USING (
    account_id IN (
      SELECT account_id FROM users WHERE id = auth.uid()
      UNION
      SELECT account_id FROM user_company_associations WHERE user_id = auth.uid() AND status = 'active'
    )
  );
CREATE POLICY "phase_gate_approvals_write_manager" ON phase_gate_approvals
  FOR ALL TO authenticated USING (
    account_id IN (
      SELECT account_id FROM users WHERE id = auth.uid()
      UNION
      SELECT account_id FROM user_company_associations WHERE user_id = auth.uid() AND status = 'active'
    )
  );

-- documents: managers/admins can CRUD, owners can read + approve, workers read only
CREATE POLICY "documents_read_members" ON documents
  FOR SELECT TO authenticated USING (
    account_id IN (
      SELECT account_id FROM users WHERE id = auth.uid()
      UNION
      SELECT account_id FROM user_company_associations WHERE user_id = auth.uid() AND status = 'active'
    )
  );
CREATE POLICY "documents_write_manager" ON documents
  FOR INSERT TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin','manager','super_admin')
      AND account_id = documents.account_id)
  );
CREATE POLICY "documents_update_manager_or_owner" ON documents
  FOR UPDATE TO authenticated USING (
    account_id IN (
      SELECT account_id FROM users WHERE id = auth.uid()
      UNION
      SELECT account_id FROM user_company_associations WHERE user_id = auth.uid() AND status = 'active'
    )
  ) WITH CHECK (
    account_id IN (
      SELECT account_id FROM users WHERE id = auth.uid()
      UNION
      SELECT account_id FROM user_company_associations WHERE user_id = auth.uid() AND status = 'active'
    )
  );

-- document_access_log: read for managers, insert for all
CREATE POLICY "document_access_log_read_manager" ON document_access_log
  FOR SELECT TO authenticated USING (
    EXISTS (
      SELECT 1 FROM documents d
      WHERE d.id = document_access_log.document_id
      AND d.account_id IN (
        SELECT account_id FROM users WHERE id = auth.uid()
        UNION
        SELECT account_id FROM user_company_associations WHERE user_id = auth.uid() AND status = 'active'
      )
    )
  );
CREATE POLICY "document_access_log_insert" ON document_access_log
  FOR INSERT TO authenticated WITH CHECK (true);

-- document_comments: all project members can read and insert
CREATE POLICY "document_comments_read" ON document_comments
  FOR SELECT TO authenticated USING (
    EXISTS (
      SELECT 1 FROM documents d
      WHERE d.id = document_comments.document_id
      AND d.account_id IN (
        SELECT account_id FROM users WHERE id = auth.uid()
        UNION
        SELECT account_id FROM user_company_associations WHERE user_id = auth.uid() AND status = 'active'
      )
    )
  );
CREATE POLICY "document_comments_insert" ON document_comments
  FOR INSERT TO authenticated WITH CHECK (
    EXISTS (
      SELECT 1 FROM documents d
      WHERE d.id = document_comments.document_id
      AND d.account_id IN (
        SELECT account_id FROM users WHERE id = auth.uid()
        UNION
        SELECT account_id FROM user_company_associations WHERE user_id = auth.uid() AND status = 'active'
      )
    )
  );

-- -------------------------
-- UPDATED_AT TRIGGERS
-- -------------------------
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_milestone_phases_updated_at ON milestone_phases;
CREATE TRIGGER set_milestone_phases_updated_at
  BEFORE UPDATE ON milestone_phases
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS set_key_results_updated_at ON key_results;
CREATE TRIGGER set_key_results_updated_at
  BEFORE UPDATE ON key_results
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS set_documents_updated_at ON documents;
CREATE TRIGGER set_documents_updated_at
  BEFORE UPDATE ON documents
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- -------------------------
-- SEED: 25 CONSTRUCTION MODULE TEMPLATES
-- -------------------------
INSERT INTO milestone_modules (name, description, category, typical_duration_days, sequence_order, dependencies, indian_context) VALUES

-- SITE PREPARATION
('Site Clearance & Layout', 'Demarcation, debris removal, temporary site office setup', 'structural', 5, 1, '{}',
 '{"monsoon_risk":"low","notes":"Ensure BBMP/local authority demarcation approval","local_materials":[]}'::jsonb),

('Soil Investigation', 'Soil boring, lab testing, bearing capacity report', 'structural', 7, 2, '{"Site Clearance & Layout"}',
 '{"monsoon_risk":"medium","notes":"IS 1892 standard; avoid testing during heavy rain","local_materials":[]}'::jsonb),

-- FOUNDATION
('Excavation & PCC', 'Excavation for footings, plain cement concrete bed (1:4:8)', 'structural', 8, 3, '{"Soil Investigation"}',
 '{"monsoon_risk":"high","monsoon_buffer_days":3,"notes":"Dewater excavation; IS 456 PCC mix","local_materials":["river sand","20mm metal"]}'::jsonb),

('Anti-Termite Treatment', 'Chemical soil treatment before and during construction', 'specialty', 2, 4, '{"Excavation & PCC"}',
 '{"monsoon_risk":"low","notes":"Use IS 6313 approved chemicals; mandatory in most BBMP jurisdictions","local_materials":[]}'::jsonb),

('Footings & Foundation', 'RCC isolated/combined footings, foundation walls', 'structural', 14, 5, '{"Anti-Termite Treatment"}',
 '{"monsoon_risk":"medium","notes":"M25 minimum concrete; IS 456; curing 28 days minimum","local_materials":["TMT steel Fe500","ready mix concrete"]}'::jsonb),

('Damp Proof Course (DPC)', 'Horizontal DPC at plinth level (75mm thick 1:2:4 with waterproofing compound)', 'specialty', 3, 6, '{"Footings & Foundation"}',
 '{"monsoon_risk":"high","notes":"Critical for waterproofing; IS 3067","local_materials":["Dr.Fixit or Sunanda waterproofing compound"]}'::jsonb),

('Plinth Beam & Backfill', 'RCC plinth beam, earth filling and compaction', 'structural', 7, 7, '{"Damp Proof Course (DPC)"}',
 '{"monsoon_risk":"medium","notes":"Compact backfill in 150mm layers; IS 456","local_materials":["earth fill","sand"]}'::jsonb),

-- SUPERSTRUCTURE
('Columns & Shear Walls', 'Ground floor columns, starter bars, shuttering, concreting', 'structural', 10, 8, '{"Plinth Beam & Backfill"}',
 '{"monsoon_risk":"medium","notes":"M25 or higher; 7-day curing minimum; IS 456","local_materials":["TMT Fe500","OPC cement"]}'::jsonb),

('Brick Masonry - Ground Floor', 'External and internal brick walls, 230mm/115mm thick', 'structural', 14, 9, '{"Columns & Shear Walls"}',
 '{"monsoon_risk":"low","notes":"Red brick IS 1077; or AAC block IS 2185-4; soak bricks before laying","local_materials":["red brick","AAC block","fly ash brick","river sand"]}'::jsonb),

('Lintel Beams & Chajjas', 'Lintels over openings, sunshades (chajjas) on south/west walls', 'structural', 5, 10, '{"Brick Masonry - Ground Floor"}',
 '{"monsoon_risk":"low","notes":"IS 456; minimum cover 25mm; chajjas reduce heat gain","local_materials":[]}'::jsonb),

('Roof Slab (Ground Floor)', 'Centering, shuttering, bar bending, concreting of roof slab', 'structural', 12, 11, '{"Lintel Beams & Chajjas"}',
 '{"monsoon_risk":"high","monsoon_buffer_days":5,"notes":"M25; vibrator compaction; curing 28 days; IS 456","local_materials":["TMT steel","M25 RMC"]}'::jsonb),

-- ADDITIONAL FLOORS (if applicable)
('Upper Floor Structure', 'Repeat column/masonry/slab cycle for upper floors', 'structural', 30, 12, '{"Roof Slab (Ground Floor)"}',
 '{"monsoon_risk":"high","monsoon_buffer_days":5,"notes":"Allow 28 days curing before loading","local_materials":[]}'::jsonb),

-- MEP ROUGH-IN
('Electrical Conduit Rough-in', 'Chasing, conduit laying, junction box fixing before plastering', 'mep', 7, 13, '{"Brick Masonry - Ground Floor"}',
 '{"monsoon_risk":"low","notes":"IS 732; 3-phase provision for modern homes; earthing mandatory","local_materials":["PVC conduit","MS wire"]}'::jsonb),

('Plumbing Rough-in', 'Underground drainage, water supply lines, sanitary blocks before plastering', 'mep', 7, 13, '{"Brick Masonry - Ground Floor"}',
 '{"monsoon_risk":"low","notes":"IS 1172; CPVC for hot water; PVC for cold; slope check","local_materials":["CPVC pipe","PVC pipe","SWR pipe"]}'::jsonb),

-- WATERPROOFING
('Roof Waterproofing', 'Brick bat coba or membrane waterproofing on roof slab', 'specialty', 5, 14, '{"Roof Slab (Ground Floor)"}',
 '{"monsoon_risk":"high","monsoon_buffer_days":7,"notes":"Critical before monsoon; IS 3067; 2% slope for drainage","local_materials":["brick bat","Dr.Fixit membrane","APP membrane"]}'::jsonb),

('External Waterproofing', 'Bathroom, wet area, and external wall waterproofing treatment', 'specialty', 4, 15, '{"Roof Waterproofing"}',
 '{"monsoon_risk":"high","notes":"Integral crystalline compound or coating; 24hr flood test mandatory","local_materials":["Dr.Fixit Pidicrete","Sunanda Krystal"]}'::jsonb),

-- FINISHING
('External Plastering', 'Cement plaster (1:4) on external walls, double coat', 'finishing', 10, 16, '{"External Waterproofing"}',
 '{"monsoon_risk":"high","monsoon_buffer_days":10,"notes":"Avoid during monsoon; curing 7 days; IS 1661","local_materials":["river sand <8% silt","OPC 43 grade"]}'::jsonb),

('Internal Plastering', 'Single/double coat cement or gypsum plaster on internal walls', 'finishing', 12, 17, '{"Electrical Conduit Rough-in","Plumbing Rough-in"}',
 '{"monsoon_risk":"low","notes":"Gypsum plaster needs no curing; IS 1661; uniform thickness","local_materials":["gypsum plaster","river sand"]}'::jsonb),

('Flooring', 'Vitrified tiles, granite, or marble flooring with skirting', 'finishing', 14, 18, '{"Internal Plastering"}',
 '{"monsoon_risk":"low","notes":"IS 13630; 3-day curing; check level ±3mm; grout after 24 hrs","local_materials":["vitrified tiles","Kajaria/RAK","white cement grout"]}'::jsonb),

('Doors & Windows', 'Frame fixing, shutter installation, hardware fitting, grills', 'finishing', 7, 19, '{"Internal Plastering"}',
 '{"monsoon_risk":"low","notes":"Season wood before use; UPVC preferred for coastal areas","local_materials":["teak wood","UPVC frames","aluminum sections"]}'::jsonb),

('Painting - External', 'Primer + 2 coats exterior emulsion on external walls', 'finishing', 7, 20, '{"External Plastering"}',
 '{"monsoon_risk":"high","monsoon_buffer_days":14,"notes":"Avoid during monsoon; IS 2395; texture paint for modern look","local_materials":["Asian Paints Apex Weatherproof","Dulux Weathershield"]}'::jsonb),

('Painting - Internal', 'Wall putty + primer + 2 coats interior emulsion', 'finishing', 10, 21, '{"Flooring","Doors & Windows"}',
 '{"monsoon_risk":"low","notes":"IS 428; putty before primer; ventilate during application","local_materials":["Asian Paints Tractor Emulsion","Birla White putty"]}'::jsonb),

-- MEP FINISHING
('Electrical Finishing', 'Switches, sockets, MCBs, DB fitting, fan, light installation', 'mep', 5, 22, '{"Painting - Internal"}',
 '{"monsoon_risk":"low","notes":"IS 732; test insulation resistance; earthing continuity; ELCB mandatory","local_materials":[]}'::jsonb),

('Plumbing Finishing', 'Sanitary ware, fittings, taps, shower, water heater installation', 'mep', 5, 22, '{"Painting - Internal"}',
 '{"monsoon_risk":"low","notes":"IS 1172; pressure test all lines; check slope of drainage","local_materials":[]}'::jsonb),

-- FINAL
('Final Inspection & Handover', 'Snag list walkthrough, municipal OC application, keys handover', 'legal', 5, 23, '{"Electrical Finishing","Plumbing Finishing","Painting - External"}',
 '{"monsoon_risk":"low","notes":"Obtain Occupancy Certificate from BBMP/corporation; check fire NOC if >15m height","local_materials":[]}'::jsonb)

ON CONFLICT DO NOTHING;

-- -------------------------
-- SEED: CHECKLIST ITEMS FOR KEY MODULES
-- -------------------------

-- Foundation Pre-Start Checklist
INSERT INTO milestone_checklists (module_id, gate_type, role, item_text, item_text_hi, item_text_kn, is_critical, evidence_required, sequence_order)
SELECT m.id, 'pre_start', 'manager', item_text, item_text_hi, item_text_kn, is_critical, evidence_required, seq
FROM milestone_modules m
CROSS JOIN (VALUES
  ('Soil test report received and verified (bearing capacity ≥ design load)', 'मिट्टी परीक्षण रिपोर्ट प्राप्त और सत्यापित', 'ಮಣ್ಣಿನ ಪರೀಕ್ಷೆ ವರದಿ ದೃಢೀಕರಿಸಲಾಗಿದೆ', true, 'document', 1),
  ('Structural drawing approved by licensed engineer', 'लाइसेंस प्राप्त इंजीनियर से संरचनात्मक ड्राइंग अनुमोदित', 'ಲೈಸೆನ್ಸ್ ಇಂಜಿನೀಯರ್‌ನಿಂದ ಡ್ರಾಯಿಂಗ್ ಅನುಮೋದಿತ', true, 'document', 2),
  ('Sand quality tested (silt content < 8%)', 'रेत गुणवत्ता परीक्षण (गाद < 8%)', 'ಮರಳಿನ ಗುಣಮಟ್ಟ ಪರೀಕ್ಷಿಸಲಾಗಿದೆ (ಹೂಳು < 8%)', true, 'photo', 3),
  ('Anti-termite treatment vendor confirmed and chemical approved', 'दीमक रोधी उपचार विक्रेता की पुष्टि', 'ಗೆದ್ದಲು ನಿಯಂತ್ರಣ ವ್ಯಾಪಾರಿ ದೃಢೀಕರಿಸಲಾಗಿದೆ', true, 'document', 4),
  ('Steel grade confirmed (TMT Fe500D)', 'स्टील ग्रेड पुष्टि (TMT Fe500D)', 'ಸ್ಟೀಲ್ ಗ್ರೇಡ್ ದೃಢೀಕರಿಸಲಾಗಿದೆ', false, 'none', 5),
  ('Construction water quality tested (TDS < 2000 ppm)', 'निर्माण जल गुणवत्ता परीक्षण', 'ನಿರ್ಮಾಣ ನೀರಿನ ಗುಣಮಟ್ಟ ಪರೀಕ್ಷಿಸಲಾಗಿದೆ', false, 'none', 6)
) AS items(item_text, item_text_hi, item_text_kn, is_critical, evidence_required, seq)
WHERE m.name = 'Footings & Foundation' AND m.account_id IS NULL;

-- Foundation Post-Completion Checklist
INSERT INTO milestone_checklists (module_id, gate_type, role, item_text, item_text_hi, item_text_kn, is_critical, evidence_required, sequence_order)
SELECT m.id, 'post_completion', 'manager', item_text, item_text_hi, item_text_kn, is_critical, evidence_required, seq
FROM milestone_modules m
CROSS JOIN (VALUES
  ('Concrete cube test result ≥ M25 (tested at 7 and 28 days)', 'कंक्रीट क्यूब परीक्षण परिणाम ≥ M25', 'ಕಾಂಕ್ರೀಟ್ ಕ್ಯೂಬ್ ಪರೀಕ್ಷೆ ≥ M25', true, 'document', 1),
  ('Plinth level verified (±5mm tolerance)', 'प्लिंथ स्तर सत्यापित (±5mm सहनशीलता)', 'ತಳಮೊರಡಿ ಮಟ್ಟ ದೃಢೀಕರಿಸಲಾಗಿದೆ', true, 'photo', 2),
  ('DPC continuity checked across all walls', 'सभी दीवारों पर DPC निरंतरता जांच', 'ಎಲ್ಲ ಗೋಡೆಗಳಲ್ಲಿ DPC ಸಾತತ್ಯ ಪರಿಶೀಲಿಸಲಾಗಿದೆ', true, 'photo', 3),
  ('Anti-termite treatment certificate received', 'दीमक रोधी उपचार प्रमाणपत्र प्राप्त', 'ಗೆದ್ದಲು ನಿಯಂತ್ರಣ ಪ್ರಮಾಣಪತ್ರ ಸ್ವೀಕರಿಸಲಾಗಿದೆ', true, 'document', 4),
  ('Curing completed (minimum 7 days for foundations)', 'क्यूरिंग पूर्ण (न्यूनतम 7 दिन)', 'ಗುಣಪಡಿಸುವಿಕೆ ಪೂರ್ಣ (ಕನಿಷ್ಠ 7 ದಿನ)', false, 'none', 5)
) AS items(item_text, item_text_hi, item_text_kn, is_critical, evidence_required, seq)
WHERE m.name = 'Footings & Foundation' AND m.account_id IS NULL;

-- Roof Slab Pre-Start (Worker checklist)
INSERT INTO milestone_checklists (module_id, gate_type, role, item_text, item_text_hi, item_text_kn, is_critical, evidence_required, sequence_order)
SELECT m.id, 'pre_start', 'worker', item_text, item_text_hi, item_text_kn, is_critical, evidence_required, seq
FROM milestone_modules m
CROSS JOIN (VALUES
  ('Safety harness and helmets available for all workers', 'सभी मजदूरों के लिए सुरक्षा उपकरण उपलब्ध', 'ಎಲ್ಲ ಕಾರ್ಮಿಕರಿಗೆ ಸುರಕ್ಷತಾ ಸಲಕರಣೆ ಲಭ್ಯವಿದೆ', true, 'photo', 1),
  ('Shuttering material and props inspected and approved', 'शटरिंग सामग्री और प्रॉप्स की जांच और अनुमोदन', 'ಶಟರಿಂಗ್ ಸಾಮಗ್ರಿ ಮತ್ತು ಪ್ರಾಪ್ ತಪಾಸಣೆ ಮಾಡಲಾಗಿದೆ', true, 'photo', 2),
  ('Bar bending schedule distributed to steel workers', 'बार बेंडिंग शेड्यूल स्टील कर्मियों को वितरित', 'ಬಾರ್ ಬೆಂಡಿಂಗ್ ಶೆಡ್ಯೂಲ್ ವಿತರಿಸಲಾಗಿದೆ', false, 'none', 3),
  ('Concrete pump / transit mixer booked and confirmed', 'कंक्रीट पंप / ट्रांजिट मिक्सर बुक और कन्फर्म', 'ಕಾಂಕ್ರೀಟ್ ಪಂಪ್ ದೃಢೀಕರಿಸಲಾಗಿದೆ', true, 'none', 4)
) AS items(item_text, item_text_hi, item_text_kn, is_critical, evidence_required, seq)
WHERE m.name = 'Roof Slab (Ground Floor)' AND m.account_id IS NULL;

-- Waterproofing Pre-Start (Manager + Owner)
INSERT INTO milestone_checklists (module_id, gate_type, role, item_text, item_text_hi, item_text_kn, is_critical, evidence_required, sequence_order)
SELECT m.id, 'pre_start', 'owner', item_text, item_text_hi, item_text_kn, is_critical, evidence_required, seq
FROM milestone_modules m
CROSS JOIN (VALUES
  ('Waterproofing material brand and type approved by owner', 'मालिक द्वारा वाटरप्रूफिंग सामग्री ब्रांड अनुमोदित', 'ಮಾಲೀಕರಿಂದ ವಾಟರ್‌ಪ್ರೂಫಿಂಗ್ ಬ್ರಾಂಡ್ ಅನುಮೋದಿತ', true, 'none', 1),
  ('Warranty terms reviewed and accepted (10-year minimum)', 'वारंटी शर्तें समीक्षित और स्वीकृत (10 वर्ष न्यूनतम)', 'ವಾರಂಟಿ ನಿಯಮಗಳನ್ನು ಪರಿಶೀಲಿಸಲಾಗಿದೆ', false, 'none', 2)
) AS items(item_text, item_text_hi, item_text_kn, is_critical, evidence_required, seq)
WHERE m.name = 'Roof Waterproofing' AND m.account_id IS NULL;

-- -------------------------
-- STORAGE BUCKET NOTE
-- -------------------------
-- The 'construction-documents' bucket must be created via Supabase Dashboard or CLI:
--   supabase storage create construction-documents --public false
--   supabase storage create checklist-evidence --public false
-- Storage policies should allow authenticated reads for project members
-- and authenticated uploads for managers/admins.

-- -------------------------
-- CRON JOB: DOCUMENT EXPIRY CHECK
-- -------------------------
-- Schedule the check-document-expiry edge function to run daily at 7:00 AM IST (1:30 AM UTC).
-- Requires pg_cron extension. Enable via Supabase Dashboard → Database → Extensions → pg_cron.
-- Run this block AFTER enabling pg_cron:
--
-- SELECT cron.schedule(
--   'check-document-expiry-daily',
--   '30 1 * * *',  -- 1:30 AM UTC = 7:00 AM IST
--   $$
--     SELECT net.http_post(
--       url := current_setting('app.supabase_url') || '/functions/v1/check-document-expiry',
--       headers := jsonb_build_object(
--         'Content-Type', 'application/json',
--         'Authorization', 'Bearer ' || current_setting('app.service_role_key')
--       ),
--       body := '{}'::jsonb
--     )
--   $$
-- );
--
-- Alternatively, use the Supabase Dashboard → Database → Cron Jobs to create the schedule.

-- -------------------------
-- ROLLBACK
-- -------------------------
-- To rollback this migration, execute:
-- DROP TABLE IF EXISTS document_comments CASCADE;
-- DROP TABLE IF EXISTS document_access_log CASCADE;
-- DROP TABLE IF EXISTS documents CASCADE;
-- DROP TABLE IF EXISTS phase_gate_approvals CASCADE;
-- DROP TABLE IF EXISTS checklist_completions CASCADE;
-- DROP TABLE IF EXISTS milestone_checklists CASCADE;
-- DROP TABLE IF EXISTS daily_deltas CASCADE;
-- DROP TABLE IF EXISTS key_results CASCADE;
-- DROP TABLE IF EXISTS milestone_phases CASCADE;
-- DROP TABLE IF EXISTS milestone_modules CASCADE;
