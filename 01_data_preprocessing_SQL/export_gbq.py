    #  Authenticate with Google Cloud
## gcloud auth application-default login ##

# Import libraries
import pandas as pd
from google.cloud import bigquery
from pathlib import Path

# Set working directory
project_root = Path(__file__).parent.parent
output_dir = project_root / "data" / "processed" / "home_credit_cleaned.csv"

# Export cleaned data from BigQuery to CSV locally
selectQuery = """SELECT * FROM fresh-edge-485011-c3.Home_Credit_data.home_credit_cleaned"""
bigqueryClient = bigquery.Client()
df = bigqueryClient.query(selectQuery).to_dataframe()
df.to_csv(output_dir, index=False)
print(f"Data exported to {output_dir}")

