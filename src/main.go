package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

type ResponseData struct {
	Message    string      `json:"message"`
	Event      interface{} `json:"event"`
	StatusCode int         `json:"statusCode"`
}

type ErrorResponse struct {
	Error string `json:"error"`
}

func lambdaHandler(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	log.Printf("Received event: %+v", request)

	body, err := parseRequestBody(request)
	if err != nil {
		log.Printf("Error processing request: %v", err)
		errorResponse := ErrorResponse{Error: err.Error()}
		errorBody, _ := json.Marshal(errorResponse)

		return events.APIGatewayProxyResponse{
			StatusCode: 500,
			Headers: map[string]string{
				"Content-Type":                "application/json",
				"Access-Control-Allow-Origin": "*",
			},
			Body: string(errorBody),
		}, nil
	}

	responseData := ResponseData{
		Message:    "Hello again from the pikin Lambda!",
		Event:      body,
		StatusCode: 200,
	}

	responseBody, err := json.Marshal(responseData)
	if err != nil {
		log.Printf("Error marshaling response: %v", err)
		errorResponse := ErrorResponse{Error: "Failed to marshal response"}
		errorBody, _ := json.Marshal(errorResponse)

		return events.APIGatewayProxyResponse{
			StatusCode: 500,
			Headers: map[string]string{
				"Content-Type":                "application/json",
				"Access-Control-Allow-Origin": "*",
			},
			Body: string(errorBody),
		}, nil
	}

	return events.APIGatewayProxyResponse{
		StatusCode: 200,
		Headers: map[string]string{
			"Content-Type":                "application/json",
			"Access-Control-Allow-Origin": "*",
		},
		Body: string(responseBody),
	}, nil
}

func parseRequestBody(request events.APIGatewayProxyRequest) (interface{}, error) {
	if request.Body == "" {
		return request, nil
	}

	var body string
	if request.IsBase64Encoded {
		decoded, err := base64.StdEncoding.DecodeString(request.Body)
		if err != nil {
			return nil, fmt.Errorf("failed to decode base64 body: %w", err)
		}
		body = string(decoded)
	} else {
		body = request.Body
	}

	var jsonBody interface{}
	if err := json.Unmarshal([]byte(body), &jsonBody); err != nil {
		return map[string]string{"raw_body": body}, nil
	}

	return jsonBody, nil
}

func main() {
	lambda.Start(lambdaHandler)
}
