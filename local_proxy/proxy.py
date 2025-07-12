import asyncio
import base64
import json
from aiohttp import web, ClientSession
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad, unpad

LAMBDA_URL = "<YOUR_LAMBDA_FUNCTION_URL>"  # Set this to your deployed Lambda function URL
AES_KEY = b"<32_byte_aes_key_here>"  # 32 bytes for AES-256
BLOCK_SIZE = 16

async def encrypt_payload(data: bytes, key: bytes) -> str:
    cipher = AES.new(key, AES.MODE_CBC)
    ct_bytes = cipher.encrypt(pad(data, BLOCK_SIZE))
    iv = cipher.iv
    encrypted = base64.b64encode(iv + ct_bytes).decode()
    return encrypted

def decrypt_payload(encrypted_b64: str, key: bytes) -> bytes:
    raw = base64.b64decode(encrypted_b64)
    iv = raw[:BLOCK_SIZE]
    ct = raw[BLOCK_SIZE:]
    cipher = AES.new(key, AES.MODE_CBC, iv)
    return unpad(cipher.decrypt(ct), BLOCK_SIZE)

async def handle(request):
    try:
        body = await request.read()
        encrypted_payload = await encrypt_payload(body, AES_KEY)
        async with ClientSession() as session:
            lambda_payload = json.dumps({"payload": encrypted_payload})
            async with session.post(LAMBDA_URL, data=lambda_payload, headers={"Content-Type": "application/json"}) as resp:
                lambda_response = await resp.read()
                # Try to decrypt the response if it is base64 encoded
                try:
                    response_json = json.loads(lambda_response)
                    if "payload" in response_json:
                        decrypted = decrypt_payload(response_json["payload"], AES_KEY)
                        return web.Response(body=decrypted, status=resp.status)
                except Exception:
                    pass
                return web.Response(body=lambda_response, status=resp.status)
    except Exception as e:
        return web.Response(text=str(e), status=500)

app = web.Application()
app.router.add_route('*', '/{tail:.*}', handle)

if __name__ == "__main__":
    web.run_app(app, port=8080)
