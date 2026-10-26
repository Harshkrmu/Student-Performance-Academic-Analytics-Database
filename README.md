# Student Performance & Academic Analytics (Flask + MySQL)

## Run locally
1. Load `student_analytics.sql` in MySQL Workbench (File > Open SQL Script > run).
2. `pip install -r requirements.txt`
3. PowerShell: `$env:DB_USER="root"; $env:DB_PASSWORD="your_password"; python app.py`
4. Open http://127.0.0.1:5000

## Deploy (GitHub + Render + cloud MySQL)
- Database: create a cloud MySQL, run `student_analytics_cloud.sql` on it.
- App: connect this repo to Render; Build `pip install -r requirements.txt`, Start `gunicorn app:app`.
- Set the environment variables listed in `.env.example`.
