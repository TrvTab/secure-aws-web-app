import bcrypt
from flask_jwt_extended import create_access_token
from psycopg2 import pool, errors as db_errors
from configuration import Configuration

# Create pool once when module loads
db_pool = pool.SimpleConnectionPool(
    minconn=1,
    maxconn=10,
    host=Configuration.DB_HOST,
    user=Configuration.DB_USER,
    password=Configuration.DB_PASSWORD,
    database=Configuration.DB_NAME
)

def hash_password(password: str) -> str:
    passwordBytes = password.encode("utf-8")
    hashed = bcrypt.hashpw(passwordBytes, bcrypt.gensalt()) # gensalt adds salting to password    
    return hashed.decode("utf-8")

def verify_password(password: str, hashedPassword: str) -> str:
    passwordBytes = password.encode("utf-8")
    hashBytes = hashedPassword.encode("utf-8")
    return bcrypt.checkpw(passwordBytes, hashBytes)


def create_token(userId: str):
    return create_access_token(identity=userId)


def get_db_connection():
    return db_pool.getconn()

def end_db_connection(connection, cursor):
    cursor.close()
    db_pool.putconn(connection)


def create_user(username: str, passwordHash: str, email:str):
    connection = get_db_connection()
    cursor = connection.cursor()
    try:
        cursor.execute("INSERT INTO users (username, password_hash, email, created_at, updated_at) " \
            "VALUES (%s, %s, %s, NOW(), NOW());", (username, passwordHash, email))
        sample = cursor.fetchone()
        print(sample)
        user_id = sample[0]
        connection.commit()
        return user_id
    except db_errors.UniqueViolation:
        connection.rollback()
        raise ValueError("Username or email already exists")
    except db_errors.NotNullViolation:
        connection.rollback()
        raise ValueError("All fields are required")
    except db_errors.IntegrityError:
        connection.rollback()
        raise ValueError("Invalid data")
    except db_errors.OperationalError:
        connection.rollback()
        raise ConnectionError("Database unavailable")
    finally:
        end_db_connection(connection=connection, cursor=cursor)

def get_user_by_username(username):
    connection = get_db_connection()
    cursor = connection.cursor()
    try:
        cursor.execute(
            "SELECT id, password_hash FROM users WHERE username = %s",
            (username)
        )
        user = cursor.fetchone()
        if not user:
            return None        
        return user
    except db_errors.OperationalError:
        raise ConnectionError("Database unavailable")
    finally:
        end_db_connection(connection=connection, cursor=cursor)

def update_user_login_time(user_id: str):
    connection = get_db_connection()
    cursor = connection.cursor()
    try:
        cursor.execute("UPDATE users SET last_login = NOW() WHERE id = %s;", (user_id,))
    except db_errors.OperationalError:
        connection.rollback()
        raise ConnectionError("Database unavailable")
    finally:
        end_db_connection(connection=connection, cursor=cursor)

def get_all_users():
    connection = get_db_connection()
    cursor = connection.cursor()
    try:
        cursor.execute("SELECT username, email FROM users;")
        rows = cursor.fetchall()
        return rows
    except db_errors.OperationalError:
        raise ConnectionError("Database unavailable")
    finally:
        end_db_connection(connection=connection, cursor=cursor)

def get_user_by_id(user_id: str):
    connection = get_db_connection()
    cursor = connection.cursor()
    try:
        cursor.execute(
        "SELECT email, username, last_login, created_at, updated_at " \
        "FROM users " \
        "WHERE username = %s; ", (user_id))
        user = cursor.fetchone()
        return user
    except db_errors.OperationalError:
        raise ConnectionError("Database unavailable")
    finally:
        end_db_connection(connection=connection, cursor=cursor)

def delete_user_by_id(user_id: str):
    connection = get_db_connection()
    cursor = connection.cursor()
    try:
        cursor.execute("DELETE FROM users WHERE id = %s;", (user_id,))
        connection.commit()
    except db_errors.OperationalError:
        raise ConnectionError("Database unavailable")
    finally:
        end_db_connection(connection=connection, cursor=cursor)

def update_password(user_id: str, new_password: str):
    connection = get_db_connection()
    cursor = connection.cursor()
    try:
       hashed_password = hash_password(password=new_password)
       cursor.execute(
        "UPDATE users SET password_hash = %s, updated_at = NOW() WHERE id = %s;",
        (hashed_password, user_id))
       connection.commit()
    except db_errors.OperationalError:
        raise ConnectionError("Database unavailable")
    finally:
        end_db_connection(connection=connection, cursor=cursor)
