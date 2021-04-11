package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/awserr"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/codebuild"
	"github.com/aws/aws-sdk-go/service/codecommit"
	"github.com/aws/aws-sdk-go/service/codepipeline"
	"github.com/aws/aws-sdk-go/service/s3"
)

const releaseProdTagPrefix = "prod-release"

// CodeCommitEventDetail used to store data from different CodeCommit event types
type CodeCommitEventDetail struct {
	Event             string   `json:"event"`
	RepositoryName    string   `json:"repositoryName"`
	RepositoryID      string   `json:"repositoryId"`
	ReferenceType     string   `json:"referenceType"`
	ReferenceName     string   `json:"referenceName"`
	RepositoryNames   []string `json:"repositoryNames"`
	ReferenceFullName string   `json:"referenceFullName"`
	CommitID          string   `json:"commitId"`
	SourceReference   string   `json:"sourceReference"`
	PullRequestID     string   `json:"pullRequestId"`
	SourceCommit      string   `json:"sourceCommit"`
	DestinationCommit string   `jsong:"destinationCommit"`
}

type CodePipelineEventDetail struct {
	Pipeline    string `json:"pipeline"`
	ExecutionID string `json:"execution-id"`
	State       string `json:"state"`
}

type TriggerData struct {
	Pipeline      string
	Repository    string
	Branch        string
	PullRequestID string
}

type PRStateData struct {
	Bucket        string
	ExecID        string
	Repository    string
	PullRequestID string
}

func after(value string, a string) string {
	// Get substring after a string.
	pos := strings.LastIndex(value, a)
	if pos == -1 {
		return ""
	}
	adjustedPos := pos + len(a)
	if adjustedPos >= len(value) {
		return ""
	}
	return value[adjustedPos:len(value)]
}

func retrievePRExec(data PRStateData) (PRStateData, error) {
	mySession := session.Must(session.NewSession())

	// Create S3 client from session
	svc := s3.New(mySession)

	out, err := svc.ListObjectsV2(&s3.ListObjectsV2Input{
		Bucket: aws.String(data.Bucket),
		Prefix: aws.String(data.ExecID),
	})

	if err != nil {
		return PRStateData{}, err
	}

	log.Printf("Retrieved store contents for PR with id: %s", data.ExecID)

	result := PRStateData{
		Bucket: data.Bucket,
		ExecID: data.ExecID,
	}

	for _, c := range out.Contents {
		key := c.Key
		p := strings.Split(*key, "/")

		result.Repository = p[1]
		result.PullRequestID = p[2]

		log.Printf("Returning result: %s", result)
	}

	return result, nil
}

func storePRExec(data PRStateData, session *session.Session) error {
	// Create S3 client from session
	svc := s3.New(session)

	key := fmt.Sprintf("%s/%s/%s", data.ExecID, data.Repository, data.PullRequestID)

	_, err := svc.PutObject(&s3.PutObjectInput{
		Bucket: &data.Bucket,
		Key:    &key,
	})

	if err != nil {
		return err
	}

	return nil
}

// validate triggers Codepipeline PR validation pipeline
func pushToValidate(data TriggerData, session *session.Session) (string, error) {
	// Create CodePipeline client from session.
	svc := codepipeline.New(session)

	// Update pipeline source branch to point to target branch
	pipelinesOut, err := svc.GetPipeline(&codepipeline.GetPipelineInput{
		Name: &data.Pipeline,
	})

	if err != nil {
		if awsErr, ok := err.(awserr.Error); ok {
			switch awsErr.Code() {
			case codepipeline.ErrCodePipelineNotFoundException:
				return "", nil
			}
		}
		return "", err
	}

	pipeline := pipelinesOut.Pipeline
	for _, s := range pipeline.Stages {
		for _, a := range s.Actions {

			repoName := data.Repository
			if !strings.HasSuffix(repoName, "-repo") {
				repoName = fmt.Sprintf("%s-repo", repoName)
			}

			if *a.Name == repoName {
				// Extract branch name
				branchName := strings.Split(data.Branch, "/")

				a.SetConfiguration(map[string]*string{
					"RepositoryName": &data.Repository,
					"BranchName":     &branchName[len(branchName)-1],
				})
			}
		}
	}

	_, err = svc.UpdatePipeline(&codepipeline.UpdatePipelineInput{
		Pipeline: pipeline,
	})

	if err != nil {
		return "", err
	}

	log.Printf("Triggering pipeline %s for branch %s", data.Repository, data.Branch)

	out, err := svc.StartPipelineExecution(&codepipeline.StartPipelineExecutionInput{
		Name: &data.Pipeline,
	})

	if err != nil {
		return "", err
	}

	return *out.PipelineExecutionId, nil
}

func handler(event events.CloudWatchEvent) (string, error) {
	mySession := session.Must(session.NewSession())
	log.Printf("%s", event)
	store := os.Getenv("STORE_BUCKET")

	// Check if event is Pull request event
	switch event.DetailType {
	case "CodeCommit Pull Request State Change":
		// Unmarshal CodeCommit event
		var detail CodeCommitEventDetail
		err := json.Unmarshal([]byte(event.Detail), &detail)
		if err != nil {
			errMsg := fmt.Sprintf("Failed to unmarshal CodeCommit Event message")
			return errMsg, err
		}

		log.Printf("Unmarshalled CodeCommit event details: %s", detail)
		pipelineName := fmt.Sprintf("%s-pr-review", detail.RepositoryNames[0])

		switch detail.Event {
		case "pullRequestCreated":
			execID, err := pushToValidate(TriggerData{
				Pipeline:      pipelineName,
				Repository:    detail.RepositoryNames[0],
				Branch:        detail.SourceReference,
				PullRequestID: detail.PullRequestID,
			}, mySession)
			if err != nil {
				errMsg := fmt.Sprintf("Failed to trigger a pipelines for PR %s for repository %s. Aborting...", detail.PullRequestID, detail.RepositoryNames[0])
				return errMsg, err
			}

			if execID != "" {
				// Store PR ID for future reference
				err = storePRExec(PRStateData{
					Repository:    detail.RepositoryNames[0],
					ExecID:        execID,
					PullRequestID: detail.PullRequestID,
					Bucket:        store,
				}, mySession)

				if err != nil {
					return err.Error(), err
				}

				// Generate pipeline/execution URL, which is posted as PR comment
				pipelineURL := fmt.Sprintf("https://us-west-2.console.aws.amazon.com/codesuite/codepipeline/pipelines/%s/view?region=us-west-2", pipelineName)
				execURL := fmt.Sprintf("https://us-west-2.console.aws.amazon.com/codesuite/codepipeline/pipelines/%s/executions/%s/timeline?region=us-west-2", pipelineName, execID)
				// Creade CodeCommit client from session
				cc := codecommit.New(mySession)
				commentContent := fmt.Sprintf("PR review pipeline triggered with ID: [%s](%s). You can find build details [here](%s)", execID, execURL, pipelineURL)

				// Update PR with a build status
				_, err = cc.PostCommentForPullRequest(&codecommit.PostCommentForPullRequestInput{
					PullRequestId:  &detail.PullRequestID,
					RepositoryName: &detail.RepositoryNames[0],
					Content:        &commentContent,
					BeforeCommitId: &detail.DestinationCommit,
					AfterCommitId:  &detail.SourceCommit,
				})
				if err != nil {
					errMsg := fmt.Sprintf("Failed to post badge status comment in PR %s for repository %s. Aborting...", detail.PullRequestID, detail.RepositoryName)
					return errMsg, err
				}
			}

		case "pullRequestSourceBranchUpdated":
			execID, err := pushToValidate(TriggerData{
				Pipeline:      pipelineName,
				Repository:    detail.RepositoryNames[0],
				Branch:        detail.SourceReference,
				PullRequestID: detail.PullRequestID,
			}, mySession)
			if err != nil {
				errMsg := fmt.Sprintf("Failed to trigger a pipelines for PR %s for repository %s. Aborting...", detail.PullRequestID, detail.RepositoryNames[0])
				return errMsg, err
			}

			if execID != "" {
				// Store PR ID for future reference
				err = storePRExec(PRStateData{
					Repository:    detail.RepositoryNames[0],
					ExecID:        execID,
					PullRequestID: detail.PullRequestID,
					Bucket:        store,
				}, mySession)

				if err != nil {
					return err.Error(), err
				}

				// Generate pipeline/execution URL, which is posted as PR comment
				pipelineURL := fmt.Sprintf("https://us-west-2.console.aws.amazon.com/codesuite/codepipeline/pipelines/%s/view?region=us-west-2", pipelineName)
				execURL := fmt.Sprintf("https://us-west-2.console.aws.amazon.com/codesuite/codepipeline/pipelines/%s/executions/%s/timeline?region=us-west-2", pipelineName, execID)
				// Creade CodeCommit client from session
				cc := codecommit.New(mySession)
				commentContent := fmt.Sprintf("PR review pipeline triggered with ID: [%s](%s). You can find build details [here](%s)", execID, execURL, pipelineURL)

				// Update PR with a build status
				_, err = cc.PostCommentForPullRequest(&codecommit.PostCommentForPullRequestInput{
					PullRequestId:  &detail.PullRequestID,
					RepositoryName: &detail.RepositoryNames[0],
					Content:        &commentContent,
					BeforeCommitId: &detail.DestinationCommit,
					AfterCommitId:  &detail.SourceCommit,
				})
				if err != nil {
					errMsg := fmt.Sprintf("Failed to post badge status comment in PR %s for repository %s. Aborting...", detail.PullRequestID, detail.RepositoryName)
					return errMsg, err
				}
			}
		}
	// Handle CodePipeline events
	case "CodePipeline Pipeline Execution State Change":
		// Unmarshal CodeCommit event
		var detail CodePipelineEventDetail
		err := json.Unmarshal([]byte(event.Detail), &detail)
		if err != nil {
			errMsg := fmt.Sprintf("Failed to unmarshal Codepipeline Event message")
			return errMsg, err
		}

		log.Printf("Unmarshalled Codepipeline event details: %s", detail)

		if strings.Contains(detail.Pipeline, "-pr-review") {
			switch detail.State {
			case "STARTED":
				// Get PR ID and repository name for s3
				data, err := retrievePRExec(PRStateData{
					Bucket: store,
					ExecID: detail.ExecutionID,
				})

				log.Printf("State data: %s", data)

				if err != nil {
					return err.Error(), err
				}

				// Creade CodeCommit client from session
				cc := codecommit.New(mySession)

				approvalState := "REVOKE"
				prDetail, err := cc.GetPullRequest(&codecommit.GetPullRequestInput{
					PullRequestId: &data.PullRequestID,
				})

				if err != nil {
					return err.Error(), err
				}

				// Review PR
				_, err = cc.UpdatePullRequestApprovalState(&codecommit.UpdatePullRequestApprovalStateInput{
					ApprovalState: &approvalState,
					PullRequestId: &data.PullRequestID,
					RevisionId:    prDetail.PullRequest.RevisionId,
				})

				if err != nil {
					if aerr, ok := err.(awserr.Error); ok {
						switch aerr.Code() {
						case codebuild.ErrCodeInvalidInputException:
							fmt.Println(codebuild.ErrCodeInvalidInputException, aerr.Error())
						default:
							fmt.Println(aerr.Error())
						}
					} else {
						// Print the error, cast err to awserr.Error to get the Code and
						// Message from an error.
						fmt.Println(err.Error())
					}
					return err.Error(), err
				}
				log.Printf("Repository: %s. PR (ID: %s) was reviewed with %s status", data.Repository, data.PullRequestID, approvalState)

			case "SUCCEEDED":
				// Get PR ID and repository name for s3
				data, err := retrievePRExec(PRStateData{
					Bucket: store,
					ExecID: detail.ExecutionID,
				})

				log.Printf("State data: %s", data)

				if err != nil {
					return err.Error(), err
				}

				// Creade CodeCommit client from session
				cc := codecommit.New(mySession)

				approvalState := "APPROVE"
				prDetail, err := cc.GetPullRequest(&codecommit.GetPullRequestInput{
					PullRequestId: &data.PullRequestID,
				})

				if err != nil {
					return err.Error(), err
				}

				// Review PR
				_, err = cc.UpdatePullRequestApprovalState(&codecommit.UpdatePullRequestApprovalStateInput{
					ApprovalState: &approvalState,
					PullRequestId: &data.PullRequestID,
					RevisionId:    prDetail.PullRequest.RevisionId,
				})

				if err != nil {
					if aerr, ok := err.(awserr.Error); ok {
						switch aerr.Code() {
						case codebuild.ErrCodeInvalidInputException:
							fmt.Println(codebuild.ErrCodeInvalidInputException, aerr.Error())
						default:
							fmt.Println(aerr.Error())
						}
					} else {
						// Print the error, cast err to awserr.Error to get the Code and
						// Message from an error.
						fmt.Println(err.Error())
					}
					return err.Error(), err
				}
				log.Printf("Repository: %s. PR (ID: %s) was reviewed with %s status", data.Repository, data.PullRequestID, approvalState)

			case "FAILED":
				// Get PR ID and repository name for s3
				data, err := retrievePRExec(PRStateData{
					Bucket: store,
					ExecID: detail.ExecutionID,
				})

				log.Printf("State data: %s", data)

				if err != nil {
					return err.Error(), err
				}

				// Creade CodeCommit client from session
				cc := codecommit.New(mySession)

				approvalState := "REVOKE"
				prDetail, err := cc.GetPullRequest(&codecommit.GetPullRequestInput{
					PullRequestId: &data.PullRequestID,
				})

				if err != nil {
					return err.Error(), err
				}

				// Review PR
				_, err = cc.UpdatePullRequestApprovalState(&codecommit.UpdatePullRequestApprovalStateInput{
					ApprovalState: &approvalState,
					PullRequestId: &data.PullRequestID,
					RevisionId:    prDetail.PullRequest.RevisionId,
				})

				if err != nil {
					if aerr, ok := err.(awserr.Error); ok {
						switch aerr.Code() {
						case codebuild.ErrCodeInvalidInputException:
							fmt.Println(codebuild.ErrCodeInvalidInputException, aerr.Error())
						default:
							fmt.Println(aerr.Error())
						}
					} else {
						// Print the error, cast err to awserr.Error to get the Code and
						// Message from an error.
						fmt.Println(err.Error())
					}
					return err.Error(), err
				}
				log.Printf("Repository: %s. PR (ID: %s) was reviewed with %s status", data.Repository, data.PullRequestID, approvalState)
			}
		}
	}

	return "Status: Success", nil
}

func main() {
	// Trigger Lambda function
	lambda.Start(handler)
}
