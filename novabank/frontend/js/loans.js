/**
 * NovaBank - Loans & Credit Module
 * Manages loan origination (sp_apply_loan) and amortized payments (sp_pay_loan_installment) in INR.
 */

async function loadLoans() {
  try {
    const data = await api.getLoans();
    if (data.success) {
      renderLoansTable(data.loans);
    }
  } catch (err) {
    console.error('Failed to load loans:', err);
  }
}

function renderLoansTable(loans) {
  const tbody = document.getElementById('tbody-loans');
  if (!tbody) return;

  if (!loans || loans.length === 0) {
    tbody.innerHTML = '<tr><td colspan="10" class="text-center text-muted">No active loan facilities found.</td></tr>';
    return;
  }

  tbody.innerHTML = loans.map(l => {
    let statusClass = 'badge-success';
    if (l.status === 'PAID_OFF') statusClass = 'badge-info';
    if (l.status === 'DEFAULTED') statusClass = 'badge-danger';

    const canPay = l.status === 'ACTIVE' && l.outstanding_balance > 0;

    return `
      <tr>
        <td><strong><code>${l.loan_number}</code></strong></td>
        <td>
          <div style="font-weight: 600;">${l.customer_name}</div>
          <small class="text-muted">${l.customer_email}</small>
        </td>
        <td><span class="badge">${l.loan_type}</span></td>
        <td class="font-mono">${formatINR(l.principal_amount)}</td>
        <td><span class="text-warning font-mono">${l.interest_rate}%</span></td>
        <td class="font-mono">${l.term_months} mos</td>
        <td class="font-mono text-warm" style="font-weight: 700;">${formatINR(l.monthly_emi)}/mo</td>
        <td class="font-mono" style="font-weight: 700;">${formatINR(l.outstanding_balance)}</td>
        <td><span class="badge ${statusClass}">${l.status}</span></td>
        <td>
          ${canPay ? `
            <button class="btn btn-xs btn-pill-dark" onclick="payLoanInstallment(${l.loan_id}, '${l.account_number}')">
              Pay EMI (${formatINR(l.monthly_emi)})
            </button>
          ` : `<span class="text-muted"><small>Paid in full</small></span>`}
        </td>
      </tr>
    `;
  }).join('');
}

async function payLoanInstallment(loanId, accountNumber) {
  if (!confirm(`Confirm debiting monthly EMI installment from account ${accountNumber}?`)) return;

  try {
    const res = await api.payLoan(loanId, { account_number: accountNumber });
    if (res.success) {
      showToast(res.message, 'success');
      loadLoans();
      if (window.loadAccounts) window.loadAccounts();
      if (window.loadTransactions) window.loadTransactions();
      if (window.loadDashboard) window.loadDashboard();
      if (window.loadAuditLogs) window.loadAuditLogs();
    }
  } catch (err) {}
}

async function handleApplyLoan(e) {
  e.preventDefault();
  const payload = {
    customer_id: parseInt(document.getElementById('loan-customer-select').value),
    account_id: parseInt(document.getElementById('loan-account-select').value),
    loan_type: document.getElementById('loan-type-select').value,
    principal_amount: parseFloat(document.getElementById('loan-principal').value),
    term_months: parseInt(document.getElementById('loan-term').value),
    interest_rate: document.getElementById('loan-type-select').value === 'AUTO' ? 9.25 :
                   document.getElementById('loan-type-select').value === 'HOME' ? 8.50 : 12.50
  };

  try {
    const res = await api.applyLoan(payload);
    if (res.success) {
      showToast(`Loan Approved & Disbursed! Monthly EMI: ${formatINR(res.monthly_emi)} (sp_apply_loan)`, 'success');
      document.getElementById('modal-apply-loan').classList.remove('active');
      document.getElementById('form-apply-loan').reset();

      loadLoans();
      if (window.loadAccounts) window.loadAccounts();
      if (window.loadTransactions) window.loadTransactions();
      if (window.loadDashboard) window.loadDashboard();
      if (window.loadAuditLogs) window.loadAuditLogs();
    }
  } catch (err) {}
}

window.loadLoans = loadLoans;
window.payLoanInstallment = payLoanInstallment;
window.handleApplyLoan = handleApplyLoan;
