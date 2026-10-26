import os
from datetime import datetime
import pymysql
from flask import Flask, render_template, request, redirect, url_for, flash

app = Flask(__name__)
app.secret_key = os.environ.get("SECRET_KEY", "dev-only-change-me")

# All settings come from environment variables, so no password lives in the code.
DB = dict(
    host=os.environ.get("DB_HOST", "localhost"),
    port=int(os.environ.get("DB_PORT", 3306)),
    user=os.environ.get("DB_USER", "root"),
    password=os.environ.get("DB_PASSWORD", ""),
    database=os.environ.get("DB_NAME", "student_analytics"),
    cursorclass=pymysql.cursors.DictCursor,
    autocommit=True,
    connect_timeout=10,
)

# Cloud MySQL providers (Aiven, Railway, etc.) usually require SSL.
if os.environ.get("DB_SSL", "").lower() in ("1", "true", "yes"):
    ca = os.environ.get("DB_SSL_CA")
    DB["ssl"] = {"ca": ca} if ca else {"check_hostname": False}


@app.context_processor
def inject_today():
    return {"today": datetime.now().strftime("%A, %d %B %Y")}


def query(sql, args=None, one=False):
    conn = pymysql.connect(**DB)
    try:
        with conn.cursor() as cur:
            cur.execute(sql, args)
            rows = cur.fetchall()
            return (rows[0] if rows else None) if one else rows
    finally:
        conn.close()


def execute(sql, args=None):
    conn = pymysql.connect(**DB)
    try:
        with conn.cursor() as cur:
            cur.execute(sql, args)
    finally:
        conn.close()


@app.route("/")
def dashboard():
    stats = query("""
        SELECT (SELECT COUNT(*) FROM Student)  AS students,
               (SELECT COUNT(*) FROM Subject)  AS subjects,
               (SELECT COUNT(*) FROM Faculty)  AS faculty,
               (SELECT ROUND(AVG(attendance_pct),1) FROM v_student_performance) AS avg_att,
               (SELECT ROUND(AVG(marks_pct),1) FROM v_student_performance)      AS avg_marks
    """, one=True)
    levels = {r["risk_level"]: r["n"] for r in query(
        "SELECT risk_level, COUNT(*) n FROM v_risk_analysis GROUP BY risk_level")}
    high = query("SELECT * FROM v_at_risk_students ORDER BY risk_score DESC, marks_pct")
    subjects = query("""
        SELECT s.subject_name, f.name AS faculty,
               ROUND(AVG(v.attendance_pct),1) AS avg_att
        FROM Subject s JOIN Faculty f ON f.faculty_id = s.faculty_id
        JOIN v_attendance_summary v ON v.subject_id = s.subject_id
        GROUP BY s.subject_id, s.subject_name, f.name""")
    return render_template("dashboard.html", stats=stats, levels=levels,
                           high=high, subjects=subjects)


@app.route("/students")
def students():
    q = request.args.get("q", "").strip()
    rows = query("""
        SELECT st.student_id, st.name, st.email, st.department, st.semester,
               r.marks_pct, r.attendance_pct, r.risk_level
        FROM Student st LEFT JOIN v_risk_analysis r ON r.student_id = st.student_id
        WHERE st.name LIKE %s ORDER BY st.student_id""", (f"%{q}%",))
    return render_template("students.html", rows=rows, q=q)


@app.route("/students/add", methods=["GET", "POST"])
def add_student():
    if request.method == "POST":
        f = request.form
        try:
            execute("""INSERT INTO Student (name, email, dob, department, semester)
                       VALUES (%s,%s,%s,%s,%s)""",
                    (f["name"], f["email"], f["dob"], f["department"], f["semester"]))
            flash("Student added.", "ok")
            return redirect(url_for("students"))
        except pymysql.MySQLError as e:
            flash(f"Could not add student: {e.args[-1]}", "err")
    return render_template("add_student.html")


@app.route("/students/<int:sid>")
def student_detail(sid):
    student = query("SELECT *, fn_cgpa(student_id) AS cgpa FROM Student WHERE student_id=%s",
                    (sid,), one=True)
    if not student:
        return "Student not found", 404
    risk = query("SELECT * FROM v_risk_analysis WHERE student_id=%s", (sid,), one=True)
    subjects = query("""
        SELECT sub.subject_name, fn_attendance_pct(%s, sub.subject_id) AS attendance_pct,
               ROUND(100*SUM(m.marks_obtained)/SUM(e.max_marks),2) AS marks_pct
        FROM Subject sub JOIN Exam e ON e.subject_id = sub.subject_id
        JOIN Marks m ON m.exam_id = e.exam_id AND m.student_id = %s
        GROUP BY sub.subject_id, sub.subject_name""", (sid, sid))
    assignments = query("""
        SELECT a.title, a.due_date, s.submitted_date, s.marks_obtained, a.max_marks,
               CASE WHEN s.submitted_date IS NULL THEN 'Pending'
                    WHEN s.submitted_date > a.due_date THEN 'Late' ELSE 'On time' END AS status
        FROM Submission s JOIN Assignment a ON a.assignment_id = s.assignment_id
        WHERE s.student_id=%s ORDER BY a.due_date""", (sid,))
    flags = query("""SELECT f.reason, f.flagged_on, sub.subject_name FROM Risk_Flag f
                     JOIN Subject sub ON sub.subject_id=f.subject_id WHERE f.student_id=%s""", (sid,))
    return render_template("student_detail.html", s=student, risk=risk,
                           subjects=subjects, assignments=assignments, flags=flags)


@app.route("/at-risk")
def at_risk():
    rows = query("SELECT * FROM v_risk_analysis WHERE risk_level <> 'SAFE' "
                 "ORDER BY risk_score DESC, marks_pct")
    flags = query("""SELECT st.name, sub.subject_name, f.reason, f.flagged_on
                     FROM Risk_Flag f JOIN Student st ON st.student_id=f.student_id
                     JOIN Subject sub ON sub.subject_id=f.subject_id
                     ORDER BY f.flagged_on DESC""")
    return render_template("at_risk.html", rows=rows, flags=flags)


@app.route("/attendance", methods=["GET", "POST"])
def attendance():
    if request.method == "POST":
        f = request.form
        try:
            execute("""INSERT INTO Attendance (student_id, subject_id, class_date, status)
                       VALUES (%s,%s,%s,%s)""",
                    (f["student_id"], f["subject_id"], f["class_date"], f["status"]))
            flash("Attendance recorded. (The trigger checks the 75% rule automatically.)", "ok")
        except pymysql.MySQLError as e:
            flash(f"Could not record attendance: {e.args[-1]}", "err")
        return redirect(url_for("attendance"))
    subject_id = request.args.get("subject_id", type=int)
    cutoff = request.args.get("cutoff", 75, type=float)
    low = []
    if subject_id:
        conn = pymysql.connect(**DB)
        try:
            with conn.cursor() as cur:
                cur.callproc("sp_low_attendance", (subject_id, cutoff))
                low = cur.fetchall()
        finally:
            conn.close()
    return render_template("attendance.html",
                           students=query("SELECT student_id, name FROM Student ORDER BY name"),
                           subjects=query("SELECT subject_id, subject_name FROM Subject"),
                           low=low, subject_id=subject_id, cutoff=cutoff)


@app.route("/marks", methods=["GET", "POST"])
def marks():
    if request.method == "POST":
        f = request.form
        try:
            execute("""INSERT INTO Marks (student_id, exam_id, marks_obtained) VALUES (%s,%s,%s)
                       ON DUPLICATE KEY UPDATE marks_obtained = VALUES(marks_obtained)""",
                    (f["student_id"], f["exam_id"], f["marks_obtained"]))
            flash("Marks saved.", "ok")
        except pymysql.MySQLError as e:
            flash(f"Rejected by database: {e.args[-1]}", "err")
        return redirect(url_for("marks"))
    return render_template("marks.html",
        students=query("SELECT student_id, name FROM Student ORDER BY name"),
        exams=query("""SELECT e.exam_id, CONCAT(sub.subject_name,' - ',e.exam_type,' (max ',e.max_marks,')') AS label
                       FROM Exam e JOIN Subject sub ON sub.subject_id=e.subject_id ORDER BY label"""),
        ranking=query("""SELECT name, total_marks,
                                RANK() OVER (ORDER BY total_marks DESC) AS rnk
                         FROM (SELECT st.name, SUM(m.marks_obtained) AS total_marks
                               FROM Marks m JOIN Student st ON st.student_id=m.student_id
                               GROUP BY st.student_id, st.name) t ORDER BY rnk, name LIMIT 10"""))


@app.route("/assignments")
def assignments():
    rows = query("""
        SELECT st.student_id, st.name, a.title, a.due_date, s.submitted_date,
               CASE WHEN s.submitted_date IS NULL THEN 'Pending' ELSE 'Late' END AS status
        FROM Submission s JOIN Assignment a ON a.assignment_id=s.assignment_id
        JOIN Student st ON st.student_id=s.student_id
        WHERE s.submitted_date IS NULL OR s.submitted_date > a.due_date
        ORDER BY status, st.name, a.due_date""")
    return render_template("assignments.html", rows=rows)


if __name__ == "__main__":
    app.run(debug=os.environ.get("FLASK_DEBUG") == "1")
