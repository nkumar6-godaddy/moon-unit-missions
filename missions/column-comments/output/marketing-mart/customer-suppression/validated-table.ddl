CREATE TABLE customer_suppression (
   customer_id string comment '@ForeignKey(customer360.dim_customer_vw) GoDaddy customer identifier (UUID) in ShopperUniverse. Alternative key; shopper_id is the primary key of this table.',
   shopper_id string comment '@PrimaryKey GoDaddy shopper account identifier. Numeric values represent standard external shopper accounts; non-numeric (3-character) values indicate internal GoDaddy accounts.',
   internal_account_flag boolean comment 'TRUE if the shopper is a GoDaddy internal account, including 3-letter employee accounts (non-numeric shopper_id) and accounts in the internal shopper registry. Suppressed from marketing.',
   private_label_13_suppression_flag boolean comment 'Private Label suppression: the shopper email is tied to a Reseller who the shopper purchased from in the last 12 months. Suppresses direct GoDaddy marketing to protect the reseller relationship.',
   restricted_country_flag boolean comment 'TRUE if the shopper country or country-region is on eComm blocked-country or blocked-country-region lists. Consolidates country-level and country-region-level suppression checks.',
   excluded_email_flag boolean comment 'TRUE if the shopper email address has been explicitly excluded or cancelled in the FortKnox email attributes system. Corresponds to the legacy IsCancelledEmail suppression flag.',
   competitor_email_flag boolean comment 'TRUE if the shopper email address belongs to a known competitor domain, as flagged in the FortKnox email attributes system. Corresponds to the legacy IsCompetitorEmail suppression flag.',
   bad_email_address_format_flag boolean comment 'TRUE if the shopper email address fails standard format validation, as flagged in the FortKnox email attributes system. Inverted form of the legacy IsValidEmailAddress flag.',
   email_address_hard_bounced_flag boolean comment 'TRUE if the shopper email address has experienced a hard bounce (permanent delivery failure), as recorded in the FortKnox email attributes system and corroborated by marketing bounce system events.',
   email_address_soft_bounced_flag boolean comment 'TRUE if the shopper email address has been flagged as soft-bounced (temporary delivery failure) in the FortKnox email attributes system, corroborated by marketing bounce system and email platform events.',
   etl_build_mst_ts timestamp comment 'Timestamp (Mountain Standard Time) recording when this row was last built by the ETL pipeline. Used for data freshness auditing and SLA monitoring per the marketing_mart.customer_suppression SLO.'
);
