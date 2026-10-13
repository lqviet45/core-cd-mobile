#!/usr/bin/env node
// Lấy dữ liệu THẬT từ một backend đang chạy để làm fixture cho test DTO (test/fixtures/*.json).
// Dùng: API=http://localhost:5080 USER=admin PASS=... node tool/capture_fixtures.mjs
// Danh sách được cắt còn vài phần tử; token được thay bằng giá trị giả. Dữ liệu nên là dữ liệu thử nghiệm, không phải dữ liệu thật của khách.
import { mkdirSync, writeFileSync } from 'node:fs';

const API = process.env.API ?? 'http://localhost:5080';
const USER = process.env.USER_NAME ?? 'admin';
const PASS = process.env.PASS;
if (!PASS) { console.error('Thiếu PASS (mật khẩu tài khoản thử nghiệm).'); process.exit(1); }
const OUT = new URL('../test/fixtures/', import.meta.url).pathname;
mkdirSync(OUT, { recursive: true });

const save = (name, data) => { writeFileSync(`${OUT}${name}.json`, JSON.stringify(data, null, 2) + '\n'); console.log('✓', name); };
const trim = (page, n = 3) => ({ ...page, items: page.items.slice(0, n) });

const loginRes = await fetch(`${API}/api/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ username: USER, password: PASS, deviceName: 'fixture-capture' }) });
const login = await loginRes.json();
const token = login.accessToken;
save('auth_login', { ...login, accessToken: 'ACCESS_TOKEN', refreshToken: 'REFRESH_TOKEN' });

const get = async (path) => { const r = await fetch(`${API}${path}`, { headers: { Authorization: `Bearer ${token}` } }); if (!r.ok) throw new Error(`${path} → ${r.status}`); return r.json(); };

save('auth_me', await get('/api/auth/me'));
const dash = await get('/api/dashboard/summary');
save('dashboard_summary', { ...dash, recentTransactions: dash.recentTransactions.slice(0, 3), issuedLast30Days: dash.issuedLast30Days.slice(0, 5) });

const certs = await get('/api/certificates?pageSize=20');
save('certificates_page', trim(certs));
const monthly = certs.items.find((c) => c.paymentMethod === 'Monthly') ?? certs.items[0];
const closed = certs.items.find((c) => c.status === 'RedeemedEarly' || c.status === 'RedeemedAtMaturity');
save('certificate_detail', await get(`/api/certificates/${monthly.id}`));
if (monthly.paymentMethod !== 'AtMaturity') save('certificate_interest_schedule', await get(`/api/certificates/${monthly.id}/interest-schedule`));
if (closed) save('certificate_detail_redeemed', await get(`/api/certificates/${closed.id}`));

const customers = await get('/api/customers?pageSize=20');
save('customers_page', trim(customers));
const cust = customers.items.find((c) => c.totalCertificates > 0) ?? customers.items[0];
save('customer_detail', await get(`/api/customers/${cust.id}`));
save('customer_certificates', trim(await get(`/api/certificates?customerId=${cust.id}&pageSize=20`)));
save('customer_transactions', trim(await get(`/api/transactions?cif=${encodeURIComponent(cust.cif)}&pageSize=20`)));

const lots = await get('/api/cdlots');
save('lots_list', lots.slice(0, 4));
save('lots_summary', await get('/api/cdlots/summary'));
const lot = lots.find((l) => l.issuedFaceValue > 0) ?? lots[0];
save('lot_detail', await get(`/api/cdlots/${lot.id}`));
save('lot_stats', { ...(await get(`/api/cdlots/${lot.id}/stats`)) });

save('report_portfolio', await get('/api/reports/portfolio'));
save('report_upcoming', await get('/api/reports/upcoming-maturities?daysAhead=30'));
const to = new Date().toISOString().slice(0, 10);
const from = new Date(Date.now() - 90 * 864e5).toISOString().slice(0, 10);
save('report_liquidity', await get(`/api/reports/liquidity?dateFrom=${from}&dateTo=${to}&groupBy=Month`));

// ── Payload đọc cho luồng ghi (không đổi dữ liệu) ──
const today = new Date().toISOString().slice(0, 10);
const active = (await get('/api/certificates?status=Active&pageSize=50')).items.find((c) => new Date(c.maturityDate) > new Date());
if (active) {
  save('early_preview', await get(`/api/certificates/${active.id}/preview-early-redemption?redemptionDate=${today}&demandRate=0.001`));
  const post = async (path, body) => { const r = await fetch(`${API}${path}`, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` }, body: JSON.stringify(body) }); return r.json(); };
  save('sell_preview', await post('/api/transactions/sell/preview', { customerId: active.customerId, sellType: 'All', quantity: null, targetAmount: null, redemptionDate: today, demandRate: 0.001 }));
}
const trx = (await get('/api/transactions?pageSize=1')).items[0];
if (trx) save('transaction_detail', await get(`/api/transactions/${trx.id}`));
save('interest_summary', await get('/api/settlement/interest/summary'));
const overdue = await get('/api/settlement/interest/due?bucket=overdue&pageSize=3');
save('interest_due_overdue', overdue);

// ── Payload của lệnh GHI: chỉ chạy khi bật WRITES=1 (làm thay đổi dữ liệu thử nghiệm!) ──
if (process.env.WRITES === '1') {
  const w = async (path, body, headers = {}) => { const r = await fetch(`${API}${path}`, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}`, ...headers }, body: JSON.stringify(body) }); return { status: r.status, body: await r.json() }; };
  if (active) {
    const lotId = active.lotId;
    const b = await w('/api/transactions/buy', { customerId: active.customerId, lotId, principal: 1000000, issueDate: today, notes: null, channel: 'MOBILE' }, { 'Idempotency-Key': crypto.randomUUID() });
    save('buy_created', b.body);
  }
  const i = overdue.items[0];
  if (i) {
    const r = await w('/api/settlement/interest/bulk-pay', { items: [{ certificateId: i.certificateId, periodStart: i.periodStart, periodEnd: i.periodEnd }, { certificateId: i.certificateId, periodStart: '2020-01-01', periodEnd: '2020-02-01' }] });
    save('bulk_pay_result', r.body);
  }
  const c = await w('/api/customers', { customerType: 'Individual', cif: 'FX' + Date.now(), fullName: 'Khách thử', identityNumber: '0790000' + Date.now(), email: 'fx@example.com', phone: '0909000000', address: null });
  save('customer_created', c.body);
  const bad = await w('/api/customers', { customerType: 'Individual', cif: '', fullName: '', identityNumber: '', email: 'x', phone: '', address: null });
  save('problem_validation', bad.body);
}
console.log('Xong.');
