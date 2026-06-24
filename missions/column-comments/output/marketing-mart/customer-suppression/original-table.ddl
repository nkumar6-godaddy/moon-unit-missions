CREATE TABLE customer_suppression (
   customer_id string,
   shopper_id string,
   internal_account_flag boolean,
   private_label_13_suppression_flag boolean comment 'Private Label suppression, the same email address is tied to a Reseller and they have purchased from that Reseller in the last 12 months',
   restricted_country_flag boolean,
   excluded_email_flag boolean,
   competitor_email_flag boolean,
   bad_email_address_format_flag boolean,
   email_address_hard_bounced_flag boolean,
   email_address_soft_bounced_flag boolean,
   etl_build_mst_ts timestamp
);
