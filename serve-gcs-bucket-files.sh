# Author: Shrikrishna Khose
#!/bin/bash

# Script to set up Caddy on Cloud Run to serve a GCS bucket.

# --- Input Arguments ---
GCS_BUCKET_NAME="$1"
PROJECT_ID="$2"
REGION="us-central1"  # You can change this to your preferred region
SERVICE_ACCOUNT_NAME="caddy-gcs-sa"
REPOSITORY_NAME="caddy-repo"
SERVICE_NAME="serve-movies-service"
IMAGE_TAG="v1"
ARTIFACT_REGISTRY_HOST="${REGION}-docker.pkg.dev"
IMAGE_PATH="${ARTIFACT_REGISTRY_HOST}/${PROJECT_ID}/${REPOSITORY_NAME}/caddy-gcs:${IMAGE_TAG}"

# --- Usage ---
usage() {
    echo "Usage: $0 <GCS_BUCKET_NAME_NAME> <PROJECT_ID>"
    echo "  <GCS_BUCKET_NAME_NAME>: The name of your Google Cloud Storage bucket."
    echo "  <PROJECT_ID>: Your Google Cloud project ID."
    exit 1
}

# --- Input Validation ---
if [ -z "$GCS_BUCKET_NAME" ] || [ -z "$PROJECT_ID" ]; then
    usage
fi

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
  echo "Error: gcloud command not found. Please install the Google Cloud SDK."
  exit 1
fi

# # Check if Docker is installed
# if ! command -v docker &> /dev/null; then
#   echo "Error: docker command not found. Please install Docker."
#   exit 1
# fi

# --- Create Files (Caddyfile and Dockerfile) ---
# These are defined as heredocs for easy inclusion in the script

# Caddyfile
cat > Caddyfile <<EOF
:8080 {
    root * /mnt/${GCS_BUCKET_NAME}
    file_server
    encode gzip
    log {
        output file /tmp/caddy.log
    }
}
EOF

# Dockerfile
cat > Dockerfile <<EOF
FROM caddy:latest

COPY Caddyfile /etc/caddy/Caddyfile

EXPOSE 8080
EOF


# --- 1. Service Account Setup ---
echo "--- Setting up Service Account ---"
gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" \
  --project="$PROJECT_ID" \
  --description="Service account for Caddy on Cloud Run to access GCS" \
  --display-name="Caddy GCS Service Account" || true # ignore if already created

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"

# --- 2. Artifact Registry Setup ---
echo "--- Setting up Artifact Registry ---"
gcloud artifacts repositories create "$REPOSITORY_NAME" \
  --repository-format=docker \
  --location="$REGION" \
  --project="$PROJECT_ID" \
  --description="Docker repository for Caddy" || true  # Ignore error if already exists


# --- 3. Deploy to Cloud Run ---
echo "--- Deploying to Cloud Run ---"

gcloud run deploy "$SERVICE_NAME"  \
  --region="$REGION" \
  --project="$PROJECT_ID" \
  --allow-unauthenticated \
  --execution-environment gen2 \
  --service-account="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --add-volume=name=serve,type=cloud-storage,bucket=${GCS_BUCKET_NAME},readonly=true \
  --add-volume-mount volume=serve,mount-path=/mnt/${GCS_BUCKET_NAME} \
  --source .  

echo "--- Deployment Complete ---"
echo "Service URL:"
gcloud run services describe "$SERVICE_NAME" --region="$REGION" --project="$PROJECT_ID" --format='value(status.url)'

# --- Cleanup (Optional) ---
#  Leave the files (Dockerfile, Caddyfile) so the user can inspect and modify if needed.
# rm Dockerfile Caddyfile

echo "Done."