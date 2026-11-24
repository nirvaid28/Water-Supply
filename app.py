from datetime import date, datetime
import pandas as pd
import streamlit as st
from mysql.connector import Error

from db import (
    call_procedure,
    execute_write,
    fetch_df,
    get_default_config,
    test_connection,
)

st.set_page_config(
    page_title="WATER-CAD // Utility Dispatch",
    page_icon="◼",
    layout="wide",
    initial_sidebar_state="expanded",
)

# ---------------------------------------------------------------------------
# 911 / CAD Tactical Monochrome Theme (Black & White Minimalist CSS)
# ---------------------------------------------------------------------------
st.markdown(
    """
    <style>
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;600;700&display=swap');

    html, body, [class*="css"] {
        font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
        background-color: #09090B;
        color: #F4F4F5;
    }

    /* Tighten page padding for high-density command view */
    .block-container {
        padding-top: 1.2rem;
        padding-bottom: 1.5rem;
        padding-left: 1.5rem;
        padding-right: 1.5rem;
        max-width: 100%;
    }

    /* Hide default Streamlit chrome */
    #MainMenu, footer {visibility: hidden;}
    header[data-testid="stHeader"] {
        background: #09090B;
        border-bottom: 1px solid #1F1F23;
    }

    /* Sidebar styling */
    section[data-testid="stSidebar"] {
        background-color: #0C0C0E;
        border-right: 1px solid #27272A;
    }
    section[data-testid="stSidebar"] .stRadio label {
        font-family: 'JetBrains Mono', monospace;
        font-size: 0.78rem;
        text-transform: uppercase;
        letter-spacing: 0.06em;
        padding: 4px 0;
    }

    /* Tactical top command bar */
    .cad-topbar {
        display: flex;
        justify-content: space-between;
        align-items: center;
        background: #111113;
        border: 1px solid #27272A;
        border-left: 3px solid #FFFFFF;
        padding: 10px 16px;
        margin-bottom: 14px;
        border-radius: 2px;
    }
    .cad-title {
        font-family: 'JetBrains Mono', monospace;
        font-size: 0.95rem;
        font-weight: 700;
        letter-spacing: 0.12em;
        color: #FFFFFF;
        text-transform: uppercase;
    }
    .cad-meta {
        font-family: 'JetBrains Mono', monospace;
        font-size: 0.72rem;
        color: #A1A1AA;
        letter-spacing: 0.08em;
        text-transform: uppercase;
    }
    .cad-badge-online {
        display: inline-block;
        background: #FFFFFF;
        color: #09090B;
        font-family: 'JetBrains Mono', monospace;
        font-size: 0.68rem;
        font-weight: 700;
        padding: 2px 8px;
        border-radius: 2px;
        letter-spacing: 0.1em;
        margin-left: 10px;
    }
    .cad-badge-offline {
        display: inline-block;
        background: #27272A;
        color: #FFFFFF;
        border: 1px solid #71717A;
        font-family: 'JetBrains Mono', monospace;
        font-size: 0.68rem;
        font-weight: 700;
        padding: 2px 8px;
        border-radius: 2px;
        letter-spacing: 0.1em;
        margin-left: 10px;
    }

    /* Section panel headers */
    .cad-panel-hdr {
        font-family: 'JetBrains Mono', monospace;
        font-size: 0.74rem;
        font-weight: 700;
        letter-spacing: 0.12em;
        text-transform: uppercase;
        color: #E4E4E7;
        background: #141417;
        border: 1px solid #27272A;
        border-bottom: none;
        padding: 7px 12px;
        margin-top: 8px;
        border-radius: 2px 2px 0 0;
        display: flex;
        justify-content: space-between;
        align-items: center;
    }
    .cad-panel-tag {
        font-size: 0.65rem;
        color: #A1A1AA;
        font-weight: 400;
    }

    /* Metric cards */
    div[data-testid="stMetric"] {
        background-color: #111113;
        border: 1px solid #27272A;
        border-top: 2px solid #FFFFFF;
        padding: 10px 14px;
        border-radius: 2px;
    }
    div[data-testid="stMetric"] label {
        font-family: 'JetBrains Mono', monospace !important;
        font-size: 0.68rem !important;
        text-transform: uppercase;
        letter-spacing: 0.1em;
        color: #A1A1AA !important;
    }
    div[data-testid="stMetric"] [data-testid="stMetricValue"] {
        font-family: 'JetBrains Mono', monospace !important;
        font-size: 1.35rem !important;
        font-weight: 700 !important;
        color: #FFFFFF !important;
    }

    /* DataFrames & Tables */
    div[data-testid="stDataFrame"] {
        border: 1px solid #27272A;
        border-radius: 0 0 2px 2px;
    }

    /* High-contrast monochrome buttons */
    .stButton > button, .stFormSubmitButton > button {
        background-color: #FFFFFF !important;
        color: #09090B !important;
        border: 1px solid #FFFFFF !important;
        border-radius: 2px !important;
        font-family: 'JetBrains Mono', monospace !important;
        font-size: 0.75rem !important;
        font-weight: 700 !important;
        letter-spacing: 0.08em !important;
        text-transform: uppercase !important;
        padding: 0.45rem 1rem !important;
    }
    .stButton > button:hover, .stFormSubmitButton > button:hover {
        background-color: #D4D4D8 !important;
        border-color: #D4D4D8 !important;
        color: #09090B !important;
    }

    /* Tabs */
    button[data-baseweb="tab"] {
        font-family: 'JetBrains Mono', monospace !important;
        font-size: 0.75rem !important;
        text-transform: uppercase;
        letter-spacing: 0.08em;
        color: #A1A1AA !important;
    }
    button[data-baseweb="tab"][aria-selected="true"] {
        color: #FFFFFF !important;
        border-bottom-color: #FFFFFF !important;
    }

    /* Inputs & forms */
    div[data-testid="stForm"] {
        background: #111113;
        border: 1px solid #27272A;
        border-radius: 2px;
        padding: 14px;
    }
    </style>
    """,
    unsafe_allow_html=True,
)

CORE_TABLES = [
    "LOCALITY",
    "CUSTOMER",
    "TARIFF",
    "SERVICE_CONNECTION",
    "WATER_METER",
    "METER_REPLACEMENT_HISTORY",
    "METER_READING",
    "BILL",
    "BILL_DETAIL",
    "PAYMENT",
    "COMPLAINT",
    "MAINTENANCE_REQUEST",
    "SERVICE_INTERRUPTION",
    "AUDIT_LOG",
]

CORE_VIEWS = [
    "vw_customer_connections",
    "vw_outstanding_bills",
    "vw_locality_consumption_revenue",
    "vw_active_maintenance_complaints",
]


def panel_header(title: str, tag: str = ""):
    st.markdown(
        f'<div class="cad-panel-hdr"><span>▪ {title}</span><span class="cad-panel-tag">{tag}</span></div>',
        unsafe_allow_html=True,
    )


def show_sql_error(err: Exception):
    if isinstance(err, Error):
        st.error(f"MYSQL ERROR {err.errno}: {err.msg}")
    else:
        st.error(str(err))


# ---------------------------------------------------------------------------
# Sidebar: Dispatch Navigation & MySQL Link
# ---------------------------------------------------------------------------
if "db_cfg" not in st.session_state:
    st.session_state.db_cfg = get_default_config()

with st.sidebar:
    st.markdown(
        '<div style="font-family:JetBrains Mono,monospace;font-size:0.95rem;font-weight:700;letter-spacing:0.14em;color:#FFF;padding-bottom:2px;">◼ WATER-CAD</div>'
        '<div style="font-family:JetBrains Mono,monospace;font-size:0.68rem;color:#71717A;letter-spacing:0.08em;margin-bottom:14px;">UTILITY COMMAND // IBD312</div>',
        unsafe_allow_html=True,
    )

    page = st.radio(
        "MODULES",
        [
            "01 // Command Center",
            "02 // Customers & Units",
            "03 // Readings & Billing",
            "04 // Payments & Dues",
            "05 // Incidents & Outages",
            "06 // Table Explorer",
            "07 // Audit & SQL Console",
        ],
        label_visibility="collapsed",
    )

    st.divider()
    with st.expander("DB CONNECTION", expanded=False):
        cfg = st.session_state.db_cfg
        host = st.text_input("Host", value=cfg["host"])
        port = st.number_input("Port", value=int(cfg["port"]), step=1)
        user = st.text_input("User", value=cfg["user"])
        password = st.text_input("Password", value=cfg["password"], type="password")
        database = st.text_input("Database", value=cfg["database"])
        if st.button("APPLY & TEST", use_container_width=True):
            st.session_state.db_cfg = {
                "host": host,
                "port": int(port),
                "user": user,
                "password": password,
                "database": database,
            }
            st.rerun()

    ok, msg = test_connection(st.session_state.db_cfg)
    status_color = "#FFFFFF" if ok else "#71717A"
    st.markdown(
        f'<div style="font-family:JetBrains Mono,monospace;font-size:0.7rem;color:{status_color};'
        f'border:1px solid #27272A;background:#111113;padding:8px 10px;border-radius:2px;">'
        f'LINK: {"ONLINE" if ok else "OFFLINE"}<br><span style="color:#A1A1AA;">{msg}</span></div>',
        unsafe_allow_html=True,
    )

db_cfg = st.session_state.db_cfg

# Persistent Tactical Command Bar across all pages
now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
badge_html = (
    '<span class="cad-badge-online">DB ONLINE</span>'
    if ok
    else '<span class="cad-badge-offline">DB OFFLINE</span>'
)
st.markdown(
    f"""
    <div class="cad-topbar">
        <div>
            <span class="cad-title">WATER-CAD // UTILITY OPERATIONS DISPATCH</span>
            {badge_html}
        </div>
        <div class="cad-meta">OP: NIRVAID JAIN (TCA2573025) &nbsp;|&nbsp; DB: {db_cfg['database'].upper()} &nbsp;|&nbsp; {now_str}</div>
    </div>
    """,
    unsafe_allow_html=True,
)

if not ok:
    st.warning("DATABASE OFFLINE — Open DB CONNECTION in the left sidebar and enter your MySQL credentials.")
    st.stop()


# ===========================================================================
# 01 // COMMAND CENTER — EVERY IMPORTANT METRIC & FEED ON ONE SCREEN
# ===========================================================================
if page == "01 // Command Center":
    kpi_df = fetch_df(
        db_cfg,
        """
        SELECT
            (SELECT COUNT(*) FROM SERVICE_CONNECTION WHERE connection_status = 'ACTIVE') AS active_conns,
            (SELECT IFNULL(SUM(units_billed), 0) FROM BILL) AS total_units_kl,
            (SELECT IFNULL(SUM(total_amount), 0) FROM BILL) AS total_billed,
            (SELECT IFNULL(SUM(amount_paid), 0) FROM BILL) AS total_collected,
            (SELECT IFNULL(SUM(total_amount - amount_paid), 0) FROM BILL WHERE bill_status IN ('UNPAID','PARTIAL','OVERDUE')) AS pending_dues,
            (SELECT COUNT(*) FROM COMPLAINT WHERE complaint_status IN ('OPEN','IN_PROGRESS')) AS open_incidents
        """,
    )
    row = kpi_df.iloc[0]

    # Row 1: 6-tile live telemetry strip
    c1, c2, c3, c4, c5, c6 = st.columns(6)
    c1.metric("ACTIVE CONNECTIONS", int(row["active_conns"]))
    c2.metric("TOTAL CONSUMPTION", f"{int(row['total_units_kl']):,} KL")
    c3.metric("TOTAL BILLED", f"Rs.{float(row['total_billed']):,.0f}")
    c4.metric("COLLECTED", f"Rs.{float(row['total_collected']):,.0f}")
    c5.metric("PENDING DUES", f"Rs.{float(row['pending_dues']):,.0f}")
    c6.metric("OPEN INCIDENTS", int(row["open_incidents"]))

    # Row 2: Active Incidents + High Consumption Alerts | Outstanding Dues + Outages
    left_col, right_col = st.columns(2)

    with left_col:
        panel_header("ACTIVE INCIDENTS & DISPATCH", "vw_active_maintenance_complaints")
        inc_df = fetch_df(
            db_cfg,
            "SELECT complaint_id AS ID, priority AS PRI, complaint_type AS TYPE, full_name AS CUSTOMER, "
            "locality_name AS ZONE, complaint_status AS STATUS, assigned_team AS UNIT "
            "FROM vw_active_maintenance_complaints ORDER BY filed_date DESC",
        )
        st.dataframe(inc_df, use_container_width=True, hide_index=True, height=185)

        panel_header("HIGH CONSUMPTION ANOMALIES (>1.5x AVG)", "UNIT-2 SUBQUERY")
        high_df = fetch_df(
            db_cfg,
            """
            SELECT mr.billing_month AS MONTH, sc.connection_no AS CONN, c.full_name AS CUSTOMER,
                   c.customer_type AS CAT, mr.units_consumed AS KL,
                   (
                       SELECT ROUND(AVG(mr2.units_consumed), 1)
                       FROM METER_READING mr2
                       INNER JOIN SERVICE_CONNECTION sc2 ON mr2.connection_id = sc2.connection_id
                       INNER JOIN CUSTOMER c2 ON sc2.customer_id = c2.customer_id
                       WHERE c2.customer_type = c.customer_type
                   ) AS AVG_KL
            FROM METER_READING mr
            INNER JOIN SERVICE_CONNECTION sc ON mr.connection_id = sc.connection_id
            INNER JOIN CUSTOMER c ON sc.customer_id = c.customer_id
            WHERE mr.units_consumed > 1.5 * (
                SELECT AVG(mr3.units_consumed)
                FROM METER_READING mr3
                INNER JOIN SERVICE_CONNECTION sc3 ON mr3.connection_id = sc3.connection_id
                INNER JOIN CUSTOMER c3 ON sc3.customer_id = c3.customer_id
                WHERE c3.customer_type = c.customer_type
            )
            ORDER BY mr.units_consumed DESC
            """,
        )
        st.dataframe(high_df, use_container_width=True, hide_index=True, height=150)

    with right_col:
        panel_header("OUTSTANDING & OVERDUE ACCOUNTS", "vw_outstanding_bills")
        out_df = fetch_df(
            db_cfg,
            "SELECT bill_number AS BILL, full_name AS CUSTOMER, locality_name AS ZONE, "
            "due_date AS DUE, balance_due AS BALANCE_RS, bill_status AS STATUS "
            "FROM vw_outstanding_bills ORDER BY due_date",
        )
        st.dataframe(out_df, use_container_width=True, hide_index=True, height=185)

        panel_header("SERVICE INTERRUPTIONS LOG", "SERVICE_INTERRUPTION")
        int_df = fetch_df(
            db_cfg,
            """
            SELECT l.locality_name AS ZONE, si.interruption_type AS TYPE,
                   DATE_FORMAT(si.start_time, '%Y-%m-%d %H:%i') AS START,
                   IFNULL(DATE_FORMAT(si.end_time, '%H:%i'), 'ACTIVE') AS END,
                   si.reason AS REASON
            FROM SERVICE_INTERRUPTION si
            INNER JOIN LOCALITY l ON si.locality_id = l.locality_id
            ORDER BY si.start_time DESC
            """,
        )
        st.dataframe(int_df, use_container_width=True, hide_index=True, height=150)

    # Row 3: Locality Telemetry | Live Audit Stream
    b_left, b_right = st.columns(2)
    with b_left:
        panel_header("ZONE CONSUMPTION & REVENUE TELEMETRY", "vw_locality_consumption_revenue")
        loc_df = fetch_df(
            db_cfg,
            "SELECT ward_code AS WARD, locality_name AS ZONE, total_connections AS CONNS, "
            "total_units_kl AS KL, total_billed_rs AS BILLED, total_collected_rs AS COLLECTED, "
            "total_pending_rs AS PENDING "
            "FROM vw_locality_consumption_revenue ORDER BY total_billed_rs DESC",
        )
        st.dataframe(loc_df, use_container_width=True, hide_index=True, height=190)

    with b_right:
        panel_header("LIVE AUDIT STREAM (LATEST 12 EVENTS)", "AUDIT_LOG // TRIGGERS")
        aud_df = fetch_df(
            db_cfg,
            "SELECT log_id AS ID, table_name AS SRC, action_type AS EVENT, action_details AS DETAILS "
            "FROM AUDIT_LOG ORDER BY log_id DESC LIMIT 12",
        )
        st.dataframe(aud_df, use_container_width=True, hide_index=True, height=190)


# ===========================================================================
# 02 // CUSTOMERS & UNITS
# ===========================================================================
elif page == "02 // Customers & Units":
    t1, t2, t3, t4 = st.tabs(["ACTIVE DIRECTORY", "REGISTER CUSTOMER", "NEW CONNECTION & METER", "EDIT CUSTOMER"])

    with t1:
        df = fetch_df(db_cfg, "SELECT * FROM vw_customer_connections ORDER BY customer_id")
        q = st.text_input("FILTER BY NAME / ZONE / CONNECTION NO", placeholder="Type to filter...")
        if q:
            mask = (
                df["full_name"].str.contains(q, case=False, na=False)
                | df["locality_name"].str.contains(q, case=False, na=False)
                | df["connection_no"].str.contains(q, case=False, na=False)
            )
            df = df[mask]
        panel_header("CUSTOMER & CONNECTION REGISTRY", f"{len(df)} RECORDS")
        st.dataframe(df, use_container_width=True, hide_index=True)

    with t2:
        localities = fetch_df(db_cfg, "SELECT locality_id, locality_name FROM LOCALITY ORDER BY locality_name")
        with st.form("add_customer_form"):
            c1, c2 = st.columns(2)
            full_name = c1.text_input("Full Name *")
            phone = c2.text_input("Phone *")
            c3, c4 = st.columns(2)
            email = c3.text_input("Email")
            loc_name = c4.selectbox("Locality *", localities["locality_name"].tolist())
            address_line = st.text_input("Address *")
            c5, c6 = st.columns(2)
            cust_type = c5.selectbox("Customer Type *", ["DOMESTIC", "COMMERCIAL", "INDUSTRIAL"])
            reg_date = c6.date_input("Registered On", value=date.today())
            if st.form_submit_button("REGISTER CUSTOMER"):
                if not full_name.strip() or not phone.strip() or not address_line.strip():
                    st.error("Full Name, Phone, and Address are required.")
                else:
                    loc_id = int(localities.loc[localities["locality_name"] == loc_name, "locality_id"].iloc[0])
                    try:
                        execute_write(
                            db_cfg,
                            "INSERT INTO CUSTOMER (full_name, phone, email, address_line, locality_id, customer_type, registered_on) "
                            "VALUES (%s, %s, %s, %s, %s, %s, %s)",
                            (full_name.strip(), phone.strip(), email.strip() or None, address_line.strip(), loc_id, cust_type, reg_date),
                        )
                        st.success(f"REGISTERED: {full_name}")
                        st.rerun()
                    except Exception as e:
                        show_sql_error(e)

    with t3:
        customers = fetch_df(db_cfg, "SELECT customer_id, full_name, locality_id FROM CUSTOMER ORDER BY customer_id DESC")
        tariffs = fetch_df(db_cfg, "SELECT tariff_id, tariff_name FROM TARIFF WHERE is_active = 1 ORDER BY tariff_id")
        with st.form("add_conn_meter_form"):
            c1, c2 = st.columns(2)
            cust_opts = {f"#{r.customer_id} - {r.full_name}": (int(r.customer_id), int(r.locality_id)) for r in customers.itertuples()}
            tariff_opts = {r.tariff_name: int(r.tariff_id) for r in tariffs.itertuples()}
            sel_cust = c1.selectbox("Customer *", list(cust_opts.keys()))
            sel_tariff = c2.selectbox("Tariff Plan *", list(tariff_opts.keys()))
            c3, c4 = st.columns(2)
            conn_no = c3.text_input("Connection Number *", placeholder="CONN-1007")
            pipe_mm = c4.selectbox("Pipe Diameter (mm)", [15, 20, 25, 40, 50])
            c5, c6 = st.columns(2)
            meter_serial = c5.text_input("Meter Serial No. *", placeholder="WM-2026-010")
            manufacturer = c6.text_input("Manufacturer *", value="Kranti")
            conn_date = st.date_input("Installation Date", value=date.today())
            if st.form_submit_button("CREATE CONNECTION & METER"):
                if not conn_no.strip() or not meter_serial.strip():
                    st.error("Connection Number and Meter Serial Number are required.")
                else:
                    cid, lid = cust_opts[sel_cust]
                    tid = tariff_opts[sel_tariff]
                    try:
                        execute_write(
                            db_cfg,
                            "INSERT INTO SERVICE_CONNECTION (connection_no, customer_id, locality_id, tariff_id, pipe_diameter_mm, connection_date) "
                            "VALUES (%s, %s, %s, %s, %s, %s)",
                            (conn_no.strip(), cid, lid, tid, pipe_mm, conn_date),
                        )
                        new_conn_id = int(
                            fetch_df(db_cfg, "SELECT connection_id FROM SERVICE_CONNECTION WHERE connection_no = %s", (conn_no.strip(),)).iloc[0]["connection_id"]
                        )
                        execute_write(
                            db_cfg,
                            "INSERT INTO WATER_METER (meter_serial_no, connection_id, manufacturer, installed_on, initial_reading, meter_status) "
                            "VALUES (%s, %s, %s, %s, 0, 'ACTIVE')",
                            (meter_serial.strip(), new_conn_id, manufacturer.strip(), conn_date),
                        )
                        st.success(f"CREATED: {conn_no} / {meter_serial}")
                        st.rerun()
                    except Exception as e:
                        show_sql_error(e)

    with t4:
        cust_df = fetch_df(db_cfg, "SELECT customer_id, full_name, phone, email, address_line, customer_type, status FROM CUSTOMER ORDER BY customer_id")
        if not cust_df.empty:
            choice = st.selectbox("SELECT CUSTOMER", [f"#{r.customer_id} - {r.full_name}" for r in cust_df.itertuples()])
            cid = int(choice.split(" - ")[0].replace("#", ""))
            cur_row = cust_df[cust_df["customer_id"] == cid].iloc[0]
            with st.form("edit_customer_form"):
                c1, c2 = st.columns(2)
                e_name = c1.text_input("Full Name", value=cur_row["full_name"])
                e_phone = c2.text_input("Phone", value=cur_row["phone"])
                c3, c4 = st.columns(2)
                e_email = c3.text_input("Email", value=cur_row["email"] or "")
                e_addr = c4.text_input("Address", value=cur_row["address_line"])
                c5, c6 = st.columns(2)
                types = ["DOMESTIC", "COMMERCIAL", "INDUSTRIAL"]
                statuses = ["ACTIVE", "INACTIVE", "SUSPENDED"]
                e_type = c5.selectbox("Customer Type", types, index=types.index(cur_row["customer_type"]))
                e_status = c6.selectbox("Status", statuses, index=statuses.index(cur_row["status"]))
                if st.form_submit_button("SAVE CHANGES"):
                    try:
                        execute_write(
                            db_cfg,
                            "UPDATE CUSTOMER SET full_name=%s, phone=%s, email=%s, address_line=%s, customer_type=%s, status=%s WHERE customer_id=%s",
                            (e_name.strip(), e_phone.strip(), e_email.strip() or None, e_addr.strip(), e_type, e_status, cid),
                        )
                        st.success("CUSTOMER UPDATED.")
                        st.rerun()
                    except Exception as e:
                        show_sql_error(e)


# ===========================================================================
# 03 // READINGS & BILLING
# ===========================================================================
elif page == "03 // Readings & Billing":
    t1, t2, t3, t4 = st.tabs(["BILLS & LINE ITEMS", "RECORD READING", "GENERATE BILL", "ATOMIC CORRECTION"])

    with t1:
        bills_df = fetch_df(
            db_cfg,
            """
            SELECT b.bill_id, b.bill_number, sc.connection_no, c.full_name,
                   b.billing_month, b.units_billed, b.total_amount, b.amount_paid,
                   (b.total_amount - b.amount_paid) AS balance_due, b.bill_status
            FROM BILL b
            INNER JOIN SERVICE_CONNECTION sc ON b.connection_id = sc.connection_id
            INNER JOIN CUSTOMER c ON sc.customer_id = c.customer_id
            ORDER BY b.bill_id DESC
            """,
        )
        panel_header("BILLING LEDGER", f"{len(bills_df)} BILLS")
        st.dataframe(bills_df, use_container_width=True, hide_index=True)

        if not bills_df.empty:
            sel_bill = st.selectbox("INSPECT BILL_DETAIL LINE ITEMS", bills_df["bill_number"].tolist())
            sel_bill_id = int(bills_df.loc[bills_df["bill_number"] == sel_bill, "bill_id"].iloc[0])
            details_df = fetch_df(
                db_cfg,
                "SELECT detail_id, charge_type, description, amount, created_at FROM BILL_DETAIL WHERE bill_id = %s ORDER BY detail_id",
                (sel_bill_id,),
            )
            panel_header(f"LINE ITEMS // {sel_bill}", "BILL_DETAIL")
            st.dataframe(details_df, use_container_width=True, hide_index=True)

    with t2:
        active_meters = fetch_df(
            db_cfg,
            """
            SELECT sc.connection_id, wm.meter_id,
                   CONCAT(sc.connection_no, ' | ', c.full_name, ' | ', wm.meter_serial_no) AS label,
                   IFNULL((SELECT MAX(mr.current_reading) FROM METER_READING mr WHERE mr.connection_id = sc.connection_id), wm.initial_reading) AS last_reading
            FROM SERVICE_CONNECTION sc
            INNER JOIN CUSTOMER c ON sc.customer_id = c.customer_id
            INNER JOIN WATER_METER wm ON sc.connection_id = wm.connection_id AND wm.meter_status = 'ACTIVE'
            ORDER BY sc.connection_id
            """,
        )
        with st.form("record_reading_form"):
            sel_m = st.selectbox("Active Connection & Meter", active_meters["label"].tolist())
            m_row = active_meters[active_meters["label"] == sel_m].iloc[0]
            c1, c2 = st.columns(2)
            billing_month = c1.text_input("Billing Month (YYYY-MM)", value=date.today().strftime("%Y-%m"))
            reading_date = c2.date_input("Reading Date", value=date.today())
            c3, c4 = st.columns(2)
            prev_r = c3.number_input("Previous Reading (KL)", value=int(m_row["last_reading"]), min_value=0, step=1)
            curr_r = c4.number_input("Current Reading (KL)", value=int(m_row["last_reading"]) + 20, min_value=0, step=1)
            recorded_by = st.text_input("Recorded By", value="CAD-OPERATOR")
            if st.form_submit_button("SAVE METER READING"):
                try:
                    execute_write(
                        db_cfg,
                        "INSERT INTO METER_READING (connection_id, meter_id, billing_month, reading_date, previous_reading, current_reading, recorded_by) "
                        "VALUES (%s, %s, %s, %s, %s, %s, %s)",
                        (int(m_row["connection_id"]), int(m_row["meter_id"]), billing_month.strip(), reading_date, int(prev_r), int(curr_r), recorded_by.strip()),
                    )
                    st.success("READING SAVED (TRIGGER AUTO-CALCULATED CONSUMPTION).")
                    st.rerun()
                except Exception as e:
                    show_sql_error(e)

    with t3:
        unbilled = fetch_df(
            db_cfg,
            """
            SELECT mr.reading_id, sc.connection_no, c.full_name, mr.billing_month, mr.units_consumed
            FROM METER_READING mr
            INNER JOIN SERVICE_CONNECTION sc ON mr.connection_id = sc.connection_id
            INNER JOIN CUSTOMER c ON sc.customer_id = c.customer_id
            LEFT JOIN BILL b ON mr.reading_id = b.reading_id
            WHERE b.bill_id IS NULL
            ORDER BY mr.reading_id DESC
            """,
        )
        if unbilled.empty:
            st.info("ALL READINGS ARE BILLED. RECORD A NEW READING FIRST.")
        else:
            panel_header("UNBILLED READINGS QUEUE", f"{len(unbilled)} PENDING")
            st.dataframe(unbilled, use_container_width=True, hide_index=True)
            with st.form("gen_bill_form"):
                opts = {f"#{r.reading_id} | {r.connection_no} ({r.full_name}) | {r.billing_month} | {r.units_consumed} KL": int(r.reading_id) for r in unbilled.itertuples()}
                sel_r = st.selectbox("Select Reading", list(opts.keys()))
                b_date = st.date_input("Bill Date", value=date.today())
                if st.form_submit_button("EXECUTE sp_generate_monthly_bill"):
                    try:
                        call_procedure(db_cfg, "sp_generate_monthly_bill", (opts[sel_r], b_date))
                        st.success("BILL GENERATED.")
                        st.rerun()
                    except Exception as e:
                        show_sql_error(e)

    with t4:
        billed_readings = fetch_df(
            db_cfg,
            """
            SELECT mr.reading_id, b.bill_number, sc.connection_no, c.full_name,
                   mr.previous_reading, mr.current_reading, b.total_amount, b.amount_paid
            FROM METER_READING mr
            INNER JOIN BILL b ON mr.reading_id = b.reading_id
            INNER JOIN SERVICE_CONNECTION sc ON mr.connection_id = sc.connection_id
            INNER JOIN CUSTOMER c ON sc.customer_id = c.customer_id
            ORDER BY mr.reading_id DESC
            """,
        )
        if not billed_readings.empty:
            opts = {
                f"#{r.reading_id} | {r.bill_number} | {r.full_name} | Prev={r.previous_reading} Curr={r.current_reading} | Paid=Rs.{r.amount_paid}": int(r.reading_id)
                for r in billed_readings.itertuples()
            }
            sel_corr = st.selectbox("SELECT BILLED READING TO CORRECT", list(opts.keys()))
            rid = opts[sel_corr]
            cur_r_row = billed_readings[billed_readings["reading_id"] == rid].iloc[0]
            with st.form("correct_reading_form"):
                c1, c2 = st.columns(2)
                new_curr = c1.number_input(
                    f"Corrected Current KL (>= {int(cur_r_row['previous_reading'])})",
                    value=int(cur_r_row["current_reading"]),
                    min_value=int(cur_r_row["previous_reading"]),
                    step=1,
                )
                corr_date = c2.date_input("Correction Date", value=date.today())
                reason = st.text_input("Correction Reason *", value="Meter photo verification")
                if st.form_submit_button("EXECUTE ATOMIC RECALCULATION & AUTO-REFUND"):
                    try:
                        call_procedure(db_cfg, "sp_correct_reading_and_recalculate_bill", (rid, int(new_curr), corr_date, reason.strip()))
                        st.success("RECONCILED ATOMICALLY (ZERO DUPLICATE BILLS).")
                        st.rerun()
                    except Exception as e:
                        show_sql_error(e)


# ===========================================================================
# 04 // PAYMENTS & DUES
# ===========================================================================
elif page == "04 // Payments & Dues":
    c1, c2 = st.columns([3, 2])
    with c1:
        out_df = fetch_df(db_cfg, "SELECT * FROM vw_outstanding_bills ORDER BY due_date")
        panel_header("OUTSTANDING BILLS", f"{len(out_df)} OPEN")
        st.dataframe(out_df, use_container_width=True, hide_index=True)

    with c2:
        panel_header("RECORD PAYMENT", "sp_record_payment")
        if out_df.empty:
            st.info("ZERO OUTSTANDING BALANCES.")
        else:
            bill_opts = {f"#{r.bill_id} | {r.bill_number} ({r.full_name}) | Due Rs.{r.balance_due}": (int(r.bill_id), float(r.balance_due)) for r in out_df.itertuples()}
            sel_b = st.selectbox("Select Bill", list(bill_opts.keys()))
            bid, max_due = bill_opts[sel_b]
            with st.form("record_payment_form"):
                p_amt = st.number_input("Amount (Rs.)", min_value=1.0, max_value=max_due, value=max_due, step=10.0)
                p_mode = st.selectbox("Mode", ["UPI", "NETBANKING", "CARD", "CASH", "CHEQUE"])
                p_ref = st.text_input("Reference No *", value=f"{p_mode}-{datetime.now().strftime('%Y%m%d%H%M%S')}")
                p_date = st.date_input("Date", value=date.today())
                if st.form_submit_button("POST PAYMENT"):
                    try:
                        call_procedure(db_cfg, "sp_record_payment", (bid, p_date, float(p_amt), p_mode, p_ref.strip()))
                        st.success("PAYMENT POSTED.")
                        st.rerun()
                    except Exception as e:
                        show_sql_error(e)

    pay_df = fetch_df(
        db_cfg,
        """
        SELECT p.payment_id, b.bill_number, c.full_name, p.payment_date,
               p.payment_type, p.payment_mode, p.amount, p.reference_no, p.remarks
        FROM PAYMENT p
        INNER JOIN BILL b ON p.bill_id = b.bill_id
        INNER JOIN SERVICE_CONNECTION sc ON b.connection_id = sc.connection_id
        INNER JOIN CUSTOMER c ON sc.customer_id = c.customer_id
        ORDER BY p.payment_id DESC
        """,
    )
    panel_header("PAYMENTS & AUTO-REFUND LEDGER", f"{len(pay_df)} TRANSACTIONS")
    st.dataframe(pay_df, use_container_width=True, hide_index=True)


# ===========================================================================
# 05 // INCIDENTS & OUTAGES
# ===========================================================================
elif page == "05 // Incidents & Outages":
    t1, t2, t3 = st.tabs(["ACTIVE DISPATCH", "FILE / UPDATE INCIDENT", "OUTAGES & METER SWAPS"])

    with t1:
        active_cp = fetch_df(db_cfg, "SELECT * FROM vw_active_maintenance_complaints ORDER BY filed_date DESC")
        panel_header("ACTIVE COMPLAINTS & WORK ORDERS", f"{len(active_cp)} ACTIVE")
        st.dataframe(active_cp, use_container_width=True, hide_index=True)

    with t2:
        c_left, c_right = st.columns(2)
        with c_left:
            conns = fetch_df(
                db_cfg,
                "SELECT sc.connection_id, sc.customer_id, CONCAT(sc.connection_no, ' - ', c.full_name) AS label "
                "FROM SERVICE_CONNECTION sc INNER JOIN CUSTOMER c ON sc.customer_id = c.customer_id ORDER BY sc.connection_id",
            )
            with st.form("new_complaint_form"):
                st.caption("FILE NEW INCIDENT")
                sel_c = st.selectbox("Connection *", conns["label"].tolist())
                c_row = conns[conns["label"] == sel_c].iloc[0]
                c_type = st.selectbox("Type", ["LEAKAGE", "LOW_PRESSURE", "NO_SUPPLY", "FAULTY_METER", "BILLING_ISSUE"])
                priority = st.selectbox("Priority", ["HIGH", "MEDIUM", "LOW"])
                desc = st.text_area("Incident Details *")
                f_date = st.date_input("Filed Date", value=date.today())
                if st.form_submit_button("LOG INCIDENT"):
                    if not desc.strip():
                        st.error("Description is required.")
                    else:
                        try:
                            execute_write(
                                db_cfg,
                                "INSERT INTO COMPLAINT (customer_id, connection_id, complaint_type, description, filed_date, priority) "
                                "VALUES (%s, %s, %s, %s, %s, %s)",
                                (int(c_row["customer_id"]), int(c_row["connection_id"]), c_type, desc.strip(), f_date, priority),
                            )
                            st.success("INCIDENT LOGGED.")
                            st.rerun()
                        except Exception as e:
                            show_sql_error(e)

        with c_right:
            all_cp = fetch_df(db_cfg, "SELECT complaint_id, complaint_type, complaint_status FROM COMPLAINT ORDER BY complaint_id DESC")
            if not all_cp.empty:
                cp_opts = {f"#{r.complaint_id} | {r.complaint_type} ({r.complaint_status})": int(r.complaint_id) for r in all_cp.itertuples()}
                sel_cp = st.selectbox("SELECT INCIDENT", list(cp_opts.keys()))
                with st.form("upd_complaint_form"):
                    st.caption("UPDATE STATUS (AUTO-AUDITED)")
                    new_st = st.selectbox("New Status", ["OPEN", "IN_PROGRESS", "RESOLVED", "CLOSED"])
                    res_date = st.date_input("Resolved Date", value=date.today())
                    if st.form_submit_button("UPDATE STATUS"):
                        try:
                            execute_write(
                                db_cfg,
                                "UPDATE COMPLAINT SET complaint_status = %s, resolved_date = %s WHERE complaint_id = %s",
                                (new_st, res_date if new_st in ("RESOLVED", "CLOSED") else None, cp_opts[sel_cp]),
                            )
                            st.success("STATUS UPDATED.")
                            st.rerun()
                        except Exception as e:
                            show_sql_error(e)

    with t3:
        int_df = fetch_df(
            db_cfg,
            "SELECT si.interruption_id, l.locality_name, si.interruption_type, si.start_time, si.end_time, si.reason "
            "FROM SERVICE_INTERRUPTION si INNER JOIN LOCALITY l ON si.locality_id = l.locality_id ORDER BY si.start_time DESC",
        )
        panel_header("SERVICE INTERRUPTIONS", f"{len(int_df)} LOGS")
        st.dataframe(int_df, use_container_width=True, hide_index=True)

        rep_df = fetch_df(
            db_cfg,
            """
            SELECT sc.connection_no, c.full_name, wm_old.meter_serial_no AS old_meter,
                   wm_new.meter_serial_no AS new_meter, mrh.replacement_date, mrh.old_final_reading, mrh.reason
            FROM METER_REPLACEMENT_HISTORY mrh
            INNER JOIN SERVICE_CONNECTION sc ON mrh.connection_id = sc.connection_id
            INNER JOIN CUSTOMER c ON sc.customer_id = c.customer_id
            INNER JOIN WATER_METER wm_old ON mrh.old_meter_id = wm_old.meter_id
            INNER JOIN WATER_METER wm_new ON mrh.new_meter_id = wm_new.meter_id
            ORDER BY mrh.replacement_date DESC
            """,
        )
        panel_header("METER REPLACEMENT HISTORY", f"{len(rep_df)} SWAPS")
        st.dataframe(rep_df, use_container_width=True, hide_index=True)


# ===========================================================================
# 06 // TABLE EXPLORER
# ===========================================================================
elif page == "06 // Table Explorer":
    c1, c2 = st.columns([1, 2])
    obj_type = c1.radio("OBJECT TYPE", ["TABLES (14)", "VIEWS (4)"], horizontal=True)
    obj_list = CORE_TABLES if obj_type.startswith("TABLES") else CORE_VIEWS
    selected_obj = c2.selectbox("SELECT OBJECT", obj_list)

    df = fetch_df(db_cfg, f"SELECT * FROM `{selected_obj}`")
    panel_header(selected_obj, f"{len(df)} ROWS")
    st.dataframe(df, use_container_width=True, hide_index=True)

    col_dl, col_del = st.columns([1, 2])
    with col_dl:
        st.download_button(
            f"EXPORT {selected_obj}.CSV",
            data=df.to_csv(index=False).encode("utf-8"),
            file_name=f"{selected_obj.lower()}.csv",
            mime="text/csv",
        )
    if obj_type.startswith("TABLES") and not df.empty:
        with col_del:
            pk_col = df.columns[0]
            del_id = st.selectbox(f"DELETE BY {pk_col}", df[pk_col].tolist())
            if st.button(f"DELETE {pk_col} = {del_id}"):
                try:
                    execute_write(db_cfg, f"DELETE FROM `{selected_obj}` WHERE `{pk_col}` = %s", (int(del_id),))
                    st.success(f"DELETED {pk_col} = {del_id}")
                    st.rerun()
                except Exception as e:
                    show_sql_error(e)


# ===========================================================================
# 07 // AUDIT & SQL CONSOLE
# ===========================================================================
elif page == "07 // Audit & SQL Console":
    t1, t2 = st.tabs(["AUDIT STREAM", "READ-ONLY SQL CONSOLE"])
    with t1:
        audit_df = fetch_df(db_cfg, "SELECT * FROM AUDIT_LOG ORDER BY log_id DESC")
        panel_header("SYSTEM AUDIT LOG", f"{len(audit_df)} ENTRIES")
        st.dataframe(audit_df, use_container_width=True, hide_index=True)

    with t2:
        default_sql = (
            "SELECT l.locality_name, COUNT(b.bill_id) AS bills, SUM(b.total_amount) AS total_billed\n"
            "FROM LOCALITY l\n"
            "INNER JOIN SERVICE_CONNECTION sc ON l.locality_id = sc.locality_id\n"
            "INNER JOIN BILL b ON sc.connection_id = b.connection_id\n"
            "GROUP BY l.locality_id, l.locality_name\n"
            "ORDER BY total_billed DESC;"
        )
        sql_text = st.text_area("SQL QUERY (SELECT / SHOW / DESCRIBE)", value=default_sql, height=150)
        if st.button("EXECUTE QUERY"):
            cleaned = sql_text.strip().lstrip("(").upper()
            if not cleaned.startswith(("SELECT", "SHOW", "DESCRIBE", "EXPLAIN")):
                st.error("CONSOLE RESTRICTED TO READ-ONLY QUERIES (SELECT / SHOW / DESCRIBE / EXPLAIN).")
            else:
                try:
                    res = fetch_df(db_cfg, sql_text)
                    panel_header("QUERY RESULT", f"{len(res)} ROWS")
                    st.dataframe(res, use_container_width=True, hide_index=True)
                except Exception as e:
                    show_sql_error(e)