# Water Supply & Utility Billing Management System — Web App

Interactive **Streamlit + MySQL 8.0** web application for managing, viewing, and editing the `water_billing_db` database (IBD312 Project — Nirvaid Jain, TCA2573025).

## Option 1: Run Locally with Your Existing MySQL Workbench Server
1. Make sure you have run `sql/water_billing_system.sql` in MySQL Workbench.
2. Copy `.env.example` to `.env` and fill in your MySQL password.
3. Install dependencies and launch Streamlit:
   ```bash
   pip install -r requirements.txt
   streamlit run app.py
   ```
4. Open `http://localhost:8501` in your browser. (You can also edit MySQL credentials directly in the left sidebar.)

## Option 2: One-Command Run with Docker Compose (No Manual MySQL Setup)
Docker automatically starts MySQL 8.0, loads `sql/water_billing_system.sql`, and launches the web app:
```bash
docker compose up --build
```
Then open `http://localhost:8501`. (If your local MySQL already uses port `3306`, change `"3306:3306"` in `docker-compose.yml` to `"3307:3306"`.)

## Option 3: Host Free Online (Streamlit Community Cloud + Free Cloud MySQL)
1. Create a free MySQL 8.0 database on **Aiven** or **TiDB Cloud**, and run `sql/water_billing_system.sql` on it (if your host gives you a pre-created database name, replace `USE water_billing_db;` with your assigned database name).
2. Push this folder to a GitHub repository.
3. Go to [share.streamlit.io](https://share.streamlit.io), select your repo and `app.py`, and add your database credentials under **Settings → Secrets**:
   ```toml
   [mysql]
   host = "your-cloud-mysql-host"
   port = 3306
   user = "your-user"
   password = "your-password"
   database = "water_billing_db"
   ```
4. Click **Deploy**.
