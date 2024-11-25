# pip install cryptography

from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.backends import default_backend
import base64
import os

# Parameters
encrypted_file = "db_password.enc"  # Path to the encrypted file
key = "my_secret_key"              # Passphrase (should be exactly 32 bytes for AES-256)

# Convert the passphrase to a 32-byte key
key = key.ljust(32)[:32].encode('utf-8')

def decrypt_file(filepath, key):
    with open(filepath, 'rb') as f:
        # Read salt and ciphertext
        file_data = f.read()
        salt = file_data[:16]
        ciphertext = file_data[16:]
        
        # Generate key and IV from passphrase and salt using PBKDF2
        from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
        from cryptography.hazmat.primitives.hashes import SHA256

        kdf = PBKDF2HMAC(
            algorithm=SHA256(),
            length=32 + 16,  # 32 bytes for key, 16 bytes for IV
            salt=salt,
            iterations=100000,
            backend=default_backend()
        )
        key_iv = kdf.derive(key)
        aes_key = key_iv[:32]
        iv = key_iv[32:]
        
        # Decrypt the ciphertext
        cipher = Cipher(algorithms.AES(aes_key), modes.CBC(iv), backend=default_backend())
        decryptor = cipher.decryptor()
        plaintext = decryptor.update(ciphertext) + decryptor.finalize()
        
        # Remove padding
        unpadded_plaintext = plaintext[:-plaintext[-1]]
        return unpadded_plaintext.decode('utf-8')

# Decrypt the password
try:
    db_password = decrypt_file(encrypted_file, key)
    print("Decrypted DB Password:", db_password)
except Exception as e:
    print(f"Failed to decrypt the file: {e}")
