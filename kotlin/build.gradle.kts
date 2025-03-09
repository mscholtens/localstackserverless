plugins {
    kotlin("jvm") version "1.6.10" // Kotlin JVM plugin (ensure the version matches the one used in your code)
    application // Apply the application plugin
}

repositories {
    mavenCentral() // Repository for fetching dependencies
}

dependencies {
    // Kotlin standard library
    implementation(kotlin("stdlib"))

    // AWS SDK for DynamoDB
    implementation("software.amazon.awssdk:dynamodb:2.17.96") // AWS SDK for DynamoDB
    implementation("software.amazon.awssdk:auth:2.17.96") // AWS SDK for authentication
    implementation("software.amazon.awssdk:core:2.17.96") // AWS SDK core module

    // Jackson library for JSON parsing (if needed by your project)
    implementation("com.fasterxml.jackson.core:jackson-databind:2.12.4")
}

tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile> {
    kotlinOptions.jvmTarget = "1.8" // Set JVM target to 1.8
}

tasks.named<JavaExec>("run") {
    standardInput = System.`in`
}

application {
    // The main class for the application entry point
    mainClass.set("MainKt")
}
