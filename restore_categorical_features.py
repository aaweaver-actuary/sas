import duckdb
import pandas as pd
from sas7bdat import SAS7BDAT

# Lazily connect to the CSV files using DuckDB
con = duckdb.connect(database=':memory:', read_only=False)
con.execute("CREATE SCHEMA IF NOT EXISTS csv")

# Load metadata table
metadata = pd.read_csv('metadata.csv')

for _, row in metadata.iterrows():
    # Register each lookup CSV table
    con.execute(f"COPY csv.{row['lookup_table_name']} FROM 'lookup_{row['orig_col_name']}.csv' WITH HEADER")

# Load the SAS dataset
with SAS7BDAT('mydata_encoded.sas7bdat') as f:
    for chunk in f.readchunk(1000000):  # adjust the chunk size depending on your available memory
        # Store the chunk in DuckDB
        con.register('sas_chunk', chunk)

        # Iterate over the metadata and reconstruct the original dataset
        for _, row in metadata.iterrows():
            # Join with each lookup table on the corresponding column
            con.execute(f"""
                CREATE OR REPLACE VIEW sas_chunk AS
                SELECT COALESCE(csv.{row['lookup_table_name']}.{row['orig_col_name']}, sas_chunk.{row['orig_col_name']}) as {row['orig_col_name']},
                       sas_chunk.*
                FROM sas_chunk
                LEFT JOIN csv.{row['lookup_table_name']}
                ON sas_chunk.{row['orig_col_name']} = csv.{row['lookup_table_name']}.{row['int_id_col_name']}
            """)

        # Write out the chunk to a Parquet file
        df = con.table('sas_chunk').to_df()
        df.to_parquet('mydata.parquet', engine='fastparquet', append=True)

        # Unregister the chunk so it doesn't take up memory
        con.unregister('sas_chunk')
