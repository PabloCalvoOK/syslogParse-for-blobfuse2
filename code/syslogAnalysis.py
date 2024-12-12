# This program requires pandas sqlalchemy sklearn matplotlib psycopg2-binary 
import pandas as pd
from sqlalchemy import create_engine
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives.hashes import SHA256
from cryptography.hazmat.backends import default_backend
import base64
import configparser 
import psycopg2 

# Parameters
encrypted_file = "db_password.enc"  # Path to the encrypted file
passphrase = "my_secret_key"  # Passphrase used during encryption (adjust as needed)

def decrypt_file(filepath, passphrase):
    with open(filepath, 'rb') as f:
        file_data = f.read()
        
        # OpenSSL adds "Salted__" as the first 8 bytes followed by the 8-byte salt
        if file_data[:8] != b"Salted__":
            raise ValueError("Invalid OpenSSL file format. Missing 'Salted__'.")
        
        salt = file_data[8:16]
        ciphertext = file_data[16:]
        
        # Derive the key and IV using PBKDF2 (matches OpenSSL behavior)
        kdf = PBKDF2HMAC(
            algorithm=SHA256(),
            length=32 + 16,  # 32 bytes for AES key, 16 bytes for IV
            salt=salt,
            iterations=10000,  # OpenSSL's default PBKDF2 iteration count
            backend=default_backend()
        )
        
        key_iv = kdf.derive(passphrase.encode('utf-8'))
        aes_key = key_iv[:32]
        iv = key_iv[32:]
        
        # Create AES cipher
        cipher = Cipher(algorithms.AES(aes_key), modes.CBC(iv), backend=default_backend())
        decryptor = cipher.decryptor()
        plaintext = decryptor.update(ciphertext) + decryptor.finalize()
        
        # Remove padding (PKCS#7)
        padding_len = plaintext[-1]
        unpadded_plaintext = plaintext[:-padding_len]
        return unpadded_plaintext.decode('utf-8')

# Database connection
def fetch_data():
    # Load configuration from syslog.ini
    config = configparser.ConfigParser()
    config.read('syslog.ini')
    # Create a SQLAlchemy engine
    dbname = config['database']['dbname']
    user = config['database']['user']
    container_ip = config['database']['container_ip']
    container = config['database']['container']
    port = config['database']['port']
    db_url = f"postgresql://{user}:{password}@{container_ip}:{port}/{dbname}"
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

    # Decrypt the password
    try:
        password = decrypt_file(encrypted_file, passphrase)
    except Exception as e:
        print(f"Failed to decrypt the file: {e}")

    # Step 1: Fetch data
    syslog_data = fetch_data()

    # Step 2: Preprocess
    processed_data = preprocess_data(syslog_data)

    # Step 3: Detect anomalies
    anomalies = detect_anomalies(processed_data)
    print(f"Detected {len(anomalies)} anomalies.")

    # Step 4: Visualize
    visualize_data(processed_data, save_path="/app/severity_plot.png")
