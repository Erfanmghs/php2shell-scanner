# php2shell-scanner

ابزار خط فرمان برای ارزیابی **مجاز** میزبان‌های PHP در برابر RCEهای هسته‌ای PHP2Shell (**CVE-2026-109618** و **CVE-2026-109619**). پس از افشای عمومی، برای پایش سریع دارایی‌های داخلی قبل از پچ کامل و بدون نیاز به اکسploit عمومی روی هر هدف ساخته شده است. فقط روی سیستم‌هایی که مالکیت یا مجوز کتبی تست دارید اجرا کنید.

محل کار محلی: پوشه `php2shell-scanner/` (همان clone). انتشار به ریشه repo: `./sync-from-workdir.sh` — محتوای `dev/` push نمی‌شود.

## نصب و اجرا

```bash
pip install -r requirements.txt
python3 scanner.py -u https://example.com
python3 scanner.py -l hosts.txt -t 20 -o results.json
```

**سوییچ‌های مهم:** `-u` / `-l` (هدف یا فایل لیست)، `-t` (thread، پیش‌فرض ۱۰)، `--timeout`، `-o` (JSON)، `-H` (هدر سفارشی)، `-k` (نادیده گرفتن TLS)، `--follow-redirects`، `--sapi auto|mod_php|fpm`، `--path` / `--path-file`، `-v` / `-q` / `--all-results` / `--no-color`.

## تکنیک‌هایی که اسکنر برای تشخیص به کار می‌برد

- **پروب multipart کنترل** — درخواست کوچک برای baseline پاسخ
- **پروب multipart با نام فیلد تو در تو (۶۲ سطح آرایه PHP)** — فشار حافظه در پارسر RFC1867 (مسیر CVE-2026-109618)
- **افزایش اندازه پروب (حدود ۱ / ۸ / ۲۰ مگابایت)** — تا رسیدن به امضای exhaustion یا تفاوت پاسخ
- **تشخیص خطای `Allowed memory size … exhausted` / `Unknown on line 0`**
- **قواعد verdict جدا برای mod_php و PHP-FPM** (`--sapi`)
- **استخراج نسخه PHP از هدر Server** و مقایسه با نسخه‌های پچ‌شده (۸.۲.۳۵، ۸.۳.۳۶، ۸.۴.۲۷، ۸.۵.۱۲)
- **نشانه‌های session upload progress** در زنجیره‌های مرتبط (فیلدهای `PHP_SESSION_UPLOAD_PROGRESS` / `PHPSESSID` در PoCهای عمومی)

## مسیرهایی که بررسی می‌شوند

- **`/index.php`** — پیش‌فرض وقتی مسیر در URL نباشد
- **مسیر داخل URL** — اگر در `-u` مسیر بدهید، همان حفظ می‌شود
- **`--path` / `--path-file`** — مسیرهای سفارشی (چندبار `--path` یا یک فایل خط‌به‌خط)
- **`/show_config_errors.php`** — در صورت تشخیص phpMyAdmin، تست تکمیلی خودکار

## نکات برای تیم Defense

- **WAF / پروکسی:** POSTهای `multipart/form-data` با فیلدهای **`PHP_SESSION_UPLOAD_PROGRESS`**، **`PHPSESSID`** غیرعادی، تعداد part زیاد، نام فیلد با براکت تو در تو عمیق، یا بدنه چند مگابایتی نسبت به baseline اپلیکیشن.
- **لاگ PHP:** `Fatal error: Allowed memory size … exhausted` همراه **`Unknown on line 0`** (قبل از اجرای اسکript اپ)؛ burst کوتاه از این خطاها از یک IP.
- **وب‌سرور:** Segfault worker (مثلاً signal 11) پس از POSTهای بزرگ.
- **EDR / Auditd:** **`sh`/`bash` فرزند `apache2`، `php-fpm` یا worker مشابه** — اولویت بالاتر از خود اسکن.
- **پاسخ HTTP:** `Set-Cookie: PHPSESSID=` با مقدار غیرمعمول طولانی یا باینری (مرحله افشای حافظه در زنجیره‌های عمومی).
- **محدودیت:** پچ کامل = ارتقای PHP؛ قوانین SOC جایگزین آپدیت نیستند.

## مجوز

کد `scanner.py` تحت [MIT License](LICENSE) است (مبتنی بر منطق تشخیص عمومی PHP2Shell).
