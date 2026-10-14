#!/usr/bin/env node
// Fixture THẬT cho app khách hàng (test/fixtures/customer/*.json) từ một backend dev đang chạy.
//
// Hai bước vì OTP chỉ được gửi qua SMS (dev: `Otp:Provider=Log` ghi mã vào log của API):
//   1) API=http://localhost:5080 PASS=<mật khẩu admin> [SEED=1] PHONE=0901234567 node tool/capture_customer_fixtures.mjs
//      → (SEED=1: tạo khách + CCTG + giao dịch thử), bật quyền app cho khách, xin OTP rồi dừng.
//   2) đọc mã OTP trong log API rồi chạy lại bước 1 kèm OTP_CODE=<mã>  → đăng nhập và lưu fixture.
// CHỈ dùng với dữ liệu thử nghiệm. Token được thay bằng giá trị giả.
import { mkdirSync, writeFileSync } from 'node:fs';

const API = process.env.API ?? 'http://localhost:5080';
const USER = process.env.USER_NAME ?? 'admin';
const PASS = process.env.PASS;
const PHONE = process.env.PHONE ?? '0901234567';
const CODE = process.env.OTP_CODE;
if (!PASS) { console.error('Thiếu PASS (mật khẩu tài khoản nhân viên thử nghiệm).'); process.exit(1); }
const OUT = new URL('../test/fixtures/customer/', import.meta.url).pathname;
mkdirSync(OUT, { recursive: true });
const save = (name, data) => { writeFileSync(`${OUT}${name}.json`, JSON.stringify(data, null, 2) + '\n'); console.log('✓', name); };

const json = { 'Content-Type': 'application/json' };
async function call(method, path, { token, body, headers } = {}) {
  const r = await fetch(`${API}${path}`, { method, headers: { ...json, ...(token ? { Authorization: `Bearer ${token}` } : {}), ...headers }, body: body === undefined ? undefined : JSON.stringify(body) });
  const text = await r.text();
  if (!r.ok) throw new Error(`${method} ${path} → ${r.status} ${text.slice(0, 200)}`);
  return text ? JSON.parse(text) : null;
}

// ── nhân viên: dữ liệu thử + bật quyền app ──
const staff = (await call('POST', '/api/auth/login', { body: { username: USER, password: PASS, deviceName: 'fixture-capture' } })).accessToken;
let customerId;
if (process.env.SEED === '1') {
  const sfx = Date.now().toString().slice(-6);
  customerId = (await call('POST', '/api/customers', { token: staff, body: { customerType: 'Individual', cif: `K${sfx}`, fullName: 'Nguyễn Thị Lan', identityNumber: `07920${sfx}1`, email: `lan${sfx}@example.com`, phone: PHONE, address: '12 Lê Lợi, Quận 1, TP.HCM' } })).id;
  const policies = (await call('GET', '/api/interest-rate-policies?pageSize=50', { token: staff })).items;
  const pick = (name) => policies.find((p) => p.termName === name).id;
  const today = new Date().toISOString().slice(0, 10);
  const mat = new Date(Date.now() + 400 * 864e5).toISOString().slice(0, 10);
  for (const [policy, principal] of [[pick('12 tháng - Trả hàng tháng'), 200_000_000], [pick('12 tháng'), 100_000_000]]) {
    const lot = await call('POST', '/api/cdlots', { token: staff, body: { interestRatePolicyId: policy, totalFaceValue: 5_000_000_000, minPurchaseAmount: 1_000_000, issueDate: today, maturityDate: mat, description: 'fixture' } });
    await call('POST', '/api/certificates', { token: staff, body: { customerId, lotId: lot.id, principal, issueDate: today, notes: 'fixture' } });
  }
  const lot = await call('POST', '/api/cdlots', { token: staff, body: { interestRatePolicyId: pick('12 tháng'), totalFaceValue: 1_000_000_000, minPurchaseAmount: 1_000_000, issueDate: today, maturityDate: mat, description: 'fixture buy' } });
  await call('POST', '/api/transactions/buy', { token: staff, headers: { 'Idempotency-Key': crypto.randomUUID() }, body: { customerId, lotId: lot.id, principal: 20_000_000, issueDate: today, channel: 'WEB' } });
} else {
  const found = (await call('GET', `/api/customers?pageSize=100&searchTerm=${encodeURIComponent(PHONE)}`, { token: staff })).items;
  if (found.length === 0) { console.error(`Không thấy khách có số ${PHONE}; chạy với SEED=1.`); process.exit(1); }
  customerId = found[0].id;
}
await call('PUT', `/api/customers/${customerId}/app-access`, { token: staff, body: { phone: PHONE } });

// ── khách: OTP ──
if (!CODE) {
  const r = await call('POST', '/api/customer/auth/otp/request', { body: { phone: PHONE } });
  console.log('Đã xin OTP', r, '\nĐọc mã trong log API rồi chạy lại với OTP_CODE=<mã>.');
  process.exit(0);
}
const login = await call('POST', '/api/customer/auth/otp/verify', { body: { phone: PHONE, code: CODE, deviceName: 'fixture-capture' } });
save('auth_verify', { ...login, accessToken: 'ACCESS_TOKEN', refreshToken: 'REFRESH_TOKEN' });
const token = login.accessToken;
const get = (p) => call('GET', p, { token });

save('me', await get('/api/customer/me'));
save('summary', await get('/api/customer/summary'));
const certs = await get('/api/customer/certificates?scope=Holding');
save('certificates_page', certs);
const monthly = certs.items.find((c) => c.paymentMethod === 'Monthly') ?? certs.items[0];
const atMaturity = certs.items.find((c) => c.paymentMethod === 'AtMaturity');
save('certificate_detail', await get(`/api/customer/certificates/${monthly.id}`));
save('interest_schedule_monthly', await get(`/api/customer/certificates/${monthly.id}/interest-schedule`));
if (atMaturity) save('interest_schedule_at_maturity', await get(`/api/customer/certificates/${atMaturity.id}/interest-schedule`));
const trxs = await get('/api/customer/transactions');
save('transactions_page', trxs);
if (trxs.items[0]) save('transaction_detail', await get(`/api/customer/transactions/${trxs.items[0].id}`));
save('documents_empty', await get(`/api/customer/certificates/${monthly.id}/documents`));
