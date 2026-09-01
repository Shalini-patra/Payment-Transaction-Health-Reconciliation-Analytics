"""
Synthetic Payment Transaction & Settlement Data Generator
------------------------------------------------------------
Simulates a UPI/card payments ecosystem for the "Payment
Transaction Health & Reconciliation Analytics" project.

Produces 4 CSVs, ready to load into BigQuery:
  - merchants.csv
  - users.csv
  - transactions.csv
  - settlements.csv

Realistic issues are deliberately injected so the SQL layer
(window functions, CTEs, reconciliation logic) has something
real to find:
  - ~2% baseline transaction failures (with failure_reason)
  - weekend + peak-hour failure bumps
  - a handful of "sudden gateway degradation" anomaly days
  - ~0.5% duplicate transactions
  - ~1.2% missing settlements
  - ~1% delayed settlements (T+3 to T+7 instead of T+1)
  - ~0.3% settlement amount mismatches

Usage:
    pip install pandas numpy --break-system-packages
    python payment_data_generator.py
"""

import numpy as np
import pandas as pd
from datetime import datetime, timedelta
import uuid

# ------------------------------------------------------------------
# CONFIG — tweak these to scale the dataset up/down
# ------------------------------------------------------------------
SEED = 42
np.random.seed(SEED)

NUM_TRANSACTIONS = 1000000
NUM_USERS = 50000
NUM_MERCHANTS = 1500
DAYS_OF_DATA = 365 * 3
END_DATE = datetime(2026, 8, 21)
START_DATE = END_DATE - timedelta(days=DAYS_OF_DATA)

GATEWAYS = ["Gateway_A", "Gateway_B", "Gateway_C"]
GATEWAY_WEIGHTS = [0.45, 0.35, 0.20]

# Per-gateway performance profiles — this is the ONLY behavioral difference
# introduced between gateways. Assignment probability (GATEWAY_WEIGHTS),
# transaction volume, dates, amounts, and everything else stay unchanged.
# failure_reason_weights order matches the FAILURE_REASONS list below.
GATEWAY_PROFILES = {
    "Gateway_A": {
        "base_success_rate": 0.990,       # most reliable gateway
        "response_time_shape": 1.8,       # fastest, tightest spread
        "response_time_scale": 220,
        "failure_reason_weights": [0.15, 0.20, 0.25, 0.15, 0.25],
    },
    "Gateway_B": {
        "base_success_rate": 0.810,       # least reliable gateway
        "response_time_shape": 2.6,       # slowest, most variable
        "response_time_scale": 480,
        "failure_reason_weights": [0.45, 0.20, 0.10, 0.20, 0.05],  # timeout-prone
    },
    "Gateway_C": {
        "base_success_rate": 0.931,       # middle ground
        "response_time_shape": 2.0,
        "response_time_scale": 330,
        "failure_reason_weights": [0.20, 0.30, 0.25, 0.10, 0.15],  # decline-prone
    },
}

PAYMENT_METHODS = ["UPI", "Debit Card", "Credit Card", "Net Banking"]
PAYMENT_METHOD_WEIGHTS = [0.55, 0.20, 0.15, 0.10]

MERCHANT_CATEGORIES = [
    "Grocery", "Food Delivery", "Electronics", "Fashion", "Travel",
    "Entertainment", "Utilities", "Education", "Fuel", "Pharmacy",
]

CITIES = [
    "Bengaluru", "Mumbai", "Delhi", "Hyderabad", "Chennai", "Pune",
    "Kolkata", "Ahmedabad", "Bhubaneswar", "Jaipur",
]

AGE_GROUPS = ["11-17", "18-24", "25-34", "35-44", "45-60"]
AGE_GROUP_WEIGHTS = [0.10, 0.35, 0.30, 0.15, 0.10]

FAILURE_REASONS = [
    "TIMEOUT", "INSUFFICIENT_BALANCE", "BANK_DECLINE",
    "GATEWAY_ERROR", "AUTH_FAILURE",
]
FAILURE_REASON_WEIGHTS = [0.30, 0.25, 0.20, 0.15, 0.10]

OUTPUT_DIR = r"C:\Users\HP\Fintech"


# ------------------------------------------------------------------
# 1. MERCHANTS
# ------------------------------------------------------------------
def generate_merchants(n=NUM_MERCHANTS):
    merchant_ids = [f"M{str(i).zfill(6)}" for i in range(1, n + 1)]
    return pd.DataFrame({
        "merchant_id": merchant_ids,
        "merchant_name": [f"Merchant_{i}" for i in range(1, n + 1)],
        "merchant_category": np.random.choice(MERCHANT_CATEGORIES, n),
        "city": np.random.choice(CITIES, n),
    })


# ------------------------------------------------------------------
# 2. USERS
# ------------------------------------------------------------------
def generate_users(n=NUM_USERS):
    user_ids = [f"U{str(i).zfill(7)}" for i in range(1, n + 1)]
    return pd.DataFrame({
        "user_id": user_ids,
        "age_group": np.random.choice(AGE_GROUPS, n, p=AGE_GROUP_WEIGHTS),
        "city": np.random.choice(CITIES, n),
    })


# ------------------------------------------------------------------
# 3. TRANSACTIONS (core generator with all injected anomalies)
# ------------------------------------------------------------------
def random_timestamps(n, start, end):
    total_seconds = int((end - start).total_seconds())
    offsets = np.random.randint(0, total_seconds, size=n)
    return pd.to_datetime(start) + pd.to_timedelta(offsets, unit="s")


def generate_transactions(users_df, merchants_df, n=NUM_TRANSACTIONS):
    user_ids = np.random.choice(users_df["user_id"], n)
    merchant_ids = np.random.choice(merchants_df["merchant_id"], n)
    gateways = np.random.choice(GATEWAYS, n, p=GATEWAY_WEIGHTS)
    payment_methods = np.random.choice(PAYMENT_METHODS, n, p=PAYMENT_METHOD_WEIGHTS)
    timestamps = random_timestamps(n, START_DATE, END_DATE)

    amounts = np.round(np.random.lognormal(mean=6.0, sigma=0.9, size=n), 2)
    amounts = np.clip(amounts, 20, 50000)

    # Each gateway draws response time from its own gamma distribution
    # (shape/scale from GATEWAY_PROFILES) instead of one shared distribution.
    response_times = np.empty(n)
    for gw, profile in GATEWAY_PROFILES.items():
        gw_mask = gateways == gw
        gw_count = gw_mask.sum()
        response_times[gw_mask] = np.random.gamma(
            shape=profile["response_time_shape"],
            scale=profile["response_time_scale"],
            size=gw_count,
        )
    response_times = np.round(np.clip(response_times, 80, 8000), 1)

    df = pd.DataFrame({
        "transaction_id": [f"TXN{uuid.uuid4().hex[:12].upper()}" for _ in range(n)],
        "user_id": user_ids,
        "merchant_id": merchant_ids,
        "gateway": gateways,
        "payment_method": payment_methods,
        "transaction_timestamp": timestamps,
        "amount": amounts,
        "response_time_ms": response_times,
    })

    # ---------------- GATEWAY-SPECIFIC BASE SUCCESS/FAILURE RATE ----------------
    # Each gateway now has its own baseline success probability (from
    # GATEWAY_PROFILES) instead of one shared 98% applied to every row.
    base_success_prob = np.array(
        [GATEWAY_PROFILES[gw]["base_success_rate"] for gw in gateways]
    )
    df["status"] = np.where(np.random.rand(n) < base_success_prob, "SUCCESS", "FAILED")

    # ---------------- WEEKEND EFFECT ----------------
    is_weekend = df["transaction_timestamp"].dt.dayofweek >= 5
    weekend_flip = is_weekend & (np.random.rand(n) < 0.01)
    df.loc[weekend_flip & (df["status"] == "SUCCESS"), "status"] = "FAILED"

    # ---------------- PEAK-HOUR FAILURE BUMP ----------------
    hour = df["transaction_timestamp"].dt.hour
    peak_hours = hour.isin([12, 13, 19, 20, 21])
    peak_flip = peak_hours & (np.random.rand(n) < 0.015)
    df.loc[peak_flip & (df["status"] == "SUCCESS"), "status"] = "FAILED"

    # ---------------- SUDDEN GATEWAY DEGRADATION ANOMALY ----------------
    # A handful of days where one gateway suddenly spikes in failures.
    # This is what your anomaly-detection SQL/AI layer should catch.
    candidate_days = pd.date_range(START_DATE, END_DATE, freq="D")
    anomaly_days = pd.to_datetime(
        np.random.choice(candidate_days, size=4, replace=False)
    )
    anomaly_gateway_map = {day: np.random.choice(GATEWAYS) for day in anomaly_days}

    for day, bad_gateway in anomaly_gateway_map.items():
        mask = (df["transaction_timestamp"].dt.date == day.date()) & (df["gateway"] == bad_gateway)
        degrade_mask = mask & (np.random.rand(n) < 0.28)  # big extra failure spike that day
        df.loc[degrade_mask, "status"] = "FAILED"

    # ---------------- GATEWAY-SPECIFIC FAILURE REASONS ----------------
    # Each gateway draws failure reasons from its own weight distribution
    # (e.g. Gateway_B skews toward TIMEOUT) instead of one shared distribution.
    failed_mask = df["status"] == "FAILED"
    df["failure_reason"] = None
    for gw, profile in GATEWAY_PROFILES.items():
        gw_failed_mask = failed_mask & (df["gateway"] == gw)
        count = gw_failed_mask.sum()
        if count > 0:
            df.loc[gw_failed_mask, "failure_reason"] = np.random.choice(
                FAILURE_REASONS, count, p=profile["failure_reason_weights"]
            )

    # ---------------- A FEW GENUINE "PENDING" TRANSACTIONS ----------------
    pending_mask = (df["status"] == "SUCCESS") & (np.random.rand(n) < 0.004)
    df.loc[pending_mask, "status"] = "PENDING"
    df.loc[pending_mask, "failure_reason"] = None

    # ---------------- DUPLICATE TRANSACTIONS (~0.5%) ----------------
    dup_candidates = df[df["status"] == "SUCCESS"].sample(frac=0.005, random_state=SEED)
    duplicates = dup_candidates.copy()
    duplicates["transaction_id"] = [f"TXN{uuid.uuid4().hex[:12].upper()}" for _ in range(len(duplicates))]
    duplicates["transaction_timestamp"] = duplicates["transaction_timestamp"] + pd.to_timedelta(
        np.random.randint(2, 90, size=len(duplicates)), unit="s"
    )
    df = pd.concat([df, duplicates], ignore_index=True)

    df = df.sort_values("transaction_timestamp").reset_index(drop=True)
    return df, anomaly_gateway_map


# ------------------------------------------------------------------
# 4. SETTLEMENTS (built from successful transactions, with injected issues)
# ------------------------------------------------------------------
def generate_settlements(transactions_df):
    successful = transactions_df[transactions_df["status"] == "SUCCESS"].copy()
    n = len(successful)

    # ~1.2% of successful transactions never get a settlement record at all
    missing_mask = np.random.rand(n) < 0.012
    settle_source = successful[~missing_mask].copy()
    m = len(settle_source)

    # Base settlement: T+1 day
    settlement_dates = settle_source["transaction_timestamp"].dt.floor("D") + pd.to_timedelta(1, unit="D")

    # ~1% delayed settlements: T+3 to T+7
    delayed_mask = np.random.rand(m) < 0.01
    delay_days = np.random.randint(3, 8, size=m)
    settlement_dates = settlement_dates.where(
        ~delayed_mask,
        settle_source["transaction_timestamp"].dt.floor("D") + pd.to_timedelta(delay_days, unit="D"),
    )

    settlement_amounts = settle_source["amount"].values.copy()

    # ~0.3% settlement amount mismatches (small discrepancy vs transaction amount)
    mismatch_mask = np.random.rand(m) < 0.003
    mismatch_adjustment = np.random.uniform(-25, 25, size=m)
    settlement_amounts = np.where(
        mismatch_mask,
        np.round(settlement_amounts + mismatch_adjustment, 2),
        settlement_amounts,
    )

    settlement_status = np.where(delayed_mask, "DELAYED", "SETTLED")

    return pd.DataFrame({
        "settlement_id": [f"STL{uuid.uuid4().hex[:12].upper()}" for _ in range(m)],
        "transaction_id": settle_source["transaction_id"].values,
        "settlement_date": settlement_dates.values,
        "settlement_amount": settlement_amounts,
        "settlement_status": settlement_status,
    })


# ------------------------------------------------------------------
# MAIN
# ------------------------------------------------------------------
def main():
    print("Generating merchants...")
    merchants_df = generate_merchants()

    print("Generating users...")
    users_df = generate_users()

    print("Generating transactions (this includes all injected anomalies)...")
    transactions_df, anomaly_map = generate_transactions(users_df, merchants_df)

    print("Generating settlements (with delays / mismatches / missing records)...")
    settlements_df = generate_settlements(transactions_df)

    merchants_df.to_csv(f"{OUTPUT_DIR}/merchants.csv", index=False)
    users_df.to_csv(f"{OUTPUT_DIR}/users.csv", index=False)
    transactions_df.to_csv(f"{OUTPUT_DIR}/transactions.csv", index=False)
    settlements_df.to_csv(f"{OUTPUT_DIR}/settlements.csv", index=False)

    print("\n--- SUMMARY ---")
    print(f"Merchants:    {len(merchants_df):,}")
    print(f"Users:        {len(users_df):,}")
    print(f"Transactions: {len(transactions_df):,}")
    print(f"Settlements:  {len(settlements_df):,}")
    print(f"Overall success rate: {(transactions_df['status'] == 'SUCCESS').mean() * 100:.2f}%")
    print("\nInjected gateway degradation days (use these to validate your anomaly SQL):")
    for day, gw in anomaly_map.items():
        print(f"  {day.date()} -> {gw}")

    # ---------------- VALIDATION: confirm gateways now differ ----------------
    # Read-only summary — does not modify transactions_df or the saved CSVs.
    print("\n--- GATEWAY VALIDATION ---")
    for gw in GATEWAYS:
        gw_df = transactions_df[transactions_df["gateway"] == gw]
        total = len(gw_df)
        success_rate = (gw_df["status"] == "SUCCESS").mean() * 100
        failure_rate = (gw_df["status"] == "FAILED").mean() * 100
        avg_response = gw_df["response_time_ms"].mean()
        top_reason = (
            gw_df.loc[gw_df["status"] == "FAILED", "failure_reason"].mode().iloc[0]
            if (gw_df["status"] == "FAILED").any() else "N/A"
        )
        print(
            f"  {gw:<10} | Transactions: {total:>7,} | Success: {success_rate:5.2f}% | "
            f"Failure: {failure_rate:5.2f}% | Avg Response: {avg_response:6.1f} ms | "
            f"Top Failure Reason: {top_reason}"
        )


if __name__ == "__main__":
    main()
