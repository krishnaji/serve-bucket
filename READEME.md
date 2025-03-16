
# Cloud Run for Serving GCS Bucket Static Files

**Author:** Shrikrishna Khose

This script automates the deployment of a Caddy web server on Google Cloud Run, configured to serve files directly from a Google Cloud Storage (GCS) bucket. It handles the setup of a service account, Artifact Registry, and the Cloud Run deployment.

## Prerequisites

1.  **Google Cloud Project:** You need an active Google Cloud project with billing enabled.
2.  **Google Cloud SDK (gcloud):**  Make sure the `gcloud` command-line tool is installed and configured. You can install it from [https://cloud.google.com/sdk/docs/install](https://cloud.google.com/sdk/docs/install).  After installation, authenticate with:
    ```bash
    gcloud auth login
    gcloud init  # Follow prompts to select/create a project
    ```
3. **GCS Bucket**: Ensure you have created GCS Bucket with data
4.  **Permissions:**  The user running this script needs sufficient permissions to:
    *   Create and manage service accounts.
    *   Grant IAM roles (Storage Object Viewer).
    *   Create Artifact Registry repositories.
    *   Deploy Cloud Run services.
    *   Mount GCS buckets to the Cloud Run instances.
    *   Typically, the "Project Owner" or "Project Editor" roles have these permissions.

## Script Overview

The script performs the following steps:

1.  **Input Validation:** Checks for the required GCS bucket name and Project ID.  Verifies that `gcloud` is installed.

2.  **File Creation:** Creates the `Caddyfile` and `Dockerfile` used for the deployment:
    *   **`Caddyfile`:** Configures Caddy to serve files from the specified GCS bucket mounted at `/mnt/<GCS_BUCKET_NAME>`.  It enables Gzip compression and basic logging.
    *   **`Dockerfile`:** Uses the official Caddy Docker image and copies the `Caddyfile` into the container.

3.  **Service Account Setup:**
    *   Creates a service account named `caddy-gcs-sa` (or uses it if it already exists).
    *   Grants the `roles/storage.objectViewer` role to the service account, allowing it to read objects from the GCS bucket.

4.  **Artifact Registry Setup:**
    *   Creates a Docker repository named `caddy-repo` in Artifact Registry (or uses it if it already exists).  This is where the Caddy Docker image will be stored.

5.  **Cloud Run Deployment:**
    *   Deploys a Cloud Run service named `serve-movies-service` using the source code in the current directory(`.`).
    *   Uses the `gen2` execution environment.
    *   Specifies the service account to be used.
    *   Uses `--allow-unauthenticated` for public access (see Security Considerations below).
    *   Mounts the GCS bucket as a volume to the container at `/mnt/<GCS_BUCKET_NAME>`, making the bucket's contents accessible to Caddy.
    *   Uses the current directory (`.`) as the source, which includes the `Caddyfile` and `Dockerfile`.
    *   Prints the URL of the deployed service.

6.  **Cleanup (Optional):** The script *does not* delete the `Dockerfile` and `Caddyfile` after deployment.  This allows you to inspect and modify them if needed.

## Usage

```bash
./serve-gcs-bucket-files <GCS_BUCKET_NAME> <PROJECT_ID>
```

*   **`<GCS_BUCKET_NAME>`:**  The name of your Google Cloud Storage bucket (e.g., `my-bucket`).
*   **`<PROJECT_ID>`:**  Your Google Cloud project ID.

**Example:**

```bash
./serve-gcs-bucket-files my-bucket my-gcp-project-12345
```

After the script completes successfully, it will output the URL of your Cloud Run service.  You can access your GCS bucket's files through this URL.

## Important Variables

*   **`REGION`:**  The Google Cloud region where resources will be deployed (default: `us-central1`).  Change this if needed.
*   **`SERVICE_ACCOUNT_NAME`:** The name of the service account (default: `caddy-gcs-sa`).
*   **`REPOSITORY_NAME`:** The name of the Artifact Registry repository (default: `caddy-repo`).
*   **`SERVICE_NAME`:** The name of the Cloud Run service (default: `serve-movies-service`).
*   **`IMAGE_TAG`:**  The tag for the Docker image (default: `v1`).

You can modify these variables directly within the script if you need to use different names or settings.

## Security Considerations

*   **`--allow-unauthenticated`:**  This flag makes your Cloud Run service publicly accessible.  **This is generally not recommended for production environments.** For restricted access, consider using:
    *   **Cloud IAM:**  Grant specific users or service accounts access to invoke the Cloud Run service.  Remove the `--allow-unauthenticated` flag and use `gcloud run services add-iam-policy-binding` to grant the `roles/run.invoker` role.
    *   **Cloud Identity-Aware Proxy (IAP):**  IAP can be used to authenticate users before they access your Cloud Run service.

*   **Service Account Permissions:** The script grants the `roles/storage.objectViewer` role, which allows read-only access to *all* objects in the project.  For a more secure setup, consider creating a custom role with minimal permissions, specifically scoped to the GCS bucket you are using.

*   **GCS Bucket Permissions:** Make sure your GCS bucket's permissions are appropriately configured.  If you are using `--allow-unauthenticated`, the bucket *does not* need to be publicly readable.  The service account's permissions handle access.

## Troubleshooting

*   **`gcloud` not found:** Ensure the Google Cloud SDK is installed and in your `PATH`.
*   **Permissions errors:** Make sure you have the necessary IAM roles (as described in the Prerequisites section).
*   **Cloud Run deployment failures:** Check the Cloud Run logs in the Google Cloud Console for detailed error messages.
*   **404 errors:** Verify that the GCS bucket name is correct and that the files you are trying to access exist in the bucket. Check the Caddy logs (configured to `/tmp/caddy.log` inside the container).
*  **Service Account Issues**: Service Account must be created and roles/storage.objectViewer should be granted.

## Customization

*   **Caddyfile:** You can modify the `Caddyfile` to customize Caddy's behavior (e.g., add custom headers, configure caching, etc.).
*   **Dockerfile:** If you need to use a specific version of Caddy or add other dependencies, modify the `Dockerfile`.
*   **Cloud Run Settings:** Adjust the Cloud Run deployment parameters (e.g., memory, CPU, concurrency) as needed.
*   **GCS bucket as a volume**: This method uses volume mounting with Cloud Storage FUSE.

 