# Application Configuration (APP_CONFIG)

Home: [README](../README.md) · **Docs** · **Application Configuration**

`APP_CONFIG` is the runtime configuration store for the application. The goal is simple:
**the same bundle should run in different environments with only configuration changes**.

This document is a reference for all keys found in `APP_CONFIG`.

---

## How to use this reference
- Keys are **case-sensitive** in the sense that the application expects specific key names.
- Values are stored as **strings**. Some values are interpreted as:
  - booleans (`Y`/`N`)
  - numbers
  - JSON payloads (must be valid JSON)
  - comma-separated lists
- When changing configuration, prefer using the in-app admin pages so changes are logged and validated.

### Recommended change process
1. Change one key at a time.
2. Validate the relevant dashboard/job behavior.
3. Keep a small record of “why” for non-obvious changes (ticket / change request reference).

---

## Non-Modifiable Configuration Keys

Structural and system-owned keys. These must not be modified during normal operation.

| CONFIG_KEY | Default Value | Purpose | Usage | Notes |
| --- | --- | --- | --- | --- |
| AVAILABILITY_DAYS_BACK | 7 | Lookback window for availability metrics. | Constrains availability ingestion and reporting time range. | Affects data volume and processing time. |
| AVAILABILITY_METRICS_TABLE | OCI_AVAILABILITY_METRICS_PY | Target table for persisted availability metrics. | Written by availability jobs; read by dashboards and reports. | Table must exist and match expected schema. |
| AVAILABILITY_METRIC_GROUPS_JSON | [   {     "namespace":"oci_computeagent",     "resource_group":null,     "metrics":["CpuUtilization","MemoryUtilization"],     "resource_display_keys":["resourceDisplayName","instanceId"]   } ] | JSON definition of availability metric groupings. | Drives metric grouping/aggregation in dashboards and queries. | Must be valid JSON. |
| AVAILABILITY_QUERY_SUFFIX | .mean() | Optional SQL suffix applied to availability queries. | Appended to generated availability SQL for advanced filtering/extensions. | -- |
| AVAILABILITY_RESOLUTION | 1h | Aggregation granularity for availability metrics. | Controls hourly vs daily rollups in availability processing. | Higher resolution increases data volume. |
| COMPARTMENTS_TABLE | OCI_COMPARTMENTS_PY | Database table storing discovered OCI compartments. | Populated by discovery jobs; referenced by dashboards, filters, and chatbot context. | Do not modify manually. |
| CREDENTIAL_NAME | OCI$RESOURCE_PRINCIPAL | Legacy DBMS_CLOUD credential name reference. | Used only in credential-based deployments; ignored with Resource Principal. | Must not contain secrets. |
| CSV_FIELD_LIST | AVAILABILITYZONE CHAR(4000), BILLEDCOST DECIMAL(38,12), BILLINGACCOUNTID INTEGER, BILLINGACCOUNTNAME VARCHAR(32767), BILLINGCURRENCY CHAR(4000), BILLINGPERIODEND VARCHAR(64), BILLINGPERIODSTART VARCHAR(64), CHARGECATEGORY CHAR(4000), CHARGEDESCRIPTION CHAR(4000), CHARGEFREQUENCY VARCHAR(32767), CHARGEPERIODEND VARCHAR(64), CHARGEPERIODSTART VARCHAR(64), CHARGESUBCATEGORY VARCHAR(32767), COMMITMENTDISCOUNTCATEGORY VARCHAR(32767), COMMITMENTDISCOUNTID VARCHAR(32767), COMMITMENTDISCOUNTNAME VARCHAR(32767), COMMITMENTDISCOUNTTYPE VARCHAR(32767), EFFECTIVECOST DECIMAL(38,12), INVOICEISSUER CHAR(4000), LISTCOST DECIMAL(38,12), LISTUNITPRICE DECIMAL(38,12), PRICINGCATEGORY VARCHAR(32767), PRICINGQUANTITY DECIMAL(38,12), PRICINGUNIT CHAR(4000), PROVIDER CHAR(4000), PUBLISHER CHAR(4000), REGION CHAR(4000), RESOURCEID CHAR(4000), RESOURCENAME VARCHAR(32767), RESOURCETYPE CHAR(4000), SERVICECATEGORY CHAR(4000), SERVICENAME CHAR(4000), SKUID CHAR(4000), SKUPRICEID VARCHAR(32767), SUBACCOUNTID CHAR(4000), SUBACCOUNTNAME CHAR(4000), TAGS VARCHAR(32767), USAGEQUANTITY DECIMAL(38,12), USAGEUNIT CHAR(4000), OCI_REFERENCENUMBER CHAR(4000), OCI_COMPARTMENTID CHAR(4000), OCI_COMPARTMENTNAME CHAR(4000), OCI_OVERAGEFLAG CHAR(4000), OCI_UNITPRICEOVERAGE VARCHAR(32767), OCI_BILLEDQUANTITYOVERAGE VARCHAR(32767), OCI_COSTOVERAGE VARCHAR(32767), OCI_ATTRIBUTEDUSAGE DECIMAL(38,12), OCI_ATTRIBUTEDCOST DECIMAL(38,12), OCI_BACKREFERENCENUMBER CHAR(4000) | Ordered list of fields used for CSV generation. | Controls column order during CSV export/import pipelines. | Must align with stage/target table structures. |
| DAYS_BACK | 1 | Default historical window for cost and usage processing. | Constrains cost ingestion time range and processing volume. | Larger values increase runtime and data volume. |
| EXA_MAINTENANCE_METRICS_TABLE | OCI_EXA_MAINTENANCE_PY | Target table for Exadata maintenance metrics. | Used by maintenance/availability monitoring logic. | Table must exist if feature is enabled. |
| FILE_SUFFIX | .csv.gz | File extension used for generated files. | Applied when creating export or staging files. | -- |
| FILTER_BY_CREATED_SINCE | Y | Toggle to filter resources by creation date. | Applied during resource selection to limit analysis scope. | Values: true/false. |
| KEY_COLUMN | OCI_REFERENCENUMBER | Primary identifier column used during merges/joins. | Used as join key between stage/target/resources/relationships as applicable. | Must exist in the referenced tables. |
| POST_PROCS | [   "PAGE1_CONS_WRKLD_MONTH_CHART_DATA_PROC",   "PAGE1_CONS_WRKLD_WEEK_CHART_DATA_PROC",   "COST_USAGE_TS_PKG.REFRESH_COST_USAGE_TS",   "REFRESH_CREDIT_USAGE_AGG_PROC",   "REFRESH_CREDIT_CONSUMPTION_STATE_PROC",   "DBMS_MVIEW.REFRESH('FILTER_VALUES_MV', METHOD => 'C')"] | List of post-processing procdures/functions/mviews after cost data load | Executed after successful cost data load | Must be valid JSON. Objects must exist |
| POST_SUBS_PROC_1 | UPDATE_OCI_SUBSCRIPTION_DETAILS | First post-processing procedure after subscription ingestion. | Executed after subscription ingestion to normalize/enrich data. | Procedure must exist and be executable. |
| POST_SUBS_PROC_2 | REFRESH_CREDIT_CONSUMPTION_STATE_PROC | Second post-processing procedure after subscription ingestion. | Executed after POST_SUBS_PROC_1 if configured. | Procedure must exist and be executable. |
| PREFIX_BASE | FOCUS Reports | Base prefix used for object naming in Object Storage. | Default as per Oracle documentation: *https://docs.oracle.com/en-us/iaas/Content/Billing/Concepts/costusagereportsoverview.htm#costreports* | -- |
| PREFIX_FILE | -- | Additional per-file prefix component. | Used to distinguish file types or processing stages. | Combined with PREFIX_BASE and FILE_SUFFIX. |
| RESOURCES_TABLE | OCI_RESOURCES_PY | Target table for discovered OCI resources. | Written by discovery jobs; read by dashboards/reports/chatbot. | Schema must align with discovery procedures. |
| RESOURCE_OKE_RELATIONSHIPS_PROC | POPULATE_OKE_RELATIONSHIPS_PROC | Procedure building OKE-specific resource relationships. | Links OKE clusters, node pools, nodes, and related resources. | Optional if OKE is not used. |
| RESOURCE_RELATIONSHIPS_PROC | POPULATE_RESOURCE_RELATIONSHIPS_PROC | Procedure building generic resource-to-resource relationships. | Builds parent-child and dependency relationships. | Should be idempotent for safe re-execution. |
| STAGE_TABLE | FOCUS_REPORTS_STAGE | Staging table used during file-based processing. | Receives transient intermediate data prior to final load. | Data is transient by design. |
| SUBSCRIPTIONS_TARGET_TABLE | OCI_SUBSCRIPTIONS_PY | Target table for processed subscription data. | Written by subscription ingestion jobs; used for reporting. | Schema must match ingestion logic. |
| SUBSCRIPTION_COMMIT_TARGET_TABLE | OCI_SUBSCRIPTION_COMMITMENTS | Target table for subscription commitment data. | Stores committed amounts/usage for commitment analytics. | Schema must match ingestion logic. |
| TARGET_TABLE | FOCUS_REPORTS_PY | Final target table for processed data. | Receives validated and transformed data from pipelines. | Schema must match load/merge logic. |
| USE_DYNAMIC_PREFIX | Y | Toggle for dynamic prefix generation. | Enables/disables context-based (e.g., time-based) naming to avoid collisions. | Values: true/false. |

---

## Modifiable Configuration Keys

Operational keys that administrators can modify through the application UI.

| CONFIG_KEY | Purpose | Usage | Notes (examples) |
| --- | --- | --- | --- |
| ADB_COMPUTE_COUNT_DOWN | Minimum compute value for Autonomous Database scaling. | Used by scaling logic to reduce compute allocation. | Integer value (2). |
| ADB_COMPUTE_COUNT_UP | Maximum compute value for Autonomous Database scaling. | Used by scaling logic to increase compute allocation. | Integer value (8). |
| ADB_OCID | OCID of the Autonomous Database. | Used for scheduled OCPU scaling. | OCID format (ocid1.autonomousdatabase.oc1.eu-frankfurt-1.....). |
| AVAILABILITY_REGIONS | Subscribed regions in tenancy. | Used to discover cost/resources across tenancy's subscribed regions. |  Comma-separated list (eu-frankfurt-1,eu-amsterdam-1). |
| COMPARTMENTS_PATH_PREFIX_CHILD1 | Logical path prefix for compartment hierarchy of child tenancies in a multi-org OCI tenancy. | Used to distinguish tenancy's root and other compartments from children tenancies. | Organization-specific convention (myothertenancy). |
| COMPARTMENT_ID | Application's compartment OCID. | Typically this is ADB's compartment OCID. | Must be an OCID (ocid1.compartment.oc1....). |
| COST_TAG_COSTCENTER_KEY | Tag key used to extract cost center value. | Used when parsing OCI tags JSON to derive cost center. Usually a tag that would define a workload/application | Must of format: tag-namespace.tag-key (Oracle-Standard.CostCenter). |
| COST_TAG_CREATED_BY_KEY | Tag key used to extract created-by value. | Used when parsing OCI tags JSON to derive creator. | Must of format: tag-namespace.tag-key (Oracle-Tags.CreatedBy). |
| COST_TAG_ENVIRONMENT_KEY | Tag key used to extract environment label. | Used when parsing OCI tags JSON to derive environment label. | Must of format: tag-namespace.tag-key (Oracle-Standard.Environment). |
| COST_TAG_IMPLEMENTOR_KEY | Tag key used to extract implementor value. | Used when parsing OCI tags JSON to derive implementor. | Must of format: tag-namespace.tag-key (Oracle-Standard.Implementor). |
| FC_ADB_REGION | OCI region of the application's ADB placement. | Used for region-aware OCI endpoint selection. | Example: (eu-frankfurt-1). |
| OBJECT_BASE_URI | Base URI for OCI Object Storage FOCUS REPORTS access. | Used by DBMS_CLOUD when retrieving FOCUS reports objects of the tenancy. The URL is constructed in two parts -> Fixed part: https://objectstorage.eu-frankfurt-1.oraclecloud.com/n/bling/b/ Tenant specific part: ocid1.tenancy.oc1..../o/ .  | Tenant specific (https://objectstorage.eu-frankfurt-1.oraclecloud.com/n/bling/b/ocid1.tenancy.oc1...../o/). |
| OCI_HOME_REGION | Tenancy home region. | Used for tenancy-level and global OCI interactions. | May differ from FC_ADB_REGION (eu-frankfurt-1). |
| OCI_ROOT_CHILD1_COMPARTMENT_OCID | Primary child tenancy OCID. | In a multi-org tenancy, this would be the 1st child. If more need to be added, manual APP_CONFIG addtions and Scheduled jobs have to be added | OCID format (ocid1.tenancy.oc1..). |
| OCI_ROOT_COMPARTMENT_OCID | Tenancy root compartment OCID. | Used for compartment discovery and tenancy-wide scope operations. | OCID format (ocid1.tenancy.oc1..). |
| OIDC_DISCOVERY_URL | OIDC discovery endpoint used for authentication configuration. | Consumed by authentication flow to resolve OIDC metadata. | Only used when APEX is configured for External Authentication (OCI IAM Domains example: https://idcs-....identity.oraclecloud.com:443/.well-known/openid-configuration). |
| P2_COMPARTMENT_ID | Same as COMPARTMENT_ID. | Same as COMPARTMENT_ID. | Must be an OCID (ocid1.compartment.oc1....). |
| l_auth_scheme_name | Name of the Oracle APEX authentication scheme. | Used to select the authentication mechanism used by the application. | Must match an existing APEX authentication scheme name. Usually "Oracle APEX Accounts" or Application's default "OCI SSO" (OCI SSO)|
| model_id | Generative AI model identifier used by the chatbot. | Passed to the AI execution layer for interpretation and summarization. | Must be an OCID of the OCI's GenAI model chosen and must be available/enabled for the tenancy/region (ocid1.generativeaimodel.oc1.eu-frankfurt-1.amaaaaaask7dceyaaypm2hg4db3evqkmjfdli5mggcxrhp2i4qmhvggyb4ja). |
