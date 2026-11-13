/**
 * NovaBank - Accounts & Clients Module
 * Manages accounts ledger, account creation (sp_open_account), and status updates (INR).
 */

let allAccounts = [];

async function loadAccounts() {
  try {
    const data = await api.getAccounts();
    if (data.success) {
      allAccounts = data.accounts;
      renderAccountsTable(allAccounts);
      populateAccountDropdowns(allAccounts);
      document.getElementById('accounts-count-badge').textContent = `${allAccounts.length} Accounts`;
    }
  } catch (err) {
    console.error('Failed to load accounts:', err);
  }
}

function renderAccountsTable(accounts) {
  const tbody = document.getElementById('tbody-accounts');
  if (!tbody) return;

  if (!accounts || accounts.length === 0) {
    tbody.innerHTML = '<tr><td colspan="9" class="text-center text-muted">No accounts found matching criteria.</td></tr>';
    return;
  }

  tbody.innerHTML = accounts.map(a => {
    let statusBadge = 'badge-success';
    if (a.status === 'FROZEN') statusBadge = 'badge-danger';
    if (a.status === 'DORMANT') statusBadge = 'badge-warning';

    const toggleStatusTarget = a.status === 'ACTIVE' ? 'FROZEN' : 'ACTIVE';
    const toggleLabel = a.status === 'ACTIVE' ? 'Freeze' : 'Unfreeze';
    const toggleBtnClass = a.status === 'ACTIVE' ? 'btn-danger' : 'btn-success';

    return `
      <tr>
        <td><strong><code>${a.account_number}</code></strong></td>
        <td>
          <div style="font-weight: 600;">${a.customer_name}</div>
          <small class="text-muted">${a.customer_tier} &bull; ${a.customer_email}</small>
        </td>
        <td>${a.branch_name} <small class="text-muted">(${a.branch_city})</small></td>
        <td><span class="badge">${a.account_type}</span></td>
        <td class="font-mono" style="font-weight: 700;">${formatINR(a.balance)}</td>
        <td class="font-mono text-muted">${formatINR(a.minimum_balance)}</td>
        <td><span class="text-primary font-mono">${a.interest_rate}%</span></td>
        <td><span class="badge ${statusBadge}">${a.status}</span></td>
        <td>
          <button class="btn btn-xs ${toggleBtnClass}" onclick="toggleAccountStatus('${a.account_number}', '${toggleStatusTarget}')">
            ${toggleLabel}
          </button>
        </td>
      </tr>
    `;
  }).join('');
}

function filterAccounts() {
  const search = document.getElementById('filter-accounts-search').value.toLowerCase();
  const filtered = allAccounts.filter(a => {
    return a.account_number.toLowerCase().includes(search) ||
           a.customer_name.toLowerCase().includes(search) ||
           a.branch_city.toLowerCase().includes(search) ||
           a.account_type.toLowerCase().includes(search);
  });
  renderAccountsTable(filtered);
}

function populateAccountDropdowns(accounts) {
  const fromSelect = document.getElementById('transfer-from-account');
  const toSelect = document.getElementById('transfer-to-account');
  const cashSelect = document.getElementById('cash-account-select');
  const loanAccSelect = document.getElementById('loan-account-select');

  const options = accounts.map(a => 
    `<option value="${a.account_number}">${a.account_number} - ${a.customer_name} (${formatINR(a.balance)} &bull; ${a.account_type})</option>`
  ).join('');

  if (fromSelect) fromSelect.innerHTML = options;
  if (toSelect) {
    toSelect.innerHTML = options;
    if (toSelect.options.length > 1) toSelect.selectedIndex = 1;
  }
  if (cashSelect) cashSelect.innerHTML = options;
  if (loanAccSelect) {
    loanAccSelect.innerHTML = accounts.map(a => `<option value="${a.account_id}">${a.account_number} - ${a.customer_name}</option>`).join('');
  }
}

async function populateModalDropdowns() {
  try {
    const custData = await api.getCustomers();
    const branchData = await api.getBranches();

    const custSelect = document.getElementById('open-customer-select');
    const loanCustSelect = document.getElementById('loan-customer-select');
    if (custData.success && custSelect) {
      const opts = custData.customers.map(c => `<option value="${c.customer_id}">${c.full_name} (${c.customer_number} &bull; ${c.customer_tier})</option>`).join('');
      custSelect.innerHTML = opts;
      if (loanCustSelect) loanCustSelect.innerHTML = opts;
    }

    const branchSelect = document.getElementById('open-branch-select');
    if (branchData.success && branchSelect) {
      branchSelect.innerHTML = branchData.branches.map(b => `<option value="${b.branch_id}">${b.branch_name} (${b.city})</option>`).join('');
    }
  } catch (err) {
    console.error('Failed to populate meta dropdowns:', err);
  }
}

async function toggleAccountStatus(accountNumber, newStatus) {
  try {
    const res = await api.updateAccountStatus(accountNumber, newStatus);
    if (res.success) {
      showToast(res.message, 'success');
      loadAccounts();
      if (window.loadDashboard) window.loadDashboard();
    }
  } catch (err) {}
}

async function handleOpenAccount(e) {
  e.preventDefault();
  const payload = {
    customer_id: parseInt(document.getElementById('open-customer-select').value),
    branch_id: parseInt(document.getElementById('open-branch-select').value),
    account_type: document.getElementById('open-type-select').value,
    initial_deposit: parseFloat(document.getElementById('open-initial-deposit').value),
    minimum_balance: parseFloat(document.getElementById('open-min-balance').value),
    interest_rate: document.getElementById('open-type-select').value === 'SAVINGS' ? 4.50 : 3.00
  };

  try {
    const res = await api.openAccount(payload);
    if (res.success) {
      showToast(`Account ${res.account_number} created via ${res.procedure_used}!`, 'success');
      document.getElementById('modal-open-account').classList.remove('active');
      document.getElementById('form-open-account').reset();
      loadAccounts();
      if (window.loadDashboard) window.loadDashboard();
    }
  } catch (err) {}
}

window.loadAccounts = loadAccounts;
window.filterAccounts = filterAccounts;
window.toggleAccountStatus = toggleAccountStatus;
window.handleOpenAccount = handleOpenAccount;
window.populateModalDropdowns = populateModalDropdowns;
