import sqlite3
import polars as pl

# Path to your exported CSV
csv_file_path = "/sas/data/project/EG/ActShare/SmallBusiness/aw/data/sb_daily_loss.csv"

# Path to your SQLite database
db_path = "/sas/data/project/EG/ActShare/SmallBusiness/aw/aw.db"

# Read CSV into a Polars DataFrame
df = pl.read_csv(csv_file_path)

# Create SQLite connection and cursor
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# Create table if not exists
create_table_query = """
CREATE TABLE IF NOT EXISTS daily_loss (
    cy INTEGER,
    cm INTEGER,
    claim_numb INTEGER,
    subclaim_numb INTEGER,
    claimant_numb INTEGER,
    seq_numb INTEGER,
    risk_unit INTEGER,
    occur INTEGER,
    bldg_numb INTEGER,
    rpt_date TEXT,
    rpt_loc_numb INTEGER,
    status_chg_date TEXT,
    aia_1_2 TEXT,
    aia_3_4 TEXT,
    aia_5_6 TEXT,
    status_desc TEXT,
    trans_order INTEGER,
    rsv_trans_type TEXT,
    trans_amt FLOAT,
    trans_type TEXT,
    trans_cat TEXT,
    benefit_type_code TEXT,
    pmt_reason_gp_code TEXT,
    pmt_reason_code TEXT,
    pay_type_code TEXT,
    pay_cat_code TEXT,
    pay_status_code TEXT,
    loss_resv FLOAT,
    paid_loss FLOAT,
    lae_resv FLOAT,
    paid_dcce FLOAT,
    paid_aoe FLOAT,
    exp_recovery_resv FLOAT, 
    paid_exp_recovery FLOAT,
    ded_recovery_resv FLOAT,
    paid_ded_recovery FLOAT,
    salvage_resv FLOAT,
    paid_salvage FLOAT,
    subro_resv FLOAT,
    paid_subro FLOAT,
    rr_resv FLOAT,
    reins_company TEXT,
    reins_numb TEXT,
    major_peril TEXT,
    type_bureau TEXT,
    subline_numb TEXT,
    risk_st INTEGER,
    risk_zip INTEGER,
    risk_territory INTEGER,
    agency_full_numb INTEGER,
    agency_st INTEGER,
    accident_st INTEGER,
    cat_start TEXT,
    cat_end TEXT,
    cat_code TEXT,
    cause_of_loss TEXT,
    cat_date TEXT,
    company_numb INTEGER,
    policy_sym TEXT,
    policy_numb INTEGER,
    module INTEGER,
    policy_eff_date TEXT,
    policy_type TEXT,
    producer_code TEXT,
    tier_rate_code TEXT,
    class_code TEXT,
    minor_class TEXT,
    major_class TEXT,
    cfc_class TEXT,
    date_of_loss TEXT,
    uobg INTEGER,
    mrl_detail TEXT,
    asl INTEGER,
    bus_line TEXT,
    bus_seg TEXT,
    uw_line TEXT,
    mrl TEXT,
    mrl_sub_gp TEXT,
    treaty_type TEXT,
    trans_date TEXT,
    source_system TEXT,
    city TEXT,
    county_fips TEXT,
    county TEXT,
    state_abbrev TEXT,
    zip INTEGER,
    loc_unknown TEXT,
    covered_by_treaty TEXT,
    country_code TEXT,
    longitude TEXT,
    latitude TEXT,
    cover_eff_date TEXT,
    cover_exp_date TEXT,
    exposure FLOAT,
    rs_tb_stat_key TEXT,
    policy_stat_bureau_dim_key TEXT,
    dly_prm_fact_key TEXT,
    pmt_numb INTEGER,
    pmt_item_numb INTEGER,
    suit TEXT
);
"""
cursor.execute(create_table_query)
conn.commit()

# Insert data from DataFrame into SQLite
for row in df.iter_rows():
    insert_query = f"""
    INSERT INTO daily_loss (cy,
                            cm,
                            claim_numb,
                            subclaim_numb,
                            claimant_numb,
                            seq_numb,
                            risk_unit,
                            occur,
                            bldg_numb,
                            rpt_date,
                            rpt_loc_numb,
                            status_chg_date,
                            aia_1_2,
                            aia_3_4,
                            aia_5_6,
                            status_desc,
                            
    VALUES (?, ?, ?, ?, ?, ...);
    """
    cursor.execute(insert_query, row)
    conn.commit()

# Close the SQLite connection
conn.close()
