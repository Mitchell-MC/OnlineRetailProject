import os
import snowflake.connector
import pandas as pd
from sqlalchemy import create_engine

# --- Configuration ---
SNOWFLAKE_USER = os.getenv("SNOWFLAKE_USER")
SNOWFLAKE_PASSWORD = os.getenv("SNOWFLAKE_PASSWORD")
SNOWFLAKE_ACCOUNT = os.getenv("SNOWFLAKE_ACCOUNT")

# PostgreSQL connection string
POSTGRES_CONN_STRING = "postgresql://postgres:mysecretpassword@localhost:5432/postgres"

def fetch_customer_profiles():
    """Fetches the customer 360 profiles from Snowflake."""
    print("Connecting to Snowflake...")
    with snowflake.connector.connect(
        user=SNOWFLAKE_USER,
        password=SNOWFLAKE_PASSWORD,
        account=SNOWFLAKE_ACCOUNT,
        warehouse="COMPUTE_WH",
        database="ECOMMERCE_DB",
        schema="ANALYTICS"
    ) as conn:
        print("Fetching customer profiles...")
        query = "SELECT * FROM CUSTOMER_360_PROFILE"
        df = pd.read_sql(query, conn)
        print(f"Fetched {len(df)} profiles.")
        # Snowflake column names are often uppercase, convert to lowercase for PostgreSQL
        df.columns = [x.lower() for x in df.columns]
        return df

def write_to_postgres(df):
    """Writes the DataFrame to a PostgreSQL table."""
    print("Connecting to PostgreSQL...")
    engine = create_engine(POSTGRES_CONN_STRING)
    print("Writing data to customer_profiles table...")
    # Use pandas to_sql to write the dataframe. 'replace' will drop the table if it exists.
    df.to_sql('customer_profiles', engine, if_exists='replace', index=False)
    print("Write to PostgreSQL complete.")

if __name__ == "__main__":
    customer_df = fetch_customer_profiles()
    if not customer_df.empty:
        write_to_postgres(customer_df)