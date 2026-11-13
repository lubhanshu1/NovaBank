/**
 * NovaBank - Executive Dashboard & Analytics
 * Powers live charts, KPI stat cards, and analytical view inspections (INR).
 */

let chartDaily = null;
let chartBranches = null;

async function loadDashboard() {
  try {
    // 1. Fetch Summary Metrics
    const summaryData = await api.getSummary();
    if (summaryData.success) {
      renderSummaryMetrics(summaryData.metrics);
    }

    // 2. Fetch Daily Transactions for Chart
    const dailyData = await api.getDailyMetrics();
    if (dailyData.success) {
      renderDailyChart(dailyData.daily_metrics);
    }

    // 3. Fetch Branch Performance for Chart
    const branchData = await api.getBranchPerformance();
    if (branchData.success) {
      renderBranchChart(branchData.branches);
    }

    // 4. Fetch High Risk Compliance Alerts
    const riskData = await api.getHighRisk();
    if (riskData.success) {
      renderHighRiskTable(riskData.alerts);
    }

    // 5. Fetch Recent Ledger Transactions
    const txnData = await api.getTransactions({ limit: 8 });
    if (txnData.success) {
      renderRecentTransactions(txnData.transactions);
    }

  } catch (err) {
    console.error('Failed to load dashboard:', err);
  }
}

function renderSummaryMetrics(m) {
  document.getElementById('stat-total-deposits').textContent = formatINR(m.total_deposits);
  document.getElementById('stat-total-volume').textContent = formatINR(m.total_volume_settled);
  document.getElementById('stat-total-txns').textContent = `${m.total_transactions} Total Transactions`;
  document.getElementById('stat-loan-book').textContent = formatINR(m.total_loan_book);
  document.getElementById('stat-active-loans').textContent = `${m.active_loans} Active Loans`;
  document.getElementById('stat-active-accounts').textContent = m.total_active_accounts;
  document.getElementById('stat-total-customers').textContent = `${m.total_customers} Verified Customers`;
}

function renderDailyChart(metrics) {
  const ctx = document.getElementById('chart-daily-transactions');
  if (!ctx) return;

  const labels = metrics.map(d => d.txn_date);
  const volumes = metrics.map(d => d.total_volume);
  const counts = metrics.map(d => d.transaction_count);

  if (chartDaily) chartDaily.destroy();

  chartDaily = new Chart(ctx, {
    type: 'line',
    data: {
      labels: labels,
      datasets: [
        {
          label: 'Settled Volume (₹)',
          data: volumes,
          borderColor: '#e96c2f',
          backgroundColor: 'rgba(233, 108, 47, 0.08)',
          fill: true,
          tension: 0.35,
          yAxisID: 'y',
          borderWidth: 2.5,
          pointBackgroundColor: '#e96c2f'
        },
        {
          label: 'Transaction Count',
          data: counts,
          borderColor: '#6366f1',
          borderDash: [4, 4],
          fill: false,
          tension: 0.35,
          yAxisID: 'y1',
          borderWidth: 2,
          pointBackgroundColor: '#6366f1'
        }
      ]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: { mode: 'index', intersect: false },
      plugins: {
        legend: {
          labels: {
            color: '#3d3d3d',
            font: { family: 'Plus Jakarta Sans', size: 11.5, weight: '500' }
          }
        }
      },
      scales: {
        x: {
          ticks: { color: '#666666', font: { family: 'Plus Jakarta Sans', size: 10.5 } },
          grid: { color: 'rgba(0, 0, 0, 0.04)' }
        },
        y: {
          ticks: {
            color: '#666666',
            font: { family: 'JetBrains Mono', size: 10.5 },
            callback: v => '₹' + (v >= 100000 ? (v / 100000).toFixed(1) + 'L' : (v / 1000).toFixed(0) + 'k')
          },
          grid: { color: 'rgba(0, 0, 0, 0.04)' }
        },
        y1: {
          position: 'right',
          grid: { drawOnChartArea: false },
          ticks: { color: '#6366f1', font: { family: 'JetBrains Mono', size: 10.5 } }
        }
      }
    }
  });
}

function renderBranchChart(branches) {
  const ctx = document.getElementById('chart-branch-deposits');
  if (!ctx) return;

  const labels = branches.map(b => b.branch_name.replace(' Branch', '').replace(' Hub', ''));
  const deposits = branches.map(b => b.total_deposits);

  if (chartBranches) chartBranches.destroy();

  chartBranches = new Chart(ctx, {
    type: 'bar',
    data: {
      labels: labels,
      datasets: [{
        label: 'Total Deposits (₹)',
        data: deposits,
        backgroundColor: [
          '#1e2033',
          '#e96c2f',
          '#6366f1',
          '#83c040',
          '#3b82f6'
        ],
        borderRadius: 8
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { display: false }
      },
      scales: {
        x: {
          ticks: { color: '#666666', font: { family: 'Plus Jakarta Sans', size: 10.5 } },
          grid: { display: false }
        },
        y: {
          ticks: {
            color: '#666666',
            font: { family: 'JetBrains Mono', size: 10.5 },
            callback: v => '₹' + (v >= 100000 ? (v / 100000).toFixed(1) + 'L' : (v / 1000).toFixed(0) + 'k')
          },
          grid: { color: 'rgba(0, 0, 0, 0.04)' }
        }
      }
    }
  });
}

function renderHighRiskTable(alerts) {
  const tbody = document.getElementById('tbody-high-risk');
  if (!tbody) return;

  if (!alerts || alerts.length === 0) {
    tbody.innerHTML = '<tr><td colspan="5" class="text-center text-muted">No high-risk compliance alerts flagged.</td></tr>';
    return;
  }

  tbody.innerHTML = alerts.slice(0, 6).map(a => {
    let badgeClass = 'badge-warning';
    if (a.risk_classification.includes('LARGE')) badgeClass = 'badge-danger';
    if (a.status === 'FAILED') badgeClass = 'badge-danger';

    return `
      <tr>
        <td><code>${a.reference_no}</code></td>
        <td>${a.account_holder} <small class="text-muted">(${a.customer_tier})</small></td>
        <td class="text-danger" style="font-weight: 700; font-family: var(--font-mono);">${formatINR(a.amount)}</td>
        <td><span class="badge">${a.channel}</span></td>
        <td><span class="badge ${badgeClass}">${a.risk_classification.replace(/_/g, ' ')}</span></td>
      </tr>
    `;
  }).join('');
}

function renderRecentTransactions(txns) {
  const tbody = document.getElementById('tbody-recent-txns');
  if (!tbody) return;

  if (!txns || txns.length === 0) {
    tbody.innerHTML = '<tr><td colspan="5" class="text-center text-muted">No recent transactions recorded.</td></tr>';
    return;
  }

  tbody.innerHTML = txns.map(t => {
    const isCredit = ['DEPOSIT', 'TRANSFER_IN', 'INTEREST_CREDIT', 'LOAN_DISBURSEMENT'].includes(t.transaction_type);
    const colorClass = isCredit ? 'text-success' : 'text-danger';
    const sign = isCredit ? '+' : '-';

    return `
      <tr>
        <td><code>${t.reference_no}</code></td>
        <td><span class="badge">${t.transaction_type}</span></td>
        <td class="${colorClass} font-mono" style="font-weight: 700;">${sign}${formatINR(t.amount)}</td>
        <td class="font-mono">${formatINR(t.balance_after)}</td>
        <td class="text-muted"><small>${new Date(t.transaction_date).toLocaleString()}</small></td>
      </tr>
    `;
  }).join('');
}

window.loadDashboard = loadDashboard;
