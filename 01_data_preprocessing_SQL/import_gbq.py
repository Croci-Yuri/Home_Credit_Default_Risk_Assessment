    # Authenticate with Google Cloud
## gcloud auth application-default login ##



# Import libraries
from google.cloud import bigquery
import os
from pathlib import Path


# Set working directory
project_root = Path(__file__).parent.parent
folder = project_root / 'data' / 'raw'

# BigQuery Info
client = bigquery.Client(project="fresh-edge-485011-c3")

# Loop through files and load to BigQuery
for file in os.listdir(folder):
    if file.endswith('.csv'):
        table_name = file.replace('.csv', '')
        table_id = f"fresh-edge-485011-c3.Home_Credit_data.{table_name}"
        
        job_config = bigquery.LoadJobConfig(
            source_format=bigquery.SourceFormat.CSV,
            skip_leading_rows=1,
            autodetect=True,
            write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE
        )
        
        with open(os.path.join(folder, file), "rb") as f:
            job = client.load_table_from_file(f, table_id, job_config=job_config)
        
        job.result()
        print(f"✓ Loaded {file} to {table_name}")

print("\nDone!")