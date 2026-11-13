/**
 * NovaBank - DBMS Syllabus Laboratory Controller
 * Live interactive experiments for Query Optimization, ACID, Concurrency, and Cursors (INR).
 */

// Preset Queries for Optimizer Lab
const SQL_PRESETS = {
  unindexed: "SELECT * FROM query_demo_data WHERE unindexed_tag = 'TAG-0042' LIMIT 50;",
  indexed: "SELECT * FROM query_demo_data WHERE indexed_tag = 'TAG-0042' LIMIT 50;",
  composite: "SELECT * FROM query_demo_data WHERE city = 'Mumbai' AND amount > 25000.00 LIMIT 50;",
  join: `SELECT 
    c.customer_number, 
    CONCAT(c.first_name, ' ', c.last_name) AS full_name, 
    a.account_number, 
    a.account_type, 
    a.balance, 
    b.branch_name, 
    b.city
FROM customers c
JOIN accounts a ON c.customer_id = a.customer_id
JOIN branches b ON a.branch_id = b.branch_id
ORDER BY a.balance DESC
LIMIT 25;`
};

function initLab() {
  // Preset buttons
  document.querySelectorAll('.preset-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const presetKey = btn.dataset.preset;
      if (SQL_PRESETS[presetKey]) {
        document.getElementById('sql-query-input').value = SQL_PRESETS[presetKey];
        runQueryOptimizer();
      }
    });
  });

  // Query Run Button
  const btnRun = document.getElementById('btn-run-sql');
  if (btnRun) btnRun.addEventListener('click', runQueryOptimizer);

  // Atomicity Test
  const btnAtomicity = document.getElementById('btn-run-atomicity');
  if (btnAtomicity) btnAtomicity.addEventListener('click', runAtomicityExperiment);

  // Consistency Buttons
  const btnNeg = document.getElementById('btn-test-negative-bal');
  if (btnNeg) btnNeg.addEventListener('click', () => runConsistencyExperiment('NEGATIVE_BALANCE'));

  const btnDup = document.getElementById('btn-test-dup-id');
  if (btnDup) btnDup.addEventListener('click', () => runConsistencyExperiment('DUPLICATE_NATIONAL_ID'));

  const btnFk = document.getElementById('btn-test-fk-delete');
  if (btnFk) btnFk.addEventListener('click', () => runConsistencyExperiment('FOREIGN_KEY_VIOLATION'));

  // Isolation Buttons
  document.querySelectorAll('.isolation-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.isolation-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      loadIsolationLevel(btn.dataset.level);
    });
  });

  // Concurrency / Deadlock Button
  const btnDeadlock = document.getElementById('btn-trigger-deadlock');
  if (btnDeadlock) btnDeadlock.addEventListener('click', runDeadlockSimulation);

  // Cursor Batch Button
  const btnCursor = document.getElementById('btn-run-interest-batch');
  if (btnCursor) btnCursor.addEventListener('click', runCursorInterestBatch);

  // Load Normalization data initially
  loadNormalizationData();
  loadIsolationLevel('REPEATABLE READ');
}

// ----------------------------------------------------------------------------
// 1. Query Optimizer & EXPLAIN Execution
// ----------------------------------------------------------------------------
async function runQueryOptimizer() {
  const query = document.getElementById('sql-query-input').value.trim();
  if (!query) return;

  const btn = document.getElementById('btn-run-sql');
  btn.disabled = true;
  btn.textContent = 'Analyzing Plan...';

  try {
    const res = await api.runQuery(query);
    if (res.success) {
      renderOptimizerResults(res);
    }
  } catch (err) {
  } finally {
    btn.disabled = false;
    btn.textContent = 'Execute Query & Analyze Plan';
  }
}

function renderOptimizerResults(data) {
  // 1. Summary Metrics Banner
  const banner = document.getElementById('optimizer-metrics-card');
  banner.style.display = 'flex';

  const sum = data.optimization_summary;
  document.getElementById('opt-access-type').textContent = sum.access_type;
  document.getElementById('opt-index-used').textContent = sum.index_used;
  document.getElementById('opt-rows-examined').textContent = sum.rows_examined;
  document.getElementById('opt-cost').textContent = sum.query_cost;
  document.getElementById('opt-time').textContent = `${data.execution_time_ms} ms`;

  // 2. Verdict Box
  const verdictBox = document.getElementById('optimizer-verdict-box');
  verdictBox.style.display = 'block';
  verdictBox.className = `verdict-box ${sum.is_table_scan ? 'verdict-warn' : 'verdict-success'}`;
  verdictBox.innerHTML = `<strong>DBMS Optimizer Verdict:</strong> ${sum.verdict} <br><small>Returned ${data.total_rows_returned} rows in ${data.execution_time_ms} ms.</small>`;

  // 3. Raw Data Table
  document.getElementById('query-result-count').textContent = `${data.total_rows_returned} Rows`;
  const container = document.getElementById('query-results-table-container');

  if (data.data.length === 0) {
    container.innerHTML = '<div class="text-center text-muted" style="padding: 20px;">Query returned zero rows.</div>';
  } else {
    const table = document.createElement('table');
    table.className = 'data-table';

    const ths = data.columns.map(col => `<th>${col}</th>`).join('');
    const trs = data.data.map(row => {
      const tds = data.columns.map(col => `<td>${row[col] !== null ? row[col] : '<em>NULL</em>'}</td>`).join('');
      return `<tr>${tds}</tr>`;
    }).join('');

    table.innerHTML = `<thead><tr>${ths}</tr></thead><tbody>${trs}</tbody>`;
    container.innerHTML = '';
    container.appendChild(table);
  }

  // 4. Raw JSON EXPLAIN Plan
  document.getElementById('explain-json-output').textContent = JSON.stringify(data.explain_plan, null, 2);
}

// ----------------------------------------------------------------------------
// 2. ACID: Atomicity Experiment
// ----------------------------------------------------------------------------
async function runAtomicityExperiment() {
  const amount = parseFloat(document.getElementById('atomicity-amount').value || 1000);
  const simulateFailure = document.getElementById('atomicity-simulate-crash').value === 'true';

  const btn = document.getElementById('btn-run-atomicity');
  btn.disabled = true;
  btn.textContent = 'Simulating Transaction...';

  try {
    const res = await api.testAtomicity({ simulate_failure: simulateFailure, amount: amount });
    if (res.success) {
      renderAtomicityStepper(res);
      if (window.loadAccounts) window.loadAccounts();
      if (window.loadTransactions) window.loadTransactions();
      if (window.loadDashboard) window.loadDashboard();
      if (window.loadAuditLogs) window.loadAuditLogs();
    }
  } catch (err) {
  } finally {
    btn.disabled = false;
    btn.textContent = 'Run Atomicity Experiment';
  }
}

function renderAtomicityStepper(res) {
  const container = document.getElementById('atomicity-stepper');
  container.style.display = 'flex';

  const statusBadge = res.status === 'COMMITTED' ? 
    '<span class="badge badge-success">TRANSACTION COMMITTED</span>' : 
    '<span class="badge badge-danger">TRANSACTION ROLLED BACK (ATOMICITY PRESERVED)</span>';

  let html = `
    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
      <h4 style="font-size: 0.95rem; font-weight: 600;">Execution Lifecycle:</h4>
      ${statusBadge}
    </div>
  `;

  html += res.steps.map(s => `
    <div class="step-card">
      <div class="step-number">${s.step}</div>
      <div class="step-details">
        <h5>${s.title}</h5>
        <p>${s.detail}</p>
      </div>
    </div>
  `).join('');

  html += `
    <div class="solution-box" style="margin-top: 10px;">
      <strong>Invariance Verification:</strong> Initial Pool Balance: ${formatINR(res.balances.initial.account_a + res.balances.initial.account_b)} &rarr; Final Pool Balance: ${formatINR(res.balances.final.account_a + res.balances.final.account_b)}.
      <br><strong>Status:</strong> ${res.invariance_maintained ? '<span class="text-success">&check; Perfect Invariance Maintained. Zero money lost or created.</span>' : '<span class="text-danger">&cross; Invariance violated!</span>'}
    </div>
  `;

  container.innerHTML = html;
}

// ----------------------------------------------------------------------------
// 3. ACID: Consistency & Constraint Enforcement
// ----------------------------------------------------------------------------
async function runConsistencyExperiment(scenario) {
  const resultBox = document.getElementById('consistency-result-box');
  resultBox.style.display = 'block';
  resultBox.className = 'verdict-box verdict-warn';
  resultBox.textContent = 'Executing constraint test against MySQL engine...';

  try {
    const res = await api.testConsistency(scenario);
    if (res.success && res.result) {
      const r = res.result;
      resultBox.className = 'verdict-box verdict-success';
      resultBox.innerHTML = `
        <h5 style="color: var(--color-twilight-indigo); font-weight: 700; margin-bottom: 6px;">Constraint Successfully Enforced by MySQL Engine:</h5>
        <div><strong>Status:</strong> <span class="badge badge-danger">${r.status}</span></div>
        <div><strong>MySQL Error Code:</strong> <code>${r.error_number} (SQLSTATE: ${r.sqlstate})</code></div>
        <div><strong>Engine Message:</strong> <code>${r.mysql_message}</code></div>
        <p style="margin-top: 10px; font-size: 0.82rem; color: var(--color-text-secondary); line-height: 1.5;">${r.academic_concept}</p>
      `;
    }
  } catch (err) {}
}

// ----------------------------------------------------------------------------
// 4. ACID: Isolation Levels
// ----------------------------------------------------------------------------
async function loadIsolationLevel(level) {
  try {
    const res = await api.testIsolation(level);
    if (res.success) {
      document.getElementById('iso-level-title').textContent = `Isolation Level: ${res.selected_level}`;
      document.getElementById('iso-dirty-read').textContent = res.properties.dirty_reads;
      document.getElementById('iso-non-rep').textContent = res.properties.non_repeatable_reads;
      document.getElementById('iso-phantom').textContent = res.properties.phantom_reads;

      document.getElementById('iso-explanation').innerHTML = `
        <strong>Lock Overhead:</strong> ${res.properties.lock_overhead} <br>
        <strong>NovaBank Architecture Rationale:</strong> ${res.properties.novabank_recommendation} <br>
        <strong>Current MySQL Server Config:</strong> Session = <code>${res.current_mysql_configuration.session_level}</code>, Global = <code>${res.current_mysql_configuration.global_level}</code>.
      `;
    }
  } catch (err) {}
}

// ----------------------------------------------------------------------------
// 5. Concurrency & Deadlock Detection
// ----------------------------------------------------------------------------
async function runDeadlockSimulation() {
  const btn = document.getElementById('btn-trigger-deadlock');
  btn.disabled = true;
  btn.textContent = 'Simulating Concurrent Contention...';

  document.getElementById('thread-a-output').innerHTML = '<span class="text-warning">Acquiring Lock on Acc 1...</span>';
  document.getElementById('thread-b-output').innerHTML = '<span class="text-warning">Acquiring Lock on Acc 2...</span>';

  try {
    const res = await api.testDeadlock();
    if (res.success) {
      const sim = res.concurrency_simulation;
      
      document.getElementById('thread-a-output').innerHTML = sim.thread_a.status === 'COMMITTED' ? 
        '<span class="text-success">&check; Acquired both locks and COMMITTED</span>' : 
        `<span class="text-danger">&cross; ${sim.thread_a.msg || 'DEADLOCK VICTIM ROLLED BACK'}</span>`;

      document.getElementById('thread-b-output').innerHTML = sim.thread_b.status === 'COMMITTED' ? 
        '<span class="text-success">&check; Acquired both locks and COMMITTED</span>' : 
        `<span class="text-danger">&cross; ${sim.thread_b.msg || 'DEADLOCK VICTIM ROLLED BACK'}</span>`;

      showToast('Concurrency simulation completed. InnoDB cycle detection recorded.', 'info');
    }
  } catch (err) {
  } finally {
    btn.disabled = false;
    btn.textContent = 'Simulate Concurrent Deadlock';
  }
}

// ----------------------------------------------------------------------------
// 6. Stored Procedures & Cursors
// ----------------------------------------------------------------------------
async function runCursorInterestBatch() {
  const btn = document.getElementById('btn-run-interest-batch');
  btn.disabled = true;
  btn.textContent = 'Iterating Cursor Across Accounts...';

  try {
    const res = await api.runInterestBatch();
    if (res.success) {
      document.getElementById('cursor-summary-stats').style.display = 'grid';
      document.getElementById('cursor-count').textContent = res.processed_savings_accounts;
      document.getElementById('cursor-total-interest').textContent = formatINR(res.total_interest_credited);

      const tbody = document.getElementById('tbody-cursor-results');
      tbody.innerHTML = res.recent_transactions.map(t => `
        <tr>
          <td><code>${t.reference_no}</code></td>
          <td class="text-success font-mono" style="font-weight: 700;">+${formatINR(t.amount)}</td>
          <td class="font-mono">${formatINR(t.balance_after)}</td>
          <td>${t.description}</td>
          <td class="text-muted"><small>${new Date(t.transaction_date).toLocaleTimeString()}</small></td>
        </tr>
      `).join('');

      showToast(`Cursor Batch Complete! Credited interest across ${res.processed_savings_accounts} accounts.`, 'success');

      if (window.loadAccounts) window.loadAccounts();
      if (window.loadDashboard) window.loadDashboard();
      if (window.loadAuditLogs) window.loadAuditLogs();
    }
  } catch (err) {
  } finally {
    btn.disabled = false;
    btn.textContent = 'Trigger Interest Accrual Batch';
  }
}

// ----------------------------------------------------------------------------
// 7. Normalization Reference
// ----------------------------------------------------------------------------
async function loadNormalizationData() {
  try {
    const res = await api.getNormalization();
    if (res.success) {
      // 1. Normalization Forms
      const container = document.getElementById('normalization-cards-container');
      container.innerHTML = res.forms.map(f => `
        <div style="background: var(--color-surface-raised); border: 1px solid var(--color-border); padding: 14px 18px; border-radius: 12px; margin-bottom: 12px;">
          <h5 style="color: var(--color-twilight-indigo); font-weight: 700; margin-bottom: 4px;">${f.level}</h5>
          <div style="font-size: 0.8rem; color: var(--color-text-muted); margin-bottom: 4px;"><strong>Academic Rule:</strong> ${f.rules}</div>
          <div style="font-size: 0.84rem; color: var(--color-text);"><strong>NovaBank Implementation:</strong> ${f.novabank_design}</div>
        </div>
      `).join('');

      // 2. Relational Schema Tables
      const tbody = document.getElementById('tbody-normalization-tables');
      tbody.innerHTML = res.tables.map(t => `
        <tr>
          <td><strong><code>${t.name}</code></strong></td>
          <td><code>${t.pk}</code></td>
          <td>${t.fks.length > 0 ? t.fks.map(fk => `<span class="badge">${fk}</span>`).join(' ') : '<span class="text-muted">None (Master Root)</span>'}</td>
          <td><span class="badge badge-success">3NF / BCNF</span></td>
        </tr>
      `).join('');
    }
  } catch (err) {}
}

window.initLab = initLab;
window.runQueryOptimizer = runQueryOptimizer;
