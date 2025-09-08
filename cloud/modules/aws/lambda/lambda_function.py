"""
Lambda that accepts JSON {"payload": "<base64-of-raw-http-request-bytes>"},
decodes it, makes the described HTTP request, and returns JSON
{"payload": "<base64-of-raw-http-response-bytes>"}.

This is a minimal implementation (no AES) used with the local proxy that
forwards requests to this Lambda which performs the actual upstream HTTP
request and returns the raw response bytes.
"""
from __future__ import annotations

import base64
import json
import logging
from typing import Any, Dict

import requests

LOG = logging.getLogger()
LOG.setLevel(logging.INFO)


def _parse_raw_http_request(raw: bytes) -> Dict[str, Any]:
    """Parse a raw HTTP request bytes into components.

    Returns a dict with keys: method, path, version, headers (dict), body (bytes)
    """
    try:
        parts = raw.split(b"\r\n\r\n", 1)
        head = parts[0]
        body = parts[1] if len(parts) > 1 else b""
        lines = head.split(b"\r\n")
        start_line = lines[0].decode(errors="replace")
        header_lines = lines[1:]

        method, path, version = (start_line.split(maxsplit=2) + ["HTTP/1.1"])[:3]

        headers: Dict[str, str] = {}
        for hl in header_lines:
            if b":" in hl:
                k, v = hl.split(b":", 1)
                headers[k.decode(errors="replace").strip()] = v.decode(errors="replace").strip()

        return {"method": method, "path": path, "version": version, "headers": headers, "body": body}
    except Exception as e:
        raise ValueError(f"Failed to parse raw HTTP request: {e}") from e


def _build_raw_http_response(status_code: int, reason: str, headers: Dict[str, str], body: bytes) -> bytes:
    """Construct raw HTTP response bytes from components."""
    status_line = f"HTTP/1.1 {status_code} {reason}\r\n"
    # Copy headers but ensure content-length matches body length and is present
    hdrs = headers.copy() if headers else {}
    hdrs.pop("Content-Length", None)
    hdrs.pop("Transfer-Encoding", None)
    hdrs["Content-Length"] = str(len(body))

    header_lines = "\r\n".join(f"{k}: {v}" for k, v in hdrs.items())
    return status_line.encode() + header_lines.encode() + b"\r\n\r\n" + body


def lambda_handler(event, context):
    """AWS Lambda handler entrypoint.

    Expects event to be a dict containing either:
    - 'body' (string or bytes) that is JSON containing {'payload': '<base64>'}
    or
    - the event itself containing 'payload' key (for direct Lambda invoke tests).
    """
    try:
        # Extract JSON payload from event
        payload_obj = None
        if isinstance(event, dict) and "body" in event and event["body"] is not None:
            body = event["body"]
            # API Gateway / Function URL often sends body as a string
            if isinstance(body, str):
                try:
                    payload_obj = json.loads(body)
                except Exception:
                    # If body is a raw base64 string in 'body'
                    payload_obj = {"payload": body}
            elif isinstance(body, (bytes, bytearray)):
                payload_obj = json.loads(body.decode())
            else:
                payload_obj = body
        elif isinstance(event, dict) and "payload" in event:
            payload_obj = event
        else:
            # Fallback: try to treat event as payload container
            payload_obj = event

        if not payload_obj or "payload" not in payload_obj:
            return {"statusCode": 400, "body": json.dumps({"error": "missing payload"})}

        payload_b64 = payload_obj["payload"]
        raw_req = base64.b64decode(payload_b64)

        # Parse raw HTTP request bytes
        req = _parse_raw_http_request(raw_req)
        LOG.info("Parsed request: %s %s", req.get("method"), req.get("path"))

        # Determine URL to call
        path = req.get("path", "/")
        headers = req.get("headers", {})
        body_bytes = req.get("body", b"") or b""

        if path.lower().startswith("http://") or path.lower().startswith("https://"):
            url = path
        else:
            # Use Host header; default to http if scheme not present
            host = headers.get("Host")
            if not host:
                return {"statusCode": 400, "body": json.dumps({"error": "missing Host header and no absolute URL in request path"})}
            scheme = headers.get("X-Forwarded-Proto", "http")
            # Ensure path begins with /
            if not path.startswith("/"):
                path = "/" + path
            url = f"{scheme}://{host}{path}"

        # Perform the HTTP request using requests
        method = req.get("method", "GET").upper()

        # Remove hop-by-hop headers that requests will manage
        hop_by_hop = [
            "Connection",
            "Keep-Alive",
            "Proxy-Authenticate",
            "Proxy-Authorization",
            "TE",
            "Trailers",
            "Transfer-Encoding",
            "Upgrade",
        ]
        request_headers = {k: v for k, v in headers.items() if k not in hop_by_hop}

        # Make the request
        resp = requests.request(method, url, headers=request_headers, data=body_bytes, allow_redirects=False, timeout=20)

        # Build raw HTTP response bytes
        resp_headers = {k: v for k, v in resp.headers.items()}
        raw_resp = _build_raw_http_response(resp.status_code, resp.reason or "", resp_headers, resp.content)

        resp_b64 = base64.b64encode(raw_resp).decode()
        return {"statusCode": 200, "body": json.dumps({"payload": resp_b64})}
    except Exception as e:
        LOG.exception("Error in lambda_handler")
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}
