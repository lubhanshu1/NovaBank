/**
 * NovaBank - Core Application Driver
 * Initializes navigation, modals, event listeners, and data synchronization.
 */

document.addEventListener('DOMContentLoaded', () => {
  initApp();
});

async function initApp() {
  setupNavigation();
  setupModals();
  setupPersonaSwitcher();
  setupEventListeners();

  // Check Database Connection & Server Health
  checkDbHealth();

  // Initialize DBMS Lab
  if (window.initLab) window.initLab();

  // Populate dynamic form select options
  if (window.populateModalDropdowns) window.populateModalDropdowns();

  // Load initial view data
  if (window.loadDashboard) window.loadDashboard();
  if (window.loadAccounts) window.loadAccounts();
  if (window.loadTransactions) window.loadTransactions();
  if (window.loadLoans) window.loadLoans();
  loadAuditLogs();
}

// Database Connection Indicator
async function checkDbHealth() {
  try {
    const health = await api.getHealth();
    const ind = document.getElementById('db-indicator');
    const label = document.getElementById('db-engine-label');
    const status = document.getElementById('db-conn-status');

    if (health.status === 'online') {
      ind.className = 'status-dot dot-online';
      label.textContent = `MySQL ${health.database.version}`;
      status.textContent = `Schema: ${health.database.database} (${health.database.total_tables} objects)`;
    } else {
      ind.style.backgroundColor = '#f43f5e';
      label.textContent = 'Database Offline';
      status.textContent = health.database.error || 'Connection Failed';
    }
  } catch (err) {
    console.error('Database health check failed:', err);
  }
}

// Navigation between Main Tabs
function setupNavigation() {
  const navItems = document.querySelectorAll('.nav-item');
  const tabs = document.querySelectorAll('.content-tab');
  const heading = document.getElementById('page-heading');
  const subheading = document.getElementById('page-subheading');

  const titles = {
    'dashboard': { title: 'Executive Dashboard', subtitle: 'Enterprise Core Banking Metrics & InnoDB Analytics' },
    'accounts': { title: 'Accounts & Client Portfolio', subtitle: 'Deposit Accounts, Minimum Balance Constraints & Branches' },
    'transactions': { title: 'Transfers & Ledger', subtitle: 'Immutable Ledger, Atomic Procedures & Banking Channels' },
    'loans': { title: 'Loans & Credit Facilities', subtitle: 'Loan Origination (sp_apply_loan) & EMI Amortization' },
    'audit': { title: 'Database Audit Trail', subtitle: 'Trigger-Generated Audit Trail (trg_accounts_after_update)' },
    'dbms-lab': { title: 'DBMS Academic Laboratory', subtitle: 'Live Syllabus Demonstrations: EXPLAIN, ACID, Concurrency & Cursors' }
  };

  navItems.forEach(item => {
    item.addEventListener('click', () => {
      const targetTab = item.dataset.tab;

      navItems.forEach(n => n.classList.remove('active'));
      item.classList.add('active');

      tabs.forEach(tab => {
        tab.classList.remove('active');
        if (tab.id === `section-${targetTab}`) {
          tab.classList.add('active');
        }
      });

      if (titles[targetTab]) {
        heading.textContent = titles[targetTab].title;
        subheading.textContent = titles[targetTab].subtitle;
      }

      // Refresh specific tab data on activation
      if (targetTab === 'dashboard' && window.loadDashboard) window.loadDashboard();
      if (targetTab === 'accounts' && window.loadAccounts) window.loadAccounts();
      if (targetTab === 'transactions' && window.loadTransactions) window.loadTransactions();
      if (targetTab === 'loans' && window.loadLoans) window.loadLoans();
      if (targetTab === 'audit') loadAuditLogs();
    });
  });

  // Lab Subtab Navigation
  const subtabs = document.querySelectorAll('.lab-subtab');
  const panels = document.querySelectorAll('.lab-panel');

  subtabs.forEach(st => {
    st.addEventListener('click', () => {
      const targetPanel = st.dataset.subtab;
      subtabs.forEach(s => s.classList.remove('active'));
      st.classList.add('active');

      panels.forEach(p => {
        p.classList.remove('active');
        if (p.id === targetPanel) p.classList.add('active');
      });
    });
  });
}

// Modal Handlers
function setupModals() {
  // Close buttons
  document.querySelectorAll('[data-close]').forEach(btn => {
    btn.addEventListener('click', () => {
      const modalId = btn.dataset.close;
      const modal = document.getElementById(modalId);
      if (modal) modal.classList.remove('active');
    });
  });

  // Backdrop click to close
  document.querySelectorAll('.modal-backdrop').forEach(modal => {
    modal.addEventListener('click', (e) => {
      if (e.target === modal) modal.classList.remove('active');
    });
  });

  // Open Transfer Modal
  const btnTransfer = document.getElementById('btn-quick-transfer');
  const btnTransfer2 = document.getElementById('btn-transfer-action');
  const modalTransfer = document.getElementById('modal-transfer');

  [btnTransfer, btnTransfer2].forEach(b => {
    if (b) b.addEventListener('click', () => {
      if (modalTransfer) modalTransfer.classList.add('active');
    });
  });

  // Open Deposit Modal
  const btnDeposit = document.getElementById('btn-deposit-action');
  if (btnDeposit) {
    btnDeposit.addEventListener('click', () => {
      document.getElementById('cash-modal-title').textContent = 'Cash / Electronic Deposit (sp_deposit_funds)';
      document.getElementById('cash-action-type').value = 'DEPOSIT';
      document.getElementById('modal-cash-action').classList.add('active');
    });
  }

  // Open Withdraw Modal
  const btnWithdraw = document.getElementById('btn-withdraw-action');
  if (btnWithdraw) {
    btnWithdraw.addEventListener('click', () => {
      document.getElementById('cash-modal-title').textContent = 'ATM Cash Withdrawal (sp_withdraw_funds)';
      document.getElementById('cash-action-type').value = 'WITHDRAWAL';
      document.getElementById('modal-cash-action').classList.add('active');
    });
  }

  // Open Account Modal
  const btnOpenAcc = document.getElementById('btn-open-account-modal');
  if (btnOpenAcc) {
    btnOpenAcc.addEventListener('click', () => {
      document.getElementById('modal-open-account').classList.add('active');
    });
  }

  // Apply Loan Modal
  const btnApplyLoan = document.getElementById('btn-apply-loan-modal');
  if (btnApplyLoan) {
    btnApplyLoan.addEventListener('click', () => {
      document.getElementById('modal-apply-loan').classList.add('active');
    });
  }
}

// Persona Switcher
function setupPersonaSwitcher() {
  const select = document.getElementById('persona-selector');
  const badge = document.getElementById('current-role-badge');

  if (select) {
    select.addEventListener('change', async () => {
      const targetUser = select.value;
      try {
        const res = await api.switchPersona(targetUser);
        if (res.success) {
          badge.textContent = res.user.role;
          showToast(`Active Persona: ${res.user.username} (${res.user.role})`, 'info');
          
          // Refresh views scoped to role
          if (window.loadAccounts) window.loadAccounts();
          if (window.loadTransactions) window.loadTransactions();
          if (window.loadLoans) window.loadLoans();
          if (window.loadDashboard) window.loadDashboard();
        }
      } catch (err) {}
    });
  }
}

// Form and Search Event Listeners
function setupEventListeners() {
  const searchAcc = document.getElementById('filter-accounts-search');
  if (searchAcc && window.filterAccounts) {
    searchAcc.addEventListener('input', window.filterAccounts);
  }

  const txnTypeFilter = document.getElementById('filter-txn-type');
  if (txnTypeFilter && window.loadTransactions) {
    txnTypeFilter.addEventListener('change', window.loadTransactions);
  }

  const btnRefreshTxns = document.getElementById('btn-refresh-txns');
  if (btnRefreshTxns && window.loadDashboard) {
    btnRefreshTxns.addEventListener('click', () => {
      window.loadDashboard();
      showToast('Ledger refreshed', 'info');
    });
  }

  // Form submits
  const formTransfer = document.getElementById('form-transfer');
  if (formTransfer && window.handleTransfer) {
    formTransfer.addEventListener('submit', window.handleTransfer);
  }

  const formCash = document.getElementById('form-cash-action');
  if (formCash && window.handleCashAction) {
    formCash.addEventListener('submit', window.handleCashAction);
  }

  const formOpen = document.getElementById('form-open-account');
  if (formOpen && window.handleOpenAccount) {
    formOpen.addEventListener('submit', window.handleOpenAccount);
  }

  const formLoan = document.getElementById('form-apply-loan');
  if (formLoan && window.handleApplyLoan) {
    formLoan.addEventListener('submit', window.handleApplyLoan);
  }
}

// Audit Logs Module
async function loadAuditLogs() {
  try {
    const data = await api.getAuditLogs(60);
    if (data.success) {
      const stats = data.stats;
      document.getElementById('audit-total-events').textContent = stats.total_logs;
      document.getElementById('audit-total-updates').textContent = stats.total_updates;
      document.getElementById('audit-total-inserts').textContent = stats.total_inserts;

      const tbody = document.getElementById('tbody-audit-logs');
      if (!tbody) return;

      tbody.innerHTML = data.logs.map(log => {
        let opClass = 'badge-info';
        if (log.operation === 'UPDATE') opClass = 'badge-warning';
        if (log.operation === 'DELETE') opClass = 'badge-danger';

        return `
          <tr>
            <td><code>#${log.audit_id}</code></td>
            <td><strong>${log.table_name}</strong></td>
            <td><span class="badge ${opClass}">${log.operation}</span></td>
            <td>${log.action_summary || '-'}</td>
            <td><span class="badge">${log.changed_by}</span></td>
            <td><code style="font-size: 0.72rem;">${log.old_values ? JSON.stringify(log.old_values) : 'NULL'}</code></td>
            <td><code style="font-size: 0.72rem;">${log.new_values ? JSON.stringify(log.new_values) : 'NULL'}</code></td>
            <td class="text-muted"><small>${new Date(log.timestamp).toLocaleTimeString()}</small></td>
          </tr>
        `;
      }).join('');
    }
  } catch (err) {
    console.error('Failed to load audit logs:', err);
  }
}

window.loadAuditLogs = loadAuditLogs;

