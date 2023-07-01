import os
import pandas as pd
import polars as pl
import psutil

def process_sas_to_parquet(sas_filepath, metadata_filepath, output_filepath, threshold=0.5):
    """
    Convert a SAS dataset to Parquet format, processing it in chunks if it exceeds a specified threshold relative to 
    the available memory.

    Args:
        sas_filepath (str): The filepath to the SAS dataset.
        metadata_filepath (str): The filepath to the metadata CSV file.
        output_filepath (str): The filepath where the output Parquet file will be saved.
        threshold (float, optional): The threshold, as a proportion of the available memory, above which the SAS 
            dataset will be processed in chunks. Defaults to 0.5.

    Returns:
        None

    Raises:
        FileNotFoundError: If the specified SAS dataset or metadata CSV file does not exist.
        ValueError: If the threshold is not a valid float between 0 and 1.

    Notes:
        - This function assumes that the SAS dataset and metadata CSV file are compatible and have the appropriate
          structure as expected by the implementation.
        - The metadata CSV file should contain information about lookup tables for mapping specific columns in the 
          SAS dataset. Each row in the metadata file should include the following columns:
          'orig_col_name': The original column name in the SAS dataset.
          'int_id_col_name': The column name in the lookup table used for joining.
        - The lookup tables should be named as 'lookup_<orig_col_name>.csv' and should contain at least two columns:
          one for the join key and another for the mapped values.
        - The output Parquet file will contain the transformed SAS dataset with mapped values from the lookup tables.
    """

    # Load metadata table
    metadata = pd.read_csv(metadata_filepath)

    # Get the size of the dataset (in bytes)
    dataset_size = os.path.getsize(sas_filepath)

    # Get the available memory (in bytes)
    available_memory = psutil.virtual_memory().available

    if not 0 < threshold <= 1:
        raise ValueError("Threshold must be a float between 0 and 1.")

    if not os.path.exists(sas_filepath):
        raise FileNotFoundError(f"The specified SAS dataset '{sas_filepath}' does not exist.")

    if not os.path.exists(metadata_filepath):
        raise FileNotFoundError(f"The specified metadata CSV file '{metadata_filepath}' does not exist.")

    if dataset_size > threshold * available_memory:
        # If the dataset is larger than the threshold, use chunking
        chunksize = int(available_memory / dataset_size)  # Adjust this calculation as needed based on your specific use case
    else:
        # If the dataset is smaller than the threshold, load the whole dataset at once
        chunksize = None

    # Initialize empty DataFrame for the full dataset
    full_data = pl.DataFrame()

    # Load the SAS dataset in chunks (or all at once if chunksize is None)
    for chunk in pd.read_sas(sas_filepath, chunksize=chunksize):
        # Convert the pandas DataFrame chunk to a Polars DataFrame
        numeric_data = pl.from_pandas(chunk)

        # Lazy DataFrame operation
        ldf = numeric_data.lazy()

        # Loop through metadata to join numeric data with each lookup table
        for _, row in metadata.iterrows():
            # Lazily load each lookup table
            lookup_table = pl.scan_csv(f"lookup_{row['orig_col_name']}.csv")

            # Merge numeric data with lookup table
            ldf = ldf.join(
                lookup_table,
                left_on=row['orig_col_name'],
                right_on=row['int_id_col_name'],
                how='left'
            )

            # Replace the original numeric column with the mapped value
            ldf = ldf.with_column(
                pl.col(row['orig_col_name']).fillna(pl.col(row['orig_col_name'] + '_right')).alias(row['orig_col_name'])
            ).drop(row['orig_col_name'] + '_right')

        # Collect the computation for the chunk and append to full_data
        df_chunk = ldf.collect()
        full_data = full_data.vstack([full_data, df_chunk])

    # Write out the dataset to a Parquet file
    full_data.write_parquet(output_filepath)
