"""Database access layer for MySQL and TiDB Cloud.

TiDB does not implement MySQL stored procedures or triggers. The seven
legacy procedure entry points are therefore implemented here as explicit,
transactional application services. This keeps the route contract stable.
"""
import json
import secrets
import string
from contextlib import contextmanager
from datetime import datetime, date
from decimal import Decimal

import mysql.connector
from mysql.connector import pooling
from .config import Config

db_pool = None


def init_pool():
    global db_pool
    try:
        options = dict(
            pool_name=Config.DB_POOL_NAME,
            pool_size=Config.DB_POOL_SIZE,
            pool_reset_session=True,
            host=Config.DB_HOST,
            port=Config.DB_PORT,
            user=Config.DB_USER,
            password=Config.DB_PASSWORD,
            database=Config.DB_NAME,
            autocommit=False,
            connection_timeout=15,
        )
        # TiDB Cloud requires TLS. Set DB_SSL_CA to the downloaded TiDB CA
        # certificate to enable certificate + hostname verification.
        if Config.DB_SSL_CA:
            options.update(ssl_ca=Config.DB_SSL_CA, ssl_verify_cert=True, ssl_verify_identity=True)
        else:
            options.update(ssl_disabled=False)
        db_pool = pooling.MySQLConnectionPool(**options)
        return True
    except Exception as exc:
        db_pool = None
        print(f"[DB Error] Failed to initialize database pool: {exc}")
        return False


@contextmanager
def get_db():
    global db_pool
    if db_pool is None:
        if not init_pool():
            raise RuntimeError("Database pool is unavailable. Check DB_* environment variables.")
    cnx = None
    try:
        cnx = db_pool.get_connection()
        yield cnx
    except Exception:
        if cnx:
            try: cnx.rollback()
            except Exception: pass
        raise
    finally:
        if cnx:
            try: cnx.close()
            except Exception: pass


def serialize_row(row):
    if row is None: return None
    out = {}
    for key, value in row.items():
        if isinstance(value, Decimal): out[key] = float(value)
        elif isinstance(value, (datetime, date)): out[key] = value.isoformat()
        elif isinstance(value, str) and value[:1] in ('{', '['):
            try: out[key] = json.loads(value)
            except Exception: out[key] = value
        else: out[key] = value
    return out


def execute_query(sql, params=None, fetchone=False, fetchall=False, commit=False):
    with get_db() as cnx:
        cur = cnx.cursor(dictionary=True)
        try:
            cur.execute(sql, params or ())
            if fetchone: return serialize_row(cur.fetchone())
            if fetchall: return [serialize_row(row) for row in cur.fetchall()]
            if commit: cnx.commit()
            return {"affected_rows": cur.rowcount, "last_insert_id": cur.lastrowid}
        finally: cur.close()


def _ref(prefix):
    return f"{prefix}-{datetime.utcnow():%Y%m%d%H%M%S}-{secrets.token_hex(3).upper()}"


def _audit(cur, table, operation, record_id, summary, old=None, new=None):
    cur.execute("""INSERT INTO audit_logs
        (table_name, operation, record_id, old_values, new_values, changed_by, action_summary)
        VALUES (%s,%s,%s,%s,%s,%s,%s)""",
        (table, operation, record_id, json.dumps(old) if old is not None else None,
         json.dumps(new) if new is not None else None, 'novabank_app', summary[:255]))


def _txn(cur, account_id, kind, amount, before, after, description, channel='ONLINE', related=None, ref=None):
    ref = ref or _ref('TXN')
    cur.execute("""INSERT INTO transactions
        (reference_no, account_id, transaction_type, amount, balance_before, balance_after,
         related_account_id, status, channel, description)
        VALUES (%s,%s,%s,%s,%s,%s,%s,'COMPLETED',%s,%s)""",
        (ref, account_id, kind, amount, before, after, related, channel, description))
    txn_id = cur.lastrowid
    _audit(cur, 'transactions', 'INSERT', txn_id,
           f"Transaction {ref} ({kind} ₹{amount}) recorded.", None,
           {"reference_no": ref, "account_id": account_id, "type": kind, "amount": float(amount)})
    return ref


def _update_balance(cur, account, new_balance):
    if account['status'] in ('FROZEN', 'CLOSED') and Decimal(str(new_balance)) != Decimal(str(account['balance'])):
        raise ValueError(f"Account is {account['status']} and cannot be modified.")
    if Decimal(str(new_balance)) < Decimal(str(account['minimum_balance'])):
        raise ValueError("Balance cannot fall below the account minimum balance.")
    cur.execute("UPDATE accounts SET balance=%s, updated_at=CURRENT_TIMESTAMP WHERE account_id=%s",
                (new_balance, account['account_id']))
    _audit(cur, 'accounts', 'UPDATE', account['account_id'],
           f"Account {account['account_number']} balance updated.",
           {"balance": float(account['balance']), "status": account['status']},
           {"balance": float(new_balance), "status": account['status']})


def _get_account(cur, number, lock=True):
    cur.execute("SELECT * FROM accounts WHERE account_number=%s" + (' FOR UPDATE' if lock else ''), (number,))
    return cur.fetchone()


def _service_transfer(args):
    src, dst, amount, desc, channel = args[:5]
    amount = Decimal(str(amount or 0)).quantize(Decimal('0.01'))
    if amount <= 0: return [src, dst, amount, desc, channel, 'FAILED', 'Transfer amount must be greater than zero.', None]
    if src == dst: return [src, dst, amount, desc, channel, 'FAILED', 'Sender and recipient accounts cannot be the same.', None]
    with get_db() as cnx:
        cur = cnx.cursor(dictionary=True)
        try:
            cur.execute("SELECT account_id FROM accounts WHERE account_number IN (%s,%s) ORDER BY account_id", (src,dst))
            ids = cur.fetchall()
            if len(ids) != 2: raise ValueError('Source or destination account does not exist.')
            # Deterministic lock order prevents lock-order inversion.
            locked = {}
            for row in ids:
                cur.execute("SELECT * FROM accounts WHERE account_id=%s FOR UPDATE", (row['account_id'],))
                a=cur.fetchone(); locked[a['account_number']]=a
            a,b=locked.get(src),locked.get(dst)
            if not a or not b: raise ValueError('Source or destination account does not exist.')
            if a['status'] != 'ACTIVE': raise ValueError(f"Source account is {a['status']}.")
            if b['status'] != 'ACTIVE': raise ValueError(f"Destination account is {b['status']}.")
            before_a, before_b = Decimal(str(a['balance'])), Decimal(str(b['balance']))
            after_a, after_b = before_a-amount, before_b+amount
            _update_balance(cur,a,after_a); _update_balance(cur,b,after_b)
            ref=_txn(cur,a['account_id'],'TRANSFER_OUT',amount,before_a,after_a,desc or f'Transfer to {dst}',channel or 'ONLINE',b['account_id'])
            _txn(cur,b['account_id'],'TRANSFER_IN',amount,before_b,after_b,desc or f'Transfer from {src}',channel or 'ONLINE',a['account_id'])
            cnx.commit()
            return [src,dst,float(amount),desc,channel,'SUCCESS',f'Successfully transferred ₹{amount} to {dst}.',ref]
        except Exception as exc:
            cnx.rollback(); return [src,dst,float(amount),desc,channel,'FAILED',str(exc),None]
        finally: cur.close()


def _service_money(args, kind):
    number, amount, desc, channel = args[:4]
    amount=Decimal(str(amount or 0)).quantize(Decimal('0.01'))
    if amount <= 0: return [number,float(amount),desc,channel,'FAILED','Amount must be greater than zero.',None]
    with get_db() as cnx:
        cur=cnx.cursor(dictionary=True)
        try:
            a=_get_account(cur,number)
            if not a: raise ValueError('Account not found.')
            if a['status'] != 'ACTIVE': raise ValueError(f"Account is {a['status']} and cannot transact.")
            before=Decimal(str(a['balance']))
            after=before+amount if kind=='DEPOSIT' else before-amount
            _update_balance(cur,a,after)
            ref=_txn(cur,a['account_id'],kind,amount,before,after,desc or kind.title(),channel or 'ONLINE')
            cnx.commit()
            return [number,float(amount),desc,channel,'SUCCESS',f'{kind.title()} of ₹{amount} completed.',ref]
        except Exception as exc:
            cnx.rollback(); return [number,float(amount),desc,channel,'FAILED',str(exc),None]
        finally: cur.close()


def _service_open(args):
    customer, branch, typ, deposit, rate, minimum = args[:6]
    with get_db() as cnx:
        cur=cnx.cursor(dictionary=True)
        try:
            cur.execute("SELECT customer_id FROM customers WHERE customer_id=%s",(customer,))
            if not cur.fetchone(): raise ValueError('Customer not found.')
            cur.execute("SELECT branch_id FROM branches WHERE branch_id=%s",(branch,))
            if not cur.fetchone(): raise ValueError('Branch not found.')
            number=''.join(secrets.choice(string.digits) for _ in range(12))
            cur.execute("INSERT INTO accounts (account_number,customer_id,branch_id,account_type,balance,minimum_balance,interest_rate,currency,status,opened_date) VALUES (%s,%s,%s,%s,0,%s,%s,'INR','ACTIVE',CURDATE())",(number,customer,branch,typ,minimum,rate))
            account_id=cur.lastrowid
            _audit(cur,'accounts','INSERT',account_id,f'Account {number} opened.',None,{"account_number":number,"balance":0})
            if Decimal(str(deposit)) > 0:
                cur.execute("SELECT * FROM accounts WHERE account_id=%s FOR UPDATE",(account_id,)); a=cur.fetchone()
                _update_balance(cur,a,Decimal(str(deposit)))
                _txn(cur,account_id,'DEPOSIT',Decimal(str(deposit)),Decimal('0'),Decimal(str(deposit)),'Initial account deposit','BRANCH')
            cnx.commit()
            return [customer,branch,typ,float(deposit),float(rate),float(minimum),number,'SUCCESS','Account opened successfully.']
        except Exception as exc:
            cnx.rollback(); return [customer,branch,typ,deposit,rate,minimum,None,'FAILED',str(exc)]
        finally: cur.close()


def _service_apply_loan(args):
    customer, account_id, typ, principal, term, rate = args[:6]
    principal=Decimal(str(principal)); term=int(term); rate=Decimal(str(rate))
    with get_db() as cnx:
        cur=cnx.cursor(dictionary=True)
        try:
            cur.execute("SELECT * FROM accounts WHERE account_id=%s FOR UPDATE",(account_id,)); a=cur.fetchone()
            if not a or int(a['customer_id']) != int(customer): raise ValueError('Customer/account combination is invalid.')
            if a['status'] != 'ACTIVE': raise ValueError('Loan disbursement account must be active.')
            if principal <= 0 or term <= 0: raise ValueError('Principal and term must be positive.')
            r=float(rate)/1200
            emi=(float(principal)*r*(1+r)**term/((1+r)**term-1)) if r else float(principal)/term
            emi=Decimal(str(round(emi,2)))
            loan_no=f"LN-{datetime.utcnow():%y%m}-{secrets.randbelow(100000):05d}"
            cur.execute("INSERT INTO loans (loan_number,customer_id,account_id,loan_type,principal_amount,interest_rate,term_months,monthly_emi,outstanding_balance,status,start_date,end_date) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,'ACTIVE',CURDATE(),DATE_ADD(CURDATE(), INTERVAL %s MONTH))",(loan_no,customer,account_id,typ,principal,rate,term,emi,principal,term))
            loan_id=cur.lastrowid
            _audit(cur,'loans','INSERT',loan_id,f'Loan originated: {loan_no}.',None,{"loan_number":loan_no,"principal":float(principal),"emi":float(emi)})
            before=Decimal(str(a['balance'])); after=before+principal
            _update_balance(cur,a,after)
            _txn(cur,account_id,'LOAN_DISBURSEMENT',principal,before,after,f'Disbursement for Loan {loan_no}','SYSTEM')
            cnx.commit()
            return [customer,account_id,typ,float(principal),term,float(rate),loan_id,float(emi),'SUCCESS',f'Loan approved and disbursed. Monthly EMI: ₹{emi}']
        except Exception as exc:
            cnx.rollback(); return [customer,account_id,typ,float(principal),term,float(rate),None,0,'FAILED',str(exc)]
        finally: cur.close()


def _service_pay_loan(args):
    loan_id, account_no = args[:2]
    with get_db() as cnx:
        cur=cnx.cursor(dictionary=True)
        try:
            a=_get_account(cur,account_no)
            cur.execute("SELECT * FROM loans WHERE loan_id=%s AND status='ACTIVE' FOR UPDATE",(loan_id,)); loan=cur.fetchone()
            if not a: raise ValueError('Payment account not found.')
            if not loan: raise ValueError('Active loan not found or already paid off.')
            if a['status'] != 'ACTIVE': raise ValueError('Payment account is not active.')
            emi=Decimal(str(loan['monthly_emi'])); bal=Decimal(str(a['balance'])); minimum=Decimal(str(a['minimum_balance']))
            if bal-emi < minimum: raise ValueError('Insufficient balance to pay monthly EMI.')
            outstanding=Decimal(str(loan['outstanding_balance']))
            interest=min(emi, (outstanding*Decimal(str(loan['interest_rate']))/Decimal('1200')).quantize(Decimal('.01')))
            principal=min(outstanding,emi-interest); after=bal-emi
            _update_balance(cur,a,after)
            remaining=max(Decimal('0'),outstanding-principal)
            cur.execute("UPDATE loans SET outstanding_balance=%s,status=%s WHERE loan_id=%s",(remaining,'PAID_OFF' if remaining<=0 else 'ACTIVE',loan_id))
            cur.execute("SELECT COALESCE(MAX(payment_number),0)+1 AS n FROM loan_payments WHERE loan_id=%s",(loan_id,)); n=cur.fetchone()['n']
            cur.execute("INSERT INTO loan_payments (loan_id,payment_number,payment_amount,principal_component,interest_component,status) VALUES (%s,%s,%s,%s,%s,'COMPLETED')",(loan_id,n,emi,principal,interest))
            _txn(cur,a['account_id'],'LOAN_REPAYMENT',emi,bal,after,f'EMI Payment for Loan ID {loan_id}','ONLINE')
            cnx.commit(); return [loan_id,account_no,'SUCCESS',f'EMI of ₹{emi} processed. Remaining principal: ₹{remaining}.']
        except Exception as exc:
            cnx.rollback(); return [loan_id,account_no,'FAILED',str(exc)]
        finally: cur.close()


def call_procedure(proc_name, params=None):
    """Compatibility dispatcher replacing unsupported TiDB stored procedures."""
    p=list(params or [])
    if proc_name=='sp_transfer_funds': out=_service_transfer(p)
    elif proc_name=='sp_deposit_funds': out=_service_money(p,'DEPOSIT')
    elif proc_name=='sp_withdraw_funds': out=_service_money(p,'WITHDRAWAL')
    elif proc_name=='sp_open_account': out=_service_open(p)
    elif proc_name=='sp_apply_loan': out=_service_apply_loan(p)
    elif proc_name=='sp_pay_loan_installment': out=_service_pay_loan(p)
    elif proc_name=='sp_monthly_interest_accrual': out=_service_interest()
    else: raise ValueError(f'Unknown legacy procedure: {proc_name}')
    return {"out_args": out, "results": []}


def _service_interest():
    count=0; total=Decimal('0.00')
    with get_db() as cnx:
        cur=cnx.cursor(dictionary=True)
        try:
            cur.execute("SELECT * FROM accounts WHERE account_type='SAVINGS' AND status='ACTIVE' ORDER BY account_id FOR UPDATE")
            accounts=cur.fetchall()
            for a in accounts:
                interest=(Decimal(str(a['balance']))*Decimal(str(a['interest_rate']))/Decimal('100')/Decimal('12')).quantize(Decimal('.01'))
                if interest<=0: continue
                before=Decimal(str(a['balance'])); after=before+interest
                _update_balance(cur,a,after)
                _txn(cur,a['account_id'],'INTEREST_CREDIT',interest,before,after,'Monthly savings interest accrual','SYSTEM')
                total+=interest; count+=1
            cnx.commit(); return [count,float(total)]
        except Exception:
            cnx.rollback(); raise
        finally: cur.close()


def check_connection():
    try:
        with get_db() as cnx:
            cur=cnx.cursor(dictionary=True)
            cur.execute("SELECT VERSION() AS version, DATABASE() AS db_name, CURRENT_USER() AS user_session, NOW() AS server_time")
            meta=cur.fetchone()
            cur.execute("SELECT COUNT(*) AS total_tables FROM information_schema.tables WHERE table_schema=%s",(Config.DB_NAME,))
            count=cur.fetchone()['total_tables']; cur.close()
            return {"connected":True,"version":meta['version'],"database":meta['db_name'],"user":meta['user_session'],"server_time":meta['server_time'].isoformat() if meta['server_time'] else None,"total_tables":count}
    except Exception as exc:
        return {"connected":False,"error":str(exc)}
