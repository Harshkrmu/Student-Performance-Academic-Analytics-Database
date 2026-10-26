-- Cloud version: run while connected to your hosted database (no CREATE DATABASE).
-- Safe to re-run: clears old objects first.
SET FOREIGN_KEY_CHECKS=0;
DROP VIEW IF EXISTS v_at_risk_students, v_risk_analysis, v_student_performance, v_attendance_summary;
DROP TABLE IF EXISTS Risk_Flag, Submission, Assignment, Marks, Exam, Attendance, Subject, Faculty, Student;
DROP FUNCTION IF EXISTS fn_cgpa; DROP FUNCTION IF EXISTS fn_grade_point; DROP FUNCTION IF EXISTS fn_attendance_pct;
DROP PROCEDURE IF EXISTS sp_student_report; DROP PROCEDURE IF EXISTS sp_low_attendance;
SET FOREIGN_KEY_CHECKS=1;
-- =====================================================================
-- AI-Based Student Performance & Academic Analytics Database
-- MySQL 8.0+  |  Run the whole file top to bottom on a fresh server
-- =====================================================================


-- =====================================================================
-- PART 1: TABLES (Modules 1-4)
-- =====================================================================

-- Module 1: Student profiles
CREATE TABLE Student (
    student_id  INT PRIMARY KEY AUTO_INCREMENT,
    name        VARCHAR(50)  NOT NULL,
    email       VARCHAR(80)  NOT NULL UNIQUE,
    dob         DATE         NOT NULL,
    department  VARCHAR(30)  NOT NULL,
    semester    TINYINT      NOT NULL CHECK (semester BETWEEN 1 AND 8)
);

-- Module 2: Faculty and subjects
CREATE TABLE Faculty (
    faculty_id  INT PRIMARY KEY AUTO_INCREMENT,
    name        VARCHAR(50) NOT NULL,
    email       VARCHAR(80) NOT NULL UNIQUE,
    department  VARCHAR(30) NOT NULL
);

CREATE TABLE Subject (
    subject_id    INT PRIMARY KEY AUTO_INCREMENT,
    subject_name  VARCHAR(60) NOT NULL,
    credits       TINYINT     NOT NULL CHECK (credits BETWEEN 1 AND 6),
    semester      TINYINT     NOT NULL,
    faculty_id    INT         NOT NULL,
    FOREIGN KEY (faculty_id) REFERENCES Faculty(faculty_id)
);

-- Module 3: Attendance
CREATE TABLE Attendance (
    attendance_id INT PRIMARY KEY AUTO_INCREMENT,
    student_id    INT  NOT NULL,
    subject_id    INT  NOT NULL,
    class_date    DATE NOT NULL,
    status        ENUM('Present','Absent') NOT NULL,
    UNIQUE (student_id, subject_id, class_date),
    FOREIGN KEY (student_id) REFERENCES Student(student_id) ON DELETE CASCADE,
    FOREIGN KEY (subject_id) REFERENCES Subject(subject_id) ON DELETE CASCADE
);

-- Module 4: Exams, marks, assignments
CREATE TABLE Exam (
    exam_id     INT PRIMARY KEY AUTO_INCREMENT,
    subject_id  INT NOT NULL,
    exam_type   ENUM('Internal','Final') NOT NULL,
    max_marks   INT NOT NULL CHECK (max_marks > 0),
    exam_date   DATE NOT NULL,
    FOREIGN KEY (subject_id) REFERENCES Subject(subject_id) ON DELETE CASCADE
);

CREATE TABLE Marks (
    student_id      INT NOT NULL,
    exam_id         INT NOT NULL,
    marks_obtained  INT NOT NULL CHECK (marks_obtained >= 0),
    PRIMARY KEY (student_id, exam_id),
    FOREIGN KEY (student_id) REFERENCES Student(student_id) ON DELETE CASCADE,
    FOREIGN KEY (exam_id)    REFERENCES Exam(exam_id)       ON DELETE CASCADE
);

CREATE TABLE Assignment (
    assignment_id INT PRIMARY KEY AUTO_INCREMENT,
    subject_id    INT NOT NULL,
    title         VARCHAR(80) NOT NULL,
    due_date      DATE NOT NULL,
    max_marks     INT NOT NULL CHECK (max_marks > 0),
    FOREIGN KEY (subject_id) REFERENCES Subject(subject_id) ON DELETE CASCADE
);

CREATE TABLE Submission (
    assignment_id   INT NOT NULL,
    student_id      INT NOT NULL,
    submitted_date  DATE NULL,                 -- NULL = not submitted yet
    marks_obtained  INT  NULL CHECK (marks_obtained >= 0),
    PRIMARY KEY (assignment_id, student_id),
    FOREIGN KEY (assignment_id) REFERENCES Assignment(assignment_id) ON DELETE CASCADE,
    FOREIGN KEY (student_id)    REFERENCES Student(student_id)       ON DELETE CASCADE
);

-- Module 5 support table: filled automatically by a trigger
CREATE TABLE Risk_Flag (
    flag_id     INT PRIMARY KEY AUTO_INCREMENT,
    student_id  INT NOT NULL,
    subject_id  INT NOT NULL,
    reason      VARCHAR(100) NOT NULL,
    flagged_on  DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES Student(student_id) ON DELETE CASCADE,
    FOREIGN KEY (subject_id) REFERENCES Subject(subject_id) ON DELETE CASCADE
);

-- Indexes for faster analytics
CREATE INDEX idx_att_student_subject ON Attendance(student_id, subject_id);
CREATE INDEX idx_marks_exam ON Marks(exam_id);

-- =====================================================================
-- PART 2: SAMPLE DATA
-- Students 5, 9, 14 and 18 are deliberately weak so analytics find them
-- =====================================================================

INSERT INTO Faculty (name, email, department) VALUES
('Dr. Anil Sharma',  'anil.sharma@college.edu',  'Computer Science'),
('Dr. Meera Iyer',   'meera.iyer@college.edu',   'Computer Science'),
('Prof. Rahul Verma','rahul.verma@college.edu',  'Mathematics'),
('Dr. Sunita Rao',   'sunita.rao@college.edu',   'Computer Science'),
('Prof. Karan Mehta','karan.mehta@college.edu',  'Computer Science');

INSERT INTO Subject (subject_name, credits, semester, faculty_id) VALUES
('Database Management Systems', 4, 4, 1),
('Data Structures',             4, 4, 2),
('Discrete Mathematics',        3, 4, 3),
('Operating Systems',           4, 4, 4),
('Computer Networks',           3, 4, 5);

INSERT INTO Student (name, email, dob, department, semester) VALUES
('Aarav Gupta',    'aarav@college.edu',    '2005-01-14', 'Computer Science', 4),
('Diya Singh',     'diya@college.edu',     '2005-03-22', 'Computer Science', 4),
('Rohan Patel',    'rohan@college.edu',    '2004-11-02', 'Computer Science', 4),
('Ishita Kapoor',  'ishita@college.edu',   '2005-07-19', 'Computer Science', 4),
('Vikram Yadav',   'vikram@college.edu',   '2004-09-30', 'Computer Science', 4),
('Ananya Joshi',   'ananya@college.edu',   '2005-02-11', 'Computer Science', 4),
('Kabir Malhotra', 'kabir@college.edu',    '2005-05-05', 'Computer Science', 4),
('Sneha Nair',     'sneha@college.edu',    '2004-12-25', 'Computer Science', 4),
('Arjun Reddy',    'arjun@college.edu',    '2005-04-08', 'Computer Science', 4),
('Meera Das',      'meerad@college.edu',   '2005-08-17', 'Computer Science', 4),
('Yash Agarwal',   'yash@college.edu',     '2004-10-12', 'Computer Science', 4),
('Pooja Bansal',   'pooja@college.edu',    '2005-06-01', 'Computer Science', 4),
('Nikhil Saxena',  'nikhil@college.edu',   '2005-01-27', 'Computer Science', 4),
('Riya Chopra',    'riya@college.edu',     '2004-08-09', 'Computer Science', 4),
('Siddharth Roy',  'siddharth@college.edu','2005-03-03', 'Computer Science', 4),
('Tanvi Bhatt',    'tanvi@college.edu',    '2005-09-21', 'Computer Science', 4),
('Harsh Vora',     'harsh@college.edu',    '2004-07-15', 'Computer Science', 4),
('Kritika Sen',    'kritika@college.edu',  '2005-02-28', 'Computer Science', 4),
('Manav Khanna',   'manav@college.edu',    '2005-11-11', 'Computer Science', 4),
('Zoya Ali',       'zoya@college.edu',     '2004-12-05', 'Computer Science', 4);

-- Two exams per subject: Internal (50 marks) and Final (100 marks)
INSERT INTO Exam (subject_id, exam_type, max_marks, exam_date)
SELECT s.subject_id, t.exam_type, t.max_marks,
       DATE_ADD(t.base_date, INTERVAL s.subject_id DAY)
FROM Subject s
CROSS JOIN (SELECT 'Internal' AS exam_type, 50  AS max_marks, DATE '2026-09-10' AS base_date
            UNION ALL
            SELECT 'Final', 100, DATE '2026-11-20') t;

-- Marks: weak students get noticeably lower scores
INSERT INTO Marks (student_id, exam_id, marks_obtained)
SELECT st.student_id, e.exam_id,
       ROUND(e.max_marks * (
           CASE WHEN st.student_id IN (5,9,14,18)
                THEN 0.15 + MOD(st.student_id*17 + e.exam_id*11, 30)/100
                ELSE 0.45 + MOD(st.student_id*17 + e.exam_id*11, 50)/100
           END))
FROM Student st CROSS JOIN Exam e;

-- Assignments: two per subject
INSERT INTO Assignment (subject_id, title, due_date, max_marks)
SELECT s.subject_id, CONCAT(s.subject_name, ' - Assignment ', n.k), 
       DATE_ADD('2026-08-20', INTERVAL n.k*14 + s.subject_id DAY), 20
FROM Subject s CROSS JOIN (SELECT 1 AS k UNION ALL SELECT 2) n;

-- Submissions: some on time, some late, weak students often missing
INSERT INTO Submission (assignment_id, student_id, submitted_date, marks_obtained)
SELECT a.assignment_id, st.student_id,
       CASE
         WHEN st.student_id IN (5,9,14,18) AND MOD(st.student_id + a.assignment_id, 3) <> 0 THEN NULL
         WHEN MOD(st.student_id*3 + a.assignment_id, 7) = 0 THEN DATE_ADD(a.due_date, INTERVAL 3 DAY)
         ELSE DATE_SUB(a.due_date, INTERVAL 1 DAY)
       END,
       CASE
         WHEN st.student_id IN (5,9,14,18) AND MOD(st.student_id + a.assignment_id, 3) <> 0 THEN NULL
         WHEN st.student_id IN (5,9,14,18) THEN 6 + MOD(st.student_id + a.assignment_id, 5)
         ELSE 12 + MOD(st.student_id*5 + a.assignment_id, 9)
       END
FROM Student st CROSS JOIN Assignment a;

-- Attendance: 12 class days per subject for every student
-- (weak students are absent ~50% of days, others ~10-20%)
INSERT INTO Attendance (student_id, subject_id, class_date, status)
WITH RECURSIVE days AS (
    SELECT 1 AS n UNION ALL SELECT n + 1 FROM days WHERE n < 12
)
SELECT st.student_id, sub.subject_id,
       DATE_ADD('2026-08-03', INTERVAL d.n * 3 DAY),
       CASE WHEN MOD(st.student_id*13 + sub.subject_id*7 + d.n*11, 10) <
                 CASE WHEN st.student_id IN (5,9,14,18) THEN 5
                      WHEN MOD(st.student_id, 4) = 0     THEN 2
                      ELSE 1 END
            THEN 'Absent' ELSE 'Present' END
FROM Student st CROSS JOIN Subject sub CROSS JOIN days d;

-- =====================================================================
-- PART 3: ANALYTICS QUERIES (Module 5)
-- =====================================================================

-- Q1. Attendance % per student per subject
SELECT st.student_id, st.name, sub.subject_name,
       COUNT(*) AS classes_held,
       SUM(a.status = 'Present') AS attended,
       ROUND(100 * SUM(a.status = 'Present') / COUNT(*), 2) AS attendance_pct
FROM Attendance a
JOIN Student st ON st.student_id = a.student_id
JOIN Subject sub ON sub.subject_id = a.subject_id
GROUP BY st.student_id, st.name, sub.subject_id, sub.subject_name
ORDER BY st.student_id, sub.subject_id;

-- Q2. Students whose overall attendance is below 75%
SELECT st.student_id, st.name,
       ROUND(100 * SUM(a.status = 'Present') / COUNT(*), 2) AS overall_attendance_pct
FROM Attendance a JOIN Student st ON st.student_id = a.student_id
GROUP BY st.student_id, st.name
HAVING overall_attendance_pct < 75
ORDER BY overall_attendance_pct;

-- Q3. Average marks percentage per student
SELECT st.student_id, st.name,
       ROUND(100 * SUM(m.marks_obtained) / SUM(e.max_marks), 2) AS overall_pct
FROM Marks m
JOIN Student st ON st.student_id = m.student_id
JOIN Exam e ON e.exam_id = m.exam_id
GROUP BY st.student_id, st.name
ORDER BY overall_pct DESC;

-- Q4. Subject-wise class average and topper
SELECT sub.subject_name,
       ROUND(AVG(100 * m.marks_obtained / e.max_marks), 2) AS class_avg_pct,
       (SELECT st2.name
          FROM Marks m2
          JOIN Exam e2 ON e2.exam_id = m2.exam_id
          JOIN Student st2 ON st2.student_id = m2.student_id
         WHERE e2.subject_id = sub.subject_id
         GROUP BY st2.student_id, st2.name
         ORDER BY SUM(m2.marks_obtained) DESC LIMIT 1) AS topper
FROM Marks m
JOIN Exam e ON e.exam_id = m.exam_id
JOIN Subject sub ON sub.subject_id = e.subject_id
GROUP BY sub.subject_id, sub.subject_name;

-- Q5. Students failing (below 40%) in at least one subject
SELECT st.name, sub.subject_name,
       ROUND(100 * SUM(m.marks_obtained) / SUM(e.max_marks), 2) AS subject_pct
FROM Marks m
JOIN Student st ON st.student_id = m.student_id
JOIN Exam e ON e.exam_id = m.exam_id
JOIN Subject sub ON sub.subject_id = e.subject_id
GROUP BY st.student_id, st.name, sub.subject_id, sub.subject_name
HAVING subject_pct < 40
ORDER BY st.name;

-- Q6. Pending and late assignment submissions
SELECT st.name, a.title, a.due_date, s.submitted_date,
       CASE WHEN s.submitted_date IS NULL THEN 'Pending'
            WHEN s.submitted_date > a.due_date THEN 'Late'
            ELSE 'On time' END AS submission_status
FROM Submission s
JOIN Assignment a ON a.assignment_id = s.assignment_id
JOIN Student st ON st.student_id = s.student_id
WHERE s.submitted_date IS NULL OR s.submitted_date > a.due_date
ORDER BY st.name, a.due_date;

-- Q7. Rank students by total marks (window function)
SELECT student_id, name, total_marks,
       RANK()       OVER (ORDER BY total_marks DESC) AS rnk,
       DENSE_RANK() OVER (ORDER BY total_marks DESC) AS dense_rnk
FROM (
    SELECT st.student_id, st.name, SUM(m.marks_obtained) AS total_marks
    FROM Marks m JOIN Student st ON st.student_id = m.student_id
    GROUP BY st.student_id, st.name
) t;

-- Q8. Students who submitted nothing late or pending vs. count of missed work
SELECT st.name, COUNT(*) AS missed_assignments
FROM Submission s JOIN Student st ON st.student_id = s.student_id
WHERE s.submitted_date IS NULL
GROUP BY st.student_id, st.name
HAVING COUNT(*) >= 2
ORDER BY missed_assignments DESC;

-- =====================================================================
-- PART 4: VIEWS
-- =====================================================================

CREATE VIEW v_attendance_summary AS
SELECT a.student_id, a.subject_id,
       ROUND(100 * SUM(a.status = 'Present') / COUNT(*), 2) AS attendance_pct
FROM Attendance a
GROUP BY a.student_id, a.subject_id;

CREATE VIEW v_student_performance AS
SELECT st.student_id, st.name,
       ROUND(100 * SUM(m.marks_obtained) / SUM(e.max_marks), 2) AS marks_pct,
       (SELECT ROUND(100 * SUM(a.status = 'Present') / COUNT(*), 2)
          FROM Attendance a WHERE a.student_id = st.student_id) AS attendance_pct
FROM Student st
JOIN Marks m ON m.student_id = st.student_id
JOIN Exam e ON e.exam_id = m.exam_id
GROUP BY st.student_id, st.name;

-- "AI-based" part: rule-based risk scoring and classification
CREATE VIEW v_risk_analysis AS
SELECT student_id, name, marks_pct, attendance_pct,
       (CASE WHEN attendance_pct < 75 THEN 1 ELSE 0 END
      + CASE WHEN marks_pct < 50 THEN 1 ELSE 0 END
      + CASE WHEN marks_pct < 40 THEN 1 ELSE 0 END) AS risk_score,
       CASE
         WHEN attendance_pct < 75 AND marks_pct < 50 THEN 'HIGH RISK'
         WHEN attendance_pct < 75 OR  marks_pct < 50 THEN 'MODERATE RISK'
         ELSE 'SAFE'
       END AS risk_level
FROM v_student_performance;

CREATE VIEW v_at_risk_students AS
SELECT * FROM v_risk_analysis WHERE risk_level = 'HIGH RISK';

-- =====================================================================
-- PART 5: STORED FUNCTIONS AND PROCEDURES
-- =====================================================================

DELIMITER $$

-- Attendance % of one student in one subject
CREATE FUNCTION fn_attendance_pct(p_student INT, p_subject INT)
RETURNS DECIMAL(5,2)
DETERMINISTIC READS SQL DATA
BEGIN
    DECLARE pct DECIMAL(5,2);
    SELECT ROUND(100 * SUM(status = 'Present') / COUNT(*), 2) INTO pct
    FROM Attendance WHERE student_id = p_student AND subject_id = p_subject;
    RETURN IFNULL(pct, 0);
END$$

-- Grade point (10-point scale) from a percentage
CREATE FUNCTION fn_grade_point(pct DECIMAL(5,2))
RETURNS INT
DETERMINISTIC
BEGIN
    RETURN CASE WHEN pct >= 90 THEN 10 WHEN pct >= 80 THEN 9
                WHEN pct >= 70 THEN 8  WHEN pct >= 60 THEN 7
                WHEN pct >= 50 THEN 6  WHEN pct >= 40 THEN 5
                ELSE 0 END;
END$$

-- Credit-weighted CGPA of a student
CREATE FUNCTION fn_cgpa(p_student INT)
RETURNS DECIMAL(4,2)
DETERMINISTIC READS SQL DATA
BEGIN
    DECLARE result DECIMAL(4,2);
    SELECT ROUND(SUM(fn_grade_point(subject_pct) * credits) / SUM(credits), 2) INTO result
    FROM (
        SELECT sub.credits,
               100 * SUM(m.marks_obtained) / SUM(e.max_marks) AS subject_pct
        FROM Marks m
        JOIN Exam e ON e.exam_id = m.exam_id
        JOIN Subject sub ON sub.subject_id = e.subject_id
        WHERE m.student_id = p_student
        GROUP BY sub.subject_id, sub.credits
    ) x;
    RETURN IFNULL(result, 0);
END$$

-- Full report card for one student
CREATE PROCEDURE sp_student_report(IN p_student INT)
BEGIN
    SELECT student_id, name, department, semester, fn_cgpa(student_id) AS cgpa
    FROM Student WHERE student_id = p_student;

    SELECT sub.subject_name,
           fn_attendance_pct(p_student, sub.subject_id) AS attendance_pct,
           ROUND(100 * SUM(m.marks_obtained) / SUM(e.max_marks), 2) AS marks_pct
    FROM Subject sub
    JOIN Exam e ON e.subject_id = sub.subject_id
    JOIN Marks m ON m.exam_id = e.exam_id AND m.student_id = p_student
    GROUP BY sub.subject_id, sub.subject_name;
END$$

-- Subject-wise list of students below the attendance cutoff
CREATE PROCEDURE sp_low_attendance(IN p_subject INT, IN p_cutoff DECIMAL(5,2))
BEGIN
    SELECT st.student_id, st.name, v.attendance_pct
    FROM v_attendance_summary v JOIN Student st ON st.student_id = v.student_id
    WHERE v.subject_id = p_subject AND v.attendance_pct < p_cutoff
    ORDER BY v.attendance_pct;
END$$

-- =====================================================================
-- PART 6: TRIGGERS
-- (created AFTER the sample data so they do not fire during bulk load)
-- =====================================================================

-- Auto-flag a student when attendance in a subject falls below 75%
CREATE TRIGGER trg_low_attendance
AFTER INSERT ON Attendance
FOR EACH ROW
BEGIN
    IF fn_attendance_pct(NEW.student_id, NEW.subject_id) < 75
       AND NOT EXISTS (SELECT 1 FROM Risk_Flag
                       WHERE student_id = NEW.student_id
                         AND subject_id = NEW.subject_id
                         AND reason = 'Attendance below 75%') THEN
        INSERT INTO Risk_Flag (student_id, subject_id, reason)
        VALUES (NEW.student_id, NEW.subject_id, 'Attendance below 75%');
    END IF;
END$$

-- Block marks greater than the exam's maximum
CREATE TRIGGER trg_marks_validate
BEFORE INSERT ON Marks
FOR EACH ROW
BEGIN
    DECLARE mx INT;
    SELECT max_marks INTO mx FROM Exam WHERE exam_id = NEW.exam_id;
    IF NEW.marks_obtained > mx THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Marks obtained cannot exceed maximum marks';
    END IF;
END$$

DELIMITER ;

-- =====================================================================
-- PART 7: DEMONSTRATION (run these for your screenshots)
-- =====================================================================

SELECT * FROM v_risk_analysis ORDER BY risk_score DESC, marks_pct;
SELECT * FROM v_at_risk_students;

SELECT fn_cgpa(1)  AS cgpa_student_1, fn_cgpa(5) AS cgpa_student_5;
CALL sp_student_report(5);
CALL sp_low_attendance(1, 75);

-- Trigger demo: student 1 misses a new DBMS class -> check Risk_Flag
INSERT INTO Attendance (student_id, subject_id, class_date, status)
VALUES (5, 1, '2026-10-01', 'Absent');
SELECT * FROM Risk_Flag;

-- Validation trigger demo (this is EXPECTED to give an error)
-- INSERT INTO Marks VALUES (1, 1, 999);

-- Transaction demo
START TRANSACTION;
UPDATE Marks SET marks_obtained = marks_obtained + 2 WHERE student_id = 5 AND exam_id = 1;
SELECT * FROM Marks WHERE student_id = 5 AND exam_id = 1;
ROLLBACK;   -- undo; use COMMIT to keep the change
