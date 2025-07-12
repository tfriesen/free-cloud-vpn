
import boto3
import os
import base64
import json
import requests
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad, unpad

secret_name = os.environ.get("LAMBDA_AES_KEY_SECRET", "lambda-aes-key")
region_name = os.environ.get("AWS_REGION", "us-east-1")
session = boto3.session.Session()
client = session.client(
    service_name='secretsmanager',
    region_name=region_name
)
get_secret_value_response = client.get_secret_value(SecretId=secret_name)
AES_KEY = get_secret_value_response['SecretString']
if isinstance(AES_KEY, str):
    AES_KEY = AES_KEY.encode()
BLOCK_SIZE = 16

def decrypt_payload(encrypted_b64: str, key: bytes) -> bytes:
    raw = base64.b64decode(encrypted_b64)
    iv = raw[:BLOCK_SIZE]
    ct = raw[BLOCK_SIZE:]
    cipher = AES.new(key, AES.MODE_CBC, iv)
    return unpad(cipher.decrypt(ct), BLOCK_SIZE)

def encrypt_payload(data: bytes, key: bytes) -> str:
    cipher = AES.new(key, AES.MODE_CBC)
    ct_bytes = cipher.encrypt(pad(data, BLOCK_SIZE))
    iv = cipher.iv
    encrypted = base64.b64encode(iv + ct_bytes).decode()
    return encrypted

def lambda_handler(event, context):
    try:
        body = event.get('body')
        if event.get('isBase64Encoded'):
            body = base64.b64decode(body)
        else:
            body = body.encode() if isinstance(body, str) else body
        payload = json.loads(body)
        encrypted_payload = payload['payload']
        decrypted = decrypt_payload(encrypted_payload, AES_KEY)
        req = json.loads(decrypted)
        url = req['url']
        method = req.get('method', 'GET').upper()
        headers = req.get('headers', {})
        data = req.get('data', None)
        resp = requests.request(method, url, headers=headers, data=data)
        resp_payload = {
            'status_code': resp.status_code,
            'headers': dict(resp.headers),
            'body': resp.content.decode(errors='replace')
        }
        resp_json = json.dumps(resp_payload).encode()
        encrypted_resp = encrypt_payload(resp_json, AES_KEY)
        return {
            'statusCode': 200,
            'body': json.dumps({'payload': encrypted_resp})
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': str(e)
        }
