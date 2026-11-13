/**
 * NovaBank - Transactions & Transfers Module
 * Invokes stored procedures: sp_transfer_funds, sp_deposit_funds, sp_withdraw_funds (INR).
 */

async function loadTransactions() {
  const typeFilter = document.getElementById('filter-txn-type') ? document.getElementById('filter-txn-type').value : '';
  const filters = { limit: 100 };
  if (typeFilter) filters.type = typeFilter;

  try {
    const data = await api.getTransactions(filters);
    if (data.success) {
      renderTransactionsTable(data.transactions);
    }
  } catch (err) {
    console.error('Failed to load transactions:', err);
  }
}

function renderTransactionsTable(txns) {
  const tbody = document.getElementById('tbody-full-txns');
  if (!tbody) return;

  if (!txns || txns.length === 0) {
    tbody.innerHTML = '<tr><td colspan="9" class="text-center text-muted">No transactions found matching criteria.</td></tr>';
    return;
  }

  tbody.innerHTML = txns.map(t => {
    const isCredit = ['DEPOSIT', 'TRANSFER_IN', 'INTEREST_CREDIT', 'LOAN_DISBURSEMENT'].includes(t.transaction_type);
    const colorClass = isCredit ? 'text-success' : 'text-danger';
    const sign = isCredit ? '+' : '-';

    return `
      <tr>
        <td><strong><code>${t.reference_no}</code></strong></td>
        <td><code>${t.account_number}</code> <small class="text-muted">(${t.account_type})</small></td>
        <td style="font-weight: 500;">${t.customer_name}</td>
        <td><span class="badge">${t.transaction_type}</span></td>
        <td class="${colorClass} font-mono" style="font-weight: 700;">${sign}${formatINR(t.amount)}</td>
        <td class="font-mono text-muted">${formatINR(t.balance_before)}</td>
        <td class="font-mono" style="font-weight: 600;">${formatINR(t.balance_after)}</td>
        <td><span class="badge">${t.channel}</span></td>
        <td class="text-muted"><small>${new Date(t.transaction_date).toLocaleString()}</small></td>
      </tr>
    `;
  }).join('');
}

async function handleTransfer(e) {
  e.preventDefault();
  const btn = document.getElementById('btn-submit-transfer');
  btn.disabled = true;
  btn.textContent = 'Executing Atomic Procedure...';

  const payload = {
    from_account: document.getElementById('transfer-from-account').value,
    to_account: document.getElementById('transfer-to-account').value,
    amount: parseFloat(document.getElementById('transfer-amount').value),
    description: document.getElementById('transfer-desc').value,
    channel: 'ONLINE'
  };

  try {
    const res = await api.transfer(payload);
    if (res.success) {
      showToast(`Transfer Complete! Ref: ${res.reference_no} (sp_transfer_funds)`, 'success');
      document.getElementById('modal-transfer').classList.remove('active');
      document.getElementById('form-transfer').reset();
      
      // Refresh views
      if (window.loadAccounts) window.loadAccounts();
      if (window.loadTransactions) window.loadTransactions();
      if (window.loadDashboard) window.loadDashboard();
      if (window.loadAuditLogs) window.loadAuditLogs();
    }
  } catch (err) {
  } finally {
    btn.disabled = false;
    btn.textContent = 'Execute Transfer';
  }
}

async function handleCashAction(e) {
  e.preventDefault();
  const btn = document.getElementById('btn-submit-cash');
  btn.disabled = true;

  const actionType = document.getElementById('cash-action-type').value;
  const payload = {
    account_number: document.getElementById('cash-account-select').value,
    amount: parseFloat(document.getElementById('cash-amount').value),
    description: document.getElementById('cash-desc').value,
    channel: actionType === 'DEPOSIT' ? 'BRANCH' : 'ATM'
  };

  try {
    let res;
    if (actionType === 'DEPOSIT') {
      res = await api.deposit(payload);
    } else {
      res = await api.withdraw(payload);
    }

    if (res.success) {
      showToast(`${actionType} of ${formatINR(payload.amount)} completed! Ref: ${res.reference_no}`, 'success');
      document.getElementById('modal-cash-action').classList.remove('active');
      document.getElementById('form-cash-action').reset();

      if (window.loadAccounts) window.loadAccounts();
      if (window.loadTransactions) window.loadTransactions();
      if (window.loadDashboard) window.loadDashboard();
      if (window.loadAuditLogs) window.loadAuditLogs();
    }
  } catch (err) {
  } finally {
    btn.disabled = false;
  }
}

window.loadTransactions = loadTransactions;
window.handleTransfer = handleTransfer;
window.handleCashAction = handleCashAction;
