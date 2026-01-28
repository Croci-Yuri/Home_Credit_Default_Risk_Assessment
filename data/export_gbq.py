# Authenticate with Google Cloud
# gcloud auth application-default login

# Import libraries
import pandas as pd
from google.cloud import bigquery

# Export cleaned data from BigQuery to CSV locally
selectQuery = """SELECT * FROM fresh-edge-485011-c3.Home_Credit_data.home_credit_cleaned"""
bigqueryClient = bigquery.Client()
df = bigqueryClient.query(selectQuery).to_dataframe()
df.to_csv("data/processed/home_credit_cleaned.csv", index=False)
print("Data exported to data/processed/home_credit_cleaned.csv")

