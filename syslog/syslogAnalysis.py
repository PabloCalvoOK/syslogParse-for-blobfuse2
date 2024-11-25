import pandas as pd
from sqlalchemy import create_engine

# Database connection
def fetch_data():
    # Create a SQLAlchemy engine
    dbname="aidb"
    user="dci"
    password="*julian2024*"
    host="syslogdb"
    port="5432"
    db_url = f"postgresql://{user}:{password}@{host}:{port}/{dbname}"
    engine = create_engine(db_url)
    try:
        query = "SELECT timestamp, hostname, facility, severity, message FROM syslog_entries;"
        df = pd.read_sql(query, engine)
        print(df.head())
        return df
    except Exception as e:
        print(f"Error: {e}")
        return None
    finally: engine.dispose()    # Close the database connection

def preprocess_data(df):
    # Convert timestamp to datetime
    df['timestamp'] = pd.to_datetime(df['timestamp'])
    # Encode severity levels as numbers (optional)
    severity_mapping = {'LOG_EMERG': 0, 'LOG_ALERT': 1, 'LOG_CRIT': 2, 'LOG_ERR': 3, 
                        'LOG_WARN': 4, 'LOG_TRACE': 5, 'LOG_INFO': 6, 'LOG_DEBUG': 7}
    df['severity'] = df['severity'].map(severity_mapping)
    # Example: Extract hour of day for trend analysis
    df['hour'] = df['timestamp'].dt.hour
    return df


from sklearn.ensemble import IsolationForest

def detect_anomalies(df):
    # Use severity and hour for anomaly detection
    model_data = df[['severity', 'hour']].fillna(0)
    model = IsolationForest(contamination=0.05, random_state=42)
    df['anomaly'] = model.fit_predict(model_data)
    # -1 indicates anomaly
    anomalies = df[df['anomaly'] == -1]
    return anomalies


import matplotlib.pyplot as plt

def visualize_data(df, save_path="severity_plot.png"):
    if df.empty or 'severity' not in df.columns or df['severity'].isnull().all():
        print("No data available for visualization.")
        return

    try:
        # Plot and save
        severity_counts = df['severity'].value_counts().sort_index()
        severity_counts.plot(kind='bar', color='skyblue', title="Syslog Message Frequency by Severity")
        plt.xlabel("Severity Level")
        plt.ylabel("Count")
        plt.tight_layout()
        plt.savefig(save_path)
        print(f"Plot saved to {save_path}")
    except Exception as e:
        print(f"Visualization error: {e}")


if __name__ == "__main__":
    # Step 1: Fetch data
    syslog_data = fetch_data()

    # Step 2: Preprocess
    processed_data = preprocess_data(syslog_data)

    # Step 3: Detect anomalies
    anomalies = detect_anomalies(processed_data)
    print(f"Detected {len(anomalies)} anomalies.")

    # Step 4: Visualize
    visualize_data(processed_data, save_path="/app/severity_plot.png")
