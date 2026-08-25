# 💳 Payment Reconciliation & Transaction Analytics

> An end-to-end payment analytics project built to investigate transaction failures, gateway performance, settlement completion, and reconciliation issues using SQL and BigQuery.

![Python](https://img.shields.io/badge/Python-3.11-blue?logo=python&logoColor=white)
![Pandas](https://img.shields.io/badge/Pandas-Data%20Processing-150458?logo=pandas&logoColor=white)
![NumPy](https://img.shields.io/badge/NumPy-Analysis-013243?logo=numpy&logoColor=white)
![Google BigQuery](https://img.shields.io/badge/Google%20BigQuery-Data%20Warehouse-4285F4?logo=googlebigquery&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-Analytics-336791?logo=postgresql&logoColor=white)
![Power BI](https://img.shields.io/badge/Power%20BI-Visualization-F2C811?logo=powerbi&logoColor=black)
![Looker Studio](https://img.shields.io/badge/Looker%20Studio-Reporting-4285F4?logo=google&logoColor=white)
![Google Sheets](https://img.shields.io/badge/Google%20Sheets-Data-34A853?logo=googlesheets&logoColor=white)
![GitHub](https://img.shields.io/badge/GitHub-Version%20Control-181717?logo=github&logoColor=white)
![ChatGPT](https://img.shields.io/badge/AI-ChatGPT-412991?logo=openai&logoColor=white)
![Claude](https://img.shields.io/badge/AI-Claude-D97757?logo=anthropic&logoColor=white)

---

# 📌 Project Overview

Payment platforms process large volumes of transactions across multiple gateways, users, merchants, and settlement systems.

Even when the overall payment success rate appears healthy, small operational issues can create significant financial and customer-impacting problems.

This project simulates a real-world payment operations environment and uses **BigQuery + SQL** to investigate:

- Payment success and failure rates
- Gateway performance
- Payment failure reasons
- Transaction response times
- Settlement completion
- Missing settlements
- Transaction-to-settlement mismatches
- Duplicate transactions
- Settlement delays
- Payment value at risk

The goal is not only to report metrics, but to answer the more important business question:

> **Why are payment and settlement issues happening, where are they happening, and what should the Payments/Finance/Product teams investigate?**

---

# 🎯 Business Problem

Payment operations teams need continuous visibility into the complete payment lifecycle:

```text
User
  │
  ▼
Transaction Initiated
  │
  ▼
Payment Gateway
  │
  ├── Successful Payment
  │
  └── Failed Payment
          │
          ▼
      Failure Reason
  │
  ▼
Settlement Process
  │
  ├── Settled
  │
  ├── Missing Settlement
  │
  ├── Delayed Settlement
  │
  └── Amount Mismatch
```

Without proper reconciliation and monitoring, payment teams may face:

- Failed transactions
- Lost or delayed settlements
- Incorrect settlement amounts
- Gateway reliability issues
- Revenue leakage
- Manual reconciliation effort
- Customer payment failures
- Difficulty identifying operational bottlenecks

This project was designed to reproduce these problems using realistic synthetic payment data and solve them through SQL-driven analysis.

---

# 📊 Dataset

The project uses a **3-year synthetic payment dataset** designed to represent a large-scale fintech/payment environment.

### Dataset Summary

| Entity | Records |
|---|---:|
| Merchants | 1,500 |
| Users | 60,000 |
| Transactions | 1,004,848 |
| Settlements | 962,702 |
| Overall Payment Success Rate | 96.97% |

The dataset contains approximately **1 million payment transactions** across multiple gateways and payment methods.

---

# 🗂️ Data Model

The project uses four main tables.

### 1. Merchants

Contains merchant-level information.

| Column | Description |
|---|---|
| `merchant_id` | Unique merchant identifier |
| `merchant_name` | Merchant name |
| `merchant_category` | Business/merchant category |
| `city` | Merchant location |

---

### 2. Users

Contains customer-level information.

| Column | Description |
|---|---|
| `user_id` | Unique user identifier |
| `age_group` | User age segment |
| `city` | User location |

---

### 3. Transactions

Contains payment transaction-level information.

| Column | Description |
|---|---|
| `transaction_id` | Unique transaction identifier |
| `user_id` | Customer identifier |
| `merchant_id` | Merchant identifier |
| `gateway` | Payment gateway |
| `payment_method` | Payment method |
| `transaction_timestamp` | Transaction timestamp |
| `amount` | Transaction amount |
| `response_time_ms` | Gateway response time |
| `status` | Transaction status |
| `failure_reason` | Reason for failed payment |

---

### 4. Settlements

Contains settlement-level information linked to transactions.

| Column | Description |
|---|---|
| `settlement_id` | Unique settlement identifier |
| `transaction_id` | Related transaction identifier |
| `date` | Settlement date |
| `amount` | Settlement amount |
| `status` | Settlement status |

---

# 🧹 Data Cleaning & Quality Engineering

The raw datasets were first loaded into **Google BigQuery** and validated before analysis.

The cleaning process included:

- Data type validation
- Timestamp conversion
- Amount conversion to `NUMERIC`
- Date conversion
- Text standardization
- Whitespace removal
- Status standardization
- NULL handling
- Invalid record filtering
- Duplicate detection
- Duplicate removal
- ID format validation
- Structural validation

Cleaned tables were generated from the raw tables using SQL.

Example:

```sql
CREATE OR REPLACE TABLE
`finance-ad-hoc.payment_analytics.transactions_clean`
AS
SELECT ...
FROM `finance-ad-hoc.payment_analytics.raw_transactions`;
```

The raw tables were retained separately so that the cleaning process remained traceable and reproducible.

---

# 🏗️ Data Engineering Workflow

```text
Synthetic Data Generation
          │
          ▼
       CSV Files
          │
          ▼
      BigQuery
          │
          ▼
      Raw Tables
          │
          ▼
   Data Quality Checks
          │
          ▼
    SQL Data Cleaning
          │
          ▼
     Clean Tables
          │
          ▼
   Exploratory Analysis
          │
          ▼
 Payment Performance Analysis
          │
          ▼
 Settlement Reconciliation
          │
          ▼
 Business Insights
          │
          ▼
 Dashboard / Reporting
```

---

# 🔎 SQL Data Analysis

The analysis was designed around real-world payment operations questions rather than only descriptive statistics.

The main analysis areas included:

### Payment Performance

- What is the overall payment success rate?
- What is the failure rate?
- How much transaction value is associated with successful and failed payments?
- Are failures concentrated on specific dates?

### Gateway Performance

- Which gateway processes the highest transaction volume?
- Which gateway has the highest success rate?
- Which gateway has the highest average response time?
- What is the P95 response time for each gateway?
- Does gateway response time correlate with payment failures?

### Failure Analysis

- What are the most common payment failure reasons?
- Which failure reason contributes the most failed transactions?
- Which failure reason represents the highest failed transaction value?
- Are timeout or gateway errors significant operational problems?

### Settlement Analysis

- What percentage of successful transactions are settled?
- How many settlements are missing?
- How many transactions have settlement mismatches?
- How many settlements are delayed?
- What is the settlement completion rate?

### Reconciliation

- Does every successful transaction have a corresponding settlement?
- Does the transaction amount match the settlement amount?
- Which transactions require reconciliation?
- How much transaction value is potentially affected by reconciliation issues?

---

# 📈 Key Findings

## 💰 Overall Payment Performance

The dataset contains:

- **1,004,848 transactions**
- **974,427 successful transactions**
- **96.97% overall success rate**
- Approximately **₹608.16M total transaction value**
- Approximately **₹589.82M successful transaction value**

This provides a strong baseline for monitoring payment reliability.

---

# 🚨 Payment Failure Analysis

The major failure reasons identified were:

| Failure Reason | Failed Transactions | % of Failures | Failed Value |
|---|---:|---:|---:|
| TIMEOUT | 7,789 | 29.40% | ₹4.79M |
| INSUFFICIENT_BALANCE | 6,770 | 25.56% | ₹4.06M |
| BANK_DECLINE | 5,386 | 20.33% | ₹3.21M |
| GATEWAY_ERROR | 3,969 | 14.98% | ₹2.43M |
| AUTH_FAILURE | 2,577 | 9.73% | ₹1.51M |

### Key Insight

**TIMEOUT is the largest failure category, accounting for 29.4% of failed transactions.**

This makes gateway response performance an important operational area to investigate.

---

# ⚡ Gateway Performance

| Gateway | Transactions | Success Rate | Avg Response Time | P95 Response Time |
|---|---:|---:|---:|---:|
| Gateway_A | 452,546 | 97.01% | 701.18 ms | 1,665.60 ms |
| Gateway_B | 351,789 | 96.92% | 700.45 ms | 1,659.20 ms |
| Gateway_C | 200,513 | 96.97% | 698.83 ms | 1,656.90 ms |

Gateway A processes the highest transaction volume and has the highest observed success rate.

However, gateway-level differences in average response time are relatively small, so response latency should be analyzed together with failure categories rather than treated as the sole driver of payment failures.

---

# 🧩 Response Time Analysis

Transactions were segmented into response-time buckets:

- `<500ms`
- `500–1000ms`
- `1000–2000ms`
- `2000ms+`

The analysis compares success rates across these response-time ranges and gateways.

This helps determine whether slower gateway responses are associated with higher payment failure rates.

The analysis showed that the relationship between response latency and success rate is **not strong enough to conclude that slower response time alone drives failures**.

This is an important business insight because it prevents the team from incorrectly attributing all failures to gateway latency.

---

# 💸 Settlement Performance

The settlement analysis identified:

| Metric | Result |
|---|---:|
| Successful Transactions | 974,427 |
| Settled Transactions | 962,702 |
| Missing Settlements | 11,725 |
| Settlement Completion Rate | 98.80% |

### Key Insight

Although the payment success rate is **96.97%**, settlement completion is **98.80%** against successful transactions.

The **11,725 missing settlements** represent an important reconciliation queue that Finance/Payments teams should investigate.

---

# 🔄 Reconciliation Analysis

The project also investigates transaction-to-settlement reconciliation.

The reconciliation logic checks:

```text
Successful Transaction
        │
        ▼
Find Matching Settlement
        │
        ├── Settlement Found
        │       │
        │       ▼
        │   Compare Amount
        │       │
        │       ├── Match
        │       └── Mismatch
        │
        └── Settlement Missing
```

This allows the project to identify:

- Missing settlements
- Amount mismatches
- Duplicate settlement records
- Delayed settlements
- Transactions requiring manual investigation

These outputs can be used to create a reconciliation exception report.

---

# 📊 Business Questions Answered

The project focuses on answering questions that would be relevant to a Payments, Finance, or Product Analytics team:

### Payment Reliability

> What percentage of transactions are successful?

### Gateway Monitoring

> Which gateway processes the most transactions and how does its performance compare with others?

### Failure Investigation

> What are the biggest causes of payment failures?

### Operational Risk

> How much transaction value is associated with failed payments?

### Latency Investigation

> Does slower gateway response correlate with payment failures?

### Settlement Monitoring

> How many successful transactions are missing settlements?

### Reconciliation

> Which transactions have settlement amount mismatches?

### Exception Management

> Which payment and settlement records require investigation?

---

# 🧠 Business Impact

The project converts raw transaction data into actionable operational insights.

Key findings include:

- **96.97% overall payment success rate**
- **29.4% of payment failures attributed to TIMEOUT**
- **11,725 missing settlements identified**
- **98.8% settlement completion rate**
- **₹608M+ total transaction value analyzed**
- **1M+ transactions analyzed using SQL**

These metrics provide a foundation for payment monitoring, gateway optimization, settlement reconciliation, and operational reporting.

---

# 🛠️ Technology Stack

### Database & Analytics

- Google BigQuery
- SQL

### Programming & Data Generation

- Python
- Pandas
- NumPy

### Data Visualization

- Power BI
- Looker Studio
- Google Sheets

### Version Control

- GitHub
- Git

### AI-Assisted Development

- ChatGPT
- Claude

AI tools were used to support:

- SQL development
- Debugging
- Data-quality investigation
- Query optimization
- Documentation
- Analytical exploration
- Project development

All analytical outputs were validated against the underlying dataset and SQL results.

---

# 📚 SQL Techniques Used

The project demonstrates practical SQL techniques including:

- `SELECT`
- `WHERE`
- `CASE`
- `COALESCE`
- `SAFE_CAST`
- `CAST`
- `TRIM`
- `UPPER`
- `REGEXP_CONTAINS`
- `COUNT`
- `SUM`
- `AVG`
- `MIN`
- `MAX`
- `GROUP BY`
- `ORDER BY`
- `HAVING`
- `JOIN`
- `LEFT JOIN`
- `UNION ALL`
- Common Table Expressions (`CTEs`)
- Window Functions
- `ROW_NUMBER()`
- `QUALIFY`
- Date functions
- Conditional aggregation
- Percentage calculations
- P95 response-time analysis
- Reconciliation logic

---

# 🔬 Data Quality Approach

The project follows a simple analytical data lifecycle:

```text
RAW DATA
   │
   ▼
VALIDATE
   │
   ├── NULL CHECKS
   ├── DUPLICATE CHECKS
   ├── DATA TYPE CHECKS
   ├── ID VALIDATION
   ├── RANGE CHECKS
   └── CONSISTENCY CHECKS
   │
   ▼
CLEAN
   │
   ├── STANDARDIZE
   ├── CAST TYPES
   ├── HANDLE NULLS
   ├── REMOVE INVALID RECORDS
   └── REMOVE DUPLICATES
   │
   ▼
CLEAN DATA
   │
   ▼
TRANSFORM
   │
   ▼
ANALYZE
   │
   ▼
VISUALIZE
   │
   ▼
BUSINESS INSIGHTS
```

---

# 📊 Dashboard Potential

The analysis can be converted into a payment operations dashboard containing:

### Executive KPIs

- Total Transactions
- Success Rate
- Failure Rate
- Transaction Value
- Settlement Completion Rate
- Missing Settlements

### Gateway Monitoring

- Gateway Success Rate
- Gateway Transaction Volume
- Average Response Time
- P95 Response Time
- Failure Rate by Gateway

### Failure Analysis

- Failure Reason Distribution
- Failed Transaction Value
- Failure Trends
- Gateway × Failure Reason

### Reconciliation

- Missing Settlements
- Amount Mismatches
- Settlement Delays
- Reconciliation Exceptions

---

# 🚀 Real-World Application

In a production payment environment, this type of analytics system could support:

- Payment operations monitoring
- Gateway performance management
- Finance reconciliation
- Settlement exception management
- Payment failure investigation
- Product performance monitoring
- Vendor/gateway evaluation
- Operational reporting

The raw synthetic dataset can be replaced with actual transaction, gateway, and settlement data from a payment platform.

---

# 🔮 Future Enhancements

Potential future improvements include:

- Automated daily payment monitoring
- Automated anomaly detection
- Gateway-level alerting
- Automated reconciliation reports
- Payment failure prediction
- Gateway routing optimization
- Settlement SLA monitoring
- Automated exception tickets
- Real-time payment dashboards
- ML-based failure prediction
- AI-assisted root-cause analysis

---

# 📌 Project Outcome

This project demonstrates how a Data Analyst can move beyond basic dashboard reporting and use SQL to investigate real operational problems across the payment lifecycle.

The project combines:

**Data Engineering → Data Quality → SQL Analytics → Payment Monitoring → Reconciliation → Business Insights**

The focus is on answering the **"why" behind payment metrics**, not simply reporting the numbers.

---

# 👩‍💻 Author

**T Shalini Patra**

Data Analyst | SQL | Python | BigQuery | Power BI | Data Analytics

GitHub: [Shalini-patra](https://github.com/Shalini-patra)

LinkedIn: [T Shalini Patra](https://www.linkedin.com/in/patrashalini/)

---

# ⭐ If you found this project useful

Feel free to explore the SQL analysis and data-cleaning queries, and connect with me for feedback or collaboration.
