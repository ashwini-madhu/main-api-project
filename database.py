import pymysql
import json

# Database connection details
db_host = "your-database-endpoint"
db_user = "your-username"
db_password = "your-password"
db_name = "your-database-name"

def lambda_handler(event, context):
    try:
        # Establish database connection
        connection = pymysql.connect(
            host=db_host,
            user=db_user,
            password=db_password,
            database=db_name,
            cursorclass=pymysql.cursors.DictCursor
        )

        # Return success message
        return {
            "statusCode": 200,
            "body": json.dumps({"message": "Connection successful"})
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }

    finally:
        # Close the connection if it was established
        if 'connection' in locals() and connection.open:
            connection.close()

