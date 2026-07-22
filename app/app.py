from flask import Flask, request, render_template, redirect, url_for, session
import psycopg2
import os

app = Flask(__name__)

# INTENTIONALLY INSECURE:
# Hardcoded secret for demonstration purposes.
# SonarQube should detect this.
app.secret_key = "super_secret_devsecops_key_123"

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_NAME = os.getenv("DB_NAME", "clipboarddb")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "postgres")
DB_PORT = os.getenv("DB_PORT", "5432")


def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        port=DB_PORT
    )


def init_db():

    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id SERIAL PRIMARY KEY,
            username VARCHAR(100) UNIQUE NOT NULL,
            password VARCHAR(255) NOT NULL
        )
    """)

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS notes (
            id SERIAL PRIMARY KEY,
            username VARCHAR(100),
            content TEXT
        )
    """)

    conn.commit()

    cursor.close()
    conn.close()


@app.route("/")
def index():

    return render_template("index.html")


@app.route("/register", methods=["GET", "POST"])
def register():

    if request.method == "POST":

        username = request.form["username"]
        password = request.form["password"]

        conn = get_db_connection()
        cursor = conn.cursor()

        try:

            cursor.execute(
                "INSERT INTO users (username, password) VALUES (%s, %s)",
                (username, password)
            )

            conn.commit()

        except Exception as e:

            conn.rollback()

            return f"Registration failed: {e}"

        finally:

            cursor.close()
            conn.close()

        return redirect(url_for("login"))

    return render_template("login.html", register=True)


@app.route("/login", methods=["GET", "POST"])
def login():

    if request.method == "POST":

        username = request.form["username"]
        password = request.form["password"]

        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute(
            "SELECT * FROM users WHERE username=%s AND password=%s",
            (username, password)
        )

        user = cursor.fetchone()

        cursor.close()
        conn.close()

        if user:

            session["username"] = username

            return redirect(url_for("dashboard"))

        return "Invalid username or password"

    return render_template("login.html", register=False)


@app.route("/dashboard")
def dashboard():

    if "username" not in session:

        return redirect(url_for("login"))

    conn = get_db_connection()
    cursor = conn.cursor()

    username = session["username"]

    cursor.execute(
        "SELECT id, content FROM notes WHERE username=%s",
        (username,)
    )

    notes = cursor.fetchall()

    cursor.close()
    conn.close()

    return render_template(
        "dashboard.html",
        username=username,
        notes=notes
    )


@app.route("/add_note", methods=["POST"])
def add_note():

    if "username" not in session:

        return redirect(url_for("login"))

    content = request.form["content"]

    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute(
        "INSERT INTO notes (username, content) VALUES (%s, %s)",
        (session["username"], content)
    )

    conn.commit()

    cursor.close()
    conn.close()

    return redirect(url_for("dashboard"))


@app.route("/delete_note/<int:note_id>")
def delete_note(note_id):

    if "username" not in session:

        return redirect(url_for("login"))

    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute(
        "DELETE FROM notes WHERE id=%s",
        (note_id,)
    )

    conn.commit()

    cursor.close()
    conn.close()

    return redirect(url_for("dashboard"))


@app.route("/logout")
def logout():

    session.pop("username", None)

    return redirect(url_for("index"))


if __name__ == "__main__":

    init_db()

    app.run(
        host="0.0.0.0",
        port=5000,
        debug=False
    )
