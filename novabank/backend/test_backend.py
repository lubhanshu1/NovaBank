#!/usr/bin/env python3
"""
NovaBank - Automated End-to-End Backend Verification Test Suite
Tests every stored procedure, trigger, view, API endpoint, and DBMS Lab concept.
"""

import sys
import unittest
from backend.app import create_app
from backend.db import check_connection, execute_query

class NovaBankTestSuite(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = create_app()
        cls.client = cls.app.test_client()

    def test_01_db_connection(self):
        status = check_connection()
        self.assertTrue(status.get('connected'), "Database connection failed")
        self.assertIsNotNone(status.get('version'), "MySQL version should be present")

    def test_02_health_endpoint(self):
        res = self.client.get('/api/health')
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertEqual(data.get('status'), 'online')

    def test_03_authentication_login(self):
        # Valid admin login
        res = self.client.post('/api/auth/login', json={"username": "admin", "password": "admin123"})
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertTrue(data.get('success'))
        self.assertEqual(data['user']['role'], 'ADMIN')

        # Invalid password
        res_bad = self.client.post('/api/auth/login', json={"username": "admin", "password": "wrongpassword"})
        self.assertEqual(res_bad.status_code, 401)

    def test_04_accounts_list_and_detail(self):
        res = self.client.get('/api/accounts')
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertTrue(data.get('success'))
        self.assertGreater(data.get('count', 0), 0)

        # Detail for account 1001001001
        res_detail = self.client.get('/api/accounts/1001001001')
        self.assertEqual(res_detail.status_code, 200)
        detail_data = res_detail.get_json()
        self.assertTrue(detail_data.get('success'))
        self.assertEqual(detail_data['account']['account_number'], '1001001001')

    def test_05_stored_procedure_transfer(self):
        payload = {
            "from_account": "1001001001",
            "to_account": "1001002001",
            "amount": 25.00,
            "description": "Automated Unit Test Transfer",
            "channel": "ONLINE"
        }
        res = self.client.post('/api/transactions/transfer', json=payload)
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertTrue(data.get('success'))
        self.assertEqual(data.get('status'), 'SUCCESS')
        self.assertIsNotNone(data.get('reference_no'))

    def test_06_insufficient_funds_rejection(self):
        payload = {
            "from_account": "1001001001",
            "to_account": "1001002001",
            "amount": 999999999.00,
            "description": "Impossible Overdraft"
        }
        res = self.client.post('/api/transactions/transfer', json=payload)
        self.assertEqual(res.status_code, 400)
        data = res.get_json()
        self.assertFalse(data.get('success'))
        self.assertEqual(data.get('status'), 'FAILED')

    def test_07_deposit_and_withdrawal_procedures(self):
        # Deposit $50
        res_dep = self.client.post('/api/transactions/deposit', json={
            "account_number": "1001001001",
            "amount": 50.00,
            "description": "Test Deposit",
            "channel": "BRANCH"
        })
        self.assertEqual(res_dep.status_code, 200)

        # Withdraw $20
        res_wth = self.client.post('/api/transactions/withdraw', json={
            "account_number": "1001001001",
            "amount": 20.00,
            "description": "Test Withdrawal",
            "channel": "ATM"
        })
        self.assertEqual(res_wth.status_code, 200)

    def test_08_open_account_procedure(self):
        res = self.client.post('/api/accounts', json={
            "customer_id": 1,
            "branch_id": 1,
            "account_type": "CHECKING",
            "initial_deposit": 5000.00,
            "interest_rate": 3.5,
            "minimum_balance": 1000.00
        })
        self.assertEqual(res.status_code, 201)
        data = res.get_json()
        self.assertTrue(data.get('success'))
        self.assertIsNotNone(data.get('account_number'))

    def test_09_loan_origination_and_repayment(self):
        # Apply loan
        res_loan = self.client.post('/api/loans/apply', json={
            "customer_id": 2,
            "account_id": 3,
            "loan_type": "PERSONAL",
            "principal_amount": 50000.00,
            "term_months": 12,
            "interest_rate": 10.5
        })
        self.assertEqual(res_loan.status_code, 201)
        loan_data = res_loan.get_json()
        self.assertTrue(loan_data.get('success'))
        loan_id = loan_data.get('loan_id')
        self.assertIsNotNone(loan_id)

        # Repay installment
        res_pay = self.client.post(f'/api/loans/{loan_id}/pay', json={
            "account_number": "1001002001"
        })
        self.assertEqual(res_pay.status_code, 200)

    def test_10_analytics_views(self):
        # Summary
        res_sum = self.client.get('/api/analytics/summary')
        self.assertEqual(res_sum.status_code, 200)
        self.assertTrue(res_sum.get_json().get('success'))

        # High risk view
        res_risk = self.client.get('/api/analytics/high-risk')
        self.assertEqual(res_risk.status_code, 200)

        # Branch performance view
        res_branch = self.client.get('/api/analytics/branch-performance')
        self.assertEqual(res_branch.status_code, 200)

    def test_11_audit_logs_populated_by_triggers(self):
        res = self.client.get('/api/audit/logs?limit=10')
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertGreater(data.get('count', 0), 0)
        self.assertIsNotNone(data.get('stats'))

    def test_12_dbms_lab_query_runner_and_explain(self):
        # Query Runner with index lookup
        query = "SELECT * FROM query_demo_data WHERE indexed_tag = 'TAG-0010' LIMIT 5"
        res = self.client.post('/api/lab/query-runner', json={"query": query})
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertTrue(data.get('success'))
        self.assertIn('optimization_summary', data)
        self.assertIn('idx_demo_indexed_tag', data['optimization_summary'].get('index_used', ''))

    def test_13_dbms_lab_atomicity_demo(self):
        res = self.client.post('/api/lab/acid/atomicity', json={
            "simulate_failure": True,
            "amount": 100.00
        })
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertEqual(data.get('status'), 'ROLLED_BACK')
        self.assertTrue(data.get('invariance_maintained'))

    def test_14_dbms_lab_consistency_demo(self):
        res = self.client.post('/api/lab/acid/consistency', json={
            "scenario": "NEGATIVE_BALANCE"
        })
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertEqual(data['result'].get('status'), 'REJECTED_BY_DATABASE')

    def test_15_dbms_lab_interest_accrual_cursor(self):
        res = self.client.post('/api/lab/batch/interest')
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertTrue(data.get('success'))
        self.assertGreater(data.get('processed_savings_accounts', 0), 0)

if __name__ == '__main__':
    unittest.main()

