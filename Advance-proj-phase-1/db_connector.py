import pymysql
import os
from typing import Optional
from dotenv import load_dotenv

load_dotenv()


class Database:
    def __init__(self):
        self.config = {
            'host': os.getenv('DB_HOST', 'localhost'),
            'user': os.getenv('DB_USER', 'username'),
            'password': os.getenv('DB_PASSWORD', 'password'),
            'database': os.getenv('DB_NAME', 'mydb')
        }
        self.admin_connection = None

    def get_connection(self):
        try:
            conn = pymysql.connect(**self.config)
            if conn is None:
                raise Exception("Failed to establish database connection")
                
            with conn.cursor() as cursor:
                cursor.execute("SHOW TABLES LIKE 'users'")
                table_exists = cursor.fetchone()
                if table_exists is not None:
                    return conn
            conn.close()
        except Exception as e:
            print(f"Database connection failed: {e}")
        
        self.initialize_database()
        
        final_conn = pymysql.connect(**self.config)
        if final_conn is None:
            raise Exception("Critical: Unable to establish database connection after initialization")
        return final_conn

    def connect_as_admin(self, admin_user: str = "root", admin_password: str = "") -> bool:
        try:
            self.admin_connection = pymysql.connect(
                host=self.config['host'],
                user=admin_user,
                password=admin_password,
                charset='utf8mb4',
                cursorclass=pymysql.cursors.DictCursor
            )
            return True
        except Exception as e:
            print(f"Failed to connect as admin: {e}")
            return False

    def create_root_user(self, username: str, password: str, host: str = '%') -> bool:
        if not self.admin_connection:
            print("Not connected as admin")
            return False
        
        try:
            with self.admin_connection.cursor() as cursor:
                cursor.execute(f"CREATE USER IF NOT EXISTS '{username}'@'{host}' IDENTIFIED BY '{password}'")
                cursor.execute(f"GRANT ALL PRIVILEGES ON *.* TO '{username}'@'{host}' WITH GRANT OPTION")
                cursor.execute("FLUSH PRIVILEGES")
                self.admin_connection.commit()
                print(f"Root user '{username}' created successfully")
                return True
        except Exception as e:
            print(f"Failed to create root user: {e}")
            return False

    def create_database_schema(self, database_name: str, schema_file: Optional[str] = None) -> bool:
        if not self.admin_connection:
            print("Not connected as admin")
            return False
        
        try:
            with self.admin_connection.cursor() as cursor:
                cursor.execute(f"CREATE DATABASE IF NOT EXISTS {database_name}")
                cursor.execute(f"USE {database_name}")
                
                if schema_file and os.path.exists(schema_file):
                    with open(schema_file, 'r') as f:
                        schema_sql = f.read()
                    
                    for statement in schema_sql.split(';'):
                        statement = statement.strip()
                        if statement:
                            cursor.execute(statement)
                else:
                    self._create_default_schema(cursor)
                
                self.admin_connection.commit()
                print(f"Database '{database_name}' and schema created successfully")
                return True
        except Exception as e:
            print(f"Failed to create database schema: {e}")
            return False

    def _create_default_schema(self, cursor) -> None:
        tables = [
            """
            CREATE TABLE IF NOT EXISTS users (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_name VARCHAR(50) UNIQUE NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )
            """
        ]
        
        for table_sql in tables:
            cursor.execute(table_sql)

    def initialize_database(
        self,
        admin_user: Optional[str] = None,
        admin_password: Optional[str] = None,
        database_name: Optional[str] = None,
        new_root_user: Optional[str] = None,
        new_root_password: Optional[str] = None,
        schema_file: Optional[str] = None
    ) -> bool:
        admin_user = admin_user or os.getenv('DB_ROOT_USER', 'root')
        admin_password = admin_password or os.getenv('DB_ROOT_PASSWORD', '')
        database_name = database_name or os.getenv('DB_NAME', 'users_db')
        
        if not self.connect_as_admin(admin_user, admin_password):
            return False
        
        try:
            if new_root_user and new_root_password:
                if not self.create_root_user(new_root_user, new_root_password):
                    return False
            
            if not self.create_database_schema(database_name, schema_file):
                return False
            
            print("Database initialization completed successfully")
            return True
        finally:
            self.close_admin_connection()

    def close_admin_connection(self) -> None:
        if self.admin_connection:
            self.admin_connection.close()
            self.admin_connection = None
    
