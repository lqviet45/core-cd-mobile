#!/usr/bin/env node
// Fixture THẬT cho app khách hàng (test/fixtures/customer/*.json) từ một backend dev đang chạy.
//
//   API=http://localhost:5080 PASS=<mật khẩu admin> [SEED=1] PHONE=0901234567 node tool/capture_customer_fixtures.mjs
//
// - SEED=1: tạo khách + CCTG (lãi tháng, lãi cuối kỳ, một CCTG tất toán sớm) + một lệnh mua thử.
// - Bật quyền app cho khách; nhận mật khẩu tạm → đăng nhập → bắt buộc đổi sang CUSTOMER_PASSWORD (mặc định
//   Matkhau#Demo2026). Khách đã kích hoạt từ trước (không có mật khẩu tạm) thì đăng nhập thẳng bằng CUSTOMER_PASSWORD.
// CHỈ dùng với dữ liệu thử nghiệm. Token được thay bằng giá trị giả.
import { mkdirSync, writeFileSync } from 'node:fs';

const API = process.env.API ?? 'http://localhost:5080';
const USER = process.env.USER_NAME ?? 'admin';
const PASS = process.env.PASS;
const PHONE = process.env.PHONE ?? '0901234567';
const CUSTOMER_PASSWORD = process.env.CUSTOMER_PASSWORD ?? 'Matkhau#Demo2026';
if (!PASS) { console.error('Thiếu PASS (mật khẩu tài khoản nhân viên thử nghiệm).'); process.exit(1); }
const OUT = new URL('../test/fixtures/customer/', import.meta.url).pathname;
mkdirSync(OUT, { recursive: true });
const save = (name, data) => { writeFileSync(`${OUT}${name}.json`, JSON.stringify(data, null, 2) + '\n'); console.log('✓', name); };
const scrub = (r) => ({ ...r, accessToken: 'ACCESS_TOKEN', refreshToken: 'REFRESH_TOKEN' });

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
  customerId = (await call('POST', '/api/customers', { token: staff, body: { customerType: 'Individual', cif: `K${sfx}`, fullName: 'Nguyễn Thị Lan', identityNumber: `07920${sfx}1`, email: `thu.lan${sfx}@example.com`, phone: PHONE, address: '12 Lê Lợi, Quận 1, TP.HCM' } })).id;
  const policies = (await call('GET', '/api/interest-rate-policies?pageSize=50', { token: staff })).items;
  const pick = (name) => policies.find((p) => p.termName === name).id;
  const today = new Date().toISOString().slice(0, 10);
  const day = (offset) => new Date(Date.now() + offset * 864e5).toISOString().slice(0, 10);
  const mat = day(300);
  const ago = day(-30);
  const openLot = (policy, issueDate = today, maturityDate = mat) => call('POST', '/api/cdlots', { token: staff, body: { interestRatePolicyId: policy, totalFaceValue: 5_000_000_000, minPurchaseAmount: 1_000_000, issueDate, maturityDate, description: 'fixture' } });
  for (const [policy, principal] of [[pick('12 tháng - Trả hàng tháng'), 200_000_000], [pick('12 tháng'), 100_000_000]]) {
    const lot = await openLot(policy);
    await call('POST', '/api/certificates', { token: staff, body: { customerId, lotId: lot.id, principal, issueDate: today, notes: 'fixture' } });
  }
  // CCTG thứ ba: tất toán sớm → đã đóng (có ngày tất toán + số tiền nhận).
  const lot3 = await openLot(pick('6 tháng'), ago);
  const closedId = await call('POST', '/api/certificates', { token: staff, body: { customerId, lotId: lot3.id, principal: 50_000_000, issueDate: ago, notes: 'fixture' } });
  await call('POST', `/api/certificates/${closedId.id ?? closedId}/redeem-early`, { token: staff, body: { redemptionDate: today, demandRate: 0.001 } });
  // CCTG sắp đáo hạn (3 ngày nữa): để có khoản "sắp tới" màu hổ phách.
  const lotSoon = await openLot(pick('1 tháng'), day(-27), day(3));
  await call('POST', '/api/certificates', { token: staff, body: { customerId, lotId: lotSoon.id, principal: 30_000_000, issueDate: day(-27), notes: 'fixture' } });
  const lot = await openLot(pick('12 tháng'));
  await call('POST', '/api/transactions/buy', { token: staff, headers: { 'Idempotency-Key': crypto.randomUUID() }, body: { customerId, lotId: lot.id, principal: 20_000_000, issueDate: today, channel: 'WEB' } });
} else {
  const found = (await call('GET', `/api/customers?pageSize=100&searchTerm=${encodeURIComponent(PHONE)}`, { token: staff })).items;
  if (found.length === 0) { console.error(`Không thấy khách có số ${PHONE}; chạy với SEED=1.`); process.exit(1); }
  customerId = found[0].id;
}
const access = await call('PUT', `/api/customers/${customerId}/app-access`, { token: staff, body: { phone: PHONE } });
save('app_access_enabled', { ...access, temporaryPassword: access.temporaryPassword ? 'TEMP_PASSWORD' : null });

// ── khách: đăng nhập (mật khẩu tạm → đổi mật khẩu) ──
let session;
if (access.temporaryPassword) {
  const first = await call('POST', '/api/customer/auth/login', { body: { identifier: PHONE, password: access.temporaryPassword, deviceName: 'fixture-capture' } });
  save('auth_login_first', scrub(first));
  // Chưa đổi mật khẩu thì mọi API khác bị chặn 403.
  const blocked = await fetch(`${API}/api/customer/me`, { headers: { Authorization: `Bearer ${first.accessToken}` } });
  if (blocked.status !== 403) throw new Error(`Mong đợi 403 khi chưa đổi mật khẩu, nhận ${blocked.status}`);
  save('problem_must_change_password', await blocked.json());
  session = await call('POST', '/api/customer/auth/change-password', { token: first.accessToken, body: { currentPassword: access.temporaryPassword, newPassword: CUSTOMER_PASSWORD, deviceName: 'fixture-capture' } });
} else {
  session = await call('POST', '/api/customer/auth/login', { body: { identifier: PHONE, password: CUSTOMER_PASSWORD, deviceName: 'fixture-capture' } });
}
save('auth_login', scrub(session));
const token = session.accessToken;
const get = (p) => call('GET', p, { token });

save('me', await get('/api/customer/me'));
save('summary', await get('/api/customer/summary'));
const holding = await get('/api/customer/certificates?scope=Holding');
save('certificates_holding', holding);
save('certificates_all', await get('/api/customer/certificates'));
const closed = await get('/api/customer/certificates?scope=Closed');
save('certificates_closed', closed);
const monthly = holding.items.find((c) => c.paymentMethod === 'Monthly') ?? holding.items[0];
const atMaturity = holding.items.find((c) => c.paymentMethod === 'AtMaturity');
save('certificate_detail', await get(`/api/customer/certificates/${monthly.id}`));
if (closed.items[0]) save('certificate_closed_detail', await get(`/api/customer/certificates/${closed.items[0].id}`));
save('interest_schedule_monthly', await get(`/api/customer/certificates/${monthly.id}/interest-schedule`));
if (atMaturity) save('interest_schedule_at_maturity', await get(`/api/customer/certificates/${atMaturity.id}/interest-schedule`));
save('upcoming_30', await get('/api/customer/upcoming?days=30'));
save('upcoming_90', await get('/api/customer/upcoming?days=90'));
save('upcoming_366', await get('/api/customer/upcoming?days=366'));
const trxs = await get('/api/customer/transactions');
save('transactions_page', trxs);
save('transactions_out', await get('/api/customer/transactions?direction=Out'));
if (trxs.items[0]) save('transaction_detail', await get(`/api/customer/transactions/${trxs.items[0].id}`));
save('documents_empty', await get(`/api/customer/certificates/${monthly.id}/documents`));
