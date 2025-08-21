# Justfile for pikin project
# Commands for managing AWS infrastructure and Lambda deployment
set dotenv-load

# Variables
namespace := "default"
context := "docker-desktop"

# Default target
default:
    @just --list

# Build the Go binary for Lambda
build:
    cd src && GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -ldflags="-s -w" -o bootstrap main.go

# Clean build artifacts
clean:
    rm -f src/bootstrap lambda.zip

# Package the Lambda function
package: build
    cd src && zip ../lambda.zip bootstrap

# Test the function locally
test:
    cd src && go test -v

# Run the function locally for development
local-test:
    cd src && go run main.go

# Install dependencies
deps:
    go mod download
    go mod tidy

# Format code
fmt:
    go fmt ./...

# Check if docker is installed
_check-docker:
    #!/usr/bin/env bash
    if ! command -v docker &> /dev/null; then
        echo "Error: docker is not installed. Please install docker first."
        exit 1
    fi

# Check if kubectl is installed
_check-kubectl:
    #!/usr/bin/env bash
    if ! command -v kubectl &> /dev/null; then
        echo "Error: kubectl is not installed. Please install kubectl first."
        echo "refer to .tool-versions or visit: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi

_with-context: _check-kubectl
    #!/usr/bin/env bash
    if ! kubectl config get-contexts {{context}} &> /dev/null; then
        echo "Error: context {{context}} is not found. Please check your kubeconfig file."
        exit 1
    fi
    
    if ! kubectl config use-context {{context}}; then
        echo "Error: Failed to switch to context {{context}}"
        exit 1
    fi
    
_check-namespace: _with-context
    #!/usr/bin/env bash
    if ! kubectl get namespace {{namespace}} &> /dev/null; then
        echo "Warning: namespace {{namespace}} does not exist. Creating it..."
        if ! kubectl create namespace {{namespace}}; then
            echo "Error: Failed to create namespace {{namespace}}"
            exit 1
        fi
    fi

# Check if tilt is installed
_check-tilt: _check-docker _with-context _check-namespace
    #!/usr/bin/env bash
    if ! command -v tilt &> /dev/null; then
        echo "Error: tilt is not installed. Please install tilt first."
        echo "Visit: https://docs.tilt.dev/install.html"
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        echo "Error: helm is not installed. Please install helm first."
        echo "Visit: https://helm.sh/docs/intro/install/"
        exit 1
    fi

# Validates required environment variables and get AWS region
_check-env:
    #!/usr/bin/env bash
    missing_vars=()
    
    for var in PROJECT_NAME TERRAFORM_STATE_BUCKET AWS_REGION; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo "❌ Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            echo "   - $var"
        done
        echo ""
        echo "Please ensure these variables are set in your environment."
        echo "👀 Create a .env file from env.example: cp .env.example .env"
        echo "  NOTE: override defaults as desired"
        exit 1
    fi

# Check if required tools are installed and authenticated
_check-terraform:
    #!/usr/bin/env bash
    if ! command -v terraform &> /dev/null; then
        echo "❌ Terraform is not installed. Please install it first."
        echo "   Visit: https://developer.hashicorp.com/terraform/downloads"
        echo "   Or run: asdf plugin add terraform && asdf install terraform"
        exit 1
    fi
    echo "✅ Terraform is installed"

_check-aws-cli:
    #!/usr/bin/env bash
    if ! command -v aws &> /dev/null; then
        echo "❌ AWS CLI is not installed. Please install it first."
        echo "   Visit: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        echo "   Or run: asdf plugin add awscli && asdf install awscli"
        exit 1
    fi
    
    # Check if AWS CLI is configured and authenticated
    if ! aws sts get-caller-identity &> /dev/null; then
        echo "❌ AWS CLI is not authenticated. Please configure your credentials first."
        echo "   Run: aws configure"
        echo "   Or set environment variables: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY"
        echo "   MORE THAN LIKELY YOU CAN DO THIS:"
        echo "   1. Go to AWS Console → IAM → Users"
        echo "     set username: aws-cli-user (or your preference)"
        echo "     leave 'Provide user access to the AWS Management Console' unchecked"
        echo "     click 'Next'"
        echo "   2. Set permissions"
        echo "     click 'Attach policies directly'"
        echo "     attach required perms (or go the less safe route of using 'AdministratorAccess')"
        echo "     click 'Next'"
        echo "   3. Review and create user"
        echo "     click 'Create user'"
        echo "   4. Download credentials"
        echo "     click 'Download .csv...' and/or copy Access Key ID and Secret Access Key"
        echo "   5. Run 'aws configure' and paste the Access key ID and Secret Access Key"
        exit 1
    fi
    
    # Get and display current identity for verification
    ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null)
    USER_ARN=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null)
    echo "✅ AWS CLI is installed and authenticated"
    echo "   Account: $ACCOUNT_ID"
    echo "   User: $USER_ARN"

_check-gh:
    #!/usr/bin/env bash
    if ! command -v gh &> /dev/null; then
        echo "❌ GitHub CLI is not installed. Please install it first."
        echo "   Visit: https://cli.github.com/"
        exit 1
    fi
    
    # Check if GitHub CLI is authenticated
    if ! gh auth status &> /dev/null; then
        echo "❌ GitHub CLI is not authenticated. Please login first."
        echo "   Run: gh auth login"
        exit 1
    fi
    
    # Get and display current user for verification
    USER=$(gh api user --jq '.login' 2>/dev/null)
    echo "✅ GitHub CLI is installed and authenticated"
    echo "   User: $USER"

# Check if S3 backend bucket exists
_check-backend:
    #!/usr/bin/env bash
    if ! aws s3 ls "s3://$TERRAFORM_STATE_BUCKET" --region "$AWS_REGION" &> /dev/null; then
        echo "❌ S3 backend bucket '$TERRAFORM_STATE_BUCKET' does not exist."
        echo "   Please run 'just setup-backend' first to create the backend."
        exit 1
    fi
    echo "✅ S3 backend bucket '$TERRAFORM_STATE_BUCKET' exists"

# Prepares repository for development
@prepare:
    echo "✅ no prep setup just yet"

# Complete project setup and deployment
# Sets up infrastructure, GitHub secrets, and deploys everything in the correct order
setup: _check-gh _check-aws-cli _check-terraform _check-env
    #!/usr/bin/env bash
    echo "🚀 Complete project setup and deployment..."
    echo ""
    echo "Getting GitHub information..."
    GITHUB_OWNER=$(gh api user --jq '.login')
    if [ -n "$REPOSITORY" ]; then
        REPO_NAME="$REPOSITORY"
    else
        REPO_NAME=$(gh repo view --json name --jq '.name')
    fi
    echo "GitHub Owner: $GITHUB_OWNER"
    echo "Repository: $REPO_NAME"
    echo ""
    echo "Step 1: Setting up Terraform S3 backend bucket..."
    cd terraform && ./setup-backend.sh "$PROJECT_NAME" "$AWS_REGION" "$TERRAFORM_STATE_BUCKET"
    echo ""
    echo "Step 2: Initializing Terraform (with -upgrade to ensure providers are current)..."
    terraform init -upgrade \
        -backend-config="bucket=$TERRAFORM_STATE_BUCKET" \
        -backend-config="region=$AWS_REGION" \
        -backend-config="key=lambda/terraform.tfstate"
    echo ""
    echo "Step 3: Refreshing state to detect existing resources..."
    if ! terraform plan -refresh-only \
        -var="project_name=$PROJECT_NAME" \
        -var="aws_region=$AWS_REGION" \
        -var="lambda_timeout=${LAMBDA_TIMEOUT:-30}" \
        -var="lambda_memory_size=${LAMBDA_MEMORY_SIZE:-128}" \
        -var="cloudwatch_log_retention=${CLOUDWATCH_LOG_RETENTION:-7}" \
        -var="owner=${GITHUB_OWNER}" \
        -var="repository=${REPO_NAME}"; then
        echo ""
        echo "❌ Terraform refresh failed. Please check the error above and resolve before continuing."
        exit 1
    fi
    echo ""
    echo "Step 4: Planning infrastructure deployment..."
    if ! terraform plan \
        -var="project_name=$PROJECT_NAME" \
        -var="aws_region=$AWS_REGION" \
        -var="lambda_timeout=${LAMBDA_TIMEOUT:-30}" \
        -var="lambda_memory_size=${LAMBDA_MEMORY_SIZE:-128}" \
        -var="cloudwatch_log_retention=${CLOUDWATCH_LOG_RETENTION:-7}" \
        -var="owner=${GITHUB_OWNER}" \
        -var="repository=${REPO_NAME}" \
        -out=tfplan; then
        echo ""
        echo "❌ Terraform plan failed. Please check the error above and resolve before continuing."
        echo "   Common issues:"
        echo "   • IAM policies with duplicate names already exist"
        echo "   • Resources already exist outside of Terraform management"
        echo "   • Insufficient AWS permissions"
        exit 1
    fi
    echo ""
    echo "Step 5: Deploying infrastructure..."
    if ! terraform apply -auto-approve tfplan; then
        echo ""
        echo "❌ Terraform deployment failed. Please check the error above and resolve before continuing."
        exit 1
    fi
    echo ""
    echo "Step 6: Setting up GitHub secrets..."
    cd ..
    echo "Getting AWS account information..."
    ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
    USER_ARN=$(aws sts get-caller-identity --query 'Arn' --output text)
    echo "AWS Account ID: $ACCOUNT_ID"
    echo "User ARN: $USER_ARN"
    echo "AWS Region: $AWS_REGION"
    echo ""
    echo "Setting up Lambda function configuration..."
    gh variable set AWS_LAMBDA_FUNCTION_NAME --body "$PROJECT_NAME-lambda"
    gh variable set AWS_LAMBDA_REGION --body "$AWS_REGION"
    echo "✅ Basic GitHub variables configured successfully!"
    echo ""
    echo "Step 7: Setting up Lambda execution role secret from AWS..."
    ROLE_NAME="$PROJECT_NAME-lambda-execution"
    if aws iam get-role --role-name "$ROLE_NAME" &> /dev/null; then \
        ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text); \
        gh variable set AWS_LAMBDA_EXECUTION_ROLE_ARN --body "$ROLE_ARN"; \
        echo "✅ Lambda execution role ARN variable configured: $ROLE_ARN"; \
    else \
        echo "❌ Lambda execution role '$ROLE_NAME' not found"; \
        echo "This should not happen after running infrastructure deployment"; \
        exit 1; \
    fi
    echo ""
    echo "Step 8: Setting up GitHub Actions AWS credentials..."
    cd terraform
    ACCESS_KEY_ID=$(terraform output -raw github_actions_access_key_id)
    SECRET_ACCESS_KEY=$(terraform output -raw github_actions_secret_access_key)
    cd ..
    if [ -n "$ACCESS_KEY_ID" ] && [ -n "$SECRET_ACCESS_KEY" ]; then \
        gh secret set AWS_ACCESS_KEY_ID --body "$ACCESS_KEY_ID"; \
        gh secret set AWS_SECRET_ACCESS_KEY --body "$SECRET_ACCESS_KEY"; \
        echo "✅ GitHub Actions AWS credentials configured successfully"; \
        echo "   Access Key ID: $ACCESS_KEY_ID"; \
        echo "   Secret Access Key: [HIDDEN]"; \
    else \
        echo "❌ Failed to get GitHub Actions AWS credentials from Terraform"; \
        echo "Please check that the infrastructure was deployed successfully"; \
        exit 1; \
    fi
    echo ""
    echo "✅ All required GitHub secrets are now configured:"
    echo "   - AWS_ACCESS_KEY_ID (for GitHub Actions)"
    echo "   - AWS_SECRET_ACCESS_KEY (for GitHub Actions)"
    echo "   - AWS_LAMBDA_FUNCTION_NAME"
    echo "   - AWS_LAMBDA_REGION"
    echo "   - AWS_LAMBDA_EXECUTION_ROLE_ARN"
    echo ""
    echo "🎉 Project setup complete! Your repository is ready for CI/CD deployment."
    echo "Push your code to trigger the first deployment:"
    echo "  git push origin main"

# Open AWS Console for Lambda function monitoring
# Opens the AWS console in your browser for viewing logs, metrics, and configuration
console: _check-aws-cli _check-env
    echo "🌐 Opening AWS Console for Lambda function..."
    FUNCTION_NAME="$PROJECT_NAME-lambda"
    echo "Function: $FUNCTION_NAME"
    echo "Region: $AWS_REGION"
    echo ""
    echo "Opening AWS Console..."
    open "https://$AWS_REGION.console.aws.amazon.com/lambda/home?region=$AWS_REGION#/functions/$FUNCTION_NAME"
    echo "💡 You can view logs, metrics, and configuration in the AWS Console"

# Start Tilt for local development
# Brings up Tilt with verbose logging for debugging and development
@start: _check-tilt
    echo "🚀 Starting Tilt for local development..."
    echo "💬 Using verbose logging (-vvv) for detailed output"
    echo ""
    echo "👀 Tilt will start the development environment and open the UI in your browser."
    echo "👋 Press Ctrl+C to stop Tilt when you're done."
    echo ""
    tilt up -vvv

@stop: _check-tilt
    echo "🙊🙈🙉 Stopping Tilt...👋👋👋"
    tilt down

# Complete project teardown and cleanup
teardown: _check-gh _check-aws-cli _check-terraform _check-env
    #!/usr/bin/env bash
    echo "🧹 Complete project teardown and cleanup..."
    echo ""
    echo "⚠️  WARNING: This will destroy ALL infrastructure and remove GitHub secrets!"
    echo "   - All AWS resources managed by Terraform"
    echo "   - All GitHub repository secrets"
    echo ""
    read -p "Are you sure you want to proceed? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "❌ Teardown cancelled"
        exit 0
    fi
    echo ""
    cd terraform
    if [ ! -d ".terraform" ]; then
        echo "ℹ️  No .terraform directory found - this appears to be a fresh repository clone"
        echo "   If infrastructure was deployed from another location, you'll need to run"
        echo "   teardown from that location, or manually initialize Terraform here first."
        echo ""
        echo "Skipping infrastructure destruction and proceeding with GitHub secrets cleanup..."
        cd ..
    else
        echo "Step 1: Checking current Terraform state..."
        EXISTING_RESOURCES=$(terraform state list 2>/dev/null | wc -l)
        if [ "$EXISTING_RESOURCES" -eq 0 ]; then
            echo "✅ No resources found in Terraform state - infrastructure already clean"
            cd ..
        else
            echo "📋 Found $EXISTING_RESOURCES resources in state:"
            terraform state list
            echo ""
            echo "Step 2: Destroying Terraform infrastructure..."
            if ! terraform destroy -auto-approve \
                -var="project_name=$PROJECT_NAME" \
                -var="aws_region=$AWS_REGION" \
                -var="lambda_timeout=${LAMBDA_TIMEOUT:-30}" \
                -var="lambda_memory_size=${LAMBDA_MEMORY_SIZE:-128}" \
                -var="cloudwatch_log_retention=${CLOUDWATCH_LOG_RETENTION:-7}" \
                -var="owner=$(gh api user --jq '.login')" \
                -var="repository=$(gh repo view --json name --jq '.name')"; then
                echo "❌ Terraform destroy failed"
                cd ..
                exit 1
            fi
            echo ""
            echo "Step 3: Verifying infrastructure removal..."
            REMAINING_RESOURCES=$(terraform state list 2>/dev/null | wc -l)
            if [ "$REMAINING_RESOURCES" -gt 0 ]; then
                echo "❌ $REMAINING_RESOURCES resources still in Terraform state:"
                terraform state list
                cd ..
                exit 1
            else
                echo "✅ Terraform state is clean - all resources removed"
            fi
            cd ..
        fi
    fi
    echo ""
    echo "Step 4: Removing GitHub secrets..."
    
    # Define all secrets and variables to check and remove (portable array syntax)
    aws_secrets="AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY"
    lambda_variables="AWS_LAMBDA_FUNCTION_NAME AWS_LAMBDA_REGION AWS_LAMBDA_EXECUTION_ROLE_ARN"
    
    echo "Checking and removing AWS credentials..."
    for secret in $aws_secrets; do
        if gh secret list | grep -q "$secret"; then
            gh secret delete "$secret"
            echo "   ✅ $secret secret removed"
        else
            echo "   ℹ️  $secret secret not found (already removed or never existed)"
        fi
    done
    
    echo "Checking and removing Lambda configuration..."
    for variable in $lambda_variables; do
        if gh variable list | grep -q "$variable"; then
            gh variable delete "$variable"
            echo "   ✅ $variable variable removed"
        else
            echo "   ℹ️  $variable variable not found (already removed or never existed)"
        fi
    done
    
    echo "✅ GitHub secrets cleanup completed"
    echo ""
    echo "🎉 Project teardown complete!"
    echo "   ✅ Infrastructure destruction completed (or skipped if not deployed from here)"
    echo "   ✅ All GitHub secrets have been cleaned up"
    echo ""
    echo "Your GitHub repository secrets are now clean."
    echo "If infrastructure exists in AWS, ensure you run teardown from the deployment location."
