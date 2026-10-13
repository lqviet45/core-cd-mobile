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
console.log('Xong.');
