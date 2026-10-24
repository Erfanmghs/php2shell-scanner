# php2shell-scanner

Command-line tool for **authorized** assessment of PHP hosts against core PHP2Shell RCEs (**CVE-2026-109618** and **CVE-2026-109619**). Built for rapid internal asset monitoring after public disclosure, before full patching, without requiring a public exploit against every target. Run only on systems you own or have written permission to test.

## Install and run

```bash
pip install -r requirements.txt
python3 scanner.py -u https://example.com
python3 scanner.py -l hosts.txt -t 20 -o results.json
```

**Key flags:** `-u` / `-l` (single target or host list file), `-t` (threads, default 10), `--timeout`, `-o` (JSON output), `-H` (custom headers), `-k` (ignore TLS verification), `--follow-redirects`, `--sapi auto|mod_php|fpm`, `--path` / `--path-file`, `-v` / `-q` / `--all-results` / `--no-color`.

## Detection techniques

- **Control multipart probe** — small request to establish a response baseline
- **Nested field-name multipart probe (62 levels of PHP array nesting)** — memory pressure on the RFC1867 parser (CVE-2026-109618 path)
- **Escalating probe sizes (~1 / 8 / 20 MB)** — until exhaustion signatures or response differences appear
- **Detection of `Allowed memory size … exhausted` / `Unknown on line 0` errors**
- **Separate verdict rules for mod_php and PHP-FPM** (`--sapi`)
- **PHP version extraction from the `Server` header** and comparison to patched releases (8.2.35, 8.3.36, 8.4.27, 8.5.12)
- **Session upload progress indicators** in related chains (`PHP_SESSION_UPLOAD_PROGRESS` / `PHPSESSID` fields in public PoCs)

## Paths checked

- **`/index.php`** — default when the URL has no path
- **Path in the URL** — preserved when you pass a path in `-u`
- **`--path` / `--path-file`** — custom paths (repeat `--path` or supply a line-delimited file)
- **`/show_config_errors.php`** — automatic follow-up when phpMyAdmin is detected

## Notes for defense teams

- **WAF / proxy:** `multipart/form-data` POSTs with **`PHP_SESSION_UPLOAD_PROGRESS`**, unusual **`PHPSESSID`**, many parts, deeply nested bracket field names, or multi-megabyte bodies relative to normal application traffic.
- **PHP logs:** `Fatal error: Allowed memory size … exhausted` with **`Unknown on line 0`** (before application script execution); short bursts of these errors from one IP.
- **Web server:** Worker segfaults (e.g. signal 11) after large POSTs.
- **EDR / auditd:** **`sh`/`bash` spawned by `apache2`, `php-fpm`, or similar workers** — higher priority than the scan itself.
- **HTTP responses:** `Set-Cookie: PHPSESSID=` with unusually long or binary values (memory disclosure stage in public chains).
- **Limitation:** full remediation is PHP upgrade; SOC rules do not replace patching.

## License

`scanner.py` is under the [MIT License](LICENSE) (based on public PHP2Shell detection logic).
