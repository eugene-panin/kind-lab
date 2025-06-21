# Kind Lab for macOS

A ready-to-use local Kubernetes development environment for macOS, using Kind, dnsmasq, and mkcert. This setup provides a fully automated cluster with TLS-secured local domains (`*.local.dev` by default).

## Features

-   **Automated macOS Setup**: A single command (`make all`) installs all dependencies via Homebrew and sets up a new cluster.
-   **Custom Local Domain**: Easily configure your local domain (e.g., `*.my-app.test`) via a `.env` file.
-   **Automatic TLS**: Generates and installs trusted TLS certificates for your local domain.
-   **NGINX Ingress**: Pre-configured NGINX Ingress Controller to expose services.
-   **Status Page**: A simple "hello-world" style page at `status.<your-domain>` to verify the setup is working.

## Prerequisites

-   **macOS**
-   **Homebrew**: The script will attempt to install it if not found.

The setup scripts will install all other dependencies (Docker, Kind, kubectl, etc.) via Homebrew.

## Quick Start

1.  **Clone the repository:**
    ```sh
    git clone <repository-url>
    cd kind-lab
    ```

2.  **Configure your environment (optional):**
    Copy the example environment file and customize the variables if needed.
    ```sh
    cp .env.example .env
    ```
    You can change `LOCAL_DOMAIN` and `CLUSTER_NAME` in the `.env` file.

3.  **Run the complete setup:**
    This command will install dependencies, configure the host (DNS and certs), and start the cluster. You will be prompted for your `sudo` password.
    ```sh
    make all
    ```

4.  **Verify the installation:**
    Once the command finishes, open `https://status.local.dev` (or your custom domain) in your browser. You should see the Kind Lab status page.

## How It Works

The setup is split into two main parts:

1.  **Host Configuration (`make configure-domain`)**: This `sudo`-powered step configures your Mac.
    -   **DNS**: Uses `dnsmasq` (via Homebrew service) to resolve `*.<your-domain>` to `127.0.0.1`.
    -   **TLS**: Uses `mkcert` to generate a locally-trusted CA and a wildcard certificate for `*.<your-domain>`.
    -   It tracks the domain in a `.kind-lab.state` file to automatically clean up old configurations if you change the domain.

2.  **Cluster Setup (`make up`)**: This step runs without `sudo`.
    -   Creates a Kind cluster with the control-plane and worker nodes.
    -   Installs the NGINX Ingress Controller.
    -   Creates a TLS secret in the cluster from the generated certificate files.
    -   Deploys a simple status page application to verify that everything is working.

## Available Commands

-   `make all`: A full setup. Installs dependencies, configures the host, and starts the cluster.
-   `make up`: Creates or recreates the Kind cluster and deploys the necessary services.
-   `make down`: Deletes the Kind cluster.
-   `make clean`: Deletes the cluster and all generated files (certs, state).
-   `make deps`: Installs required tools for macOS via Homebrew.
-   `make configure-domain`: (Requires `sudo`) Configures DNS and TLS on the host.
-   `make help`: Shows the help message.
