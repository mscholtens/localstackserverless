package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/apigateway"
	"github.com/aws/aws-sdk-go/aws/awserr" 
)

const apiBaseURLPrefix = "http://"
const apiBaseURLCRUDSuffix = ".execute-api.localhost.localstack.cloud:4566/dev/entry"
const apiBaseURLListSuffix = ".execute-api.localhost.localstack.cloud:4566/dev/entries"

var apiBaseURLCRUD = ""
var apiBaseURLList = ""

type Entry struct {
	Date        string `json:"date"`
	Application string `json:"application"`
	Passed      int    `json:"passed"`
	Failed      int    `json:"failed"`
	Total       int    `json:"total"`
}

func createBaseUrls() {
	// Initialize a session that can be used to interact with AWS services
	sess, err := session.NewSession(&aws.Config{
		Region:   aws.String("us-east-1"),
		Endpoint: aws.String("http://localhost:4566"), // LocalStack endpoint
	})
	if err != nil {
		fmt.Errorf("Failed to create session: %v", err)
	}

	// Create API Gateway client
	svc := apigateway.New(sess)

	// List the APIs
	resp, err := svc.GetRestApis(&apigateway.GetRestApisInput{})
	if err != nil {
		fmt.Errorf("Failed to get rest APIs: %v", err)
	}

	// Print out the API Gateway ID(s)
	for _, item := range resp.Items {
		fmt.Printf("API ID: %s\n", *item.Id)
		fmt.Printf("API Name: %s\n", *item.Name)

		// Get the resources for this API
		resourcesResp, err := svc.GetResources(&apigateway.GetResourcesInput{
			RestApiId: item.Id,
		})
		if err != nil {
			fmt.Printf("Failed to get resources for API %s: %v", *item.Id, err)
			continue
		}

		// Print the resources (endpoints)
		for _, resource := range resourcesResp.Items {
			fmt.Printf("Resource ID: %s, Resource Path: %s\n", *resource.Id, *resource.Path)

			// List common HTTP methods for this resource (GET, POST, PUT, DELETE, etc.)
			methods := []string{"GET", "POST", "PUT", "DELETE"}

			for _, method := range methods {
				// Try to get the method for each HTTP method type
				_, err := svc.GetMethod(&apigateway.GetMethodInput{
					RestApiId:  item.Id,
					ResourceId: resource.Id,
					HttpMethod: aws.String(method),
				})

				if err != nil {
					if aerr, ok := err.(awserr.Error); ok && aerr.Code() == apigateway.ErrCodeNotFoundException {
						// Method does not exist for this resource, continue with the next method
						continue
					} else {
						// If it's another kind of error, log it
						fmt.Printf("Failed to get method %s for resource %s: %v", method, *resource.Path, err)
					}
				} else {
					// If method is found, print it
					fmt.Printf("  Method: %s\n", method)
				}
			}
		}
	}

	// Now you can use the API ID to construct the URL dynamically
	apiID := *resp.Items[0].Id // assuming you're using the first API

	// Construct the dynamic URL
	baseURLCRUD := fmt.Sprintf(apiBaseURLPrefix+"%s"+apiBaseURLCRUDSuffix, apiID)
	baseURLList := fmt.Sprintf(apiBaseURLPrefix+"%s"+apiBaseURLListSuffix, apiID)
	fmt.Println("Base URL CRUD:", baseURLCRUD)
	fmt.Println("Base URL List:", baseURLList)
	apiBaseURLCRUD = baseURLCRUD
	apiBaseURLList = baseURLList
}

func main() {

	createBaseUrls()
	for {
		// List available commands
		fmt.Println("Available commands: post, put, delete, find, list, quit")
		fmt.Print("Enter command: ")

		var command string
		fmt.Scanln(&command)

		// Handle the 'quit' command
		if command == "quit" {
			fmt.Println("Exiting...")
			break
		}

		switch command {
		case "post":
			handlePost()
		case "put":
			handlePut()
		case "delete":
			handleDelete()
		case "find":
			handleFind()
		case "list":
			handleList()
		default:
			fmt.Println("Invalid command. Please try again.")
		}
	}
}

// handlePost will prompt for a file and send a POST request with the file content.
func handlePost() {
	fmt.Println("Enter the path to the file for POST:")
	var filepath string
	fmt.Scanln(&filepath)

	fileContent, err := readFile(filepath)
	if err != nil {
		fmt.Println("Error reading file:", err)
		return
	}

	// Define the URL for the POST endpoint
	url := apiBaseURLCRUD

	// Send POST request with the file content as the request body
	resp, err := http.Post(url, "application/json", bytes.NewBuffer(fileContent))
	if err != nil {
		fmt.Println("Error sending POST request:", err)
		return
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	fmt.Printf("Response: %s\n", body)
}

// handlePut will prompt for a file and send a PUT request with the file content.
func handlePut() {
	fmt.Println("Enter the path to the file for PUT:")
	var filepath string
	fmt.Scanln(&filepath)

	fileContent, err := readFile(filepath)
	if err != nil {
		fmt.Println("Error reading file:", err)
		return
	}
	
	// Unmarshal the JSON into the Entry struct
	var entry Entry
	err = json.Unmarshal(fileContent, &entry)
	if err != nil {
		fmt.Println("Error unmarshaling JSON:", err)
		return
	}

	// Check if the date and application are present
	if entry.Date == "" || entry.Application == "" {
		fmt.Println("Error: Missing mandatory fields (date and application) in the JSON file.")
		return
	}

	// Extract date and application
	date := entry.Date
	application := entry.Application

	// Define the URL for the PUT endpoint
	url := fmt.Sprintf("%s?date=%s&application=%s", apiBaseURLCRUD, date, application)

	// Send PUT request with the file content as the request body
	req, err := http.NewRequest("PUT", url, bytes.NewBuffer(fileContent))
	if err != nil {
		fmt.Println("Error creating PUT request:", err)
		return
	}
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		fmt.Println("Error sending PUT request:", err)
		return
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	fmt.Printf("Response: %s\n", body)
}

// handleDelete will prompt for parameters and send a DELETE request.
func handleDelete() {
	var date, application string
	fmt.Println("Enter date:")
	fmt.Scanln(&date)
	fmt.Println("Enter application:")
	fmt.Scanln(&application)

	// Trim leading/trailing spaces from both inputs
	date = strings.TrimSpace(date)
	application = strings.TrimSpace(application)

	// Check if at least one of the parameters is set
	if date == "" || application == "" {
		fmt.Println("Error: Both date or application must be provided.")
		return
	}

	// Construct query parameters for DELETE
	url := fmt.Sprintf("%s?date=%s&application=%s", apiBaseURLCRUD, date, application)

	// Send DELETE request
	req, err := http.NewRequest("DELETE", url, nil)
	if err != nil {
		fmt.Println("Error creating DELETE request:", err)
		return
	}

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		fmt.Println("Error sending DELETE request:", err)
		return
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	fmt.Printf("Response: %s\n", body)
}

// handleFind will prompt for parameters and send a GET request.
func handleFind() {
	var date, application string
	fmt.Println("Enter date:")
	fmt.Scanln(&date)
	fmt.Println("Enter application:")
	fmt.Scanln(&application)

	// Trim leading/trailing spaces from both inputs
	date = strings.TrimSpace(date)
	application = strings.TrimSpace(application)

	// Check if at least one of the parameters is set
	if date == "" || application == "" {
		fmt.Println("Error: Both date or application must be provided.")
		return
	}

	// Construct query parameters for GET
	url := fmt.Sprintf("%s?date=%s&application=%s", apiBaseURLCRUD, date, application)

	// Send GET request
	resp, err := http.Get(url)
	if err != nil {
		fmt.Println("Error sending GET request:", err)
		return
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	fmt.Printf("Response: %s\n", body)
}

// handleList will prompt for optional parameters and send a GET request.
func handleList() {
	var date, application string
	fmt.Println("Enter date (or leave blank):")
	fmt.Scanln(&date)
	fmt.Println("Enter application (or leave blank):")
	fmt.Scanln(&application)

	// Construct query parameters for GET
	var queryParams []string
	if date != "" {
		queryParams = append(queryParams, "date="+date)
	}
	if application != "" {
		queryParams = append(queryParams, "application="+application)
	}

	// Join query parameters and construct the URL
	url := apiBaseURLList
	if len(queryParams) > 0 {
		url += "?" + strings.Join(queryParams, "&")
	}

	// Send GET request
	resp, err := http.Get(url)
	if err != nil {
		fmt.Println("Error sending GET request:", err)
		return
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	fmt.Printf("Response: %s\n", body)
}

// readFile reads the content of a file and returns it as a byte slice.
func readFile(filepath string) ([]byte, error) {
	fileContent, err := os.ReadFile(filepath)
	if err != nil {
		return nil, err
	}
	return fileContent, nil
}
