-- ============================================================
-- Galovic Lab Intranet — Supabase Schema + Seed Data
-- Run this in the Supabase SQL Editor (galovic lab project)
-- ============================================================

-- ============================================================
-- 1. TABLES
-- ============================================================

-- profiles: linked to auth.users
CREATE TABLE IF NOT EXISTS profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL DEFAULT '',
  role text NOT NULL DEFAULT 'member' CHECK (role IN ('admin', 'member')),
  created_at timestamptz DEFAULT now()
);

-- projects
CREATE TABLE IF NOT EXISTS projects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  icon text DEFAULT '🔬',
  area_tag text,          -- display label, e.g. "Post-Stroke Epilepsy"
  status text DEFAULT 'preparation'
    CHECK (status IN ('preparation', 'active', 'submitted', 'published', 'preprint')),
  area text,              -- area code for filtering, e.g. "pse"
  description text,
  finding text,
  database_tags text[],   -- e.g. ARRAY['TriNetX', 'UK Biobank']
  methods text,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- team_members
CREATE TABLE IF NOT EXISTS team_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  initials text,
  role text,
  affiliation text,
  focus text,
  bg_color text DEFAULT '#4a6741',
  is_visiting boolean DEFAULT false,
  is_active boolean DEFAULT true,
  sort_order int DEFAULT 0
);

-- project_members (join table)
CREATE TABLE IF NOT EXISTS project_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid REFERENCES projects(id) ON DELETE CASCADE,
  member_name text NOT NULL,
  member_role text,
  note text
);

-- ideas board (persisted)
CREATE TABLE IF NOT EXISTS ideas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text,
  area text,
  db text,
  timeline text,
  submitter text,
  feasibility text,
  note text,
  papers text[],
  created_at timestamptz DEFAULT now()
);

-- ============================================================
-- 2. UPDATED_AT TRIGGER for projects
-- ============================================================

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS projects_updated_at ON projects;
CREATE TRIGGER projects_updated_at
  BEFORE UPDATE ON projects
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- 3. HELPER FUNCTION: is_admin()
-- ============================================================

CREATE OR REPLACE FUNCTION is_admin()
RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- ============================================================
-- 4. ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE ideas ENABLE ROW LEVEL SECURITY;

-- profiles: users can read their own; admins can read all
DROP POLICY IF EXISTS "profiles_select_own" ON profiles;
CREATE POLICY "profiles_select_own" ON profiles
  FOR SELECT USING (auth.uid() = id OR is_admin());

DROP POLICY IF EXISTS "profiles_update_admin" ON profiles;
CREATE POLICY "profiles_update_admin" ON profiles
  FOR UPDATE USING (is_admin());

DROP POLICY IF EXISTS "profiles_insert_own" ON profiles;
CREATE POLICY "profiles_insert_own" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- projects: all authenticated users can read; only admins can write
DROP POLICY IF EXISTS "projects_select_auth" ON projects;
CREATE POLICY "projects_select_auth" ON projects
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "projects_insert_admin" ON projects;
CREATE POLICY "projects_insert_admin" ON projects
  FOR INSERT WITH CHECK (is_admin());

DROP POLICY IF EXISTS "projects_update_admin" ON projects;
CREATE POLICY "projects_update_admin" ON projects
  FOR UPDATE USING (is_admin());

DROP POLICY IF EXISTS "projects_delete_admin" ON projects;
CREATE POLICY "projects_delete_admin" ON projects
  FOR DELETE USING (is_admin());

-- team_members: all authenticated can read; only admins can write
DROP POLICY IF EXISTS "team_select_auth" ON team_members;
CREATE POLICY "team_select_auth" ON team_members
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "team_insert_admin" ON team_members;
CREATE POLICY "team_insert_admin" ON team_members
  FOR INSERT WITH CHECK (is_admin());

DROP POLICY IF EXISTS "team_update_admin" ON team_members;
CREATE POLICY "team_update_admin" ON team_members
  FOR UPDATE USING (is_admin());

DROP POLICY IF EXISTS "team_delete_admin" ON team_members;
CREATE POLICY "team_delete_admin" ON team_members
  FOR DELETE USING (is_admin());

-- project_members: all authenticated can read; all authenticated can insert (join project)
DROP POLICY IF EXISTS "pm_select_auth" ON project_members;
CREATE POLICY "pm_select_auth" ON project_members
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "pm_insert_auth" ON project_members;
CREATE POLICY "pm_insert_auth" ON project_members
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "pm_delete_admin" ON project_members;
CREATE POLICY "pm_delete_admin" ON project_members
  FOR DELETE USING (is_admin());

-- ideas: all authenticated can read and insert; admins can delete
DROP POLICY IF EXISTS "ideas_select_auth" ON ideas;
CREATE POLICY "ideas_select_auth" ON ideas
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "ideas_insert_auth" ON ideas;
CREATE POLICY "ideas_insert_auth" ON ideas
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "ideas_delete_admin" ON ideas;
CREATE POLICY "ideas_delete_admin" ON ideas
  FOR DELETE USING (is_admin());

-- ============================================================
-- 5. SEED DATA — Team Members
-- ============================================================

INSERT INTO team_members (name, initials, role, affiliation, focus, bg_color, is_visiting, is_active, sort_order) VALUES
('Dr. Marian Galovic',         'MG',  'Principal Investigator', 'University Hospital Zurich',        'PSE, epileptogenesis, biomarkers, multicenter trials',              '#4a6741', false, true, 1),
('Carolina Ferreira-Atuesta',  'CF',  'PhD Student',            'UZH / University of Liverpool',    'Late-onset epilepsy, TriNetX, pharmacoepidemiology',                '#6b5c8a', false, true, 2),
('Dr. Kai Michael Schubert',   'KS',  'Senior Researcher',      'University Hospital Zurich',        'EEG, PSE, SELECT consortium, epidemiology',                         '#5c7a8a', false, true, 3),
('Dr. Katharina Schuler',      'KSc', 'Clinical Researcher',    'University Hospital Zurich',        'Immunology & epilepsy, TriNetX, clinical AI',                       '#4a7a6e', false, true, 4),
('Dr. Miranda Stattmann',      'MS',  'Clinical Researcher',    'University Hospital Zurich',        'Biomarkers, IMPOSE cohort, EVs, NfL, GFAP',                         '#7a6e4a', false, true, 5),
('Dr. Marco Di Donato',        'MD',  'Clinical Researcher',    'University Hospital Zurich',        'Sleep & epilepsy, UK Biobank, mortality',                           '#5c7a8a', false, true, 6),
('Dr. Anton Schmick',          'AS',  'Clinical Researcher',    'UZH / Lübeck',                     'Oncology & epilepsy, TriNetX, pharmacotherapy',                     '#4a5c7a', false, true, 7),
('Xin You Tai',                'XT',  'Research Collaborator',  'University of Oxford',              'Neuroimaging, UK Biobank, late-onset epilepsy',                     '#5c4a7a', true,  true, 8),
('Lubin Gou',                  'LG',  'Visiting Researcher',    'University Hospital Zurich',        'Brain age estimation, MRI, ENIGMA pipeline',                        '#7a4a5c', true,  true, 9),
('Peter Westarp',              'PW',  'Research Student',       'University Hospital Zurich',        'Biological aging, PhenoAge, UK Biobank',                            '#8a6a4a', true,  true, 10)
ON CONFLICT DO NOTHING;

-- ============================================================
-- 6. SEED DATA — Projects
-- ============================================================

-- Store UUIDs in variables for use in project_members
DO $$
DECLARE
  p1  uuid; p2  uuid; p3  uuid; p4  uuid; p5  uuid;
  p6  uuid; p7  uuid; p8  uuid; p9  uuid; p10 uuid;
  p11 uuid; p12 uuid; p13 uuid;
BEGIN

INSERT INTO projects (name, icon, area_tag, status, area, description, finding, database_tags, methods, notes)
VALUES (
  'Sleep Duration & All-Cause Mortality in Adults with Epilepsy',
  '😴', 'Sleep', 'preparation', 'sleep',
  'Cohort study of 2,874 adults with epilepsy followed for 15 years in UK Biobank, examining the association between sleep duration and all-cause mortality.',
  'Sleeping ≥9h associated with significantly higher all-cause mortality vs ≤7h (HR 1.52; 95% CI 1.15–2.00; p=.003). Routine sleep assessment may identify high-risk PWE.',
  ARRAY['UK Biobank'],
  'Cox proportional hazards regression; sleep duration categories; adjusted survival analysis.',
  'UK Biobank (n=2,874; 15-year follow-up). Collaborators: Xin You Tai (Oxford), Prof. Christian R. Baumann (UZH).'
) RETURNING id INTO p1;

INSERT INTO projects (name, icon, area_tag, status, area, description, finding, database_tags, methods, notes)
VALUES (
  'Continuous vs. Short EEG after Ischemic Stroke for Predicting Post-Stroke Epilepsy',
  '🧠', 'Post-Stroke Epilepsy', 'preparation', 'pse',
  'Retrospective SeLECT Consortium study (n=283) comparing cEEG (≥12h) vs 60-min sEEG for detecting epileptiform abnormalities and predicting PSE over 41 months.',
  'cEEG tripled IED detection (OR 3.75). LPDs (sHR 4.50) and electrographic seizures (sHR 3.63) were the strongest PSE predictors. ΔC-index +0.055; NRI 0.25.',
  ARRAY['SELECT Multicenter'],
  'Fine–Gray competing-risks regression; within-patient OR; C-index; NRI.',
  'SELECT Multicenter (n=283; median 41-month follow-up). Co-senior: Galovic (UZH), Gaspard (Brussels/Yale), Punia (Cleveland Clinic).'
) RETURNING id INTO p2;

INSERT INTO projects (name, icon, area_tag, status, area, description, finding, database_tags, methods, notes)
VALUES (
  'Hearing Aid Use & Risk of Dementia in LOE, Stroke & Diabetes with Hearing Loss',
  '👂', 'Late-Onset Epilepsy', 'preparation', 'loe',
  'Target trial emulation using TriNetX (>250M patients) examining whether hearing aid use reduces dementia incidence across three high-risk neurological populations.',
  'HA use reduced Alzheimer''s risk: epilepsy HR 0.52, stroke HR 0.59, diabetes HR 0.69. All-cause dementia (epilepsy) HR 0.50.',
  ARRAY['TriNetX'],
  'Propensity score matching; target trial emulation; Cox regression; competing risks.',
  'TriNetX (epilepsy: 1,093 pairs; stroke: 2,363; diabetes: 14,934). Lead: Ferreira-Atuesta. Co-senior: Lip, Mbizvo, Galovic. Liverpool collaboration.'
) RETURNING id INTO p3;

INSERT INTO projects (name, icon, area_tag, status, area, description, finding, database_tags, methods, notes)
VALUES (
  'New Epilepsy: JAK Inhibitors vs TNFα Inhibitors in Rheumatoid Arthritis',
  '💊', 'Pharmacotherapy', 'preprint', 'pharm',
  'Pharmacoepidemiological TriNetX study comparing incident epilepsy risk in RA patients on tofacitinib or JAK inhibitors vs TNFα inhibitors.',
  'Tofacitinib vs TNFα: HR 0.42 (0.21–0.84), p=0.011. All JAK inhibitors vs TNFα: HR 0.64 (0.42–0.98), p=0.037.',
  ARRAY['TriNetX'],
  'Propensity-score matched cohort; Cox regression; competing risks; forest plot.',
  'TriNetX (tofacitinib: n=5,485 vs 5,482; all JAK: n=9,836 vs 9,844). Lead: Schuler. Linked to Koetser Foundation grant proposal (Feb 2026).'
) RETURNING id INTO p4;

INSERT INTO projects (name, icon, area_tag, status, area, description, finding, database_tags, methods, notes)
VALUES (
  'Incidence & Attributable Disease Burden of Adult-Onset Acquired Epilepsy',
  '📊', 'Epidemiology', 'preparation', 'epidemiology',
  'Real-world analysis of 2.4M adults across 20 brain insult etiologies, quantifying acquired epilepsy incidence and its independent contribution to long-term morbidity and mortality.',
  '3.8% incidence overall (1.8% MS → 10.5% malignant CNS tumors). Acquired epilepsy independently confers excess mortality, hospitalization, frailty, injury risk, and cognitive decline.',
  ARRAY['TriNetX'],
  'Incident cohort; propensity-matched controls within etiology; Cox regression; 32 prespecified outcomes across 5 clinical domains.',
  'TriNetX (n=2,489,454; 20 etiologies). Collaboration: UCL Queen Square (Koepp), Karolinska (Curman), Lübeck (Ludwig, Schmick).'
) RETURNING id INTO p5;

INSERT INTO projects (name, icon, area_tag, status, area, description, finding, database_tags, methods, notes)
VALUES (
  'Epilepsy is Associated with Accelerated Biological Aging (PhenoAge, UK Biobank)',
  '⏳', 'Brain Aging', 'preparation', 'aging',
  'Cross-sectional and prospective analysis of 415,915 UK Biobank participants comparing PhenoAgeAccel (biological − chronological age) in prevalent epilepsy, incident epilepsy, and controls.',
  'Incident epilepsy: +1.70y age acceleration (p<0.001), persisting after full adjustment (+0.85y). Higher baseline PhenoAgeAccel predicts earlier epilepsy onset. Carbamazepine: −0.99y; phenytoin: +1.05y.',
  ARRAY['UK Biobank'],
  'Multivariable regression; PhenoAge (9-biomarker composite); cross-sectional + prospective analysis; ASM subgroup analysis.',
  'UK Biobank (n=415,915). Lead: Peter Westarp (research student). Keywords: Epilepsy, Biological Aging, PhenoAge.'
) RETURNING id INTO p6;

INSERT INTO projects (name, icon, area_tag, status, area, description, finding, database_tags, methods, notes)
VALUES (
  'Brain Age Estimation from Structural MRI — ENIGMA Dataset (BrainAgeR Pipeline)',
  '🧩', 'Brain Aging', 'active', 'aging',
  'Automated brain age estimation using the BrainAgeR Pipeline (v2.1) on T1-weighted MRI from the ENIGMA epilepsy dataset. Dockerised workflow: SPM12 segmentation, R-based modeling, QC reports.',
  NULL,
  ARRAY['ENIGMA'],
  'SPM12 segmentation; BrainAgeR v2.1 Docker; tissue volume extraction; per-subject QC report.',
  'ENIGMA (T1 MRI dataset). Lead: Lubin Gou (visiting researcher). Contact: gou.lubin@usz.ch'
) RETURNING id INTO p7;

INSERT INTO projects (name, icon, area_tag, status, area, description, finding, database_tags, methods, notes)
VALUES (
  'Vortioxetine vs Citalopram & Outcomes in Patients with Brain Neoplasms',
  '🔬', 'Pharmacotherapy', 'preparation', 'pharm',
  'TriNetX pharmacoepidemiological study comparing outcomes of vortioxetine versus citalopram in patients with brain neoplasms, examining psychiatric, cognitive, and oncological endpoints.',
  NULL,
  ARRAY['TriNetX'],
  'Propensity-score matched cohort; survival analysis; multidomain outcome comparison.',
  'Lead: Anton Schmick. Collaboration: Lübeck Institute (Ludwig).'
) RETURNING id INTO p8;

INSERT INTO projects (name, icon, area_tag, status, area, description, finding, database_tags, methods, notes)
VALUES (
  'Biomarkers in Epilepsy — IMPOSE Pilot (EVs, NfL, GFAP, NULISA)',
  '🧪', 'Biomarkers', 'active', 'biomarker',
  'Pilot biomarker study using IMPOSE cohort samples with longitudinal blood collection (shortly after seizure and 6-month follow-up). Explores EVs, pTau217, NfL, GFAP, and NULISA CNS panels.',
  '8 IMPOSE patients with suitable longitudinal samples identified. Within-subject post-event vs 6-month follow-up design. NULISA: ~150 CHF/sample (Gothenburg). NfL, GFAP available on Lumipulse.',
  ARRAY['IMPOSE Study'],
  'EV isolation (NCAM+ particles); NULISA CNS panel; pTau217, NfL, GFAP (Lumipulse); within-subject paired analysis.',
  'Lead: Miranda Stattmann. Pending SNSF / alternative funding (min CHF 200–300k). FINESSE pilot data phase underway.'
) RETURNING id INTO p9;

INSERT INTO projects (name, icon, area_tag, status, area, description, finding, database_tags, methods, notes)
VALUES (
  'LLM-Assisted EEG Report Analysis (MedGemma / Local Models)',
  '🤖', 'Clinical AI', 'active', 'ai',
  'Benchmarking local large language models (incl. MedGemma) for automated extraction and classification of structured information from clinical EEG reports.',
  NULL,
  ARRAY['Clinical AI'],
  'Local LLM deployment; structured variable extraction; accuracy benchmarking; MedGemma evaluation.',
  'Lead: Katharina Schuler. Harry (external collaborator) supporting implementation. Kickoff: Tue 24.02.'
) RETURNING id INTO p10;

INSERT INTO projects (name, icon, area_tag, status, area, description, finding, database_tags, methods, notes)
VALUES (
  'LLM-Assisted Clinical Data Extraction from Medical Records',
  '📑', 'Clinical AI', 'active', 'ai',
  'Using large language models to extract structured clinical variables from unstructured medical records (discharge letters, clinical notes).',
  NULL,
  ARRAY['Clinical AI'],
  'LLM prompt engineering; structured output validation; clinical NLP pipeline.',
  'Giannis Katsaros: departmental collaborator. Proof-of-concept: Codex pre-screening in ~3 minutes.'
) RETURNING id INTO p11;

INSERT INTO projects (name, icon, area_tag, status, area, description, finding, database_tags, methods, notes)
VALUES (
  'Sodium Channel Blockers & Reduced Dementia Risk in Late-Onset Unexplained Epilepsy',
  '🧬', 'Late-Onset Epilepsy', 'preparation', 'loe',
  'Target trial emulation using global federated real-world data (>75M adults aged ≥55) comparing dementia risk across antiseizure monotherapies in late-onset unexplained epilepsy. Tests whether sodium channel blockers provide disease-modifying neuroprotection via suppression of network hyperexcitability that drives amyloid-β release and tau propagation.',
  'Sodium channel blockers associated with 27% lower all-cause dementia hazard (HR 0.73, 95% CI 0.61–0.88) and 34% lower Alzheimer''s disease hazard (HR 0.66, 0.49–0.88) vs levetiracetam/brivaracetam. Replicated in Down syndrome cohort and National Alzheimer''s Coordinating Center (NACC) dataset.',
  ARRAY['TriNetX', 'NACC'],
  'Target trial emulation; propensity-score matched cohorts; Cox regression; competing risks; external replication in NACC and Down syndrome cohort.',
  'International collaboration: Oxford (Tai), Liverpool (Marson, Lip, Mbizvo), Gothenburg (Zelano), Mount Sinai (Hedden), UZH (Noain, Skwarzynska, Wyss, Schreiner, Jung). Co-senior: Lip, Mbizvo, Galovic.'
) RETURNING id INTO p12;

INSERT INTO projects (name, icon, area_tag, status, area, description, finding, database_tags, methods, notes)
VALUES (
  'Suicide Attempt Risk: Levetiracetam vs Lacosamide/Lamotrigine in Epilepsy',
  '⚕️', 'Pharmacotherapy', 'preparation', 'pharm',
  'Pharmacoepidemiological TriNetX study comparing suicide attempt rates in patients with epilepsy initiating levetiracetam versus lacosamide or lamotrigine, addressing the known psychiatric adverse effect signal of levetiracetam.',
  NULL,
  ARRAY['TriNetX'],
  'Propensity-score matched cohort; Cox regression; competing risks; psychiatric adverse event analysis.',
  'Lead: Miranda Stattmann. Addresses FDA/EMA neuropsychiatric safety signals for levetiracetam.'
) RETURNING id INTO p13;

-- ============================================================
-- 7. SEED DATA — Project Members
-- BASE TEAM (MG, CF, KS) is on all projects
-- ============================================================

-- Project 1: Sleep + Marco Di Donato, Xin You Tai
INSERT INTO project_members (project_id, member_name, member_role) VALUES
  (p1, 'Dr. Marian Galovic', 'Co-Investigator'),
  (p1, 'Carolina Ferreira-Atuesta', 'Co-Investigator'),
  (p1, 'Dr. Kai Michael Schubert', 'Co-Investigator'),
  (p1, 'Dr. Marco Di Donato', 'Lead Investigator'),
  (p1, 'Xin You Tai', 'Co-Investigator');

-- Project 2: cEEG (base team only)
INSERT INTO project_members (project_id, member_name, member_role) VALUES
  (p2, 'Dr. Marian Galovic', 'Co-Senior Investigator'),
  (p2, 'Carolina Ferreira-Atuesta', 'Co-Investigator'),
  (p2, 'Dr. Kai Michael Schubert', 'Lead Investigator');

-- Project 3: Hearing Aid (base team only)
INSERT INTO project_members (project_id, member_name, member_role) VALUES
  (p3, 'Dr. Marian Galovic', 'Co-Senior Investigator'),
  (p3, 'Carolina Ferreira-Atuesta', 'Lead Investigator'),
  (p3, 'Dr. Kai Michael Schubert', 'Co-Investigator');

-- Project 4: JAK + Katharina Schuler
INSERT INTO project_members (project_id, member_name, member_role) VALUES
  (p4, 'Dr. Marian Galovic', 'Co-Senior Investigator'),
  (p4, 'Carolina Ferreira-Atuesta', 'Co-Investigator'),
  (p4, 'Dr. Kai Michael Schubert', 'Co-Investigator'),
  (p4, 'Dr. Katharina Schuler', 'Lead Investigator');

-- Project 5: Disease Burden + Miranda, Katharina, Anton
INSERT INTO project_members (project_id, member_name, member_role) VALUES
  (p5, 'Dr. Marian Galovic', 'Co-Senior Investigator'),
  (p5, 'Carolina Ferreira-Atuesta', 'Co-Investigator'),
  (p5, 'Dr. Kai Michael Schubert', 'Lead Investigator'),
  (p5, 'Dr. Miranda Stattmann', 'Co-Investigator'),
  (p5, 'Dr. Katharina Schuler', 'Co-Investigator'),
  (p5, 'Dr. Anton Schmick', 'Co-Investigator');

-- Project 6: Biological Aging (base team only)
INSERT INTO project_members (project_id, member_name, member_role) VALUES
  (p6, 'Dr. Marian Galovic', 'Co-Senior Investigator'),
  (p6, 'Carolina Ferreira-Atuesta', 'Co-Investigator'),
  (p6, 'Dr. Kai Michael Schubert', 'Co-Investigator'),
  (p6, 'Peter Westarp', 'Lead Investigator');

-- Project 7: Brain Age + Lubin Gou
INSERT INTO project_members (project_id, member_name, member_role) VALUES
  (p7, 'Dr. Marian Galovic', 'Co-Investigator'),
  (p7, 'Carolina Ferreira-Atuesta', 'Co-Investigator'),
  (p7, 'Dr. Kai Michael Schubert', 'Co-Investigator'),
  (p7, 'Lubin Gou', 'Lead Investigator');

-- Project 8: Vortioxetine + Anton Schmick
INSERT INTO project_members (project_id, member_name, member_role) VALUES
  (p8, 'Dr. Marian Galovic', 'Co-Investigator'),
  (p8, 'Carolina Ferreira-Atuesta', 'Co-Investigator'),
  (p8, 'Dr. Kai Michael Schubert', 'Co-Investigator'),
  (p8, 'Dr. Anton Schmick', 'Lead Investigator');

-- Project 9: Biomarkers + Miranda, Tobias Weiss, Nils Briel
INSERT INTO project_members (project_id, member_name, member_role) VALUES
  (p9, 'Dr. Marian Galovic', 'Co-Senior Investigator'),
  (p9, 'Carolina Ferreira-Atuesta', 'Co-Investigator'),
  (p9, 'Dr. Kai Michael Schubert', 'Co-Investigator'),
  (p9, 'Dr. Miranda Stattmann', 'Lead Investigator'),
  (p9, 'Dr. Tobias Weiss', 'Co-Investigator'),
  (p9, 'Dr. Nils Briel', 'Co-Investigator');

-- Project 10: LLM EEG + Katharina
INSERT INTO project_members (project_id, member_name, member_role) VALUES
  (p10, 'Dr. Marian Galovic', 'Co-Investigator'),
  (p10, 'Carolina Ferreira-Atuesta', 'Co-Investigator'),
  (p10, 'Dr. Kai Michael Schubert', 'Co-Investigator'),
  (p10, 'Dr. Katharina Schuler', 'Lead Investigator');

-- Project 11: LLM Records + Giannis Katsaros
INSERT INTO project_members (project_id, member_name, member_role) VALUES
  (p11, 'Dr. Marian Galovic', 'Co-Investigator'),
  (p11, 'Carolina Ferreira-Atuesta', 'Co-Investigator'),
  (p11, 'Dr. Kai Michael Schubert', 'Co-Investigator'),
  (p11, 'Giannis Katsaros', 'Lead Investigator');

-- Project 12: Sodium Channel Blockers + Xin You Tai, Simon Schreiner, Hans Jung
INSERT INTO project_members (project_id, member_name, member_role) VALUES
  (p12, 'Dr. Marian Galovic', 'Co-Senior Investigator'),
  (p12, 'Carolina Ferreira-Atuesta', 'Lead Investigator'),
  (p12, 'Dr. Kai Michael Schubert', 'Co-Investigator'),
  (p12, 'Xin You Tai', 'Co-Investigator'),
  (p12, 'Dr. Simon Schreiner', 'Co-Investigator'),
  (p12, 'Dr. Hans H. Jung', 'Co-Investigator');

-- Project 13: Suicide Risk + Miranda Stattmann
INSERT INTO project_members (project_id, member_name, member_role) VALUES
  (p13, 'Dr. Marian Galovic', 'Co-Senior Investigator'),
  (p13, 'Carolina Ferreira-Atuesta', 'Co-Investigator'),
  (p13, 'Dr. Kai Michael Schubert', 'Co-Investigator'),
  (p13, 'Dr. Miranda Stattmann', 'Lead Investigator');

END $$;

-- ============================================================
-- 8. AUTO-CREATE PROFILE ON SIGN-UP (trigger)
-- ============================================================

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, name, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', NEW.email),
    'member'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- SETUP INSTRUCTIONS
-- ============================================================
-- 1. Run this script in the Supabase SQL Editor.
-- 2. Go to Authentication → Users → Add User (or invite by email).
-- 3. After the user is created, run:
--    UPDATE profiles SET name = 'Dr. Marian Galovic', role = 'admin'
--    WHERE id = '<user-uuid-from-auth-dashboard>';
-- 4. Paste SUPABASE_URL and SUPABASE_ANON_KEY into galovic-lab-intranet.html.
-- ============================================================
