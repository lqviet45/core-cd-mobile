#!/usr/bin/env node
// Kiểm thử đầu-cuối app khách hàng (bản web) với backend THẬT. Chỉ để dev, không phải mã phát hành.
//
//   1) backend chạy ở :5080 với Cors__AllowedOrigins__0=http://localhost:8099, đã seed bằng
//      SEED=1 node tool/capture_customer_fixtures.mjs   (SĐT 0901234567 / mật khẩu Matkhau#Demo2026)
//   2) flutter build web --target=tool/verify/verify_customer_web_main.dart \
//        --dart-define=API_BASE_URL=http://localhost:5080 "--dart-define=SUPPORT_PHONE=1900 1234" --output=build/web_customer
//   3) (cd build/web_customer && python3 -m http.server 8099) &
//   4) PLAYWRIGHT=/đường/dẫn/node_modules/playwright/index.mjs CHROME=/đường/dẫn/chrome OUT=/tmp/shots node tool/verify/customer_web_e2e.mjs
//
// Giao diện canvas (không có DOM) nên thao tác theo toạ độ ở viewport 390×844 và kiểm bằng lưu lượng API + ảnh chụp.
import { mkdirSync } from 'node:fs';

const { chromium } = await import(process.env.PLAYWRIGHT ?? 'playwright');
const OUT = process.env.OUT ?? '/tmp/customer-e2e';
const URL_ = process.env.URL_ ?? 'http://localhost:8099/';
mkdirSync(OUT, { recursive: true });

const browser = await chromium.launch({ executablePath: process.env.CHROME, args: ['--no-sandbox'] });
const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, colorScheme: process.env.DARK ? 'dark' : 'light' });
const p = await ctx.newPage();
const calls = [];
const errors = [];
p.on('response', (r) => { const u = new URL(r.url()); if (u.pathname.startsWith('/api/')) calls.push(`${r.request().method()} ${u.pathname} ${r.status()}`); });
p.on('pageerror', (e) => errors.push(String(e).slice(0, 200)));
const shot = async (n) => { await p.waitForTimeout(1200); await p.screenshot({ path: `${OUT}/${n}.png` }); };
const tab = (i) => p.mouse.click([49, 146, 244, 341][i], 805);
const checks = [];
const check = (name, ok) => { checks.push([name, ok]); console.log(ok ? '✓' : '✗', name); };
const saw = (re) => calls.some((c) => re.test(c));

await p.goto(`${URL_}?nobio=1`);
await p.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 60000 });
await p.waitForTimeout(3000);
await shot('01_login');

// Quên mật khẩu → có nút gọi hotline
await p.mouse.click(195, 611); await shot('02_forgot');
await p.keyboard.press('Escape'); await p.waitForTimeout(600);

// Sai mật khẩu → 401, thông báo chung
await p.mouse.click(200, 382); await p.keyboard.type('0901234567');
await p.mouse.click(180, 480); await p.keyboard.type('SaiMatKhau#1');
await p.mouse.click(195, 553); await shot('03_wrong');
check('đăng nhập sai → 401', saw(/auth\/login 401/));

// Đúng → vào Trang chủ
await p.mouse.click(180, 480); await p.keyboard.press('Control+A'); await p.keyboard.type(process.env.PASS ?? 'Matkhau#Demo2026');
await p.mouse.click(195, 627); await p.waitForTimeout(3000); await shot('04_home');
check('đăng nhập đúng → 200', saw(/auth\/login 200/));
check('tải me/summary/upcoming/certificates', ['me', 'summary', 'upcoming', 'certificates'].every((x) => saw(new RegExp(`customer/${x} 200`))));

await tab(1); await shot('05_certs');
await p.mouse.click(195, 250); await p.waitForTimeout(1500); await shot('06_cert_detail');
check('chi tiết CCTG + lịch lãi', saw(/customer\/certificates\/[0-9a-f-]{36} 200/));
await p.keyboard.press('Alt+ArrowLeft'); await p.goBack().catch(() => {}); await p.waitForTimeout(800);
await tab(2); await shot('07_calendar');
await tab(3); await shot('08_account');
// Lịch sử giao dịch
await p.mouse.click(195, 685); await p.waitForTimeout(1500); await shot('09_transactions');
check('lịch sử giao dịch', saw(/customer\/transactions 200/));

console.log('\nAPI:\n' + [...new Set(calls)].join('\n'));
check('không có lỗi JS chưa bắt', errors.length === 0);
if (errors.length) console.log(errors.join('\n'));
await browser.close();
process.exit(checks.every(([, ok]) => ok) ? 0 : 1);
