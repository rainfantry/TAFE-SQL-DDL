# TAFE-SQL-DDL
Template .sql files to create a fictional Pharmacy DATABASE and populate tables with INSERT (No BULK INSERT csv handling)

# SigmaMedex

A medication catalogue database built in SQL Server as a TAFE assessment project. 415 pharmaceutical compounds across 30 categories and 22 dosage forms, with INR-to-AUD price conversions, active ingredients, and mechanism-of-action descriptors.

**Assessment:** ICTDBS416 (Build a Database) + ICTPRG431 (Apply Query Language)
**Platform:** Microsoft SQL Server / SSMS

## What It Does

The script builds a complete relational database from scratch in 4 phases:

1. **CREATE** the `SigmaMedex` database (drops and rebuilds if it exists)
1. **CREATE** 3 tables with constraints, keys, and foreign key relationships
1. **INSERT** 467 rows of data (30 categories + 22 dosage forms + 415 medications)
1. **QUERY** the data with verification, full manifest, and summary analytics

## Database Schema

```plaintext
MedicationCategory (30 rows)
├── CategoryName  NVARCHAR(60)  PK
│
DosageForm (22 rows)
├── FormName  NVARCHAR(30)  PK
│
Medication (415 rows)
├── Medication_ID       INT IDENTITY(1,1)  PK
├── ProductName         NVARCHAR(120)  NOT NULL
├── ActiveIngredient    NVARCHAR(120)
├── Strength            NVARCHAR(30)
├── PriceINR            NVARCHAR(30)
├── AUDPerStrip         DECIMAL(8,2)
├── AUDPerPill          DECIMAL(8,2)
├── PillsPerStrip       NVARCHAR(10)
├── PriceSource         NVARCHAR(20)
├── CodexDescriptor     NVARCHAR(200)  NOT NULL
├── Category_Ref        NVARCHAR(60)   NOT NULL  FK → MedicationCategory
└── DosageForm_Ref      NVARCHAR(30)             FK → DosageForm
```

Parent tables (`MedicationCategory`, `DosageForm`) are created and populated first. The child table (`Medication`) references both via foreign keys. This order is enforced by referential integrity — you cannot insert a medication with a category that doesn't exist.

## SQL Concepts Demonstrated

### DDL (Data Definition Language)

- `CREATE DATABASE` with conditional drop (`IF EXISTS` + `SINGLE_USER` + `ROLLBACK IMMEDIATE`)
- `CREATE TABLE` with typed columns (`INT`, `NVARCHAR`, `DECIMAL`)
- `IDENTITY(1,1)` auto-incrementing primary keys
- Named constraints (`CONSTRAINT TableName_PK PRIMARY KEY`)
- Foreign key relationships (`REFERENCES ParentTable(Column)`)
- `NOT NULL` enforcement on required fields
- `GO` batch separators for SSMS execution order

### DML (Data Manipulation Language)

- 467 `INSERT INTO` statements with explicit column lists
- Unicode string literals (`N'...'` prefix for `NVARCHAR`)
- `NULL` handling for missing data (no fabricated values)
- `SELECT` with column aliasing (`AS`)
- `COUNT(*)`, `MIN()`, `MAX()` aggregate functions
- `GROUP BY` with `ORDER BY` for summary analytics
- `UNION ALL` for multi-table row counts in a single result set

### Design Decisions

- **Natural keys** on lookup tables (`CategoryName`, `FormName`) instead of surrogate IDs — the category name *is* the identifier, no join needed to read it
- **NVARCHAR over VARCHAR** — supports Unicode characters for international drug names
- **Raw INR price preserved** as a string (`PriceINR`) alongside calculated `DECIMAL` AUD conversions — audit trail for the source data
- **PillsPerStrip as NVARCHAR** — some values are approximate (`~10`) or descriptive (`1 vial`, `1 kit`), so a numeric type would lose information
- **PriceSource reliability tag** — classifies each price as `Confirmed quote`, `INR converted`, or `No price listed`

## Categories

Anti Allergic, Anti Anxiety & Anti Depressants, Anti Cancer, Anti Diabetic, Anti Fungal, Anti HIV, Anti Malarial, Anti Migraine, Anti Viral, Antibiotic, Asthma, Cardiovascular, Erectile Dysfunction, Eye Care, Female Healthcare, Hair Loss, Hepatitis, Hypertension, Infertility, Ivermectin, Modafinil, Pain Killer, Pharmaceutical, Pharmaceutical Injection, Pharmaceutical Tablets, Pregabalin, Skin Care, Steroid, Veterinary, Weight Loss.

## Dosage Forms

Capsule, Chewable Tablet, Cream, Dispersible Tablet, Eye Drops, Gel, Inhaler, Injection, Injection Pen, Kit, Lotion, Ointment, Oral Jelly, Respules, Soft Gel Capsule, Soft Gelatin Capsule, Solution, Spray, Syrup, Tablet, Tablet (Extended Release), Topical.

## Usage

Open `SigmaMedex_Codex.sql` in SSMS and execute. The script is idempotent — it drops and rebuilds everything on each run. No manual setup required.

## What I Learned

- **Table creation order matters.** Foreign keys can only reference tables that already exist. Parent tables first, child tables after. Same rule applies to inserts.
- **Firewall rules for data types.** Choosing `NVARCHAR(120)` vs `DECIMAL(8,2)` vs `INT` is a constraint decision — it determines what the database will accept and reject. Get it wrong and you lose data or let garbage in.
- **Natural keys have tradeoffs.** Using `CategoryName` as the PK means no join is needed to display it, but renaming a category means updating every row that references it. For a catalogue this size, the readability won.
- **NULL is not zero.** `NULL` means "unknown" — aggregate functions like `MIN()` and `MAX()` skip it automatically. A medication with no price is not a free medication.
- **IDENTITY columns are hands-off.** You omit them from INSERT statements entirely. SQL Server assigns the value. Trying to set it manually requires `SET IDENTITY_INSERT ON`.
- **GO is not SQL.** It's an SSMS batch separator. The server never sees it. Without it, `USE SigmaMedex` might execute before `CREATE DATABASE SigmaMedex` finishes.
- **Unicode prefix matters.** `N'string'` for NVARCHAR columns. Without the `N`, SQL Server may silently convert characters and lose data for non-ASCII input.

## License

MIT
