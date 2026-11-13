#!/usr/bin/env python3
"""Install NovaBank schema, views and sample data on TiDB Cloud Starter."""
import os, re, argparse, random
from pathlib import Path
from dotenv import load_dotenv
import mysql.connector
ROOT=Path(__file__).resolve().parent
load_dotenv(ROOT/'.env')
CFG=dict(host=os.getenv('DB_HOST'),port=int(os.getenv('DB_PORT','4000')),user=os.getenv('DB_USER'),password=os.getenv('DB_PASSWORD'),database=os.getenv('DB_NAME','novabank'),autocommit=True,connection_timeout=20,ssl_disabled=False)
if os.getenv('DB_SSL_CA'):
    CFG.update(ssl_ca=os.getenv('DB_SSL_CA'),ssl_verify_cert=True,ssl_verify_identity=True)
def statements(path):
    text=Path(path).read_text(encoding='utf-8')
    text=re.sub(r'/\*.*?\*/','',text,flags=re.S)
    text='\n'.join(line for line in text.splitlines() if not line.strip().startswith('--'))
    return [x.strip() for x in text.split(';') if x.strip()]
def seed_query_demo(cur):
    cities=['Mumbai','Bengaluru','New Delhi','Hyderabad','Chennai']; cats=['RETAIL','SALARY','UTILITY','INVESTMENT','TRANSFER']; rows=[]
    for i in range(1,2501):
        tag=f'TAG-{i%100:04d}'
        rows.append((f'CUST-{10000+i%50:05d}',cities[i%5],cats[i%5],round(500+random.random()*75000,2),f'2025-01-{(i%28)+1:02d}',f'Audit ledger item #{i}',tag,tag))
    cur.executemany('INSERT INTO query_demo_data (customer_code,city,txn_category,amount,created_date,notes,indexed_tag,unindexed_tag) VALUES (%s,%s,%s,%s,%s,%s,%s,%s)',rows)
def install(reset=False):
    if not all([CFG['host'],CFG['user'],CFG['password']]): raise SystemExit('Set DB_HOST, DB_USER and DB_PASSWORD in .env first.')
    base={k:v for k,v in CFG.items() if k!='database'}; cnx=mysql.connector.connect(**base); cur=cnx.cursor(); db=CFG['database'].replace('`','')
    cur.execute('SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=%s AND table_type=\"BASE TABLE\"',(db,)); existing=cur.fetchone()[0]
    if existing and not reset:
        raise SystemExit(f'{db} already contains {existing} tables. Refusing to overwrite data. Use --reset only if you intend to erase it.')
    if reset: print('WARNING: dropping and recreating',db); cur.execute(f'DROP DATABASE IF EXISTS `{db}`')
    cur.execute(f'CREATE DATABASE IF NOT EXISTS `{db}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci'); cur.execute(f'USE `{db}`')
    for name in ['01_schema.sql','02_views.sql','06_seed_data.sql']:
        print('Applying',name)
        for sql in statements(ROOT/'database'/name): cur.execute(sql)
    print('Generating 2,500 query-optimization demo rows...'); seed_query_demo(cur)
    cur.execute('SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=%s AND table_type="BASE TABLE"',(db,)); tables=cur.fetchone()[0]
    cur.execute('SELECT COUNT(*) FROM accounts'); accounts=cur.fetchone()[0]
    cur.execute('SELECT COUNT(*) FROM transactions'); txns=cur.fetchone()[0]
    cur.execute('SELECT COUNT(*) FROM query_demo_data'); demos=cur.fetchone()[0]
    print(f'Installed. Tables={tables}, accounts={accounts}, transactions={txns}, query_demo_rows={demos}')
    cur.close(); cnx.close()
if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('--reset',action='store_true'); install(reset=parser.parse_args().reset)
