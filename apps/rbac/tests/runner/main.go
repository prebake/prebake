// Copyright 2025 Nadrama Pty Ltd
// SPDX-License-Identifier: Apache-2.0

package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/google/cel-go/cel"
	"github.com/google/cel-go/common/types"
	"github.com/olekukonko/tablewriter"
	"gopkg.in/yaml.v3"
	admissionv1 "k8s.io/api/admission/v1"
	admissionregistrationv1beta1 "k8s.io/api/admissionregistration/v1beta1"
	authenticationv1 "k8s.io/api/authentication/v1"
)

// TestSuite represents the structure of a test suite YAML file
type TestSuite struct {
	Policy struct {
		File string `yaml:"file"`
		Name string `yaml:"name"`
	} `yaml:"policy"`
	Tests []TestCase `yaml:"tests"`
}

// TestCase represents a single test case
type TestCase struct {
	Request string `yaml:"request"`
	User    string `yaml:"user"`
	Expect  string `yaml:"expect"`
}

// TestResult represents the result of running a test case
type TestResult struct {
	Result  string
	Request string
	User    string
	Expect  string
	Got     string
	Message string
}

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintf(os.Stderr, "Usage: %s <test-directory>\n", os.Args[0])
		os.Exit(1)
	}

	testDir := os.Args[1]

	// Find all .yaml test suite files
	testFiles, err := filepath.Glob(filepath.Join(testDir, "*.yaml"))
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error finding test files: %v\n", err)
		os.Exit(1)
	}

	allPassed := true

	for i, testFile := range testFiles {
		if i > 0 {
			fmt.Println("\n---\n")
		}

		passed := runTestSuite(testFile, testDir)
		if !passed {
			allPassed = false
		}
	}

	fmt.Println("\n" + strings.Repeat("-", 80))
	fmt.Println()
	if allPassed {
		fmt.Println("RESULTS: PASSED")
	} else {
		fmt.Println("RESULTS: FAILED")
	}
}

func runTestSuite(testFile, baseDir string) bool {
	// Load test suite
	suite, err := loadTestSuite(testFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error loading test suite %s: %v\n", testFile, err)
		return false
	}

	fmt.Printf("Test Suite: %s\n", filepath.Base(testFile))
	fmt.Printf("* Policy File: %s\n", suite.Policy.File)
	fmt.Printf("* Policy Name: %s\n", suite.Policy.Name)

	// Load policy
	policyPath := filepath.Join(baseDir, suite.Policy.File)
	policy, err := loadPolicy(policyPath, suite.Policy.Name)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error loading policy: %v\n", err)
		return false
	}

	results := []TestResult{}

	// Run each test case
	for _, testCase := range suite.Tests {
		result := runTestCase(testCase, policy, baseDir)
		results = append(results, result)
	}

	// Print results table
	printResultsTable(results)

	// Count passed/failed
	passed := 0
	for _, result := range results {
		if result.Result == "SUCCESS" {
			passed++
		}
	}

	total := len(results)
	if passed == total {
		fmt.Printf("SUCCESS (%d/%d passed)\n", passed, total)
		return true
	} else {
		fmt.Printf("FAILED (%d/%d passed)\n", passed, total)
		return false
	}
}

func loadTestSuite(filename string) (*TestSuite, error) {
	data, err := os.ReadFile(filename)
	if err != nil {
		return nil, err
	}

	var suite TestSuite
	err = yaml.Unmarshal(data, &suite)
	if err != nil {
		return nil, err
	}

	return &suite, nil
}

func loadPolicy(filename, policyName string) (*admissionregistrationv1beta1.ValidatingAdmissionPolicy, error) {
	data, err := os.ReadFile(filename)
	if err != nil {
		return nil, err
	}

	// Parse YAML documents
	decoder := yaml.NewDecoder(strings.NewReader(string(data)))

	for {
		var doc map[string]interface{}
		err := decoder.Decode(&doc)
		if err != nil {
			break
		}

		if doc["kind"] == "ValidatingAdmissionPolicy" {
			if metadata, ok := doc["metadata"].(map[string]interface{}); ok {
				if name, ok := metadata["name"].(string); ok && name == policyName {
					// Convert back to YAML and unmarshal into proper struct
					policyYAML, err := yaml.Marshal(doc)
					if err != nil {
						return nil, err
					}

					var policy admissionregistrationv1beta1.ValidatingAdmissionPolicy
					err = yaml.Unmarshal(policyYAML, &policy)
					if err != nil {
						return nil, err
					}

					return &policy, nil
				}
			}
		}
	}

	return nil, fmt.Errorf("policy %s not found in %s", policyName, filename)
}

func runTestCase(testCase TestCase, policy *admissionregistrationv1beta1.ValidatingAdmissionPolicy, baseDir string) TestResult {
	result := TestResult{
		Request: testCase.Request,
		User:    testCase.User,
		Expect:  testCase.Expect,
	}

	// Load request
	requestPath := filepath.Join(baseDir, "requests", testCase.Request+".yaml")
	admissionReview, err := loadAdmissionReview(requestPath)
	if err != nil {
		result.Result = "ERROR"
		result.Message = fmt.Sprintf("Failed to load request: %v", err)
		return result
	}

	// Load user
	userPath := filepath.Join(baseDir, "users", testCase.User+".yaml")
	userInfo, err := loadUserInfo(userPath)
	if err != nil {
		result.Result = "ERROR"
		result.Message = fmt.Sprintf("Failed to load user: %v", err)
		return result
	}

	// Evaluate CEL expressions
	passed, err := evaluatePolicy(policy, admissionReview, userInfo)
	if err != nil {
		result.Result = "ERROR"
		result.Message = fmt.Sprintf("CEL evaluation error: %v", err)
		return result
	}

	if passed {
		result.Got = "Pass"
	} else {
		result.Got = "Fail"
	}

	if result.Got == result.Expect {
		result.Result = "SUCCESS"
	} else {
		result.Result = "FAILED"
	}

	return result
}

func loadAdmissionReview(filename string) (*admissionv1.AdmissionReview, error) {
	data, err := os.ReadFile(filename)
	if err != nil {
		return nil, err
	}

	// First parse as generic map to extract object data
	var rawData map[string]interface{}
	err = yaml.Unmarshal(data, &rawData)
	if err != nil {
		return nil, fmt.Errorf("invalid YAML in %s: %v", filename, err)
	}

	var admissionReview admissionv1.AdmissionReview
	err = yaml.Unmarshal(data, &admissionReview)
	if err != nil {
		return nil, fmt.Errorf("invalid AdmissionReview YAML in %s: %v", filename, err)
	}

	// Validate required fields - Note: APIVersion and Kind are handled by TypeMeta embedding
	if admissionReview.Request == nil {
		return nil, fmt.Errorf("AdmissionReview in %s missing required 'request' field", filename)
	}

	// Extract object and oldObject from raw YAML for CEL evaluation
	if request, ok := rawData["request"].(map[string]interface{}); ok {
		if object, ok := request["object"]; ok {
			objectBytes, _ := yaml.Marshal(object)
			admissionReview.Request.Object.Raw = objectBytes
		}
		if oldObject, ok := request["oldObject"]; ok {
			oldObjectBytes, _ := yaml.Marshal(oldObject)
			admissionReview.Request.OldObject.Raw = oldObjectBytes
		}
	}

	return &admissionReview, nil
}

func loadUserInfo(filename string) (*authenticationv1.UserInfo, error) {
	data, err := os.ReadFile(filename)
	if err != nil {
		return nil, err
	}

	var wrapper struct {
		APIVersion string                    `yaml:"apiVersion"`
		Kind       string                    `yaml:"kind"`
		Spec       authenticationv1.UserInfo `yaml:"spec"`
	}
	err = yaml.Unmarshal(data, &wrapper)
	if err != nil {
		return nil, fmt.Errorf("invalid UserInfo YAML in %s: %v", filename, err)
	}

	// Validate required fields
	if wrapper.APIVersion == "" {
		return nil, fmt.Errorf("UserInfo in %s missing required 'apiVersion' field", filename)
	}

	if wrapper.Kind == "" {
		return nil, fmt.Errorf("UserInfo in %s missing required 'kind' field", filename)
	}

	if wrapper.Spec.Username == "" {
		return nil, fmt.Errorf("UserInfo in %s missing required 'spec.username' field", filename)
	}

	return &wrapper.Spec, nil
}

func evaluatePolicy(policy *admissionregistrationv1beta1.ValidatingAdmissionPolicy, admissionReview *admissionv1.AdmissionReview, userInfo *authenticationv1.UserInfo) (bool, error) {
	if len(policy.Spec.Validations) == 0 {
		return true, nil // No validations means pass
	}

	// Merge UserInfo into AdmissionReview request
	if admissionReview.Request.UserInfo.Username == "" {
		admissionReview.Request.UserInfo.Username = userInfo.Username
		admissionReview.Request.UserInfo.Groups = userInfo.Groups
		admissionReview.Request.UserInfo.Extra = userInfo.Extra
	}

	// Create CEL environment with standard ValidatingAdmissionPolicy variables
	env, err := cel.NewEnv(
		cel.Variable("request", cel.DynType),
		cel.Variable("userInfo", cel.DynType),
		cel.Variable("object", cel.DynType),
		cel.Variable("oldObject", cel.DynType),
	)
	if err != nil {
		return false, err
	}

	// Prepare variables for CEL evaluation
	requestMap := map[string]interface{}{
		"namespace": admissionReview.Request.Namespace,
		"operation": string(admissionReview.Request.Operation),
		"object":    admissionReview.Request.Object,
		"userInfo": map[string]interface{}{
			"username": admissionReview.Request.UserInfo.Username,
			"groups":   admissionReview.Request.UserInfo.Groups,
			"extra":    admissionReview.Request.UserInfo.Extra,
		},
	}

	userInfoMap := map[string]interface{}{
		"username": userInfo.Username,
		"groups":   userInfo.Groups,
		"extra":    userInfo.Extra,
	}

	// Convert RawExtension objects to maps for CEL
	var objectMap interface{}
	if len(admissionReview.Request.Object.Raw) > 0 {
		err := yaml.Unmarshal(admissionReview.Request.Object.Raw, &objectMap)
		if err != nil {
			return false, fmt.Errorf("failed to unmarshal object: %v", err)
		}
	}

	var oldObjectMap interface{}
	if len(admissionReview.Request.OldObject.Raw) > 0 {
		err := yaml.Unmarshal(admissionReview.Request.OldObject.Raw, &oldObjectMap)
		if err != nil {
			return false, fmt.Errorf("failed to unmarshal oldObject: %v", err)
		}
	}

	vars := map[string]interface{}{
		"request":   requestMap,
		"userInfo":  userInfoMap,
		"object":    objectMap,
		"oldObject": oldObjectMap,
	}

	// Evaluate each validation - all must pass
	for _, validation := range policy.Spec.Validations {
		ast, issues := env.Compile(validation.Expression)
		if issues != nil && issues.Err() != nil {
			return false, fmt.Errorf("CEL compilation error: %v", issues.Err())
		}

		program, err := env.Program(ast)
		if err != nil {
			return false, fmt.Errorf("CEL program creation error: %v", err)
		}

		result, _, err := program.Eval(vars)
		if err != nil {
			return false, fmt.Errorf("CEL evaluation error: %v", err)
		}

		if result != types.True {
			return false, nil // Validation failed
		}
	}

	return true, nil // All validations passed
}

func printResultsTable(results []TestResult) {
	table := tablewriter.NewWriter(os.Stdout)
	table.SetHeader([]string{"Result", "Request", "User", "Expect", "Got", "Message"})

	for _, result := range results {
		table.Append([]string{
			result.Result,
			result.Request,
			result.User,
			result.Expect,
			result.Got,
			result.Message,
		})
	}

	table.Render()
}
