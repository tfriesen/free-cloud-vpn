"""
Simple wrapper to run proxy.py as an HTTP proxy from Python.

Usage:
  python proxy.py --host 127.0.0.1 --port 8899

Requires: pip install proxy.py
"""
from __future__ import annotations

import argparse
import ipaddress
import sys
import base64
import json
import urllib.request
import urllib.error
import traceback

def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Start proxy.py HTTP proxy (embedded)")
    p.add_argument("--host", default="127.0.0.1", help="Host to bind (default 127.0.0.1)")
    p.add_argument("--port", type=int, default=8899, help="Port to bind (default 8899). Use 0 for ephemeral port")
    p.add_argument("--lambda-url", required=True, help="HTTPS URL of the AWS Lambda function to POST encoded requests to")
    p.add_argument("--debug", action="store_true", help="If set, print addiitional debug info")
    return p.parse_args()


def main() -> None:
    args = parse_args()

    # Global debug flag: when enabled, plugin will dump the client request and additional debug info
    DEBUG = bool(getattr(args, 'debug', False))

    # Derive host_obj from args.host so we can pass it to proxy.Proxy / proxy.main.
    # Convert to ipaddress object when possible; otherwise keep the string.
    try:
        host_obj = ipaddress.ip_address(args.host)
    except Exception:
        host_obj = args.host

    try:
        import proxy
    except Exception:
        print("Missing dependency: install proxy.py (pip install proxy.py)", file=sys.stderr)
        sys.exit(1)

    # Define a simple plugin class that will intercept client requests and
    # modify them before they are sent upstream. We define it here after
    # importing `proxy` so we can subclass the library's plugin base class.
    class LambdaProxyPlugin(proxy.http.proxy.HttpProxyBasePlugin):
        """Plugin that encodes the entire client HTTP request as base64 and
        POSTs it to an external Lambda. The Lambda must return JSON with a
        'payload' field containing base64-encoded raw HTTP response bytes.

        To prevent an upstream connection, this plugin queues the response
        returned from the Lambda and returns None from the hook.
        """

        def __init__(self, *args, lambda_url: str | None = None, **kwargs):
            super().__init__(*args, **kwargs)
            self.lambda_url = lambda_url

        def _serialize_request(self, request) -> bytes:
            # Best-effort request serialization into raw HTTP bytes. The
            # HttpParser exposes method, path, version, headers and body in
            # different forms across versions; use defensive checks.
            try:
                method = request.method.decode() if isinstance(request.method, (bytes, bytearray)) else str(request.method)
            except Exception:
                method = 'GET'
            try:
                path = request.path.decode() if isinstance(request.path, (bytes, bytearray)) else str(getattr(request, 'path', '/'))
            except Exception:
                path = '/'
            try:
                version = request.version or b'HTTP/1.1'
                version = version.decode() if isinstance(version, (bytes, bytearray)) else str(version)
            except Exception:
                version = 'HTTP/1.1'

            # Headers
            header_lines = []
            try:
                # HttpParser v2.4 exposes .headers where values are tuples like
                # (original_header_name_bytes, header_value_bytes). Handle that
                # format first and fall back to older formats.
                if hasattr(request, 'headers') and request.headers:
                    for k, v in request.headers.items():
                        # v expected to be a tuple (orig_key_bytes, value_bytes)
                        if isinstance(v, (list, tuple)) and len(v) >= 2:
                            k_bytes, v_bytes = v[0], v[1]
                        else:
                            # Fallback: previous code assumed k and v were bytes
                            k_bytes, v_bytes = k, v
                        k_s = k_bytes.decode() if isinstance(k_bytes, (bytes, bytearray)) else str(k_bytes)
                        v_s = v_bytes.decode() if isinstance(v_bytes, (bytes, bytearray)) else str(v_bytes)
                        header_lines.append(f"{k_s}: {v_s}")
                else:
                    # Try host attribute
                    host = getattr(request, 'host', None)
                    if host:
                        header_lines.append(f"Host: {host.decode() if isinstance(host, (bytes, bytearray)) else host}")
            except Exception:
                pass

            # Ensure Host header exists
            if not any(h.lower().startswith('host:') for h in header_lines):
                h = getattr(request, 'host', None)
                if h:
                    header_lines.insert(0, f"Host: {h.decode() if isinstance(h, (bytes, bytearray)) else h}")

            # Body
            body = b''
            try:
                if getattr(request, 'body', None):
                    body = request.body if isinstance(request.body, (bytes, bytearray)) else str(request.body).encode()
            except Exception:
                body = b''

            start_line = f"{method} {path} {version}\r\n"
            headers_raw = "\r\n".join(header_lines) + "\r\n\r\n" if header_lines else "\r\n"
            return start_line.encode() + headers_raw.encode() + body

        def _send_error_response(self, status: int, reason: str, message: str) -> None:
            """Queue a simple text error response back to the client and log to stdout."""
            body = message.encode(errors='replace')
            status_line = f"HTTP/1.1 {status} {reason}\r\n"
            headers = {
                "Content-Type": "text/plain; charset=utf-8",
                "Content-Length": str(len(body)),
                "Connection": "close",
            }
            header_lines = "\r\n".join(f"{k}: {v}" for k, v in headers.items())
            raw = status_line.encode() + header_lines.encode() + b"\r\n\r\n" + body
            try:
                # Queue the response and ensure we don't fall back to upstream.
                self.client.queue(raw)
            except Exception:
                # If even queuing fails, at least print the traceback.
                print("Failed to queue error response to client:", file=sys.stdout)
                traceback.print_exc()
            # Also log the error to stdout for visibility.
            print(f"[LambdaProxyPlugin] Error {status} {reason}: {message}", file=sys.stdout)

        #disable establishing upstream connection
        def before_upstream_connection(self, request):
            return None

        def handle_client_request(self, request):
            # Intercept the request and send to Lambda instead of upstream.
            try:
                if not self.lambda_url:
                    self._send_error_response(500, "Internal Server Error", "Lambda URL not configured")
                    return None

                raw_req = self._serialize_request(request)
                if DEBUG:
                    print(f"[LambdaProxyPlugin] Serialized raw HTTP request ({len(raw_req)} bytes):\n{raw_req.decode(errors='replace')}", file=sys.stdout)
                encoded = base64.b64encode(raw_req).decode()

                payload = json.dumps({"payload": encoded}).encode()
                req = urllib.request.Request(self.lambda_url, data=payload, headers={"Content-Type": "application/json"}, method="POST")
                with urllib.request.urlopen(req, timeout=15) as resp:
                    resp_body = resp.read()

                # Lambda should return JSON with 'payload' key containing base64
                # of raw HTTP response bytes. Parse and queue.
                try:
                    resp_json = json.loads(resp_body)
                    resp_b64 = resp_json.get('payload')
                    if resp_b64:
                        decoded = base64.b64decode(resp_b64)
                        # Queue raw HTTP response bytes back to client and
                        # prevent upstream connection by returning None.
                        if DEBUG:
                            print(f"[LambdaProxyPlugin] Queuing response from Lambda ({len(decoded)} bytes):\n{decoded.decode(errors='replace')}", file=sys.stdout)
                        self.client.queue(decoded)
                        return None
                except Exception:
                    msg = "Invalid response from Lambda: unable to parse payload"
                    print(f"[LambdaProxyPlugin] {msg}", file=sys.stdout)
                    self._send_error_response(502, "Bad Gateway", msg)
                    return None
            except urllib.error.HTTPError as e:
                # Try to extract any JSON error body provided by the Lambda
                err_extra = None
                try:
                    # HTTPError provides a file-like .read() returning bytes
                    body_bytes = e.read() if hasattr(e, 'read') else None
                    if body_bytes:
                        try:
                            body_json = json.loads(body_bytes)
                            # Prefer common error fields
                            err_extra = body_json.get('error')
                        except Exception:
                            # Not JSON; include as text snippet
                            text_snip = body_bytes.decode(errors='replace')
                            err_extra = text_snip[:200]
                except Exception:
                    err_extra = None

                base_msg = f"Lambda HTTP error: {getattr(e, 'code', 'N/A')} {getattr(e, 'reason', '')}"
                if err_extra:
                    base_msg = f"{base_msg} | lambda_error: {err_extra}"

                print(f"[LambdaProxyPlugin] {base_msg}", file=sys.stdout)
                # Return error to client including the extra info when available
                client_msg = base_msg
                self._send_error_response(502, "Bad Gateway", client_msg)
                return None
            except urllib.error.URLError as e:
                msg = f"Lambda URL error: {e.reason}"
                print(f"[LambdaProxyPlugin] {msg}", file=sys.stdout)
                self._send_error_response(502, "Bad Gateway", msg)
                return None
            except Exception as e:
                print("[LambdaProxyPlugin] Unexpected error when calling Lambda:", file=sys.stdout)
                traceback.print_exc()
                self._send_error_response(500, "Internal Server Error", str(e))
                return None
            # Default: should not reach here, but return None to avoid fallback.
            return None

    # Prefer non-blocking embedded context manager which gives access to flags.port
    # and shuts down cleanly on context exit. If the API is not available, fall
    # back to proxy.main which blocks until shutdown.
    try:
        # Proxy accepts kwargs such as hostname and port according to docs.
        def make_plugin_class(lambda_url: str):
            class ConfiguredLambdaProxyPlugin(LambdaProxyPlugin):
                def __init__(self, uid, flags, client, event_queue, *a, **kw):
                    # proxy.py core will call this constructor with required
                    # runtime arguments. Call parent initializer and attach
                    # the configured lambda_url for use in request handling.
                    super().__init__(uid, flags, client, event_queue, *a, **kw)
                    self.lambda_url = lambda_url
            return ConfiguredLambdaProxyPlugin

        PluginClass = make_plugin_class(args.lambda_url)
        with proxy.Proxy(hostname=host_obj, port=args.port, plugins=[PluginClass]) as p:
            bound_port = getattr(p.flags, "port", args.port)
            print(f"proxy.py running on {args.host}:{bound_port} (press Ctrl-C to stop)")
            # sleep_loop blocks until interrupted
            proxy.sleep_loop()
    except Exception:
        # Fallback to blocking main()
        try:
            print(f"Starting proxy.main on {args.host}:{args.port}")
            PluginClass = make_plugin_class(args.lambda_url)
            proxy.main(hostname=host_obj, port=args.port, plugins=[PluginClass])
        except Exception as e:  
            print(f"Failed to start proxy.py: {e}", file=sys.stderr)
            sys.exit(1)


if __name__ == "__main__":
    main()
