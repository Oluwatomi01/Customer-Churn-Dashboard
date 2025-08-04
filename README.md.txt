# Customer-Churn-Dashboard
# 📊 Project 1: Customer Churn Dashboard (Telco Dataset)

This is the first of 5 projects in my 2-week data challenge focused on building, storytelling, and sharing real-world projects.

## 🧠 Project Summary

Churn (i.e., customer leaving a service) is a major concern in subscription-based industries. In this project, I explored a Telco Customer Churn dataset to identify the key drivers behind customer attrition. The dataset was messy and required heavy cleaning before any meaningful insights could be drawn.

I used **Python** (for preprocessing and analysis) and **Looker Studio** (for dashboarding).

---

## 📌 Tools & Skills

- **Python** (Pandas, NumPy)
- **Looker Studio**
- Data Cleaning & Wrangling
- Feature Engineering
- Exploratory Data Analysis (EDA)
- Dashboard Design

---

## 📂 Dataset

- **Source:** [IBM Telco Customer Churn Dataset on Kaggle](https://www.kaggle.com/datasets/blastchar/telco-customer-churn)
- **Rows:** 7,043 customers
- **Target Variable:** `Churn` (Yes/No)

---

## 🔧 Process Breakdown

### 1. Data Cleaning in Python
- Handled missing values in `TotalCharges`
- Converted `SeniorCitizen` to categorical
- Grouped customers by **tenure buckets**

### 2. Key Feature Engineering
- Created `tenure_group` for better interpretability
- Simplified contract types and payment method variables

### 3. Insights from EDA
- Customers with **monthly contracts** had the highest churn rate
- Higher **monthly charges** correlated with higher churn
- Customers with **shorter tenure** were more likely to churn

---

## 📊 Final Dashboard

The final dashboard was built in **Looker Studio**.  
It includes:

- Churn rate by contract type
- Monthly charges vs churn
- Tenure group trends

📎 **Dashboard Link:** _[Add your public Looker Studio link here]_

---

## 🎯 Project Objective

To demonstrate my ability to clean messy data, explore patterns, and tell stories through interactive dashboards.

---

## 📌 About This Series

This project is part of a self-led challenge:
**5 Projects. 2 Weeks. 1 Goal — Visibility.**  
Stay tuned for the next project on loan approval prediction 👀