import os, json
import boto3

TABLE_NAME = os.environ["TABLE_NAME"]
dynamo = boto3.resource("dynamodb")
table = dynamo.Table(TABLE_NAME)

def handler(event, context):
    try:
        if event.get("requestContext", {}).get("http", {}).get("method") != "GET":
            return {"statusCode": 405, "headers": {"allow": "GET"}}

        res = table.scan()

        items = res.get("Items", [])

        # Reorder fields for each item
        ordered_items = [
            {
                "task_id": item.get("task_id"),
                "title": item.get("title"),
                "description": item.get("description"),
                "status": item.get("status"),
                "created_at": item.get("created_at"),
                "updated_at": item.get("updated_at"),
            }
            for item in items
        ]

        body = {
            "items": ordered_items,
            "next_token": res.get("LastEvaluatedKey")
        }

        return {
            "statusCode": 200,
            "headers": {"content-type": "application/json"},
            "body": json.dumps(body)
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {"content-type": "application/json"},
            "body": json.dumps({"error": "Internal Server Error"})
        }
