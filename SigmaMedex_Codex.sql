-- ============================================================
-- SIGMAMEDEX STRATEGIC POTION CODEX — DDL + DML
-- Platform: Microsoft SQL Server (SSMS)
-- Student: George Wu (803630887)
-- Date: 30 March 2026
-- Assessment: ICTDBS416 + ICTPRG431 — Personal Codex Project
-- ============================================================
-- THIS SCRIPT DOES:
--   Phase 1: Creates the SigmaMedex database
--   Phase 2: Creates all 3 tables (2 lookup, 1 main arsenal)
--   Phase 3: Populates all tables with 415 catalogued compounds
--   Phase 4: Verification queries — arsenal inventory and codex summary
-- ============================================================
-- FIELD MANUAL NOTE:
--   This is a medication catalogue database. Every compound in this
--   codex has been indexed with its active ingredient, dosage form,
--   pricing intelligence (INR source + AUD conversion), and a
--   tactical codex descriptor explaining its mechanism of action.
--   The codex is the arsenal. The arsenal is the codex.
-- ============================================================


/*===============================================================
  PHASE 1: CREATE THE DATABASE
  ---------------------------------------------------------------
  CREATE DATABASE = DDL command (Data Definition Language)
  DDL = commands that define/change the STRUCTURE of the database.
  Other DDL: CREATE TABLE, ALTER TABLE, DROP TABLE

  GO = batch separator. Tells SSMS "execute everything above this
  line before moving on." Not actual SQL — it is an SSMS directive.
  Without GO, SSMS might try to run USE before the DB exists.

  The codex must have a clean foundation. We drop and rebuild
  every time — no residue from prior deployments.
===============================================================*/

-- Check if the database already exists before creating it.
-- This lets you re-run this entire script cleanly without errors.
-- We drop it first so we start fresh every time (tables, data, everything).
-- IF EXISTS = "only do this if the thing actually exists" — prevents errors.
-- sys.databases = system view listing every database on the server.

IF EXISTS (SELECT name FROM sys.databases WHERE name = 'SigmaMedex')
BEGIN
    -- Switch to master first — you cannot drop a DB you are currently using.
    USE master;
    -- ALTER DATABASE ... SET SINGLE_USER closes all other connections.
    -- WITH ROLLBACK IMMEDIATE = kick everyone out right now, do not wait.
    -- Without this, DROP will fail if anyone else has the DB open.
    ALTER DATABASE SigmaMedex SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SigmaMedex;
END
GO

CREATE DATABASE SigmaMedex;
GO

-- USE = switch context to this database. Everything after this runs inside SigmaMedex.
USE SigmaMedex;
GO


/*===============================================================
  PHASE 2: CREATE TABLES — THE CODEX ARCHITECTURE
  ---------------------------------------------------------------
  ORDER MATTERS. Parent tables FIRST, child tables AFTER.
  Why? Because a FOREIGN KEY can only point to a table that
  already exists. If you try to create Medication before
  MedicationCategory, the FK would fail — there is nothing to
  reference yet. The supply chain must exist before the arsenal.

  Creation order:
    1. MedicationCategory  (lookup — no FKs, no dependencies)
    2. DosageForm          (lookup — no FKs, no dependencies)
    3. Medication          (FK -> MedicationCategory, FK -> DosageForm)
===============================================================*/


/* === TABLE 1: MedicationCategory (LOOKUP TABLE) === */
-- A "lookup table" stores a fixed list of valid values.
-- Think of it like the category index in a field manual — you classify before you deploy.
-- This one stores all medication categories (Pharmaceutical Tablets, Anti Cancer Medicines, etc.)
-- Each category is a theatre of operations in the codex.

CREATE TABLE MedicationCategory (

    -- CategoryName is both the column name AND the value stored.
    -- NVARCHAR(60) = variable-length Unicode string, up to 60 characters.
    -- NVARCHAR vs VARCHAR: NVARCHAR supports international characters (Chinese, Arabic, etc.)
    -- Variable-length = only uses storage for the actual characters + 2 bytes overhead.
    -- This is the classification tag. Every compound in the arsenal gets one.
    CategoryName    NVARCHAR(60),

    -- CONSTRAINT = a rule the database enforces automatically.
    -- PRIMARY KEY = the column that uniquely identifies each row.
    -- Every table MUST have a PK. No two rows can have the same PK value.
    -- Naming convention: TableName_PK
    -- The PK is the codex index — no duplicates, no ambiguity.
    CONSTRAINT MedicationCategory_PK PRIMARY KEY (CategoryName)
);
GO


/* === TABLE 2: DosageForm (LOOKUP TABLE) === */
-- Stores the delivery mechanism for each compound in the codex.
-- Tablet, Capsule, Injection, Cream, Gel, Oral Jelly, Inhaler, etc.
-- The form dictates the deployment vector — how the compound enters the body.

CREATE TABLE DosageForm (

    -- NVARCHAR(30) = enough for the longest form name (Tablet (Extended Release) = 25 chars).
    -- This is the delivery classification. Every compound references one.
    FormName    NVARCHAR(30),

    -- PRIMARY KEY constraint. Same logic as MedicationCategory.
    -- One form name, one entry. No duplicates in the armoury manifest.
    CONSTRAINT DosageForm_PK PRIMARY KEY (FormName)
);
GO


/* === TABLE 3: Medication (MAIN ARSENAL TABLE) === */
-- The core of the codex. Every row is a catalogued compound with:
--   - Product identification (name, active ingredient, strength)
--   - Pricing intelligence (INR source price, AUD conversions per strip and per pill)
--   - Deployment metadata (dosage form, pills per strip, price source reliability)
--   - Tactical descriptor (mechanism of action in codex language)
--   - Classification links (FK to MedicationCategory and DosageForm)
--
-- This table has TWO foreign keys:
--   Category_Ref -> MedicationCategory(CategoryName)
--   DosageForm_Ref -> DosageForm(FormName)
-- Both parent tables must exist and be populated before inserting here.

CREATE TABLE Medication (

    -- INT = integer (whole number), 4 bytes, range up to ~2.1 billion.
    -- IDENTITY(1,1) = auto-increment. First compound gets ID 1, next gets 2, etc.
    -- You do not manually set this value — SQL Server assigns it automatically.
    -- The (1,1) means: start at 1, increment by 1.
    -- This is the codex serial number. Every compound gets a unique designation.
    Medication_ID       INT IDENTITY(1,1),

    -- NVARCHAR(120) = product name can be up to 120 Unicode characters.
    -- NOT NULL = this field is REQUIRED. Every compound must have a name.
    -- You cannot insert a row without providing this value.
    ProductName         NVARCHAR(120)   NOT NULL,

    -- Active ingredient(s). The actual chemical compound doing the work.
    -- Nullable — some products may not have a clearly listed active ingredient.
    ActiveIngredient    NVARCHAR(120),

    -- Strength/dosage. E.g., "200 mg", "0.5 mg", "5000 IU".
    -- Nullable — some entries do not specify strength.
    Strength            NVARCHAR(30),

    -- Raw INR price string exactly as listed on the source website.
    -- E.g., "Rs 410/Stripe", "Rs 3520/Strip". Preserved for audit trail.
    -- Nullable — not all compounds have pricing data.
    PriceINR            NVARCHAR(30),

    -- DECIMAL(8,2) = fixed-precision number. 8 total digits, 2 after decimal.
    -- Range: up to 999999.99. More than enough for medication pricing.
    -- AUD price per strip — converted from INR using exchange rate at time of cataloguing.
    -- Nullable — compounds without INR pricing have no AUD conversion.
    AUDPerStrip         DECIMAL(8,2),

    -- AUD price per individual pill/unit.
    -- Calculated: AUDPerStrip / pills per strip.
    -- This is the per-unit cost intelligence — the real comparison metric.
    AUDPerPill          DECIMAL(8,2),

    -- How many pills/units per strip/pack. E.g., "~10", "1 vial", "1 kit".
    -- NVARCHAR because some values are approximate (~10) or descriptive (1 vial).
    PillsPerStrip       NVARCHAR(10),

    -- Price source reliability tag.
    -- Values: 'Confirmed quote', 'INR converted', 'No price listed'
    -- This is the intelligence confidence level for the pricing data.
    PriceSource         NVARCHAR(20),

    -- NOT NULL = every compound MUST have a codex descriptor.
    -- The tactical description: mechanism of action, classification, purpose.
    -- This is the soul of the codex — what the compound does and how it kills.
    CodexDescriptor     NVARCHAR(200)   NOT NULL,

    -- FOREIGN KEY reference to MedicationCategory.
    -- NOT NULL = every compound must be classified. No unclassified ordnance.
    -- NVARCHAR(60) must match the PK column size in MedicationCategory.
    Category_Ref        NVARCHAR(60)    NOT NULL,

    -- FOREIGN KEY reference to DosageForm.
    -- Nullable — theoretically a compound could exist without a known form.
    -- NVARCHAR(30) must match the PK column size in DosageForm.
    DosageForm_Ref      NVARCHAR(30),

    -- PRIMARY KEY constraint. Medication_ID is the unique identifier.
    -- Naming convention: TableName_PK
    CONSTRAINT Medication_PK PRIMARY KEY (Medication_ID),

    -- FOREIGN KEY constraints link this table to its parent lookup tables.
    -- REFERENCES = "this column's values must exist in that other table's PK column."
    -- If you try to insert a Category_Ref that does not exist in MedicationCategory,
    -- SQL Server will reject the insert. Referential integrity — the codex stays clean.
    -- Naming convention: ChildTable_ParentTable_FK
    CONSTRAINT Medication_MedicationCategory_FK
        FOREIGN KEY (Category_Ref) REFERENCES MedicationCategory(CategoryName),

    CONSTRAINT Medication_DosageForm_FK
        FOREIGN KEY (DosageForm_Ref) REFERENCES DosageForm(FormName)
);
GO


/*===============================================================
  PHASE 3: POPULATE THE CODEX — DML (Data Manipulation Language)
  ---------------------------------------------------------------
  INSERT INTO = DML command. Adds new rows to a table.
  DML = commands that work with the DATA inside tables.
  Other DML: SELECT, UPDATE, DELETE

  ORDER MATTERS for inserts too. Lookup tables first, then the
  main arsenal. You cannot reference a category or form that
  does not yet exist in the parent table — the FK constraint
  will reject it.

  Population order:
    1. MedicationCategory (30 categories)
    2. DosageForm (22 dosage forms)
    3. Medication (415 compounds — the full arsenal)
===============================================================*/


/* --- Populate MedicationCategory: 30 operational theatres --- */
-- Each INSERT adds one category to the classification index.
-- N prefix = NVARCHAR literal (Unicode string). Required for NVARCHAR columns.
-- These are the theatres of operations. Every compound belongs to exactly one.

INSERT INTO MedicationCategory (CategoryName) VALUES (N'Anti Allergic Medicines');
INSERT INTO MedicationCategory (CategoryName) VALUES (N'Anti Anxiety & Anti Depressants');
INSERT INTO MedicationCategory (CategoryName) VALUES (N'Anti Cancer Medicines');
INSERT INTO MedicationCategory (CategoryName) VALUES (N'Anti Diabetic Medicine');
INSERT INTO MedicationCategory (CategoryName) VALUES (N'Anti Fungal Medicines');
INSERT INTO MedicationCategory (CategoryName) VALUES (N'Anti HIV Medicines');
INSERT INTO MedicationCategory (CategoryName) VALUES (N'Anti Malarial Medicine');
INSERT INTO MedicationCategory (CategoryName) VALUES (N'Anti Migraine Medicines');
INSERT INTO MedicationCategory (CategoryName) VALUES (N'Anti Viral Medicines');
INSERT INTO MedicationCategory (CategoryName) VALUES (N'Antibiotic Medicines');
INSERT INTO MedicationCategory (CategoryName) VALUES (N'Asthma Medicine');
INSERT INTO MedicationCategory (CategoryName) VALUES (N'Cardiovascular Medicine');
INSERT INTO MedicationCategory (CategoryName) VALUES (N'Erectile Dysfunction');
INSERT INTO MedicationCategory (CategoryName) VALUES (N'Eye Care');
INSERT INTO MedicationCategory (CategoryName) VALUES (N'Female Healthcare');
INSERT INTO MedicationCategory (CategoryName) VALUES (N'Hair Loss Medicines');
INSERT INTO MedicationCategory (CategoryName) VALUES (N'Hepatitis Medicine');
INSERT INTO MedicationCategory (CategoryName) VALUES (N'Hypertension Medicine');
INSERT INTO MedicationCategory (CategoryName) VALUES (N'Infertility Drugs');
INSERT INTO MedicationCategory (CategoryName) VALUES (N'Ivermectin Tablets');
INSERT INTO MedicationCategory (CategoryName) VALUES (N'Modafinil Tablets');
INSERT INTO MedicationCategory (CategoryName) VALUES (N'Pain Killer Medicines');
INSERT INTO MedicationCategory (CategoryName) VALUES (N'Pharmaceutical');
INSERT INTO MedicationCategory (CategoryName) VALUES (N'Pharmaceutical Injection');
INSERT INTO MedicationCategory (CategoryName) VALUES (N'Pharmaceutical Tablets');
INSERT INTO MedicationCategory (CategoryName) VALUES (N'Pregabalin');
INSERT INTO MedicationCategory (CategoryName) VALUES (N'Skin Care');
INSERT INTO MedicationCategory (CategoryName) VALUES (N'Steroid Tablets');
INSERT INTO MedicationCategory (CategoryName) VALUES (N'Veterinary Medicines');
INSERT INTO MedicationCategory (CategoryName) VALUES (N'Weight Loss');
GO


/* --- Populate DosageForm: 22 delivery vectors --- */
-- Each form represents a delivery mechanism — how the compound reaches its target.
-- From tablets to injections to oral jellies. The vector shapes the deployment.

INSERT INTO DosageForm (FormName) VALUES (N'Capsule');
INSERT INTO DosageForm (FormName) VALUES (N'Chewable Tablet');
INSERT INTO DosageForm (FormName) VALUES (N'Cream');
INSERT INTO DosageForm (FormName) VALUES (N'Dispersible Tablet');
INSERT INTO DosageForm (FormName) VALUES (N'Eye Drops');
INSERT INTO DosageForm (FormName) VALUES (N'Gel');
INSERT INTO DosageForm (FormName) VALUES (N'Inhaler');
INSERT INTO DosageForm (FormName) VALUES (N'Injection');
INSERT INTO DosageForm (FormName) VALUES (N'Injection Pen');
INSERT INTO DosageForm (FormName) VALUES (N'Kit');
INSERT INTO DosageForm (FormName) VALUES (N'Lotion');
INSERT INTO DosageForm (FormName) VALUES (N'Ointment');
INSERT INTO DosageForm (FormName) VALUES (N'Oral Jelly');
INSERT INTO DosageForm (FormName) VALUES (N'Respules');
INSERT INTO DosageForm (FormName) VALUES (N'Soft Gel Capsule');
INSERT INTO DosageForm (FormName) VALUES (N'Soft Gelatin Capsule');
INSERT INTO DosageForm (FormName) VALUES (N'Solution');
INSERT INTO DosageForm (FormName) VALUES (N'Spray');
INSERT INTO DosageForm (FormName) VALUES (N'Syrup');
INSERT INTO DosageForm (FormName) VALUES (N'Tablet');
INSERT INTO DosageForm (FormName) VALUES (N'Tablet (Extended Release)');
INSERT INTO DosageForm (FormName) VALUES (N'Topical');
GO


/* --- Populate Medication: 415 compounds in the full arsenal --- */
-- Each INSERT catalogues one compound with all intelligence fields.
-- NULL = no data available for that field. We do not fabricate intelligence.
-- The IDENTITY column (Medication_ID) is omitted — SQL Server auto-assigns it.
-- N prefix on all NVARCHAR string literals. DECIMAL values are bare numbers.


/* ~~~ PHARMACEUTICAL TABLETS — 46 compounds ~~~ */

INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Artesunate 200Mg Tablets', N'Artesunate', N'200 mg', N'Rs 410/Stripe', 6.85, 0.68, N'~10', N'INR converted', N'Antimalarial strike agent. Parasite cell destruction on contact.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Piracetam Cerecetam 400mg', N'Piracetam', N'400 mg', N'Rs 71.50/Stripe', 1.19, 0.12, N'~10', N'INR converted', N'Nootropic amplifier. Cognitive flow enhancer. Racetam-class.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Amoxycillin & Potassium Clavulanate Tablets', N'Amoxycillin + Clavulanic Acid', N'625 mg', N'Rs 204.84/Stripe', 3.42, 0.34, N'~10', N'INR converted', N'Beta-lactam siege combo. Bacterial resistance breaker.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Oseltaflu Oseltamivir 75mg Capsule', N'Oseltamivir', N'75 mg', N'Rs 695/Stripe', 11.61, 1.16, N'~10', N'INR converted', N'Neuraminidase blocker. Influenza replication interruptor.', N'Pharmaceutical Tablets', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Dutaheal Dutasteride 0.5mg Tablets', N'Dutasteride', N'0.5 mg', N'Rs 140/Stripe', 2.34, 0.23, N'~10', N'INR converted', N'5-alpha reductase assassin. DHT suppression for prostate/hair.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Rybelsus Semaglutide Tablet', N'Semaglutide', N'3/7/14 mg', N'Rs 3520/Stripe', 58.78, 5.88, N'~10', N'INR converted', N'GLP-1 receptor agonist. Metabolic override. Appetite extinction.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Nizonide Nitazoxanide 500mg', N'Nitazoxanide', N'500 mg', N'Rs 119.2/Stripe', 1.99, 0.20, N'~10', N'INR converted', N'Broad-spectrum antiparasitic. Disrupts anaerobic energy metabolism.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Atomoxet Atomoxetine 18mg', N'Atomoxetine', N'18 mg', N'Rs 125/Stripe', 2.09, 0.21, N'~10', N'INR converted', N'Norepinephrine reuptake inhibitor. ADHD focus enforcer. Non-stimulant.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Tricabend Triclabendazole 250mg', N'Triclabendazole', N'250 mg', N'Rs 234/Piece', 3.91, 0.39, N'~10', N'INR converted', N'Fluke killer. Liver parasite elimination specialist.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Oseltamivir Capsules 30mg', N'Oseltamivir', N'30 mg', N'Rs 255/Stripe', 4.26, 0.43, N'~10', N'INR converted', N'Neuraminidase blocker. Influenza replication interruptor.', N'Pharmaceutical Tablets', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Praziquantel 600mg', N'Praziquantel', N'600 mg', N'Rs 150/Stripe', 2.50, 0.25, N'~10', N'INR converted', N'Anthelmintic detonator. Worm membrane disintegration.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Varenicline Varenismart 0.5mg', N'Varenicline', N'0.5 mg', N'Rs 499/Stripe', 8.33, 0.83, N'~10', N'INR converted', N'Nicotinic receptor partial agonist. Smoking cessation enforcer.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Atomoxet 10mg Tablet', N'Atomoxetine', N'10 mg', N'Rs 75/Stripe', 1.25, 0.13, N'~10', N'INR converted', N'Norepinephrine reuptake inhibitor. ADHD focus enforcer. Non-stimulant.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Caberlee Cabergoline 0.5mg', N'Cabergoline', N'0.5 mg', N'Rs 297/Stripe', 4.96, 0.50, N'~10', N'INR converted', N'Dopamine agonist. Prolactin suppressor. Pituitary override.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Atomoxet 40mg Tablet', N'Atomoxetine', N'40 mg', N'Rs 200/Stripe', 3.34, 0.33, N'~10', N'INR converted', N'Norepinephrine reuptake inhibitor. ADHD focus enforcer. Non-stimulant.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Mebenstar Mebendazole 100mg', N'Mebendazole', N'100 mg', N'Rs 74/Stripe', 1.24, 0.12, N'~10', N'INR converted', N'Anthelmintic agent. Worm glucose uptake disruptor.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Doxycycline Capsules IP 100mg', N'Doxycycline', N'100 mg', N'Rs 50/Stripe', 0.83, 0.08, N'~10', N'INR converted', N'Tetracycline-class. Broad-spectrum protein synthesis inhibitor.', N'Pharmaceutical Tablets', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Charak Obenyl Tablet', N'Garcinia Indica Extract', NULL, N'Rs 250/Stripe', 4.17, 0.42, N'~10', N'INR converted', N'Herbal metabolic modifier. Weight management adjunct.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Hcqfresh Hydroxychloroquine 200mg', N'Hydroxychloroquine', N'200 mg', N'Rs 95.8/Stripe', 1.60, 0.16, N'~10', N'INR converted', N'Immunomodulator. Antimalarial repurposed for autoimmune suppression.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Pirfenex Pirfenidone', N'Pirfenidone', N'400/600 mg', N'Rs 350/Stripe', 5.84, 0.58, N'~10', N'INR converted', N'Antifibrotic agent. Lung scar tissue formation inhibitor.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Lumenac 600mg', N'Acetylcysteine', N'600 mg', N'Rs 303.8/Stripe', 5.07, 0.51, N'~10', N'INR converted', N'Mucolytic agent. Glutathione precursor. Oxidative damage shield.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Colchiheal Colchicine 0.5mg', N'Colchicine', N'0.5 mg', N'Rs 33/Stripe', 0.55, 0.06, N'~10', N'INR converted', N'Microtubule disruptor. Anti-gout inflammatory shutdown.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Cabgolin 0.25mg', N'Cabergoline', N'0.25 mg', N'Rs 247/Stripe', 4.12, 0.41, N'~10', N'INR converted', N'Dopamine agonist. Prolactin suppressor. Pituitary override.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Famotidine 40mg', N'Famotidine', N'40 mg', N'Rs 35.23/Stripe', 0.59, 0.06, N'~10', N'INR converted', N'H2 receptor blocker. Gastric acid production suppressor.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Clopilet Clopidogrel 75mg', N'Clopidogrel', N'75 mg', N'Rs 131/Stripe', 2.19, 0.22, N'~10', N'INR converted', N'Platelet aggregation inhibitor. Blood clot prevention relay.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Naltrexone Naltima 50mg', N'Naltrexone', N'50 mg', N'Rs 880/Stripe', 14.70, 1.47, N'~10', N'INR converted', N'Opioid receptor antagonist. Addiction craving extinction agent.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Nexpro Esomeprazole', N'Esomeprazole', N'20/40 mg', N'Rs 110/Strip', 1.84, 0.18, N'~10', N'INR converted', N'Proton pump inhibitor. Gastric acid total shutdown.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Ziverdo Kit', N'Zinc + Doxycycline + Ivermectin', N'Combined', N'Rs 260/Kit', 4.34, 4.34, N'1 kit', N'INR converted', N'Triple-action kit. Antiparasitic-antibiotic-immune support combo.', N'Pharmaceutical Tablets', N'Kit');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'HQ Star Tablets', N'Hydroxychloroquine', N'200/400 mg', N'Rs 130/Stripe', 2.17, 0.22, N'~10', N'INR converted', N'Immunomodulator. Antimalarial repurposed for autoimmune suppression.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Iverheal Ivermectin 12mg', N'Ivermectin', N'12 mg', N'Rs 423/Strip', 7.06, 0.71, N'~10', N'INR converted', N'Antiparasitic neural disruptor. Broad-spectrum invertebrate killer.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Atenheal Atenolol 100mg', N'Atenolol', N'100 mg', N'Rs 53.43/Strip', 0.89, 0.09, N'~10', N'INR converted', N'Beta-1 selective blocker. Heart rate and pressure dampener.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Azeetop Azithromycin 250mg', N'Azithromycin', N'250 mg', N'Rs 130/Strip', 2.17, 0.22, N'~10', N'INR converted', N'Macrolide antibiotic. Bacterial ribosome binding agent.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Montaheal Montelukast 10mg', N'Montelukast', N'10 mg', N'Rs 289/Strip', 4.83, 0.48, N'~10', N'INR converted', N'Leukotriene receptor antagonist. Airway inflammation suppressor.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Naltivia Naltrexone 50mg', N'Naltrexone', N'50 mg', N'Rs 875/Strip', 14.61, 1.46, N'~10', N'INR converted', N'Opioid receptor antagonist. Addiction craving extinction agent.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Vomistop Domperidone 10mg', N'Domperidone', N'10 mg', N'Rs 26/Strip', 0.43, 0.04, N'~10', N'INR converted', N'Dopamine antagonist. Anti-nausea gastric motility accelerator.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Suminat 50mg Sumatriptan', N'Sumatriptan Succinate', N'50 mg', N'Rs 63/Strip', 1.05, 0.11, N'~10', N'INR converted', N'Serotonin agonist. Migraine vascular constriction agent.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Varenismart Varenicline 0.5mg', N'Varenicline', N'0.5 mg', N'Rs 499/Strip', 8.33, 0.83, N'~10', N'INR converted', N'Nicotinic receptor partial agonist. Smoking cessation enforcer.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Rifaxiheal Rifaximin 400mg', N'Rifaximin', N'400 mg', N'Rs 319/Strip', 5.33, 0.53, N'~10', N'INR converted', N'Gut-selective antibiotic. Traveler diarrhea elimination specialist.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Tor 10 Torsemide 10mg', N'Torsemide', N'10 mg', N'Rs 76/Strip', 1.27, 0.13, N'~10', N'INR converted', N'Loop diuretic. Renal sodium reabsorption blocker. Fluid purge.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Provironum Mesterolone 25mg', N'Mesterolone', N'25 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Oral androgen. DHT derivative. Hypogonadism compensator.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Viropace 25mg Tablets', N'Mesterolone', N'25 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Oral androgen. DHT derivative. Hypogonadism compensator.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'SEROQUIT Quetiapine 100mg', N'Quetiapine', N'100 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Atypical antipsychotic. Serotonin-dopamine receptor modulator.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'QL 200mg Tablets', N'Quetiapine', N'200 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Atypical antipsychotic. Serotonin-dopamine receptor modulator.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Healtroxin Thyroxine 50 Mcg', N'Levothyroxine', N'50 mcg', NULL, NULL, NULL, NULL, N'No price listed', N'Synthetic thyroid hormone. Metabolic rate calibration agent.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Atomoxet Atomoxetine 25mg', N'Atomoxetine', N'25 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Norepinephrine reuptake inhibitor. ADHD focus enforcer. Non-stimulant.', N'Pharmaceutical Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Levetiracetam 1000mg Tablet', N'Levetiracetam', N'1000 mg', N'Rs 745/Stripe', 12.44, 1.24, N'~10', N'INR converted', N'Anti-epileptic. Synaptic vesicle binding. Seizure suppressor.', N'Pharmaceutical Tablets', N'Tablet');

/* ~~~ ANTI CANCER MEDICINES — 31 compounds ~~~ */

INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Aromasin Exemestane Tablets', N'Exemestane', N'25 mg', N'Rs 5506.38/Box', 91.96, 9.20, N'~10', N'INR converted', N'Aromatase inactivator. Estrogen production terminator.', N'Anti Cancer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Feburic Febuxostat Tablet', N'Febuxostat', N'80 mg', N'Rs 210/Stripe', 3.51, 0.35, N'~10', N'INR converted', N'Xanthine oxidase inhibitor. Uric acid production blocker.', N'Anti Cancer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Fempro Letrozole 2.5mg', N'Letrozole', N'2.5 mg', N'Rs 90/Strip', 1.50, 0.15, N'~10', N'INR converted', N'Aromatase inhibitor. Estrogen synthesis shutdown for cancer.', N'Anti Cancer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Tamoxifen Mamofen Tablets', N'Tamoxifen Citrate', N'10-20 mg', N'Rs 25/Strip', 0.42, 0.04, N'~10', N'INR converted', N'Estrogen receptor antagonist. Breast cancer blockade agent.', N'Anti Cancer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Anabrez Anastrozole 1mg', N'Anastrozole', N'1 mg', N'Rs 265/Strip', 4.43, 0.44, N'~10', N'INR converted', N'Aromatase inhibitor. Estrogen biosynthesis interruptor.', N'Anti Cancer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Letroz Letrozole 2.5mg', N'Letrozole', N'2.5 mg', N'Rs 230/Strip', 3.84, 0.38, N'~10', N'INR converted', N'Aromatase inhibitor. Estrogen synthesis shutdown for cancer.', N'Anti Cancer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Imatero Imatinib Tablets', N'Imatinib', N'400 mg', N'Rs 1993.9/Stripe', 33.30, 3.33, N'~10', N'INR converted', N'Tyrosine kinase assassin. Targeted cancer cell disruption.', N'Anti Cancer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Imalek Imatinib Tablets', N'Imatinib', N'100-400 mg', N'Rs 970/Strip', 16.20, 1.62, N'~10', N'INR converted', N'Tyrosine kinase assassin. Targeted cancer cell disruption.', N'Anti Cancer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Veenat Imatinib 100mg Capsule', N'Imatinib', N'100 mg', N'Rs 700/Bottle', 11.69, 1.17, N'~10', N'INR converted', N'Tyrosine kinase assassin. Targeted cancer cell disruption.', N'Anti Cancer Medicines', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Voriconazole Voraze 200mg', N'Voriconazole', N'200 mg', N'Rs 3433/Stripe', 57.33, 5.73, N'~10', N'INR converted', N'Triazole antifungal. Fungal cell membrane synthesis destroyer.', N'Anti Cancer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Kryxana Ribociclib 200mg', N'Ribociclib', N'200 mg', N'Rs 24355/Box', 406.73, 40.67, N'~10', N'INR converted', N'CDK4/6 inhibitor. Cancer cell cycle arrest enforcer.', N'Anti Cancer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Etoposide Posid 50mg Capsule', N'Etoposide', N'50 mg', N'Rs 541/Box', 9.03, 0.90, N'~10', N'INR converted', N'Topoisomerase II inhibitor. DNA replication saboteur.', N'Anti Cancer Medicines', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Bicalutamide Calutide 50mg', N'Bicalutamide', N'50 mg', N'Rs 484/Stripe', 8.08, 0.81, N'~10', N'INR converted', N'Androgen receptor blocker. Prostate cancer hormone denial.', N'Anti Cancer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Lenshil Lenvatinib Capsules', N'Lenvatinib', N'4-10 mg', N'Rs 2450/Box', 40.91, 4.09, N'~10', N'INR converted', N'Multi-kinase inhibitor. Tumor blood supply severing agent.', N'Anti Cancer Medicines', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Flutamide Cytomid 250mg', N'Flutamide', N'250 mg', N'Rs 156/Stripe', 2.61, 0.26, N'~10', N'INR converted', N'Non-steroidal antiandrogen. Androgen receptor competitive blocker.', N'Anti Cancer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Veenat Imatinib 400mg', N'Imatinib', N'400 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Tyrosine kinase assassin. Targeted cancer cell disruption.', N'Anti Cancer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Letrozole Fempro 2.5mg', N'Letrozole', N'2.5 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Aromatase inhibitor. Estrogen synthesis shutdown for cancer.', N'Anti Cancer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Anaridex Anastrazole 1mg', N'Anastrozole', N'1 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Aromatase inhibitor. Estrogen biosynthesis interruptor.', N'Anti Cancer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Corion-C 5000 IU Injection', N'Chorionic Gonadotropin', N'5000 IU', NULL, NULL, NULL, NULL, N'No price listed', N'LH mimic. Gonadal stimulation trigger. Fertility catalyst.', N'Anti Cancer Medicines', N'Injection');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Vintor Erythropoietin Injection', N'Erythropoietin', N'10000 IU', N'Rs 2244/Vial', 37.47, 37.47, N'1 vial', N'INR converted', N'Red blood cell production amplifier. Oxygen carrying capacity boost.', N'Anti Cancer Medicines', N'Injection');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Kemocarb Carboplatin Injection', N'Carboplatin', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Platinum-based alkylator. DNA crosslink cancer cell killer.', N'Anti Cancer Medicines', N'Injection');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Carfilnat Carfilzomib Injection', N'Carfilzomib', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Proteasome inhibitor. Myeloma protein degradation disruptor.', N'Anti Cancer Medicines', N'Injection');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Epofit Erythropoietin Injection', N'Erythropoietin', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Red blood cell production amplifier. Oxygen carrying capacity boost.', N'Anti Cancer Medicines', N'Injection');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Nintedanib 150mg Capsule', N'Nintedanib', N'150 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Triple angiokinase inhibitor. Pulmonary fibrosis decelerator.', N'Anti Cancer Medicines', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Crizotinib 250mg Capsules', N'Crizotinib', N'250 mg', NULL, NULL, NULL, NULL, N'No price listed', N'ALK/ROS1 inhibitor. Lung cancer signal transduction blocker.', N'Anti Cancer Medicines', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Cazanat Cabozantinib 40mg', N'Cabozantinib', N'40 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Multi-target kinase inhibitor. Tumor growth and angiogenesis blocker.', N'Anti Cancer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Cazanat Cabozantinib 60mg', N'Cabozantinib', N'60 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Multi-target kinase inhibitor. Tumor growth and angiogenesis blocker.', N'Anti Cancer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Olumiant 4mg Tablet', N'Baricitinib', N'4 mg', NULL, NULL, NULL, NULL, N'No price listed', N'JAK1/JAK2 inhibitor. Autoimmune inflammatory cascade blocker.', N'Anti Cancer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Obrix Olaparib 150mg', N'Olaparib', N'150 mg', NULL, NULL, NULL, NULL, N'No price listed', N'PARP inhibitor. DNA repair saboteur in BRCA-mutant tumors.', N'Anti Cancer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Rituxirel Rituximab 500mg Injection', N'Rituximab', N'500 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Anti-CD20 monoclonal antibody. B-cell targeted elimination.', N'Anti Cancer Medicines', N'Injection');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Botox 100 IU Injection', N'Botulinum Toxin', N'100 IU', NULL, NULL, NULL, NULL, N'No price listed', N'Neuromuscular junction blocker. Muscle paralysis precision agent.', N'Anti Cancer Medicines', N'Injection');

/* ~~~ ANTIBIOTIC MEDICINES — 27 compounds ~~~ */

INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Almox Amoxycillin Tablets', N'Amoxycillin', N'250/500 mg', N'Rs 150/Strip', 2.50, 0.25, N'~10', N'INR converted', N'Broad-spectrum bacterial siege weapon. Penicillin-class.', N'Antibiotic Medicines', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Doxicip Doxycycline Tablets', N'Doxycycline HCl', N'100 mg', N'Rs 100/Box', 1.67, 0.17, N'~10', N'INR converted', N'Tetracycline-class. Broad-spectrum protein synthesis inhibitor.', N'Antibiotic Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Campicilin Ampicillin Capsules', N'Ampicillin', N'250/500 mg', N'Rs 148/Stripe', 2.47, 0.25, N'~10', N'INR converted', N'Broad-spectrum penicillin. Cell wall synthesis disruptor.', N'Antibiotic Medicines', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Moxiford Moxifloxacin 400mg', N'Moxifloxacin', N'400 mg', N'Rs 310/Box', 5.18, 0.52, N'~10', N'INR converted', N'Fluoroquinolone. DNA gyrase inhibitor. Respiratory pathogen killer.', N'Antibiotic Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Dalaheal Clindamycin 150mg', N'Clindamycin', N'150/300 mg', N'Rs 140/Stripe', 2.34, 0.23, N'~10', N'INR converted', N'Lincosamide antibiotic. Anaerobic and gram-positive assassin.', N'Antibiotic Medicines', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Dalacin C Capsule', N'Clindamycin', N'150/300 mg', N'Rs 320/Box', 5.34, 0.53, N'~10', N'INR converted', N'Lincosamide antibiotic. Anaerobic and gram-positive assassin.', N'Antibiotic Medicines', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Distaclor DT Tablets', N'Cefaclor', N'125/250 mg', N'Rs 270/Stripe', 4.51, 0.45, N'~10', N'INR converted', N'Second-gen cephalosporin. Bacterial cell wall breaker.', N'Antibiotic Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Distaclor CD Tablets', N'Cefaclor', N'375/750 mg', N'Rs 139/Strip', 2.32, 0.23, N'~10', N'INR converted', N'Second-gen cephalosporin. Bacterial cell wall breaker.', N'Antibiotic Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Niftas Nitrofurantoin', N'Nitrofurantoin', N'50/100 mg', N'Rs 125/Stripe', 2.09, 0.21, N'~10', N'INR converted', N'Urinary tract specialist. Bacterial DNA/RNA/protein disruptor.', N'Antibiotic Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Azipro Azithromycin', N'Azithromycin', N'250/500 mg', N'Rs 390/Strip', 6.51, 0.65, N'~10', N'INR converted', N'Macrolide antibiotic. Bacterial ribosome binding agent.', N'Antibiotic Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Klox D Capsule', N'Dicloxacillin', N'250/500 mg', N'Rs 160/Stripe', 2.67, 0.27, N'~10', N'INR converted', N'Penicillinase-resistant penicillin. Staph infection specialist.', N'Antibiotic Medicines', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Levoflox Levofloxacin', N'Levofloxacin', N'250/500/750 mg', N'Rs 140/Strip', 2.34, 0.23, N'~10', N'INR converted', N'Fluoroquinolone. Bacterial DNA replication terminator.', N'Antibiotic Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Amoxicillin + Clavulanate 625mg', N'Amoxicillin + Potassium Clavulanate', N'625 mg', N'Rs 182/Stripe', 3.04, 0.30, N'~10', N'INR converted', N'Beta-lactam siege combo. Bacterial resistance breaker.', N'Antibiotic Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Amoxicillin + Clavulanate 1000mg', N'Amoxicillin + Potassium Clavulanate', N'1000 mg', N'Rs 213/Stripe', 3.56, 0.36, N'~10', N'INR converted', N'Beta-lactam siege combo. Bacterial resistance breaker.', N'Antibiotic Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Ampoxin 500mg', N'Ampicillin + Cloxacillin', N'500 mg', N'Rs 110/Stripe', 1.84, 0.18, N'~10', N'INR converted', N'Dual penicillin combo. Broad and staph-resistant coverage.', N'Antibiotic Medicines', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Azeetop Azithromycin 500mg', N'Azithromycin', N'500 mg', N'Rs 119/Strip', 1.99, 0.20, N'~10', N'INR converted', N'Macrolide antibiotic. Bacterial ribosome binding agent.', N'Antibiotic Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Cephadex Cephalexin', N'Cephalexin', N'250/500 mg', N'Rs 130/Stripe', 2.17, 0.22, N'~10', N'INR converted', N'First-gen cephalosporin. Gram-positive bacterial wall breaker.', N'Antibiotic Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Minoz Minocycline 100mg', N'Minocycline Hydrochloride', N'100 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Tetracycline-class. Anti-inflammatory antibiotic. Acne destroyer.', N'Antibiotic Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Keto Force Ketoconazole', N'Ketoconazole', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Azole antifungal. Ergosterol synthesis inhibitor.', N'Antibiotic Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Doxypen Doxycycline 100mg Capsule', N'Doxycycline', N'100 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Tetracycline-class. Broad-spectrum protein synthesis inhibitor.', N'Antibiotic Medicines', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Febentel Fenbendazole 1000mg', N'Fenbendazole', N'1000 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Benzimidazole anthelmintic. Microtubule polymerization disruptor.', N'Antibiotic Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Armogard Armodafinil 250mg', N'Armodafinil', N'250 mg', NULL, NULL, NULL, NULL, N'No price listed', N'R-enantiomer wakefulness agent. Longer-half cognitive sustainer.', N'Antibiotic Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Febentel Fenbendazole 888mg', N'Fenbendazole', N'888 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Benzimidazole anthelmintic. Microtubule polymerization disruptor.', N'Antibiotic Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Carbophage XR 1000', N'Metformin Hydrochloride', N'1000 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Biguanide. Hepatic glucose output suppressor. Insulin sensitizer.', N'Antibiotic Medicines', N'Tablet (Extended Release)');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Amoxyheal CV 875/125mg', N'Amoxycillin + Potassium Clavulanate', N'875/125 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Beta-lactam siege combo. Bacterial resistance breaker.', N'Antibiotic Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Amoxyheal CV 500/125mg', N'Amoxycillin + Potassium Clavulanate', N'500/125 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Beta-lactam siege combo. Bacterial resistance breaker.', N'Antibiotic Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Amoxyheal CV 250/125mg', N'Amoxycillin + Potassium Clavulanate', N'250/125 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Beta-lactam siege combo. Bacterial resistance breaker.', N'Antibiotic Medicines', N'Tablet');

/* ~~~ PAIN KILLER MEDICINES — 27 compounds ~~~ */

INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Soma-Boost Carisoprodol 750mg', N'Carisoprodol', N'750 mg', N'Rs 45/Stripe', 0.75, 0.08, N'~10', N'INR converted', N'Muscle unbinder. Central nervous system sedation relay.', N'Pain Killer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Soma-Dol Carisoprodol Tablets', N'Carisoprodol', N'350/500/750 mg', N'Rs 300/Stripe', 1.58, 0.16, N'10', N'Confirmed quote', N'Muscle unbinder. Central nervous system sedation relay.', N'Pain Killer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Carisoma Carisoprodol 350mg', N'Carisoprodol', N'350 mg', N'Rs 51/Stripe', 1.58, 0.16, N'10', N'Confirmed quote', N'Muscle unbinder. Central nervous system sedation relay.', N'Pain Killer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Gabapentin 600mg Tablets', N'Gabapentin', N'600 mg', N'Rs 195/Stripe', 3.26, 0.33, N'~10', N'INR converted', N'GABA analog. Neuropathic pain dampener. Seizure auxiliary.', N'Pain Killer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Somawell Carisoprodol 350mg', N'Carisoprodol', N'350 mg', N'Rs 210/Stripe', 1.58, 0.16, N'10', N'Confirmed quote', N'Muscle unbinder. Central nervous system sedation relay.', N'Pain Killer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Pacimol Active Tablets', N'Paracetamol + Caffeine', N'500/600 mg', N'Rs 310/Stripe', 5.18, 0.52, N'~10', N'INR converted', N'Analgesic-stimulant duo. Pain relief with alertness boost.', N'Pain Killer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Asonac Aceclofenac 200mg', N'Aceclofenac + Serratiopeptidase', N'200 mg', N'Rs 158/Stripe', 2.64, 0.26, N'~10', N'INR converted', N'NSAID plus enzyme. Anti-inflammatory with swelling breakdown.', N'Pain Killer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Nucoxia P Tablet', N'Etoricoxib + Paracetamol', N'60/325 mg', N'Rs 140/Strip', 2.34, 0.23, N'~10', N'INR converted', N'Selective COX-2 plus analgesic. Dual pain elimination.', N'Pain Killer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Pain O Soma 350mg', N'Carisoprodol', N'350/500 mg', N'Rs 666/Pack', 1.58, 0.16, N'10', N'Confirmed quote', N'Muscle unbinder. Central nervous system sedation relay.', N'Pain Killer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Melorise Meloxicam 7.5mg', N'Meloxicam', N'7.5 mg', N'Rs 50/Stripe', 0.83, 0.08, N'~10', N'INR converted', N'Preferential COX-2 inhibitor. Long-acting joint pain suppressor.', N'Pain Killer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Dolonex DT Tablet', N'Piroxicam', N'20 mg', N'Rs 153/Stripe', 2.56, 0.26, N'~10', N'INR converted', N'Non-selective NSAID. Prolonged anti-inflammatory action.', N'Pain Killer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Toldin ER Tablets', N'Tolmetin', N'600 mg', N'Rs 135/Box', 2.25, 0.23, N'~10', N'INR converted', N'NSAID. Prostaglandin synthesis inhibitor. Arthritis pain relief.', N'Pain Killer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Movexx Plus Tablet', N'Paracetamol + Aceclofenac', N'600 mg', N'Rs 67/Strip', 1.12, 0.11, N'~10', N'INR converted', N'Dual analgesic-NSAID. Combined pain and inflammation strike.', N'Pain Killer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Dolokind Plus Tablet', N'Aceclofenac + Paracetamol', NULL, N'Rs 156/Strip', 2.61, 0.26, N'~10', N'INR converted', N'Dual analgesic-NSAID. Combined pain and inflammation strike.', N'Pain Killer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Nicip DS Tablets', N'Nimesulide', N'200 mg', N'Rs 142/Stripe', 2.37, 0.24, N'~10', N'INR converted', N'Preferential COX-2 inhibitor. Acute pain rapid suppressor.', N'Pain Killer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Etozox Etoricoxib', N'Etoricoxib', N'60/90/120 mg', N'Rs 105/Strip', 1.75, 0.18, N'~10', N'INR converted', N'Selective COX-2 inhibitor. Precision anti-inflammatory.', N'Pain Killer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Nucoxia SP Tablets', N'Etoricoxib + Serratiopeptidase', N'60/10 mg', N'Rs 131/Strip', 2.19, 0.22, N'~10', N'INR converted', N'COX-2 inhibitor plus enzyme. Inflammation and edema breaker.', N'Pain Killer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Gabafresh Gabapentin 1000mg', N'Gabapentin', N'1000 mg', NULL, NULL, NULL, NULL, N'No price listed', N'GABA analog. Neuropathic pain dampener. Seizure auxiliary.', N'Pain Killer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Bacloheal Baclofen 25mg', N'Baclofen', N'25 mg', NULL, NULL, NULL, NULL, N'No price listed', N'GABA-B agonist. Spinal cord muscle spasm suppressor.', N'Pain Killer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Gabapentin Gabafresh 800mg', N'Gabapentin', N'800 mg', NULL, NULL, NULL, NULL, N'No price listed', N'GABA analog. Neuropathic pain dampener. Seizure auxiliary.', N'Pain Killer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Hifenac Aceclofenac 100mg', N'Aceclofenac', N'100 mg', NULL, NULL, NULL, NULL, N'No price listed', N'NSAID. COX-2 preferential inhibitor. Joint pain suppressor.', N'Pain Killer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'P Nolol 10mg Tablet', N'Propranolol', N'10 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Non-selective beta-blocker. Anxiety tremor and heart rate dampener.', N'Pain Killer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Gabapentin 300mg Tablets', N'Gabapentin', N'300 mg', NULL, NULL, NULL, NULL, N'No price listed', N'GABA analog. Neuropathic pain dampener. Seizure auxiliary.', N'Pain Killer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Tizanidine 2mg Tablet', N'Tizanidine', N'2 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Alpha-2 adrenergic agonist. Central muscle tone reducer.', N'Pain Killer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Trinex Tizanidine 2mg', N'Tizanidine', N'2 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Alpha-2 adrenergic agonist. Central muscle tone reducer.', N'Pain Killer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Brufen 400mg Tablets', N'Ibuprofen', N'400 mg', NULL, NULL, NULL, NULL, N'No price listed', N'NSAID workhorse. Prostaglandin inhibitor. General pain suppressor.', N'Pain Killer Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Dolonex DT 20mg Tablet', N'Piroxicam', N'20 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Non-selective NSAID. Prolonged anti-inflammatory action.', N'Pain Killer Medicines', N'Tablet');

/* ~~~ ERECTILE DYSFUNCTION — 52 compounds ~~~ */

INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Vidalista Tadalafil 10mg', N'Tadalafil', N'10 mg', N'Rs 300/Stripe', 5.01, 0.50, N'~10', N'INR converted', N'PDE5 inhibitor. Prolonged vasodilation. 36-hour blood-flow agent.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Cenforce Tablet IP 100mg', N'Sildenafil', N'100 mg', N'Rs 400/Stripe', 6.68, 0.67, N'~10', N'INR converted', N'Vasodilator charge. Blood-flow amplifier. PDE5 inhibitor.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Cenforce Professional 100mg', N'Sildenafil Citrate', N'100 mg', N'Rs 400/Stripe', 6.68, 0.67, N'~10', N'INR converted', N'Vasodilator charge. Blood-flow amplifier. PDE5 inhibitor.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Cenforce Soft 100mg', N'Sildenafil Citrate', N'100 mg', N'Rs 400/Stripe', 6.68, 0.67, N'~10', N'INR converted', N'Vasodilator charge. Blood-flow amplifier. PDE5 inhibitor.', N'Erectile Dysfunction', N'Chewable Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Cenforce FM 100mg', N'Sildenafil Citrate', N'100 mg', N'Rs 400/Stripe', 6.68, 0.67, N'~10', N'INR converted', N'Vasodilator charge. Blood-flow amplifier. PDE5 inhibitor.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Cenforce Gold 100mg', N'Sildenafil Citrate', N'100 mg', N'Rs 400/Stripe', 6.68, 0.67, N'~10', N'INR converted', N'Vasodilator charge. Blood-flow amplifier. PDE5 inhibitor.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Vidalista Black 80mg', N'Tadalafil', N'80 mg', N'Rs 399/Stripe', 6.66, 0.67, N'~10', N'INR converted', N'PDE5 inhibitor. Prolonged vasodilation. 36-hour blood-flow agent.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Vidalista CT 20mg', N'Tadalafil', N'20 mg', N'Rs 500/Stripe', 8.35, 0.83, N'~10', N'INR converted', N'PDE5 inhibitor. Prolonged vasodilation. 36-hour blood-flow agent.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Cenforce 120mg', N'Sildenafil Citrate', N'120 mg', N'Rs 400/Stripe', 6.68, 0.67, N'~10', N'INR converted', N'Vasodilator charge. Blood-flow amplifier. PDE5 inhibitor.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Cenforce 50mg', N'Sildenafil Citrate', N'50 mg', N'Rs 300/Stripe', 5.01, 0.50, N'~10', N'INR converted', N'Vasodilator charge. Blood-flow amplifier. PDE5 inhibitor.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Cenforce 25mg', N'Sildenafil Citrate', N'25 mg', N'Rs 300/Stripe', 5.01, 0.50, N'~10', N'INR converted', N'Vasodilator charge. Blood-flow amplifier. PDE5 inhibitor.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Vidalista 5mg', N'Tadalafil', N'5 mg', N'Rs 395/Stripe', 6.60, 0.66, N'~10', N'INR converted', N'PDE5 inhibitor. Prolonged vasodilation. 36-hour blood-flow agent.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Cenforce Oral Jelly 100mg', N'Sildenafil', N'100 mg', N'Rs 300/Pack', 5.01, 0.72, N'~7', N'INR converted', N'Vasodilator charge. Blood-flow amplifier. PDE5 inhibitor.', N'Erectile Dysfunction', N'Oral Jelly');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Cenforce 200mg', N'Sildenafil Citrate', N'200 mg', N'Rs 400/Stripe', 6.68, 0.67, N'~10', N'INR converted', N'Vasodilator charge. Blood-flow amplifier. PDE5 inhibitor.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Vidalista 60mg', N'Tadalafil', N'60 mg', N'Rs 395/Stripe', 6.60, 0.66, N'~10', N'INR converted', N'PDE5 inhibitor. Prolonged vasodilation. 36-hour blood-flow agent.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Tadalista Super Active 20mg', N'Tadalafil', N'20 mg', N'Rs 400/Stripe', 6.68, 6.68, N'1 unit', N'INR converted', N'PDE5 inhibitor. Prolonged vasodilation. 36-hour blood-flow agent.', N'Erectile Dysfunction', N'Soft Gelatin Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Cenforce 150mg', N'Sildenafil Citrate', N'150 mg', N'Rs 400/Stripe', 6.68, 0.67, N'~10', N'INR converted', N'Vasodilator charge. Blood-flow amplifier. PDE5 inhibitor.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Cenforce 100mg', N'Sildenafil Citrate', N'100 mg', N'Rs 400/Stripe', 6.68, 0.67, N'~10', N'INR converted', N'Vasodilator charge. Blood-flow amplifier. PDE5 inhibitor.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Valif 20mg', N'Vardenafil', N'20 mg', N'Rs 34/Strip', 0.57, 0.06, N'~10', N'INR converted', N'PDE5 inhibitor. Rapid-onset erectile vasodilation agent.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Silvitra 120mg', N'Sildenafil + Vardenafil', N'120 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Dual PDE5 strike. Combined vasodilation potency.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Poxet Dapoxetine Tablets', N'Dapoxetine', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'SSRI for premature ejaculation. Serotonin reuptake timing agent.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Viprogra Sildenafil Tablets', N'Sildenafil', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Vasodilator charge. Blood-flow amplifier. PDE5 inhibitor.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Delgra Sildenafil Tablets', N'Sildenafil', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Vasodilator charge. Blood-flow amplifier. PDE5 inhibitor.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Kamagra 100 Tablets', N'Sildenafil', N'100 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Vasodilator charge. Blood-flow amplifier. PDE5 inhibitor.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Sildenafil Assurans Tablets', N'Sildenafil', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Vasodilator charge. Blood-flow amplifier. PDE5 inhibitor.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Cenforce D 160mg', N'Sildenafil + Dapoxetine', N'160 mg', NULL, NULL, NULL, NULL, N'No price listed', N'PDE5 plus SSRI. Erectile and timing dual-action agent.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Kamagra Fx Oral Jelly Cola', N'Sildenafil', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Vasodilator charge. Blood-flow amplifier. PDE5 inhibitor.', N'Erectile Dysfunction', N'Oral Jelly');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Fildena Extra Power', N'Sildenafil', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Vasodilator charge. Blood-flow amplifier. PDE5 inhibitor.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Fildena Double 200mg', N'Sildenafil', N'200 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Vasodilator charge. Blood-flow amplifier. PDE5 inhibitor.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Fildena Strong 120mg', N'Sildenafil', N'120 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Vasodilator charge. Blood-flow amplifier. PDE5 inhibitor.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Vega Extra 120mg Oral Jelly', N'Sildenafil', N'120 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Vasodilator charge. Blood-flow amplifier. PDE5 inhibitor.', N'Erectile Dysfunction', N'Oral Jelly');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Varditra Vardenafil 10mg', N'Vardenafil', N'10 mg', NULL, NULL, NULL, NULL, N'No price listed', N'PDE5 inhibitor. Rapid-onset erectile vasodilation agent.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Mesteronum Mesterolone 25mg', N'Mesterolone', N'25 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Oral androgen. DHT derivative. Hypogonadism compensator.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Snovitra Vardenafil 20mg', N'Vardenafil', N'20 mg', NULL, NULL, NULL, NULL, N'No price listed', N'PDE5 inhibitor. Rapid-onset erectile vasodilation agent.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Suhagra Sildenafil Tablets', N'Sildenafil', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Vasodilator charge. Blood-flow amplifier. PDE5 inhibitor.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Suhagra 50mg', N'Sildenafil', N'50 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Vasodilator charge. Blood-flow amplifier. PDE5 inhibitor.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Suhagra 25mg', N'Sildenafil Citrate', N'25 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Vasodilator charge. Blood-flow amplifier. PDE5 inhibitor.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Suhagra 100mg', N'Sildenafil', N'100 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Vasodilator charge. Blood-flow amplifier. PDE5 inhibitor.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Apcalis Tadalafil Tablet', N'Tadalafil', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'PDE5 inhibitor. Prolonged vasodilation. 36-hour blood-flow agent.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Super Vilitra Vardenafil + Dapoxetine', N'Vardenafil + Dapoxetine', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'PDE5 plus SSRI combo. Erection and ejaculation dual control.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Super Tadarise Tablets', N'Tadalafil + Dapoxetine', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Long-acting PDE5 plus SSRI. Sustained dual sexual function agent.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Apcalis Sx Oral Jelly', N'Tadalafil', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'PDE5 inhibitor. Prolonged vasodilation. 36-hour blood-flow agent.', N'Erectile Dysfunction', N'Oral Jelly');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Vidalista 40mg', N'Tadalafil', N'40 mg', NULL, NULL, NULL, NULL, N'No price listed', N'PDE5 inhibitor. Prolonged vasodilation. 36-hour blood-flow agent.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Vidalista 20mg', N'Tadalafil', N'20 mg', NULL, NULL, NULL, NULL, N'No price listed', N'PDE5 inhibitor. Prolonged vasodilation. 36-hour blood-flow agent.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Vidalista 2.5mg', N'Tadalafil', N'2.5 mg', NULL, NULL, NULL, NULL, N'No price listed', N'PDE5 inhibitor. Prolonged vasodilation. 36-hour blood-flow agent.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Tadalista 20mg', N'Tadalafil', N'20 mg', NULL, NULL, NULL, NULL, N'No price listed', N'PDE5 inhibitor. Prolonged vasodilation. 36-hour blood-flow agent.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Tadalista Professional', N'Tadalafil', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'PDE5 inhibitor. Prolonged vasodilation. 36-hour blood-flow agent.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Tadalista Soft Gelatin', N'Tadalafil', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'PDE5 inhibitor. Prolonged vasodilation. 36-hour blood-flow agent.', N'Erectile Dysfunction', N'Soft Gelatin Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Vilitra Vardenafil Tablets', N'Vardenafil', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'PDE5 inhibitor. Rapid-onset erectile vasodilation agent.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Snovitra Super Power', N'Vardenafil + Dapoxetine', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'PDE5 plus SSRI combo. Erection and ejaculation dual control.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Filitra Professional', N'Vardenafil', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'PDE5 inhibitor. Rapid-onset erectile vasodilation agent.', N'Erectile Dysfunction', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Vitara-V Vardenafil', N'Vardenafil', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'PDE5 inhibitor. Rapid-onset erectile vasodilation agent.', N'Erectile Dysfunction', N'Tablet');

/* ~~~ ANTI ANXIETY & ANTI DEPRESSANTS — 48 compounds ~~~ */

INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Zopiclone 25mg Tablets (Zopimaxx)', N'Zopiclone', N'20 mg', N'Rs 200/Stripe', 3.00, 0.30, N'10', N'Confirmed quote', N'Sleep induction agent. GABA receptor override. Short-half.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Zopfresh Zopiclone 7.5mg', N'Zopiclone', N'7.5 mg', N'Rs 200/Strip', 3.34, 0.33, N'~10', N'INR converted', N'Sleep induction agent. GABA receptor override. Short-half.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Zopfresh Zopiclone 20mg', N'Zopiclone', N'20 mg', N'Rs 150/Stripe', 3.00, 0.30, N'10', N'Confirmed quote', N'Sleep induction agent. GABA receptor override. Short-half.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Zopisign Zopiclone 7.5mg', N'Zopiclone', N'7.5 mg', N'Rs 121/Strip', 2.02, 0.20, N'~10', N'INR converted', N'Sleep induction agent. GABA receptor override. Short-half.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Buspin Buspirone Tablets', N'Buspirone', N'5/10 mg', N'Rs 40.75/Stripe', 0.68, 0.07, N'~10', N'INR converted', N'Serotonin partial agonist. Non-benzo anxiolytic. No dependence.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Pexep CR Tablets', N'Paroxetine', N'12.5-37.5 mg', N'Rs 300/Box', 5.01, 0.50, N'~10', N'INR converted', N'SSRI. Serotonin reuptake blockade. Anxiety and depression suppressor.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Duvanta Duloxetine Tablet', N'Duloxetine', N'20-60 mg', N'Rs 880/Stripe', 14.70, 1.47, N'~10', N'INR converted', N'SNRI. Dual serotonin-norepinephrine reuptake inhibitor. Pain auxiliary.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Serlift Sertraline Tablet', N'Sertraline', N'25-50 mg', N'Rs 400/Box', 6.68, 0.67, N'~10', N'INR converted', N'SSRI. Serotonin reuptake inhibitor. Depression and OCD suppressor.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Dulata Duloxetine Tablets', N'Duloxetine', N'20-60 mg', N'Rs 500/Stripe', 8.35, 0.83, N'~10', N'INR converted', N'SNRI. Dual serotonin-norepinephrine reuptake inhibitor. Pain auxiliary.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Lexaheal Escitalopram', N'Escitalopram', N'10-20 mg', N'Rs 390/Stripe', 6.51, 0.65, N'~10', N'INR converted', N'SSRI. Most selective serotonin reuptake inhibitor. Anxiety silencer.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Trazonil Trazodone 25mg', N'Trazodone', N'25-100 mg', N'Rs 1360/Box', 22.71, 2.27, N'~10', N'INR converted', N'Serotonin antagonist/reuptake inhibitor. Sedating antidepressant.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Zop Zopiclone 7.5mg', N'Zopiclone', N'7.5 mg', N'Rs 170/Stripe', 2.84, 0.28, N'~10', N'INR converted', N'Sleep induction agent. GABA receptor override. Short-half.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Zopicon Zopiclone 7.5mg', N'Zopiclone', N'7.5 mg', N'Rs 145/Stripe', 2.42, 0.24, N'~10', N'INR converted', N'Sleep induction agent. GABA receptor override. Short-half.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Herbal Melatonin Capsules', N'Melatonin + Zinc + Magnesium', NULL, N'Rs 749/Strip', 12.51, 1.25, N'~10', N'INR converted', N'Sleep-mineral stack. Circadian rhythm and relaxation support.', N'Anti Anxiety & Anti Depressants', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Duvanta 30mg Tablet', N'Duloxetine', N'30 mg', N'Rs 181.5/Stripe', 3.03, 0.30, N'~10', N'INR converted', N'SNRI. Dual serotonin-norepinephrine reuptake inhibitor. Pain auxiliary.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Vesca Melatonin Capsule', N'Melatonin', NULL, N'Rs 498/Stripe', 8.32, 0.83, N'~10', N'INR converted', N'Circadian rhythm regulator. Endogenous sleep signal amplifier.', N'Anti Anxiety & Anti Depressants', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Zopfresh Zopiclone 10mg', N'Zopiclone', N'10 mg', N'Rs 50/Stripe', 0.83, 0.08, N'~10', N'INR converted', N'Sleep induction agent. GABA receptor override. Short-half.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Venlafaxine 75mg Tablets', N'Venlafaxine', N'75 mg', N'Rs 77/Stripe', 1.29, 0.13, N'~10', N'INR converted', N'SNRI. Serotonin-norepinephrine dual reuptake inhibitor.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Tofifresh Tofisopam 100mg', N'Tofisopam', N'100 mg', N'Rs 450/Stripe', 7.51, 0.75, N'~10', N'INR converted', N'Atypical benzodiazepine. Anxiolytic without sedation or dependence.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Duzela 60mg Capsule', N'Duloxetine', N'60 mg', N'Rs 261/Stripe', 4.36, 0.44, N'~10', N'INR converted', N'SNRI. Dual serotonin-norepinephrine reuptake inhibitor. Pain auxiliary.', N'Anti Anxiety & Anti Depressants', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Fluvoxamine 50mg Tablet', N'Fluvoxamine', N'50 mg', N'Rs 185/Stripe', 3.09, 0.31, N'~10', N'INR converted', N'SSRI. Sigma-1 receptor agonist. OCD and anxiety suppressor.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Amitriptyline 10mg Tablets', N'Amitriptyline', N'10 mg', N'Rs 21/Stripe', 0.35, 0.04, N'~10', N'INR converted', N'Tricyclic antidepressant. Serotonin-norepinephrine reuptake blocker.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Axepta Atomoxetine 25mg', N'Atomoxetine', N'25 mg', N'Rs 295.5/Stripe', 4.93, 0.49, N'~10', N'INR converted', N'Norepinephrine reuptake inhibitor. ADHD focus enforcer. Non-stimulant.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Zosert 50mg Tablets', N'Sertraline', N'50 mg', N'Rs 132/Stripe', 2.20, 0.22, N'~10', N'INR converted', N'SSRI. Serotonin reuptake inhibitor. Depression and OCD suppressor.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Pexep 10mg Tablet', N'Paroxetine', N'10 mg', N'Rs 206.5/Stripe', 3.45, 0.34, N'~10', N'INR converted', N'SSRI. Serotonin reuptake blockade. Anxiety and depression suppressor.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Venlor-XR 150 Capsule', N'Venlafaxine', N'150 mg', N'Rs 258.79/Stripe', 4.32, 0.43, N'~10', N'INR converted', N'SNRI. Serotonin-norepinephrine dual reuptake inhibitor.', N'Anti Anxiety & Anti Depressants', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Pexep CR 37.5mg', N'Paroxetine', N'37.5 mg', N'Rs 389/Stripe', 6.50, 0.65, N'~10', N'INR converted', N'SSRI. Serotonin reuptake blockade. Anxiety and depression suppressor.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Flunil Fluoxetine 60mg', N'Fluoxetine', N'60 mg', N'Rs 126.45/Strip', 2.11, 0.21, N'~10', N'INR converted', N'SSRI. Long-half serotonin reuptake inhibitor. Depression baseline.', N'Anti Anxiety & Anti Depressants', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Eszopigard Eszopiclone 3mg', N'Eszopiclone', N'3 mg', N'Rs 850/Box', 14.20, 1.42, N'~10', N'INR converted', N'Cyclopyrrolone sedative. GABA-A modulator. Insomnia override.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Zopisign Zopiclone 10mg', N'Zopiclone', N'10 mg', N'Rs 86/Strip', 1.44, 0.14, N'~10', N'INR converted', N'Sleep induction agent. GABA receptor override. Short-half.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Quetiapine 50mg Tablets', N'Quetiapine', N'50 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Atypical antipsychotic. Serotonin-dopamine receptor modulator.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Propranolol Hydrochloride Tablet', N'Propranolol', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Non-selective beta-blocker. Anxiety tremor and heart rate dampener.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Fluvoxin 50mg Tablet', N'Fluvoxamine', N'50 mg', NULL, NULL, NULL, NULL, N'No price listed', N'SSRI. Sigma-1 receptor agonist. OCD and anxiety suppressor.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Poxet Dapoxetine 30mg', N'Dapoxetine', N'30 mg', NULL, NULL, NULL, NULL, N'No price listed', N'SSRI for premature ejaculation. Serotonin reuptake timing agent.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Poxet 60mg Dapoxetine', N'Dapoxetine', N'60 mg', NULL, NULL, NULL, NULL, N'No price listed', N'SSRI for premature ejaculation. Serotonin reuptake timing agent.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Sertafine Sertraline 50mg', N'Sertraline', N'50 mg', NULL, NULL, NULL, NULL, N'No price listed', N'SSRI. Serotonin reuptake inhibitor. Depression and OCD suppressor.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Axepta Atomoxetine 18mg', N'Atomoxetine', N'18 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Norepinephrine reuptake inhibitor. ADHD focus enforcer. Non-stimulant.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Eszop Eszopiclone 1mg', N'Eszopiclone', N'1 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Cyclopyrrolone sedative. GABA-A modulator. Insomnia override.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Eszop Eszopiclone 2mg', N'Eszopiclone', N'2 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Cyclopyrrolone sedative. GABA-A modulator. Insomnia override.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Zopigard Zopiclone 10mg', N'Zopiclone', N'10 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Sleep induction agent. GABA receptor override. Short-half.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Zunestar Eszopiclone 3mg', N'Eszopiclone', N'3 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Cyclopyrrolone sedative. GABA-A modulator. Insomnia override.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Hypnite Eszopiclone 3mg', N'Eszopiclone', N'3 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Cyclopyrrolone sedative. GABA-A modulator. Insomnia override.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Hypnite Eszopiclone 2mg', N'Eszopiclone', N'2 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Cyclopyrrolone sedative. GABA-A modulator. Insomnia override.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Hypnite 1mg', N'Eszopiclone', N'1 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Cyclopyrrolone sedative. GABA-A modulator. Insomnia override.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Fulnite Eszopiclone', N'Eszopiclone', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Cyclopyrrolone sedative. GABA-A modulator. Insomnia override.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Meloset Melatonin 3mg', N'Melatonin', N'3 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Circadian rhythm regulator. Endogenous sleep signal amplifier.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Eszop Eszopiclone 3mg', N'Eszopiclone', N'3 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Cyclopyrrolone sedative. GABA-A modulator. Insomnia override.', N'Anti Anxiety & Anti Depressants', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Voxa-50 Fluvoxamine', N'Fluvoxamine', N'50 mg', NULL, NULL, NULL, NULL, N'No price listed', N'SSRI. Sigma-1 receptor agonist. OCD and anxiety suppressor.', N'Anti Anxiety & Anti Depressants', N'Tablet');

/* ~~~ PHARMACEUTICAL INJECTION — 21 compounds ~~~ */

INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Eravone Edaravone Injection', N'Edaravone', N'20 ml', N'Rs 420/Vial', 7.01, 7.01, N'1 vial', N'INR converted', N'Free radical scavenger. Neuroprotective oxidative damage shield.', N'Pharmaceutical Injection', N'Injection');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Glutathione Glutacan Injection', N'Glutathione', N'600 mg', N'Rs 1999/Vial', 33.38, 33.38, N'1 vial', N'INR converted', N'Master antioxidant. Cellular detoxification and repair agent.', N'Pharmaceutical Injection', N'Injection');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Vintor Erythropoietin Injection', N'Erythropoietin', N'10000 IU', N'Rs 2244/Vial', 37.47, 37.47, N'1 vial', N'INR converted', N'Red blood cell production amplifier. Oxygen carrying capacity boost.', N'Pharmaceutical Injection', N'Injection');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Victoza Liraglutide Injection', N'Liraglutide', N'6 mg/ml', N'Rs 4830/Piece', 80.66, 80.66, N'1 vial', N'INR converted', N'GLP-1 receptor agonist. Appetite suppression and glucose control.', N'Pharmaceutical Injection', N'Injection');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Mounjaro Tirzepatide 5mg', N'Tirzepatide', N'5 mg', N'Rs 4375/Vial', 73.06, 73.06, N'1 vial', N'INR converted', N'Dual GIP/GLP-1 agonist. Next-gen metabolic and weight override.', N'Pharmaceutical Injection', N'Injection');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Sustaviron Testosterone 250mg', N'Testosterone', N'250 mg', N'Rs 225/Vial', 3.76, 3.76, N'1 vial', N'INR converted', N'Primary androgen. Anabolic-androgenic hormone replacement.', N'Pharmaceutical Injection', N'Injection');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Xylaxin Xylazine 30ml', N'Xylazine', N'30 ml', N'Rs 580/kg', 9.69, 9.69, N'1 vial', N'INR converted', N'Alpha-2 adrenergic agonist. Veterinary sedative and analgesic.', N'Pharmaceutical Injection', N'Injection');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Erypro Safe 40000 IU', N'Erythropoietin', N'40000 IU', NULL, NULL, NULL, NULL, N'No price listed', N'Red blood cell production amplifier. Oxygen carrying capacity boost.', N'Pharmaceutical Injection', N'Injection');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Melalite Forte Cream', N'Hydroquinone', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Tyrosinase inhibitor. Melanin production suppressor. Skin lightener.', N'Pharmaceutical Injection', N'Cream');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Sustanon Testosterone 100mg', N'Testosterone Propionate', N'100 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Fast-acting testosterone ester. Short-half androgen delivery.', N'Pharmaceutical Injection', N'Injection');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Deca Instabolin Injection', N'Nandrolone Decanoate', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Anabolic steroid. Nitrogen retention and muscle mass amplifier.', N'Pharmaceutical Injection', N'Injection');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Testoviron Depot Injection', N'Testosterone Enanthate', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Long-acting testosterone ester. Sustained androgen delivery.', N'Pharmaceutical Injection', N'Injection');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Retesto 250mg Injection', N'Testosterone', N'250 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Primary androgen. Anabolic-androgenic hormone replacement.', N'Pharmaceutical Injection', N'Injection');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Winvol Stanozolol Injection', N'Stanozolol', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Anabolic steroid. DHT derivative. Lean mass and strength agent.', N'Pharmaceutical Injection', N'Injection');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Testenate Depot 250 Injection', N'Testosterone Enanthate', N'250 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Long-acting testosterone ester. Sustained androgen delivery.', N'Pharmaceutical Injection', N'Injection');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'L Carnibol 2000mg Injection', N'L-Carnitine', N'2000 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Fatty acid mitochondrial transporter. Energy metabolism facilitator.', N'Pharmaceutical Injection', N'Injection');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Fertigyn HP 5000 Injection', N'Chorionic Gonadotropin', N'5000 IU', NULL, NULL, NULL, NULL, N'No price listed', N'LH mimic. Gonadal stimulation trigger. Fertility catalyst.', N'Pharmaceutical Injection', N'Injection');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'HUCOG 5000 HP Injection', N'Chorionic Gonadotropin', N'5000 IU', NULL, NULL, NULL, NULL, N'No price listed', N'LH mimic. Gonadal stimulation trigger. Fertility catalyst.', N'Pharmaceutical Injection', N'Injection');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Puretrig 5000 IU Injection', N'Chorionic Gonadotropin', N'5000 IU', NULL, NULL, NULL, NULL, N'No price listed', N'LH mimic. Gonadal stimulation trigger. Fertility catalyst.', N'Pharmaceutical Injection', N'Injection');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Ovigil Chorionic Gonadotropin', N'Chorionic Gonadotropin', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'LH mimic. Gonadal stimulation trigger. Fertility catalyst.', N'Pharmaceutical Injection', N'Injection');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Wepox 10000 Erythropoietin', N'Erythropoietin', N'10000 IU', NULL, NULL, NULL, NULL, N'No price listed', N'Red blood cell production amplifier. Oxygen carrying capacity boost.', N'Pharmaceutical Injection', N'Injection');

/* ~~~ HYPERTENSION MEDICINE — 10 compounds ~~~ */

INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Endobloc Ambrisentan Tablets', N'Ambrisentan', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Endothelin receptor antagonist. Pulmonary arterial pressure reducer.', N'Hypertension Medicine', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Hydrazide Hydrochlorothiazide', N'Hydrochlorothiazide', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Thiazide diuretic. Sodium-chloride reabsorption blocker.', N'Hypertension Medicine', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Valzaar Valsartan Tablets', N'Valsartan', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Angiotensin II receptor blocker. Blood pressure reduction agent.', N'Hypertension Medicine', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Metolar Metoprolol Tartrate', N'Metoprolol Tartrate', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Selective beta-1 blocker. Heart rate and cardiac output governor.', N'Hypertension Medicine', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Telmikind Telmisartan', N'Telmisartan', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'ARB. Angiotensin II receptor blocker. Long-acting BP suppressor.', N'Hypertension Medicine', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Amloheal Amlodipine 10mg', N'Amlodipine', N'10 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Calcium channel blocker. Vascular smooth muscle relaxant.', N'Hypertension Medicine', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Amlip-5 Amlodipine 5mg', N'Amlodipine', N'5 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Calcium channel blocker. Vascular smooth muscle relaxant.', N'Hypertension Medicine', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Aquazide Hydrochlorothiazide', N'Hydrochlorothiazide', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Thiazide diuretic. Sodium-chloride reabsorption blocker.', N'Hypertension Medicine', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Minoxihead Minoxidil 2.5mg', N'Minoxidil', N'2.5 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Vasodilator. Potassium channel opener. Hair regrowth activator.', N'Hypertension Medicine', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Minwin-5 Minoxidil', N'Minoxidil', N'5 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Vasodilator. Potassium channel opener. Hair regrowth activator.', N'Hypertension Medicine', N'Tablet');

/* ~~~ ANTI DIABETIC MEDICINE — 10 compounds ~~~ */

INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Biciphage Metformin Tablets', N'Metformin', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Biguanide. Hepatic glucose output suppressor. Insulin sensitizer.', N'Anti Diabetic Medicine', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Glyciphage Metformin Tablet', N'Metformin', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Biguanide. Hepatic glucose output suppressor. Insulin sensitizer.', N'Anti Diabetic Medicine', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Metformin Hydrochloride Tablets', N'Metformin Hydrochloride', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Biguanide. Hepatic glucose output suppressor. Insulin sensitizer.', N'Anti Diabetic Medicine', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Rybelsus Semaglutide 14mg', N'Semaglutide', N'14 mg', NULL, NULL, NULL, NULL, N'No price listed', N'GLP-1 receptor agonist. Metabolic override. Appetite extinction.', N'Anti Diabetic Medicine', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Rybelsus Semaglutide 7mg', N'Semaglutide', N'7 mg', N'Rs 3520/Strip', 58.78, 5.88, N'~10', N'INR converted', N'GLP-1 receptor agonist. Metabolic override. Appetite extinction.', N'Anti Diabetic Medicine', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Mounjaro KwikPen 7.5mg', N'Tirzepatide', N'7.5 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Dual GIP/GLP-1 agonist. Next-gen metabolic and weight override.', N'Anti Diabetic Medicine', N'Injection Pen');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Mounjaro KwikPen 5mg', N'Tirzepatide', N'5 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Dual GIP/GLP-1 agonist. Next-gen metabolic and weight override.', N'Anti Diabetic Medicine', N'Injection Pen');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Mounjaro KwikPen 2.5mg', N'Tirzepatide', N'2.5 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Dual GIP/GLP-1 agonist. Next-gen metabolic and weight override.', N'Anti Diabetic Medicine', N'Injection Pen');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Mounjaro KwikPen 12.5mg', N'Tirzepatide', N'12.5 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Dual GIP/GLP-1 agonist. Next-gen metabolic and weight override.', N'Anti Diabetic Medicine', N'Injection Pen');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Mounjaro Tirzepatide 15mg Pen', N'Tirzepatide', N'15 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Dual GIP/GLP-1 agonist. Next-gen metabolic and weight override.', N'Anti Diabetic Medicine', N'Injection Pen');

/* ~~~ SKIN CARE — 26 compounds ~~~ */

INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Retino A Tretinoin Cream', N'Tretinoin', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Retinoid. Keratinocyte differentiation accelerator. Skin renewal.', N'Skin Care', N'Cream');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Ilumax Skin Cream', N'Hydroquinone', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Tyrosinase inhibitor. Melanin production suppressor. Skin lightener.', N'Skin Care', N'Cream');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'A Ret Tretinoin 0.1% Gel', N'Tretinoin', N'0.1%', NULL, NULL, NULL, NULL, N'No price listed', N'Retinoid. Keratinocyte differentiation accelerator. Skin renewal.', N'Skin Care', N'Gel');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Melamet Hydroquinone Cream', N'Hydroquinone', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Tyrosinase inhibitor. Melanin production suppressor. Skin lightener.', N'Skin Care', N'Cream');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Supatret Tretinoin Gel', N'Tretinoin', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Retinoid. Keratinocyte differentiation accelerator. Skin renewal.', N'Skin Care', N'Gel');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Placenta Extract Gel', N'Placenta Extract', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Bioactive tissue extract. Wound healing and skin repair adjunct.', N'Skin Care', N'Gel');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Tretiva Isotretinoin 20mg', N'Isotretinoin', N'20 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Potent retinoid. Sebum production annihilator. Severe acne cure.', N'Skin Care', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Tugain Solution 2% Minoxidil', N'Minoxidil', N'2%', NULL, NULL, NULL, NULL, N'No price listed', N'Vasodilator. Potassium channel opener. Hair regrowth activator.', N'Skin Care', N'Spray');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Isotroin 30mg Capsules', N'Isotretinoin', N'30 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Potent retinoid. Sebum production annihilator. Severe acne cure.', N'Skin Care', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Tretiheal Cream 0.1', N'Tretinoin', N'0.1%', NULL, NULL, NULL, NULL, N'No price listed', N'Retinoid. Keratinocyte differentiation accelerator. Skin renewal.', N'Skin Care', N'Cream');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Terbicip 1% Terbinafine Cream', N'Terbinafine', N'1%', NULL, NULL, NULL, NULL, N'No price listed', N'Allylamine antifungal. Squalene epoxidase inhibitor. Fungal wall breaker.', N'Skin Care', N'Cream');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Minoxihead Minoxidil 1.25mg', N'Minoxidil', N'1.25 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Vasodilator. Potassium channel opener. Hair regrowth activator.', N'Skin Care', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Tretimaxx Tretinoin 0.025% Cream', N'Tretinoin', N'0.025%', NULL, NULL, NULL, NULL, N'No price listed', N'Retinoid. Keratinocyte differentiation accelerator. Skin renewal.', N'Skin Care', N'Cream');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'MInwin Minoxidil 2.5mg', N'Minoxidil', N'2.5 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Vasodilator. Potassium channel opener. Hair regrowth activator.', N'Skin Care', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Tretigel Tretinoin 0.1% Gel', N'Tretinoin', N'0.1%', NULL, NULL, NULL, NULL, N'No price listed', N'Retinoid. Keratinocyte differentiation accelerator. Skin renewal.', N'Skin Care', N'Gel');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Tretiva Isotretinoin 10mg', N'Isotretinoin', N'10 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Potent retinoid. Sebum production annihilator. Severe acne cure.', N'Skin Care', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Accufine Isotretinoin 20mg', N'Isotretinoin', N'20 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Potent retinoid. Sebum production annihilator. Severe acne cure.', N'Skin Care', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Isotroin Isotretinoin 20mg', N'Isotretinoin', N'20 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Potent retinoid. Sebum production annihilator. Severe acne cure.', N'Skin Care', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Adakleen Adapalene 0.1% Gel', N'Adapalene', N'0.1%', NULL, NULL, NULL, NULL, N'No price listed', N'Retinoid-like. Comedolytic and anti-inflammatory. Acne specialist.', N'Skin Care', N'Gel');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Terbinafine Hydrochloride Cream', N'Terbinafine', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Allylamine antifungal. Squalene epoxidase inhibitor. Fungal wall breaker.', N'Skin Care', N'Cream');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Tretin Tretinoin 0.05% Cream', N'Tretinoin', N'0.05%', NULL, NULL, NULL, NULL, N'No price listed', N'Retinoid. Keratinocyte differentiation accelerator. Skin renewal.', N'Skin Care', N'Cream');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Tacroheal Tacrolimus 0.1%', N'Tacrolimus', N'0.1%', NULL, NULL, NULL, NULL, N'No price listed', N'Calcineurin inhibitor. T-cell activation suppressor. Immune modulator.', N'Skin Care', N'Ointment');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Adapalene 0.1% 15gm Gel', N'Adapalene', N'0.1%', NULL, NULL, NULL, NULL, N'No price listed', N'Retinoid-like. Comedolytic and anti-inflammatory. Acne specialist.', N'Skin Care', N'Gel');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'A Ret Gel 0.1% Tretinoin', N'Tretinoin', N'0.1%', NULL, NULL, NULL, NULL, N'No price listed', N'Retinoid. Keratinocyte differentiation accelerator. Skin renewal.', N'Skin Care', N'Gel');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Tretiforce Tretinoin 0.05% Cream', N'Tretinoin', N'0.05%', NULL, NULL, NULL, NULL, N'No price listed', N'Retinoid. Keratinocyte differentiation accelerator. Skin renewal.', N'Skin Care', N'Cream');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Terbiface Plus NF Cream', N'Terbinafine', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Allylamine antifungal. Squalene epoxidase inhibitor. Fungal wall breaker.', N'Skin Care', N'Cream');

/* ~~~ HAIR LOSS MEDICINES — 6 compounds ~~~ */

INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Finpecia Finasteride 1mg', N'Finasteride', N'1 mg', NULL, NULL, NULL, NULL, N'No price listed', N'5-alpha reductase inhibitor. DHT blocker. Hair loss defense agent.', N'Hair Loss Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'F Pecia Tablet', N'Finasteride', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'5-alpha reductase inhibitor. DHT blocker. Hair loss defense agent.', N'Hair Loss Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Vesca Biotin Capsules', N'Biotin', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Vitamin B7. Keratin infrastructure support. Hair-nail fortifier.', N'Hair Loss Medicines', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Lonitab 5mg Tablet', N'Minoxidil', N'5 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Vasodilator. Potassium channel opener. Hair regrowth activator.', N'Hair Loss Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Lonitab Minoxidil 10mg', N'Minoxidil', N'10 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Vasodilator. Potassium channel opener. Hair regrowth activator.', N'Hair Loss Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Minoxia Finasteride 5mg', N'Finasteride', N'5 mg', NULL, NULL, NULL, NULL, N'No price listed', N'5-alpha reductase inhibitor. DHT blocker. Hair loss defense agent.', N'Hair Loss Medicines', N'Tablet');

/* ~~~ STEROID TABLETS — 8 compounds ~~~ */

INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Omnacortil Prednisolone 5mg', N'Prednisolone', N'5 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Corticosteroid. Broad anti-inflammatory and immunosuppressive agent.', N'Steroid Tablets', N'Dispersible Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Omnacortil Prednisolone 20mg', N'Prednisolone', N'20 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Corticosteroid. Broad anti-inflammatory and immunosuppressive agent.', N'Steroid Tablets', N'Dispersible Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Cernos Soft Gel Capsule', N'Testosterone Undecanoate', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Oral testosterone ester. Long-chain androgen delivery system.', N'Steroid Tablets', N'Soft Gel Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Testoheal Testosterone Undecanoate', N'Testosterone Undecanoate', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Oral testosterone ester. Long-chain androgen delivery system.', N'Steroid Tablets', N'Soft Gel Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Tizan Tizanidine 2mg', N'Tizanidine', N'2 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Alpha-2 adrenergic agonist. Central muscle tone reducer.', N'Steroid Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Lupi HCG 2000 IU', N'Chorionic Gonadotropin', N'2000 IU', NULL, NULL, NULL, NULL, N'No price listed', N'LH mimic. Gonadal stimulation trigger. Fertility catalyst.', N'Steroid Tablets', N'Injection');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Anavar Gold Oxandrolone 10mg', N'Oxandrolone', N'10 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Mild anabolic steroid. Lean tissue preservation. Low androgenic.', N'Steroid Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Testoheal Testosterone 40mg Capsule', N'Testosterone', N'40 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Primary androgen. Anabolic-androgenic hormone replacement.', N'Steroid Tablets', N'Capsule');

/* ~~~ EYE CARE — 7 compounds ~~~ */

INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Ciplox Ciprofloxacin 10ml Eye Drops', N'Ciprofloxacin', N'10 ml', NULL, NULL, NULL, NULL, N'No price listed', N'Fluoroquinolone. DNA gyrase and topoisomerase IV dual inhibitor.', N'Eye Care', N'Eye Drops');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Tropicacyl Eye Drop', N'Tropicamide', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Mydriatic agent. Pupil dilation for ophthalmic examination.', N'Eye Care', N'Eye Drops');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Latoprost Eye Drop', N'Latanoprost', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Prostaglandin analog. Intraocular pressure reduction agent.', N'Eye Care', N'Eye Drops');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Gatilox Eye Drops', N'Gatifloxacin', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Fourth-gen fluoroquinolone. Ophthalmic bacterial coverage.', N'Eye Care', N'Eye Drops');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Latocom Latanoprost Eye Drop', N'Latanoprost', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Prostaglandin analog. Intraocular pressure reduction agent.', N'Eye Care', N'Eye Drops');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Eyeheal Eye Drops', NULL, NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Ophthalmic lubricant. Eye moisture and comfort agent.', N'Eye Care', N'Eye Drops');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Alphagan Z Brimonidine Eye Drops', N'Brimonidine Tartrate', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Alpha-2 agonist. Aqueous humor suppressor. Glaucoma agent.', N'Eye Care', N'Eye Drops');

/* ~~~ VETERINARY MEDICINES — 14 compounds ~~~ */

INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Modafinil 200mg USP Tablets', N'Modafinil', N'200 mg', NULL, 2.37, 0.24, N'10', N'Confirmed quote', N'Wakefulness enforcer. Cognitive override for sustained ops.', N'Veterinary Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Fenbendazole Wormentel 888mg', N'Fenbendazole', N'888 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Benzimidazole anthelmintic. Microtubule polymerization disruptor.', N'Veterinary Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Vetoquinol Wokazole Plus Lotion', NULL, NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Veterinary antifungal lotion. Topical dermatophyte suppressor.', N'Veterinary Medicines', N'Lotion');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Virbac Nutrich Tablet', NULL, NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Veterinary nutritional supplement. Multivitamin-mineral support.', N'Veterinary Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Carodyl Chewable Tablet', N'Carprofen', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Veterinary NSAID. COX-2 preferential. Canine pain management.', N'Veterinary Medicines', N'Chewable Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Doxypet Doxycycline Tablets', N'Doxycycline', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Tetracycline-class. Broad-spectrum protein synthesis inhibitor.', N'Veterinary Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Canopas Salicylic Acid', N'Salicylic Acid', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Keratolytic agent. Skin cell turnover accelerator.', N'Veterinary Medicines', N'Topical');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Cephavet Cephalexin Tablets', N'Cephalexin', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'First-gen cephalosporin. Gram-positive bacterial wall breaker.', N'Veterinary Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Strong Beat Tablet', NULL, NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Veterinary cardiac support supplement. Heart function adjunct.', N'Veterinary Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Provical Pet 200ml Syrup', NULL, NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Veterinary calcium-phosphorus syrup. Bone and lactation support.', N'Veterinary Medicines', N'Syrup');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Febentel Fenbendazole 150mg', N'Fenbendazole', N'150 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Benzimidazole anthelmintic. Microtubule polymerization disruptor.', N'Veterinary Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Fenguard Fenbendazole 444mg', N'Fenbendazole', N'444 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Benzimidazole anthelmintic. Microtubule polymerization disruptor.', N'Veterinary Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Febental Plus Fenbendazole + Ivermectin 500mg', N'Fenbendazole + Ivermectin', N'500 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Dual antiparasitic combo. Worm and ectoparasite elimination.', N'Veterinary Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Vitabest Derm 250ml', NULL, NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Veterinary dermatological solution. Skin and coat health agent.', N'Veterinary Medicines', N'Solution');

/* ~~~ ASTHMA MEDICINE — 5 compounds ~~~ */

INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Tiova Tiotropium Bromide Inhaler', N'Tiotropium Bromide', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Long-acting muscarinic antagonist. Bronchodilation sustainer.', N'Asthma Medicine', N'Inhaler');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Ipravent Ipratropium Inhaler', N'Ipratropium', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Short-acting anticholinergic. Bronchospasm acute relief.', N'Asthma Medicine', N'Inhaler');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Duolin Levosalbutamol Respules', N'Levosalbutamol', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'R-enantiomer bronchodilator. Selective airway smooth muscle relaxant.', N'Asthma Medicine', N'Respules');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Asthalin Salbutamol Inhaler', N'Salbutamol', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Beta-2 agonist. Bronchial smooth muscle rapid relaxant.', N'Asthma Medicine', N'Inhaler');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Ketasma Ketotifen Tablets', N'Ketotifen', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Mast cell stabilizer. Antihistamine with anti-asthma action.', N'Asthma Medicine', N'Tablet');

/* ~~~ ANTI HIV MEDICINES — 5 compounds ~~~ */

INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Viraday Emtricitabine 30 Tablets', N'Emtricitabine + Tenofovir + Efavirenz', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Triple antiretroviral combo. HIV replication three-point shutdown.', N'Anti HIV Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Ricovir Tenofovir Tablets', N'Tenofovir', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Nucleotide reverse transcriptase inhibitor. HIV/HBV replication blocker.', N'Anti HIV Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Wepox 10000 Erythropoietin Injection', N'Erythropoietin', N'10000 IU', NULL, NULL, NULL, NULL, N'No price listed', N'Red blood cell production amplifier. Oxygen carrying capacity boost.', N'Anti HIV Medicines', N'Injection');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Viraday Tablets Cipla', N'Emtricitabine + Tenofovir + Efavirenz', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Triple antiretroviral combo. HIV replication three-point shutdown.', N'Anti HIV Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Acivir DT 200mg', N'Acyclovir', N'200 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Viral DNA polymerase inhibitor. Herpes replication terminator.', N'Anti HIV Medicines', N'Tablet');

/* ~~~ PREGABALIN — 5 compounds ~~~ */

INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Pregarica-300 Pregabalin Capsules', N'Pregabalin', N'300 mg', NULL, 3.32, 0.22, N'15', N'Confirmed quote', N'Nerve-silencer. Suppresses neuropathic fire. Anti-seizure secondary.', N'Pregabalin', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Nervigesic-300 Pregabalin Capsule', N'Pregabalin', N'300 mg', NULL, 3.32, 0.22, N'15', N'Confirmed quote', N'Nerve-silencer. Suppresses neuropathic fire. Anti-seizure secondary.', N'Pregabalin', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Pregabalin 150mg Capsule', N'Pregabalin', N'150 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Nerve-silencer. Suppresses neuropathic fire. Anti-seizure secondary.', N'Pregabalin', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Lyrikare Pregabalin 300mg', N'Pregabalin', N'300 mg', NULL, 3.32, 0.22, N'15', N'Confirmed quote', N'Nerve-silencer. Suppresses neuropathic fire. Anti-seizure secondary.', N'Pregabalin', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Pregafresh Pregabalin 300mg', N'Pregabalin', N'300 mg', NULL, 3.32, 0.22, N'15', N'Confirmed quote', N'Nerve-silencer. Suppresses neuropathic fire. Anti-seizure secondary.', N'Pregabalin', N'Capsule');

/* ~~~ CARDIOVASCULAR MEDICINE — 5 compounds ~~~ */

INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Apigat Apixaban 5mg', N'Apixaban', N'5 mg', N'Rs 855/Pack', 14.28, 1.43, N'~10', N'INR converted', N'Factor Xa inhibitor. Direct oral anticoagulant. Clot prevention.', N'Cardiovascular Medicine', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Apiban Apixaban 2.5mg', N'Apixaban', N'2.5 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Factor Xa inhibitor. Direct oral anticoagulant. Clot prevention.', N'Cardiovascular Medicine', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Omez Omeprazole 40mg', N'Omeprazole', N'40 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Proton pump inhibitor. Gastric acid total suppression.', N'Cardiovascular Medicine', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Telmaheal Beta 50', N'Telmisartan + Metoprolol', N'50 mg', NULL, NULL, NULL, NULL, N'No price listed', N'ARB plus beta-blocker. Dual blood pressure reduction strategy.', N'Cardiovascular Medicine', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'GlutaQuick Glutathione 500mg', N'Glutathione', N'500 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Master antioxidant. Cellular detoxification and repair agent.', N'Cardiovascular Medicine', N'Tablet');

/* ~~~ HEPATITIS MEDICINE — 5 compounds ~~~ */

INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Adesera Adefovir Dipivoxil', N'Adefovir Dipivoxil', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Nucleotide analog. Hepatitis B reverse transcriptase inhibitor.', N'Hepatitis Medicine', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Natclovir Ganciclovir 250/500mg', N'Ganciclovir', N'250/500 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Antiviral nucleoside analog. CMV DNA polymerase inhibitor.', N'Hepatitis Medicine', N'Injection');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Hepbest Tenofovir Alafenamide', N'Tenofovir Alafenamide', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Prodrug nucleotide analog. Hepatitis B with improved renal safety.', N'Hepatitis Medicine', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Ledifos Ledipasvir', N'Ledipasvir + Sofosbuvir', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Dual HCV direct-acting antivirals. Hepatitis C cure protocol.', N'Hepatitis Medicine', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Entavir Entecavir', N'Entecavir', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Guanosine analog. Hepatitis B polymerase inhibitor.', N'Hepatitis Medicine', N'Tablet');

/* ~~~ ANTI MIGRAINE MEDICINES — 5 compounds ~~~ */

INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Naratrex Naratriptan 2.5mg', N'Naratriptan', N'2.5 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Serotonin 5-HT1 agonist. Slow-onset long-acting migraine relief.', N'Anti Migraine Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Rizact Rizatriptan 5mg', N'Rizatriptan', N'5 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Serotonin 5-HT1B/1D agonist. Fast migraine vascular constrictor.', N'Anti Migraine Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Rizora Rizatriptan Benzoate', N'Rizatriptan', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Serotonin 5-HT1B/1D agonist. Fast migraine vascular constrictor.', N'Anti Migraine Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Ritza Rizatriptan', N'Rizatriptan', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Serotonin 5-HT1B/1D agonist. Fast migraine vascular constrictor.', N'Anti Migraine Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Sumitop Sumatriptan 100mg', N'Sumatriptan', N'100 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Serotonin agonist. Migraine vascular constriction agent.', N'Anti Migraine Medicines', N'Tablet');

/* ~~~ ANTI ALLERGIC MEDICINES — 5 compounds ~~~ */

INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Phenergan Promethazine', N'Promethazine', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'First-gen antihistamine. Sedating anti-allergy and anti-nausea.', N'Anti Allergic Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Medrol Methylprednisolone 4mg', N'Methylprednisolone', N'4 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Potent corticosteroid. Inflammation and immune response suppressor.', N'Anti Allergic Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Methylprednisolone 8mg', N'Methylprednisolone', N'8 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Potent corticosteroid. Inflammation and immune response suppressor.', N'Anti Allergic Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Predniheal Prednisolone 40mg', N'Prednisolone', N'40 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Corticosteroid. Broad anti-inflammatory and immunosuppressive agent.', N'Anti Allergic Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Zovirax Acyclovir 200mg', N'Acyclovir', N'200 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Viral DNA polymerase inhibitor. Herpes replication terminator.', N'Anti Allergic Medicines', N'Tablet');

/* ~~~ ANTI VIRAL MEDICINES — 6 compounds ~~~ */

INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Zoviclovir Acyclovir 200mg', N'Acyclovir', N'200 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Viral DNA polymerase inhibitor. Herpes replication terminator.', N'Anti Viral Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Zoviclovir Acyclovir 400mg', N'Acyclovir', N'400 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Viral DNA polymerase inhibitor. Herpes replication terminator.', N'Anti Viral Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Zoviclovir Acyclovir 800mg', N'Acyclovir', N'800 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Viral DNA polymerase inhibitor. Herpes replication terminator.', N'Anti Viral Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Valclovir Valacyclovir 500mg', N'Valacyclovir', N'500 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Acyclovir prodrug. Enhanced bioavailability herpes suppressor.', N'Anti Viral Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Valclovir Valacyclovir 1000mg', N'Valacyclovir', N'1000 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Acyclovir prodrug. Enhanced bioavailability herpes suppressor.', N'Anti Viral Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Valaforce Valacyclovir 1000mg', N'Valacyclovir', N'1000 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Acyclovir prodrug. Enhanced bioavailability herpes suppressor.', N'Anti Viral Medicines', N'Tablet');

/* ~~~ ANTI FUNGAL MEDICINES — 5 compounds ~~~ */

INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Flagyl Metronidazole 200mg', N'Metronidazole', N'200 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Nitroimidazole. Anaerobic bacterial and protozoal DNA disruptor.', N'Anti Fungal Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Candiforce Itraconazole 100mg', N'Itraconazole', N'100 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Triazole antifungal. Broad-spectrum ergosterol synthesis blocker.', N'Anti Fungal Medicines', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Terbiface Terbinafine 250mg', N'Terbinafine', N'250 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Allylamine antifungal. Squalene epoxidase inhibitor. Fungal wall breaker.', N'Anti Fungal Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Flagyl Metronidazole 400mg', N'Metronidazole', N'400 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Nitroimidazole. Anaerobic bacterial and protozoal DNA disruptor.', N'Anti Fungal Medicines', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Sebifin Terbinafine', N'Terbinafine', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Allylamine antifungal. Squalene epoxidase inhibitor. Fungal wall breaker.', N'Anti Fungal Medicines', N'Tablet');

/* ~~~ ANTI MALARIAL MEDICINE — 5 compounds ~~~ */

INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Norsunate Artesunate 50mg', N'Artesunate', N'50 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Antimalarial strike agent. Parasite cell destruction on contact.', N'Anti Malarial Medicine', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Ridsunate Artesunate 100mg', N'Artesunate', N'100 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Antimalarial strike agent. Parasite cell destruction on contact.', N'Anti Malarial Medicine', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Artesunate 50mg Tablets', N'Artesunate', N'50 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Antimalarial strike agent. Parasite cell destruction on contact.', N'Anti Malarial Medicine', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Artesunate 100mg Tablet', N'Artesunate', N'100 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Antimalarial strike agent. Parasite cell destruction on contact.', N'Anti Malarial Medicine', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Norsunate 200mg Artesunate', N'Artesunate', N'200 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Antimalarial strike agent. Parasite cell destruction on contact.', N'Anti Malarial Medicine', N'Tablet');

/* ~~~ INFERTILITY DRUGS — 5 compounds ~~~ */

INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Fertomid Clomiphene Tablets', N'Clomiphene', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Selective estrogen receptor modulator. Ovulation induction trigger.', N'Infertility Drugs', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Fertogard Clomifene Tablets', N'Clomifene', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Selective estrogen receptor modulator. Ovulation induction trigger.', N'Infertility Drugs', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'EN-Clofert Enclomiphene 50mg', N'Enclomiphene', N'50 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Trans-isomer SERM. Testosterone restoration via gonadotropin release.', N'Infertility Drugs', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Clomisign Tablet IP', N'Clomiphene', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Selective estrogen receptor modulator. Ovulation induction trigger.', N'Infertility Drugs', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Clomisign 100 Tablet', N'Clomiphene', N'100 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Selective estrogen receptor modulator. Ovulation induction trigger.', N'Infertility Drugs', N'Tablet');

/* ~~~ FEMALE HEALTHCARE — 5 compounds ~~~ */

INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Slimtop Orlistat 120mg', N'Orlistat', N'120 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Lipase inhibitor. Dietary fat absorption blocker. Weight loss agent.', N'Female Healthcare', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Orliash Orlistat 120mg', N'Orlistat', N'120 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Lipase inhibitor. Dietary fat absorption blocker. Weight loss agent.', N'Female Healthcare', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Cabermax 0.5mg Tablets', N'Cabergoline', N'0.5 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Dopamine agonist. Prolactin suppressor. Pituitary override.', N'Female Healthcare', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Dydrosmart Dydrogesterone 10mg', N'Dydrogesterone', N'10 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Oral progestogen. Progesterone receptor agonist. Cycle support.', N'Female Healthcare', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Estraheal Estradiol Valerate 2mg', N'Estradiol Valerate', N'2 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Estrogen ester. Hormone replacement therapy. Menopausal relief.', N'Female Healthcare', N'Tablet');

/* ~~~ WEIGHT LOSS — 5 compounds ~~~ */

INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Garcinia Cambogia Capsule', N'Garcinia Cambogia', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Hydroxycitric acid source. Fat synthesis and appetite suppressor.', N'Weight Loss', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Vesca Garcinia Cambogia Capsule', N'Garcinia Cambogia', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Hydroxycitric acid source. Fat synthesis and appetite suppressor.', N'Weight Loss', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Orligal Orlistat Capsules', N'Orlistat', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Lipase inhibitor. Dietary fat absorption blocker. Weight loss agent.', N'Weight Loss', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Slimex O Capsules', N'Orlistat', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Lipase inhibitor. Dietary fat absorption blocker. Weight loss agent.', N'Weight Loss', N'Capsule');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Slimtop Orlistat Capsule', N'Orlistat', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Lipase inhibitor. Dietary fat absorption blocker. Weight loss agent.', N'Weight Loss', N'Capsule');

/* ~~~ MODAFINIL TABLETS — 5 compounds ~~~ */

INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Modaheal Modafinil 200mg', N'Modafinil', N'200 mg', NULL, 2.37, 0.24, N'10', N'Confirmed quote', N'Wakefulness enforcer. Cognitive override for sustained ops.', N'Modafinil Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Modasmart Modafinil 400mg', N'Modafinil', N'400 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Wakefulness enforcer. Cognitive override for sustained ops.', N'Modafinil Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Modasafe Modafinil + Armodafinil', N'Modafinil + Armodafinil', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Dual wakefulness agents. Combined cognitive sustain formula.', N'Modafinil Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Modalert Modafinil 100mg', N'Modafinil', N'100 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Wakefulness enforcer. Cognitive override for sustained ops.', N'Modafinil Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Modalert Modafinil 200mg', N'Modafinil', N'200 mg', NULL, 2.37, 0.24, N'10', N'Confirmed quote', N'Wakefulness enforcer. Cognitive override for sustained ops.', N'Modafinil Tablets', N'Tablet');

/* ~~~ IVERMECTIN TABLETS — 6 compounds ~~~ */

INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Iverjohn Ivermectin 12mg', N'Ivermectin', N'12 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Antiparasitic neural disruptor. Broad-spectrum invertebrate killer.', N'Ivermectin Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Ivecare Ivermectin', N'Ivermectin', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Antiparasitic neural disruptor. Broad-spectrum invertebrate killer.', N'Ivermectin Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Iverviral Ivermectin', N'Ivermectin', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Antiparasitic neural disruptor. Broad-spectrum invertebrate killer.', N'Ivermectin Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Iversun Ivermectin', N'Ivermectin', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Antiparasitic neural disruptor. Broad-spectrum invertebrate killer.', N'Ivermectin Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Ivecop Ivermectin', N'Ivermectin', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Antiparasitic neural disruptor. Broad-spectrum invertebrate killer.', N'Ivermectin Tablets', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Iverfresh Ivermectin', N'Ivermectin', NULL, NULL, NULL, NULL, NULL, N'No price listed', N'Antiparasitic neural disruptor. Broad-spectrum invertebrate killer.', N'Ivermectin Tablets', N'Tablet');

/* ~~~ PHARMACEUTICAL — 5 compounds ~~~ */

INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Pulmoboss 62.5mg Tablet', N'Bosentan', N'62.5 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Dual endothelin receptor antagonist. Pulmonary hypertension agent.', N'Pharmaceutical', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Febutop Febuxostat 40mg', N'Febuxostat', N'40 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Xanthine oxidase inhibitor. Uric acid production blocker.', N'Pharmaceutical', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Angiotensin Lisinopril 5mg', N'Lisinopril', N'5 mg', NULL, NULL, NULL, NULL, N'No price listed', N'ACE inhibitor. Angiotensin conversion blocker. BP reducer.', N'Pharmaceutical', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Rasalect Rasagiline 1mg', N'Rasagiline', N'1 mg', NULL, NULL, NULL, NULL, N'No price listed', N'MAO-B inhibitor. Dopamine preservation. Parkinson disease agent.', N'Pharmaceutical', N'Tablet');
INSERT INTO Medication (ProductName, ActiveIngredient, Strength, PriceINR, AUDPerStrip, AUDPerPill, PillsPerStrip, PriceSource, CodexDescriptor, Category_Ref, DosageForm_Ref)
VALUES (N'Rifagut Rifaximin 200mg', N'Rifaximin', N'200 mg', NULL, NULL, NULL, NULL, N'No price listed', N'Gut-selective antibiotic. Traveler diarrhea elimination specialist.', N'Pharmaceutical', N'Tablet');
GO


/*===============================================================
  PHASE 4: VERIFICATION — CODEX INTEGRITY CHECK
  ---------------------------------------------------------------
  SELECT = DML command. Retrieves data from one or more tables.
  These queries confirm the arsenal was loaded correctly.
  COUNT(*) = aggregate function that counts all rows in a table.
  GROUP BY = groups rows sharing a value, so aggregates work per-group.
  ORDER BY = sorts the output. ASC = ascending, DESC = descending.

  Run these after the full script to verify the codex is intact.
  If the counts do not match, something went wrong in deployment.
===============================================================*/


/* --- Row counts per table: confirm the manifest matches --- */
-- Each query returns the total number of rows in that table.
-- Expected: MedicationCategory = 30, DosageForm = 22, Medication = 415

SELECT 'MedicationCategory' AS TableName, COUNT(*) AS [RowCount] FROM MedicationCategory
UNION ALL
SELECT 'DosageForm', COUNT(*) FROM DosageForm
UNION ALL
SELECT 'Medication', COUNT(*) FROM Medication;
GO


/* --- Full arsenal manifest: all compounds ordered by category and name --- */
-- This is the complete codex readout. Every compound, every field.
-- ORDER BY Category_Ref, ProductName = sorted first by theatre, then alphabetically.
-- This is how you audit the arsenal — systematic, category by category.

SELECT
    Medication_ID,
    ProductName,
    ActiveIngredient,
    Strength,
    DosageForm_Ref      AS Form,
    PriceINR,
    AUDPerStrip,
    AUDPerPill,
    PillsPerStrip,
    PriceSource,
    CodexDescriptor,
    Category_Ref        AS Category
FROM Medication
ORDER BY Category_Ref, ProductName;
GO


/* --- Codex Summary: arsenal strength by theatre --- */
-- GROUP BY Category_Ref = one row per category.
-- COUNT(*) = how many compounds in each theatre (aliased as Arsenal).
-- MIN(AUDPerPill) = cheapest per-pill cost in each theatre.
-- MAX(AUDPerPill) = most expensive per-pill cost in each theatre.
-- ORDER BY Arsenal DESC = theatres with the most compounds listed first.
-- NULL prices are excluded from MIN/MAX automatically by SQL Server.
-- This is the strategic overview — where the codex is deepest and what it costs.

SELECT
    Category_Ref        AS Category,
    COUNT(*)            AS Arsenal,
    MIN(AUDPerPill)     AS CheapestPerPill,
    MAX(AUDPerPill)     AS PriciestPerPill
FROM Medication
GROUP BY Category_Ref
ORDER BY Arsenal DESC;
GO


/* --- Dosage Form distribution: deployment vectors in use --- */
-- How many compounds use each delivery mechanism.
-- Reveals the codex's preferred vectors. Tablets dominate. Injections follow.

SELECT
    DosageForm_Ref      AS DeliveryVector,
    COUNT(*)            AS CompoundCount
FROM Medication
GROUP BY DosageForm_Ref
ORDER BY CompoundCount DESC;
GO


-- ============================================================
-- END OF SIGMAMEDEX STRATEGIC POTION CODEX
-- Total compounds catalogued: 415
-- Total categories: 30
-- Total dosage forms: 22
-- The codex is loaded. The arsenal is live.
-- ============================================================
