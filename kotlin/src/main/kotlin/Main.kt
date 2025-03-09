import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider
import software.amazon.awssdk.regions.Region
import software.amazon.awssdk.services.dynamodb.DynamoDbClient
import software.amazon.awssdk.services.dynamodb.model.*
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials
import java.net.URI
import java.util.*
import com.fasterxml.jackson.databind.ObjectMapper
import java.io.File

fun main() {

    // Initialize DynamoDB client for LocalStack (local DynamoDB endpoint)
    val dynamoDbClient = DynamoDbClient.builder()
        .endpointOverride(URI.create("http://localhost:4566")) // LocalStack endpoint
        .region(Region.US_EAST_1) // Use any AWS region
        .credentialsProvider(StaticCredentialsProvider.create(
            AwsBasicCredentials.create("accessKey", "secretKey")
        ))
        .build()

    val tableName = "ApplicationTestResults"

    // Interactive Shell
    while (true) {
        println("Enter command (add, update, delete, find, list, check, quit):")
        val command = readLine()
        println("You entered: '$command'")

        // If the command is null or empty, continue the loop
        if (command.isNullOrEmpty()) {
            println("No command entered. Try again.")
            continue
        }

        // Process the command based on user input
        when (command) {
            "add" -> addEntry(dynamoDbClient, tableName)
            "update" -> updateEntry(dynamoDbClient, tableName)
            "delete" -> deleteEntry(dynamoDbClient, tableName)
            "find" -> findEntry(dynamoDbClient, tableName)
            "list" -> listEntries(dynamoDbClient, tableName)
            "check" -> checkDynamoDb(dynamoDbClient)
            "quit" -> {
                println("Exiting...")
                break  // Exit the loop
            }
            else -> println("Invalid command. Try again.")  // Handle invalid commands
        }
    }

    dynamoDbClient.close()
}

// Add Entry
fun addEntry(dynamoDbClient: DynamoDbClient, tableName: String) {
    println("Enter file location containing JSON data for the entry:")
    val fileLocation = readLine()?.trim()

    if (fileLocation.isNullOrEmpty()) {
        println("No file location entered. Please provide a valid file.")
        return
    }

    try {
        val file = File(fileLocation)
        val objectMapper = ObjectMapper()
        val entry = objectMapper.readTree(file)

        // Validate the fields
        if (!entry.has("date") || !entry.has("application") || !entry.has("passed") || !entry.has("failed") || !entry.has("total")) {
            println("Invalid file format. Missing required fields.")
            return
        }

        val date = entry.get("date").asText()
        val application = entry.get("application").asText()
        val passed = entry.get("passed").asInt()
        val failed = entry.get("failed").asInt()
        val total = entry.get("total").asInt()

        val item = mapOf(
            "date" to AttributeValue.builder().s(date).build(),
            "application" to AttributeValue.builder().s(application).build(),
            "passed" to AttributeValue.builder().n(passed.toString()).build(),
            "failed" to AttributeValue.builder().n(failed.toString()).build(),
            "total" to AttributeValue.builder().n(total.toString()).build()
        )

        val request = PutItemRequest.builder()
            .tableName(tableName)
            .item(item)
            .build()

        dynamoDbClient.putItem(request)
        println("Entry added successfully.")
    } catch (e: Exception) {
        println("Error processing the file: ${e.message}")
    }
}

// Update Entry
fun updateEntry(dynamoDbClient: DynamoDbClient, tableName: String) {
    println("Enter file location containing JSON data for the entry (includes date and application):")
    val fileLocation = readLine()?.trim()

    if (fileLocation.isNullOrEmpty()) {
        println("No file location entered. Please provide a valid file.")
        return
    }

    try {
        val file = File(fileLocation)
        val objectMapper = ObjectMapper()
        val entry = objectMapper.readTree(file)

        // Validate the fields
        if (!entry.has("date") || !entry.has("application") || !entry.has("passed") || !entry.has("failed") || !entry.has("total")) {
            println("Invalid file format. Missing required fields.")
            return
        }

        val date = entry.get("date").asText()
        val application = entry.get("application").asText()
        val passed = entry.get("passed").asInt()
        val failed = entry.get("failed").asInt()
        val total = entry.get("total").asInt()

        // Expression Attribute Names for reserved keywords
        val expressionNames = mutableMapOf<String, String>()
        expressionNames["#total"] = "total"

        val updateExpression = "SET passed = :passed, failed = :failed, #total = :total"
        val expressionValues = mapOf(
            ":passed" to AttributeValue.builder().n(passed.toString()).build(),
            ":failed" to AttributeValue.builder().n(failed.toString()).build(),
            ":total" to AttributeValue.builder().n(total.toString()).build()
        )

        val request = UpdateItemRequest.builder()
            .tableName(tableName)
            .key(
                mapOf(
                    "date" to AttributeValue.builder().s(date).build(),
                    "application" to AttributeValue.builder().s(application).build()
                )
            )
            .updateExpression(updateExpression)
            .expressionAttributeNames(expressionNames)
            .expressionAttributeValues(expressionValues)
            .build()

        dynamoDbClient.updateItem(request)
        println("Entry updated successfully.")
    } catch (e: Exception) {
        println("Error processing the file: ${e.message}")
    }
}

// Delete Entry
fun deleteEntry(dynamoDbClient: DynamoDbClient, tableName: String) {
    println("Enter date to delete:")
    val date = readLine()?.trim()

    if (date.isNullOrEmpty()) {
        println("Date is required to delete the entry. Exiting.")
        return
    }

    println("Enter application to delete:")
    val application = readLine()?.trim()

    if (application.isNullOrEmpty()) {
        println("Application is required to delete the entry. Exiting.")
        return
    }

    val request = DeleteItemRequest.builder()
        .tableName(tableName)
        .key(
            mapOf(
                "date" to AttributeValue.builder().s(date).build(),
                "application" to AttributeValue.builder().s(application).build()
            )
        )
        .build()

    try {
        dynamoDbClient.deleteItem(request)
        println("Entry deleted or was not found.")
    } catch (e: DynamoDbException) {
        println("Error deleting entry: ${e.message}")
    }
}

// Find Entry
fun findEntry(dynamoDbClient: DynamoDbClient, tableName: String) {
    println("Enter date to find:")
    val date = readLine()?.trim()

    if (date.isNullOrEmpty()) {
        println("Date is required to find the entry. Exiting.")
        return
    }

    println("Enter application to find:")
    val application = readLine()?.trim()

    if (application.isNullOrEmpty()) {
        println("Application is required to find the entry. Exiting.")
        return
    }

    val key = mapOf(
        "date" to AttributeValue.builder().s(date).build(),
        "application" to AttributeValue.builder().s(application).build()
    )

    val request = GetItemRequest.builder()
        .tableName(tableName)
        .key(key)
        .build()

    try {
        val response = dynamoDbClient.getItem(request)
        if (response.hasItem()) {
            println("Found entry: ${response.item()}")
        } else {
            println("No entry found.")
        }
    } catch (e: DynamoDbException) {
        println("Error finding entry: ${e.message}")
    }
}

// List Entries
fun listEntries(dynamoDbClient: DynamoDbClient, tableName: String) {
    println("Enter date for filter (leave blank to skip):")
    val date = readLine()?.trim()
    println("Enter application for filter (leave blank to skip):")
    val application = readLine()?.trim()

    val filterExpression = mutableListOf<String>()
    val expressionValues = mutableMapOf<String, AttributeValue>()
    val expressionNames = mutableMapOf<String, String>()

    // If a date is given, add it to the filter and map the alias #date to "date"
    if (!date.isNullOrBlank()) {
        filterExpression.add("#date = :date")
        expressionValues[":date"] = AttributeValue.builder().s(date).build()
        expressionNames["#date"] = "date"  // Alias for reserved keyword
    }

    // If an application is given, add it to the filter
    if (!application.isNullOrBlank()) {
        filterExpression.add("application = :application")
        expressionValues[":application"] = AttributeValue.builder().s(application).build()
    }

    val requestBuilder = ScanRequest.builder()
        .tableName(tableName)

    // Only add ExpressionAttributeNames if #date is in the filter
    if (expressionNames.isNotEmpty()) {
        requestBuilder.expressionAttributeNames(expressionNames)
    }

    // If we have a filter expression, apply it
    if (filterExpression.isNotEmpty()) {
        requestBuilder.filterExpression(filterExpression.joinToString(" AND "))
            .expressionAttributeValues(expressionValues)
    }

    try {
        val result = dynamoDbClient.scan(requestBuilder.build())
        if (result.items().isEmpty()) {
            println("No entries found.")
        } else {
            result.items().forEach {
                println("Item: $it")
            }
        }
    } catch (e: DynamoDbException) {
        println("Error listing entries: ${e.message}")
    }
}

// Check DynamoDB Access
fun checkDynamoDb(dynamoDbClient: DynamoDbClient) {
    try {
        val request = DescribeTableRequest.builder().tableName("ApplicationTestResults").build()
        val response = dynamoDbClient.describeTable(request)
        println("DynamoDB is accessible. Table status: ${response.table().tableStatus()}")
    } catch (e: DynamoDbException) {
        println("Error accessing DynamoDB: ${e.message}")
    }
}
