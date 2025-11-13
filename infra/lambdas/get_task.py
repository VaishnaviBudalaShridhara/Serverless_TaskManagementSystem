import os, json
import boto3

TABLE_NAME = os.environ["TABLE_NAME"]
dynamo = boto3.resource("dynamodb")
table = dynamo.Table(TABLE_NAME)

def handler(event, context):
    try:
        if event.get("requestContext", {}).get("http", {}).get("method") != "GET":
            return {"statusCode": 405, "headers": {"allow": "GET"}}

        path_params = event.get("pathParameters") or {}
        task_id = path_params.get("id")
        if not task_id:
            return {"statusCode": 400, "headers": {"content-type": "application/json"}, "body": json.dumps({"error": "Missing path parameter 'id'"})}

        res = table.get_item(Key={"task_id": task_id})
        item = res.get("Item")
        if not item:
            return {"statusCode": 404, "headers": {"content-type": "application/json"}, "body": json.dumps({"error": "Task not found"})}

        return {"statusCode": 200, "headers": {"content-type": "application/json"}, "body": json.dumps(item)}

    except Exception as e:
        return {"statusCode": 500, "headers": {"content-type": "application/json"}, "body": json.dumps({"error": "Internal Server Error"})}
