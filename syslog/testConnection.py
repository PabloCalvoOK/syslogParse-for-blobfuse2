import psycopg2
from psycopg2 import sql

# Database connection parameters
DB_HOST = "syslogdb"  # Name of the Podman container running PostgreSQL
DB_PORT = 5432        # Default PostgreSQL port
DB_NAME = "aidb"  # Database name
DB_USER = "dci"  # Replace with your PostgreSQL username
DB_PASS = "*julian2024*"  # Replace with your PostgreSQL password

try:
    # Connect to the PostgreSQL database
    connection = psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASS
    )

    print("Connection to PostgreSQL database established successfully!")

    # Example query (optional)
    with connection.cursor() as cursor:
        cursor.execute("SELECT version();")
        db_version = cursor.fetchone()
        print(f"Database version: {db_version[0]}")

except Exception as e:
    print(f"An error occurred: {e}")

finally:
    if 'connection' in locals() and connection:
        connection.close()
        print("Database connection closed.")
