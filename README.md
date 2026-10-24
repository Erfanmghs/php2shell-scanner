# php2shell-scanner

Command-line tool for **authorized** assessment of PHP hosts against core PHP2Shell RCEs (**CVE-2026-109618** and **CVE-2026-109619**). Built for rapid internal asset monitoring after public disclosure, before full patching, without dropping a full exploit chain on every target. Run only on systems you own or have written permission to test.

**Maintainers:** optional nested workdir at `php2shell-scanner/` (gitignored). Publish `scanner.py`, `requirements.txt`, `README.md`, and `LICENSE` into the repo root with `./sync-from-workdir.sh [path]`; `dev/` is never copied.

## Download and install

Get the source from GitHub (clone or ZIP):

```bash
git clone https://github.com/Erfanmghs/php2shell-scanner.git
cd php2shell-scanner
```

Requirements: **Python 3.9+**. Install dependencies, then run the scanner:

```bash
python3 -m pip install -r requirements.txt
python3 scanner.py -u https://example.com
```

Optional: create a virtual environment first (`python3 -m venv .venv && source .venv/bin/activate` on Linux/macOS).

Bulk example:

```bash
python3 scanner.py -l hosts.txt -t 20 -o results.json
```

## CLI options

| Option | Description |
|--------|-------------|
| `-u`, `--url` | Single URL or hostname to scan (scheme optional; bare hosts get `https://`). Mutually exclusive with `-l`. |
| `-l`, `--list` | Path to a text file with one host/URL per line (`#` comments ignored). Mutually exclusive with `-u`. |
| `-t`, `--threads` | Concurrent workers (default: `10`). |
| `--timeout` | Per-request timeout in seconds (default: `60`). |
| `-o`, `--output` | Write results to a JSON file. |
| `--all-results` | With `-o`, include every host; default JSON output keeps **vulnerable** hits only. |
| `-k`, `--insecure` | Do not verify TLS certificates. |
| `--follow-redirects` | Follow up to 10 redirects; sensitive headers are stripped on cross-origin hops. |
| `-H`, `--header` | Custom header `Name: value` (repeatable). Use for auth instead of credentials in URLs. |
| `-v`, `--verbose` | Print verdict reasons and response snippets. |
| `-q`, `--quiet` | Print only vulnerable hosts. |
| `--no-color` | Disable ANSI colors (also off when stdout is not a TTY). |
| `--sapi` | Verdict heuristics: `auto` (default), `mod_php`, or `fpm`. |
| `--path` | Extra URL path to test (repeatable). Requires `-u`/`-l` URL without forcing only that path. |
| `--path-file` | File with one path per line (same semantics as `--path`). |

If the URL has no path, the scanner uses **`/index.php`**. Paths from `-u` are kept as given.

## What the scanner sends (offensive / assessment view)

Summary of the **live HTTP checks** (detection only — no shell payload in this tool):

| Stage | Method / shape | Technical load |
|-------|----------------|----------------|
| **Control probe** | `POST` `multipart/form-data; boundary=x` | Minimal body (~tens of bytes): one part with `Content-Disposition: name=a; filename=` — establishes baseline status, body size, and `X-Powered-By`. |
| **phpMyAdmin pivot** | Same control on retargeted URL | If the control response body contains `phpMyAdmin`, retest **`/show_config_errors.php`**. |
| **PHP2Shell probes (×3)** | `POST` `multipart/form-data; boundary=` (empty boundary string) | Escalating bodies: **~1 MiB / 4000 parts**, **~8 MiB / 1020 parts**, **~20 MiB / 1020 parts**. Each part uses a deeply nested field name: `a[]` plus **62** `[a]` segments (RFC1867 / array notation) to stress the multipart parser (**CVE-2026-109618** class behavior). Remaining bytes are padding lines (`x:`) to hit the target size. Upload is streamed in **64 KiB** chunks over **HTTP/1.1** (ALPN locked to HTTP/1.1 on HTTPS). |
| **Crash / weakness signals** | Response diff vs control | In-band **`Allowed memory size … exhausted`** with **`Unknown`** (parser-time fatal); **HTTP 500** with empty body while control had body; under **PHP-FPM** rules also **502/503/504** or **200** with empty body after a non-empty control — interpreted as worker death mid-parse. |
| **Version fallback** | Header parsing | `X-Powered-By` / `Server` **`PHP/x.y.z`** compared to fixed releases: **8.2.35**, **8.3.36**, **8.4.27**, **8.5.12** — can mark **FIXED** or **VULNERABLE** when no crash signal fires. |
| **Early exit** | Status filter | Probes stopped as **INCONCLUSIVE** if the edge returns **400, 403, 411, 413, 414, 417, 422, 429, 431** before PHP handles the body. |

Verdicts: **VULNERABLE**, **FIXED**, **NO SIGNAL**, **INCONCLUSIVE**, **ERROR**. JSON output includes probe metadata (sizes, bytes sent, HTTP status).

This scanner does **not** emit full public exploit chains (e.g. session upload progress gadgets); it focuses on **parser/memory crash signatures** and **version exposure** suitable for safe mass triage.

## Paths checked

- **`/index.php`** — default when the URL has no path
- **Path in `-u`** — preserved on the target host
- **`--path` / `--path-file`** — additional paths on each host
- **`/show_config_errors.php`** — after phpMyAdmin is detected in the control response

## Notes for defense teams

- **WAF / proxy:** Large `multipart/form-data` POSTs with an empty or unusual boundary, thousands of parts, field names with **deep `[…]` nesting**, and multi-megabyte bodies versus normal app traffic.
- **PHP logs:** `Fatal error: Allowed memory size … exhausted` with **`Unknown on line 0`** before application script lines; bursts from one source IP.
- **Web server:** Worker segfaults or **502/503/504** from PHP-FPM frontends after oversized multipart POSTs.
- **EDR / auditd:** Unexpected **`sh`/`bash`** children of `apache2`, `php-fpm`, or similar — treat as higher severity than the scan itself.
- **Limitation:** Definitive fix is upgrading PHP; detection rules do not replace patching.

## License

`scanner.py` is under the [MIT License](LICENSE) (based on public PHP2Shell detection logic).
