import os, json, uuid, datetime
import boto3

TABLE_NAME = os.environ["TABLE_NAME"]
ALLOWED_STATUSES = set(os.environ.get("STATUSES", "pending,in_progress,completed").split(","))

dynamo = boto3.resource("dynamodb")
table = dynamo.Table(TABLE_NAME)

def _now_iso():
    return datetime.datetime.now(datetime.timezone.utc).isoformat() #gets the TUC timestamp and converts to ISO format to store in DynamoDB

def _bad_request(msg):
    return {"statusCode": 400, "headers": {"content-type": "application/json"}, "body": json.dumps({"error": msg})}  #to display error messages in JSON format

def handler(event, context):
    try:
        if event.get("requestContext", {}).get("http", {}).get("method") != "POST":
            return {"statusCode": 405, "headers": {"allow": "POST"}}

        if not event.get("body"):
            return _bad_request("Missing JSON body")

        try:
            payload = json.loads(event["body"])  #Parses incoming JSON string into a Python dict
        except json.JSONDecodeError:
            return _bad_request("Invalid JSON")

        title = (payload.get("title") or "").strip()
        description = (payload.get("description") or "").strip()
        status = (payload.get("status") or "pending").strip()

        if not title:
            return _bad_request("Field 'title' is required")
        if status not in ALLOWED_STATUSES:
            return _bad_request(f"Invalid 'status'. Allowed: {sorted(ALLOWED_STATUSES)}")

        task_id = str(uuid.uuid4())
        now = _now_iso()

        item = {
            "task_id": task_id,
            "title": title,
            "description": description,
            "status": status,
            "created_at": now,
            "updated_at": now,
        }

        table.put_item(Item=item, ConditionExpression="attribute_not_exists(task_id)")

        body = json.dumps(item)
        return {
            "statusCode": 201,
            "headers": {
                "content-type": "application/json",
                "location": f"/tasks/{task_id}",
            },
            "body": body,
        }

    except Exception as e:
        # Avoid leaking internals, but log will have stacktrace
        return {"statusCode": 500, "headers": {"content-type": "application/json"}, "body": json.dumps({"error": "Internal Server Error"})}
