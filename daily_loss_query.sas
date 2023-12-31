/* Macro to format zip codes */
%macro format_zips(col);
INPUT(SUBSTR(&col., 1, 5), 5.)
%mend format_zips;

/* Only include transactions that have occurred since the last update */
%let lastUpdateDate=; /* Set to last updated date */
%let lastUpdatePath=/sas/data/project/EG/ActShare/SmallBusiness/aw/conrols/lastUpdate.txt;
%include "&lastUpdatePath."; /* Read in last updated date */


proc sql;
   create table read_daily_loss as
   select ACCT_YEAR as cy, 
          ACCT_MONTH as cm, 
          CLAIM_NBR as claim_numb, 
          SUBCLAIM_NBR as subclaim_numb, 
          CLAIMANT_NBR as claimant_numb,
          SEQ_NBR as seq_numb,
          RISK_UNIT as risk_unit,
          OCCUR_NBR as occur,
          BLDG_NBR as bldg_numb,
          CLAIM_RPT_DT format date12. as rpt_date,
          CLAIMS_RPT_LOC_NBR as rpt_loc_numb, 
          STATUS_CHG_DT format date12. as status_chg_date,
          AIA_1_2 as aia_1_2,
          AIA_3_4 as aia_3_4,
          AIA_5_6 as aia_5_6,
          STATUS_DESC as status_desc,
          TRS_ORDER as trans_order,
          RSV_TRS_TYPE as rsv_trans_type,
          TRS_AMT as trans_amt,
          TRS_TYPE as trans_type,
          TRS_CAT as trans_cat,
          BNFT_TYPE_CD as benefit_type_code,
          PMT_REA_GRP_CD as pmt_reason_gp_code,
          PMT_REA_CD as pmt_reason_code,
          PAY_TYPE_CD as pay_type_code,
          PAY_CAT_CD as pay_cat_code,
          PAY_STATUS_CD as pay_status_code,
          CHG_IN_LOSS_RSV_AMT as loss_resv,
          LOSS_PMT_AMT as paid_loss,
          CHG_IN_EXP_RSV_AMT as lae_resv,
          DCCE_PMT_AMT as paid_dcce,
          AOE_PMT_AMT as paid_aoe,
          CHG_IN_EXP_RCVR_RSV_AMT as exp_recovery_resv, 
          EXP_RCVR_PMT_AMT as paid_exp_recovery,
          CHG_IN_DED_RCVR_RSV_AMT as ded_recovery_resv,
          DED_RCVR_PMT_AMT as paid_ded_recovery,
          CHG_IN_SVG_RSV_AMT as salvage_resv,
          SVG_PMT_AMT as paid_salvage,
          CHG_IN_SUBRO_RSV_AMT as subro_resv,
          SUBRO_PMT_AMT as paid_subro,
          CHG_IN_RR_RSV_AMT as rr_resv,
          REINS_CO as reins_company,
          REINS_NBR as reins_numb,
          MAJ_PERIL_CD as major_peril,
          BUREAU_TYPE_CD as type_bureau,
          SUBLINE_NBR as subline_numb,
          RISK_ST_NBR as risk_st,
          %format_zips(RISK_ZIP) as risk_zip,
          RISK_TERR_CD as risk_territory,
          AGCY_FULL_NBR as agency_full_numb,
          AGCY_ST_NBR as agency_st,
          ACCIDENT_ST_NBR as accident_st,
          CATASTROPHE_START as cat_start,
          CATASTROPHE_END as cat_end,
          CATASTROPHE_CD as cat_code,
          LOSS_CAUSE_CD as cause_of_loss,
          CATASTROPHE_DT format date12. as cat_date,
          POLICY_CO_NBR as company_numb,
          POLICY_SYM as policy_sym,
          POLICY_NBR as policy_numb,
          POLICY_MODULE as module,
          POLICY_EFF_DT format date12. as policy_eff_date,
          POLICY_TYPE_CD as policy_type,
          PRODUCER_CD as producer_code,
          TIER_RATE_CD as tier_rate_code,
          CLS_CD as class_code,
          MINOR_CLS as minor_class,
          MAJOR_CLS as major_class,
          CFC_CLS_CD as cfc_class,
          LOSS_DT format date12. as date_of_loss,
          UOB_GRP_ID as uobg,
          MRL_DETAIL_ID as mrl_detail,
          ANNUAL_STMNT_LINE as asl,
          BUS_LINE as bus_line,
          BUS_SEG as bus_seg,
          UW_LINE as uw_line,
          MRL as mrl,
          MRL_SUB_GRP as mrl_sub_gp,
          REINS_TREATY_TYPE_DESC as treaty_type,
          LOSS_TRANS_DT format date12. as trans_date,
          SRC_SYSTEM_CD as source_system,
          LOSS_LOC_CITY_NM as city,
          LOSS_LOC_FIPS_COUNTY_CD as county_fips,
          LOSS_LOC_COUNTY_NM as county,
          LOSS_LOC_STATE_CD as state_abbrev,
          %format_zips(LOSS_LOC_ZIP_CD) as zip,
          LOSS_LOC_LOCATION_UNKNOWN_FLAG as loc_unknown, 
          LOSS_LOC_CAT_TREATY_FLAG as covered_by_treaty,
          LOSS_LOC_COUNTRY_CODE as country_code,
          LOSS_LOC_LONGITUDE as longitude,
          LOSS_LOC_LATITUDE as latitude,
          COVER_EFF_DATE format date12. as cover_eff_date,
          COVER_EXP_DATE format date12. as cover_exp_date,
          EXPOSURE as exposure,
          RS_TB_STAT_KEY as rs_tb_stat_key,
          POLICY_STAT_BUREAU_DIM_KEY as policy_stat_bureau_dim_key,
          DLY_PRM_FACT_KEY as dly_prm_fact_key,
          PMT_NBR as pmt_numb,
          PMT_ITEM_NBR as pmt_item_numb,
          SUIT as suit
      from 
        dlf.vmonthly_snapshot_loss_txn
      where 
        POLICY_SYM in ('SBA', 'SBB','SBW','SBU')
        and LOSS_TRANS_DT ge "&lastUpdateDate."
;
quit;

/* Export to CSV */
proc export data=read_daily_loss 
    outfile="/sas/data/project/EG/ActShare/SmallBusiness/aw/daily_loss.csv" 
    dbms=csv append;
run;


data _null_;
  file "&lastUpdatePath.";
  put "%let lastUpdateDate = '" date9. +(-1) "';";  /* Writes yesterday's date */
run;