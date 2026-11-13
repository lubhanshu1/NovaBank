/**
 * NovaBank - Frontend API Client
 * Wraps all Flask REST endpoints with fetch(), error handling, and toast notifications.
 */

const API_BASE = '/api';

// Currency Formatter (Indian Rupee - INR)
function formatINR(val) {
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 2
  }).format(val || 0);
}
window.formatINR = formatINR;
window.formatUSD = formatINR; // Alias to prevent legacy breaks

// Toast Notifications
function showToast(message, type = 'info') {
  const container = document.getElementById('toast-container');
  if (!container) return;

  const toast = document.createElement('div');
  toast.className = `toast toast-${type}`;
  
  let icon = 'ℹ️';
  if (type === 'success') icon = '✅';
  if (type === 'error') icon = '❌';

  toast.innerHTML = `
    <span>${icon}</span>
    <div style="flex: 1;">${message}</div>
  `;

  container.appendChild(toast);

  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateX(100%)';
    toast.style.transition = 'all 0.3s ease-out';
    setTimeout(() => toast.remove(), 300);
  }, 4000);
}

async function request(endpoint, options = {}) {
  const url = `${API_BASE}${endpoint}`;
  const headers = {
    'Content-Type': 'application/json',
    ...(options.headers || {})
  };

  try {
    const res = await fetch(url, { ...options, headers });
    const data = await res.json().catch(() => ({}));

    if (!res.ok) {
      const errMsg = data.message || `Server returned error (${res.status})`;
      throw new Error(errMsg);
    }
    return data;
  } catch (err) {
    showToast(err.message, 'error');
    throw err;
  }
}

const api = {
  // Health
  getHealth: () => request('/health'),

  // Auth / Persona
  switchPersona: (username) => request('/auth/demo-switch', {
    method: 'POST',
    body: JSON.stringify({ username })
  }),

  // Analytics & Views
  getSummary: () => request('/analytics/summary'),
  getDailyMetrics: () => request('/analytics/daily-metrics'),
  getHighRisk: () => request('/analytics/high-risk'),
  getBranchPerformance: () => request('/analytics/branch-performance'),

  // Accounts
  getAccounts: (customerId = null) => request(`/accounts${customerId ? `?customer_id=${customerId}` : ''}`),
  getAccountDetail: (accountNumber) => request(`/accounts/${accountNumber}`),
  openAccount: (payload) => request('/accounts', { method: 'POST', body: JSON.stringify(payload) }),
  updateAccountStatus: (accountNumber, status) => request(`/accounts/${accountNumber}/status`, {
    method: 'POST',
    body: JSON.stringify({ status })
  }),
  getCustomers: () => request('/accounts/meta/customers'),
  getBranches: () => request('/accounts/meta/branches'),

  // Transactions & Stored Procedures
  getTransactions: (filters = {}) => {
    const params = new URLSearchParams(filters);
    return request(`/transactions?${params.toString()}`);
  },
  transfer: (payload) => request('/transactions/transfer', { method: 'POST', body: JSON.stringify(payload) }),
  deposit: (payload) => request('/transactions/deposit', { method: 'POST', body: JSON.stringify(payload) }),
  withdraw: (payload) => request('/transactions/withdraw', { method: 'POST', body: JSON.stringify(payload) }),
  getBeneficiaries: (customerId) => request(`/transactions/beneficiaries${customerId ? `?customer_id=${customerId}` : ''}`),

  // Loans
  getLoans: (customerId = null) => request(`/loans${customerId ? `?customer_id=${customerId}` : ''}`),
  applyLoan: (payload) => request('/loans/apply', { method: 'POST', body: JSON.stringify(payload) }),
  payLoan: (loanId, payload) => request(`/loans/${loanId}/pay`, { method: 'POST', body: JSON.stringify(payload) }),

  // Audit Logs (Triggers)
  getAuditLogs: (limit = 50) => request(`/audit/logs?limit=${limit}`),

  // DBMS Lab Endpoints
  runQuery: (query) => request('/lab/query-runner', { method: 'POST', body: JSON.stringify({ query }) }),
  testAtomicity: (payload) => request('/lab/acid/atomicity', { method: 'POST', body: JSON.stringify(payload) }),
  testConsistency: (scenario) => request('/lab/acid/consistency', { method: 'POST', body: JSON.stringify({ scenario }) }),
  testIsolation: (level) => request('/lab/acid/isolation', { method: 'POST', body: JSON.stringify({ level }) }),
  testDeadlock: () => request('/lab/concurrency/deadlock', { method: 'POST' }),
  runInterestBatch: () => request('/lab/batch/interest', { method: 'POST' }),
  getNormalization: () => request('/lab/normalization')
};

window.api = api;
window.showToast = showToast;

