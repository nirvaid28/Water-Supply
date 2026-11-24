import os
import mysql.connector
from mysql.connector import Error
import pandas as pd
import streamlit as st
from dotenv import load_dotenv

load_dotenv()


def get_default_config() -> dict:
    """Resolve DB config priority: Streamlit secrets -> env vars -> local defaults."""
    secrets_cfg = {}
    try:
        if "mysql" in st.secrets:
            secrets_cfg = dict(st.secrets["mysql"])
    except Exception:
        secrets_cfg = {}

    return {
        "host": secrets_cfg.get("host") or os.getenv("DB_HOST", "127.0.0.1"),
        "port": int(secrets_cfg.get("port") or os.getenv("DB_PORT", "3306")),
        "user": secrets_cfg.get("user") or os.getenv("DB_USER", "root"),
        "password": secrets_cfg.get("password") or os.getenv("DB_PASSWORD", ""),
        "database": secrets_cfg.get("database") or os.getenv("DB_NAME", "water_billing_db"),
    }


def get_connection(cfg: dict):
    """Create and return a MySQL connection."""
    return mysql.connector.connect(
        host=cfg["host"],
        port=int(cfg["port"]),
        user=cfg["user"],
        password=cfg["password"],
        database=cfg["database"],
        autocommit=False,
    )


def test_connection(cfg: dict) -> tuple[bool, str]:
    """Test connectivity and confirm water_billing_db tables exist."""
    conn = None
    try:
        conn = get_connection(cfg)
        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = %s", (cfg["database"],))
        count = cur.fetchone()[0]
        cur.close()
        return True, f"Connected to `{cfg['database']}` ({count} tables/views found)"
    except Error as e:
        return False, f"MySQL Error {e.errno}: {e.msg}"
    except Exception as e:
        return False, str(e)
    finally:
        if conn and conn.is_connected():
            conn.close()


def fetch_df(cfg: dict, query: str, params: tuple | None = None) -> pd.DataFrame:
    """Run a SELECT query and return a pandas DataFrame."""
    conn = None
    try:
        conn = get_connection(cfg)
        cur = conn.cursor(dictionary=True)
        cur.execute(query, params or ())
        rows = cur.fetchall()
        cols = [d[0] for d in cur.description] if cur.description else []
        cur.close()
        return pd.DataFrame(rows, columns=cols)
    finally:
        if conn and conn.is_connected():
            conn.close()


def execute_write(cfg: dict, query: str, params: tuple | None = None) -> int:
    """Run INSERT / UPDATE / DELETE and commit."""
    conn = None
    try:
        conn = get_connection(cfg)
        cur = conn.cursor()
        cur.execute(query, params or ())
        affected = cur.rowcount
        conn.commit()
        cur.close()
        return affected
    except Exception:
        if conn and conn.is_connected():
            conn.rollback()
        raise
    finally:
        if conn and conn.is_connected():
            conn.close()


def call_procedure(cfg: dict, proc_name: str, args: tuple) -> None:
    """Invoke a MySQL stored procedure safely."""
    conn = None
    try:
        conn = get_connection(cfg)
        cur = conn.cursor()
        cur.callproc(proc_name, args)
        conn.commit()
        cur.close()
    except Exception:
        if conn and conn.is_connected():
            conn.rollback()
        raise
    finally:
        if conn and conn.is_connected():
            conn.close()
