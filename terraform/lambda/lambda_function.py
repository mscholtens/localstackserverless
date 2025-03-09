import json
import boto3
from botocore.exceptions import ClientError
import logging
from decimal import Decimal

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize DynamoDB resource
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('ApplicationTestResults')

def handler(event, context):
    # Log the incoming event for debugging purposes
    logger.info(f"Received event: {json.dumps(event)}")

    # Extract HTTP method, path parameters, query parameters, and body from the event
    method = event.get('httpMethod')
    path_params = event.get('pathParameters', {})
    query_params = event.get('queryStringParameters', {})  # Default to empty dict if not present
    body = event.get('body', None)

    # If the body is provided, parse it; otherwise, default to an empty dict
    if body:
        body = json.loads(body)
    else:
        body = {}

    try:
        # POST /entry: Create a new entry in DynamoDB
        if method == 'POST' and event['resource'] == '/entry':
            return create_entry(body)

        # PUT /entry: Update an existing entry in DynamoDB
        elif method == 'PUT' and event['resource'] == '/entry':
            return update_entry(query_params, body)

        # DELETE /entry: Delete an entry from DynamoDB
        elif method == 'DELETE' and event['resource'] == '/entry':
            return delete_entry(query_params)

        # GET /entry: Retrieve a specific entry from DynamoDB
        elif method == 'GET' and event['resource'] == '/entry':
            return get_entry(query_params)

        # GET /entries: List all entries from DynamoDB with optional filtering
        elif method == 'GET' and event['resource'] == '/entries':
            return get_entries(query_params)

        # If method is not allowed, return a 405 Method Not Allowed
        else:
            logger.warning(f"Method {method} not allowed for {event['resource']}")
            return {
                "statusCode": 405,
                "body": json.dumps({"message": "Method Not Allowed"})
            }

    except ClientError as e:
        # Log DynamoDB errors
        logger.error(f"ClientError: {str(e)}")
        return {
            "statusCode": 500,
            "body": json.dumps({"message": f"Error: {str(e)}"})
        }

    except Exception as e:
        # Log any other unexpected errors
        logger.error(f"Unexpected error: {str(e)}")
        return {
            "statusCode": 500,
            "body": json.dumps({"message": f"Unexpected error: {str(e)}"})
        }

def create_entry(data):
    """Create a new entry in DynamoDB."""
    try:
        # First, check if the entry already exists
        response = table.get_item(
            Key={
                'date': data['date'],
                'application': data['application']
            }
        )

        # If the item exists, return an error
        if 'Item' in response:
            logger.warning(f"Entry already exists: {json.dumps(data)}")
            return {
                "statusCode": 400,
                "body": json.dumps({"message": "Entry already exists with the same date and application"})
            }

        # If no existing item, proceed to insert
        response = table.put_item(
            Item={
                'date': data['date'],
                'application': data['application'],
                'passed': data['passed'],
                'failed': data['failed'],
                'total': data['total']
            }
        )
        logger.info(f"Created new entry: {json.dumps(data)}")
        return {
            "statusCode": 201,
            "body": json.dumps({"message": "Entry created"})
        }
    
    except KeyError as e:
        logger.error(f"Missing required key in data: {str(e)}")
        return {
            "statusCode": 400,
            "body": json.dumps({"message": f"Missing required key: {str(e)}"})
        }
    except ClientError as e:
        # Log any DynamoDB errors
        logger.error(f"Error creating entry: {e.response['Error']['Message']}")
        return {
            "statusCode": 500,
            "body": json.dumps({"message": f"Error creating entry: {e.response['Error']['Message']}"})
        }

def update_entry(query_params, data):
    """Update an existing entry in DynamoDB."""
    if 'date' not in query_params or 'application' not in query_params:
        logger.error("Missing mandatory query parameters (date and application)")
        return {
            "statusCode": 400,
            "body": json.dumps({"message": "Missing mandatory query parameters (date and application)"})
        }

    # Prepare ExpressionAttributeNames to handle reserved keywords
    expression_attribute_names = {
        "#total": "total"  # Alias for the reserved keyword 'total'
    }

    try:
        # Update the item in DynamoDB
        response = table.update_item(
            Key={
                'date': query_params['date'],
                'application': query_params['application']
            },
            UpdateExpression="SET #total = :total, passed = :passed, failed = :failed",
            ExpressionAttributeNames=expression_attribute_names,  # Provide the alias for 'total'
            ExpressionAttributeValues={
                ':total': data.get('total', 0),
                ':passed': data.get('passed', 0),
                ':failed': data.get('failed', 0)
            },
            ReturnValues="ALL_NEW"
        )
        logger.info(f"Updated entry: {json.dumps(query_params)}")
        return {
            "statusCode": 200,
            "body": json.dumps({"message": "Entry updated"})
        }

    except ClientError as e:
        logger.error(f"Error updating entry: {e.response['Error']['Message']}")
        return {
            "statusCode": 500,
            "body": json.dumps({"message": f"Error updating entry: {e.response['Error']['Message']}"})
        }

def delete_entry(query_params):
    """Delete an entry from DynamoDB."""
    if 'date' not in query_params or 'application' not in query_params:
        logger.error("Missing mandatory query parameters (date and application)")
        return {
            "statusCode": 400,
            "body": json.dumps({"message": "Missing mandatory query parameters (date and application)"})
        }

    try:
        # Attempt to delete the item from DynamoDB without ExpressionAttributeNames
        response = table.delete_item(
            Key={
                'date': query_params['date'],  # No alias needed for 'date' now
                'application': query_params['application']  # No alias needed for 'application'
            }
        )

        # Always return 200 and a success message indicating the entry was deleted or was not found
        logger.info(f"Entry processed for deletion (found or not): {json.dumps(query_params)}")
        return {
            "statusCode": 200,
            "body": json.dumps({"message": "Entry deleted or was not found"})
        }

    except ClientError as e:
        logger.error(f"Error deleting entry: {e.response['Error']['Message']}")
        return {
            "statusCode": 500,
            "body": json.dumps({"message": f"Error deleting entry: {e.response['Error']['Message']}"})
        }

    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return {
            "statusCode": 500,
            "body": json.dumps({"message": f"Unexpected error: {str(e)}"})
        }

def get_entry(query_params):
    """Get a specific entry from DynamoDB."""
    if 'date' not in query_params or 'application' not in query_params:
        logger.error("Missing mandatory query parameters (date and application)")
        return {
            "statusCode": 400,
            "body": json.dumps({"message": "Missing mandatory query parameters (date and application)"})
        }

    try:
        # Get the item from DynamoDB
        response = table.get_item(
            Key={
                'date': query_params['date'],
                'application': query_params['application']
            }
        )

        if 'Item' in response:
            # Convert any Decimal values in the response
            logger.info(f"Retrieved entry: {json.dumps(response['Item'], default=str)}")
            item = convert_decimal(response['Item'])
            return {
                "statusCode": 200,
                "body": json.dumps(item)
            }
        else:
            logger.warning(f"Entry not found for {json.dumps(query_params)}")
            return {
                "statusCode": 404,
                "body": json.dumps({"message": "Entry not found"})
            }

    except ClientError as e:
        logger.error(f"Error retrieving entry: {e.response['Error']['Message']}")
        return {
            "statusCode": 500,
            "body": json.dumps({"message": f"Error retrieving entry: {e.response['Error']['Message']}"})
        }

    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return {
            "statusCode": 500,
            "body": json.dumps({"message": f"Unexpected error: {str(e)}"})
        }

def get_entries(query_params):
    """Get all entries from DynamoDB with optional filtering by date and application."""
    filter_expression = []
    expression_values = {}
    expression_names = {}

    if query_params is None:
        query_params = {}

    # Handle date filter (reserved keyword)
    if query_params.get('date') is not None and query_params['date']:
        filter_expression.append("#date = :date")
        expression_values[':date'] = query_params['date']
        expression_names['#date'] = 'date'  # Mapping #date to the actual attribute name 'date'

    # Handle application filter
    if query_params.get('application') is not None and query_params['application']:
        filter_expression.append("application = :application")
        expression_values[':application'] = query_params['application']

    try:
        # If no filters were added, do a scan on the entire table
        if not filter_expression:
            response = table.scan()
        else:
            # Combine filter expressions into one string (AND conditions)
            filter_expression_str = " AND ".join(filter_expression)

            # Perform scan based on whether expression_names is populated
            if expression_names:
                # If expression_names is populated, include it in the scan
                response = table.scan(
                    FilterExpression=filter_expression_str,
                    ExpressionAttributeValues=expression_values,
                    ExpressionAttributeNames=expression_names
                )
            else:
                # If expression_names is not populated, perform the scan without it
                response = table.scan(
                    FilterExpression=filter_expression_str,
                    ExpressionAttributeValues=expression_values
                )

        if not response['Items']:
            logger.warning(f"No entries found for filters: {query_params}")
            return {
                "statusCode": 200,
                "body": json.dumps([])  # Return an empty list if no items found
            }

        logger.info(f"Successfully retrieved {len(response['Items'])} entries matching the filters: {query_params}")

        # Convert Decimal values to native types before returning the response
        items = convert_decimal(response['Items'])

        # Return the found items
        return {
            "statusCode": 200,
            "body": json.dumps(items)
        }

    except ClientError as e:
        logger.error(f"Error querying DynamoDB: {e.response['Error']['Message']}")
        return {
            "statusCode": 500,
            "body": json.dumps({"message": f"Error querying DynamoDB: {e.response['Error']['Message']}"})
        }
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return {
            "statusCode": 500,
            "body": json.dumps({"message": f"Unexpected error: {str(e)}"})
        }

def convert_decimal(items):
    """Recursively convert Decimal to float/int in DynamoDB items."""
    if isinstance(items, list):
        return [convert_decimal(item) for item in items]  # If it's a list, process each element
    elif isinstance(items, dict):
        return {k: convert_decimal(v) for k, v in items.items()}  # If it's a dict, process each key-value pair
    elif isinstance(items, Decimal):
        # Convert Decimal to int or float
        # Check if the decimal is a whole number using `to_integral_value()`
        return float(items) if items != items.to_integral_value() else int(items)  # Use int if the Decimal is whole, else float
    else:
        return items  # Return other types as is

