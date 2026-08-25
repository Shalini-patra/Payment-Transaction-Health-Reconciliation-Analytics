# 💳 Payments Operations & Reconciliation Analytics

> An end-to-end Payment Analytics and Reconciliation project that uses BigQuery SQL to analyze transaction success, payment failures, gateway performance, settlement completion, and transaction-to-settlement mismatches across 1M+ payment transactions.

![Python](https://img.shields.io/badge/Python-3.11-blue)
![BigQuery](https://img.shields.io/badge/Google%20BigQuery-SQL-blue)
![Pandas](https://img.shields.io/badge/Pandas-Data%20Processing-150458)
![NumPy](https://img.shields.io/badge/NumPy-Data%20Analysis-013243)
![Power BI](https://img.shields.io/badge/Power%20BI-Dashboard-F2C811)
![Looker Studio](https://img.shields.io/badge/Looker%20Studio-Visualization-4285F4)
![Google Sheets](https://img.shields.io/badge/Google%20Sheets-Reporting-34A853)
![GitHub](https://img.shields.io/badge/GitHub-Version%20Control-181717)
![ChatGPT](https://img.shields.io/badge/AI-ChatGPT-412991)
![Claude](https://img.shields.io/badge/AI-Claude-D97757)

---

# 📌 Project Overview

Payment platforms process millions of transactions across users, merchants, payment gateways, and settlement systems.

A high transaction success rate alone does not guarantee that the payment operation is healthy. Payments can fail, gateways can experience performance issues, successful transactions can remain unsettled, and transaction amounts can differ from settlement amounts.

This project simulates a real-world **Payments Operations and Finance Reconciliation analytics environment** using a 3-year synthetic payment dataset and Google BigQuery.

The project focuses on answering questions such as:

- Why are payments failing?
- Which failure reasons have the highest financial impact?
- Which payment gateway performs best?
- Does gateway response time affect payment success?
- How many successful transactions are missing settlements?
- How quickly are transactions settled?
- How many transactions have settlement amount mismatches?
- Which payment issues require operational investigation?

---

# 🎯 Business Objectives

The project was designed to help Payments, Finance, Product, and Operations teams:

- Monitor transaction success and failure rates
- Identify major payment failure drivers
- Compare payment gateway performance
- Detect latency and performance anomalies
- Monitor settlement completion
- Identify missing settlements
- Detect transaction-to-settlement mismatches
- Support payment reconciliation
- Quantify the financial impact of payment failures
- Convert raw payment data into actionable operational insights

---

# 🏗️ Solution Architecture

```text
                  Synthetic Data Generator
                           │
                           ▼
                  Generate 3-Year Dataset
                           │
        ┌──────────────────┼──────────────────┐
        ▼                  ▼                  ▼
    Merchants            Users          Transactions
                                               │
                                               ▼
                                         Settlements
                                               │
                                               ▼
                              Google BigQuery Raw Tables
                                               │
                                               ▼
                                      Data Quality Checks
                                               │
                                               ▼
                                      SQL Data Cleaning
                                               │
                                               ▼
                                     Clean Analytical Tables
                                               │
                                               ▼
                                     Exploratory Data Analysis
                                               │
          ┌────────────────────────────────────┼────────────────────────────┐
          ▼                                    ▼                            ▼
   Payment Performance                 Gateway Analysis             Reconciliation
          │                                    │                            │
          ├── Success Rate                     ├── Gateway KPIs             ├── Missing Settlements
          ├── Failure Rate                     ├── Response Time             ├── Settlement Cycle
          ├── Failure Reasons                  ├── P95 Latency               └── Amount Mismatches
          └── Failed Value                    └── Gateway Comparison
                                               │
                                               ▼
                                      Business Insights
                                               │
                                               ▼
                                      Dashboard / Reporting
                                  ┌────────────┴────────────┐
                                  ▼                         ▼
                              Power BI                Looker Studio
