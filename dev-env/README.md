# Development Environment for `msmtp_interactive`

This folder contains a minimal Ubuntu Server environment with `systemd` and SSH access, designed to test the `install_msmtp_armored.sh` script in conditions close to a fresh server installation.

**Key points:**

- No AppArmor or related packages are preinstalled — the script under test is expected to install and configure them.
- Provides both a non-root user (`devuser`) with passwordless `sudo` and a `root` account for testing.
- SSH access is exposed on host port `22222`.
- Healthcheck ensures SSH is ready before connecting.

---

## 📥 Cloning the Development Environment  (Host Side)

Before using this environment, clone **only** the `dev-env` folder from the repository onto your **host machine**.  
This ensures you can build and start the container before cloning the main project inside it.

### Option 1 — Standard clone (full repo)

```bash
# Clone the repository (or just the dev-env folder if using sparse checkout)
git clone https://github.com/albertochungvz/msmtp_interactive.git
cd msmtp_interactive/dev-env
```

### Option 2 — Sparse checkout (only `dev-env` folder)

This method avoids downloading the entire working tree initially (recommended):

```bash
# 1) Clone without checking out files, and avoid blobs to save time/space
git clone --filter=blob:none --no-checkout https://github.com/albertochungvz/msmtp_interactive.git
cd msmtp_interactive

# 2) Enable sparse checkout (cone mode keeps it simple and predictable)
git sparse-checkout init --cone

# 3) Select only the dev-env folder
git sparse-checkout set dev-env

# 4) Perform the initial checkout to materialize files
git checkout @
# Alternative if @ is unfamiliar:
# git read-tree -mu HEAD

# Move into the dev-env folder
cd dev-env
```

Once inside `dev-env/`, you can proceed with the usage instructions below.

---

## 📂 Contents

- **Dockerfile** — Builds a minimal Ubuntu Server with `systemd` and SSH.
- **docker-compose.yml** — Orchestrates the container with the required privileges and mounts.
- **msmtp_dev_env.sh** — Host-side helper script to start, connect, or stop the container.

---

## 🚀 Usage

### 1. Make the helper script executable (first time only)

```bash
chmod +x msmtp_dev_env.sh
```

### 2. Start and connect as `devuser`

```bash
./msmtp_dev_env.sh
```

Password: `devpass`

### 3. Start and connect as root

```bash
./msmtp_dev_env.sh --root
```

Password: `rootpass`

### 3. Stop and remove the container

```bash
./msmtp_dev_env.sh --stop
```

---

## 🧭 Workflow inside the container

Once connected via SSH:

```bash
# Clone the repository and switch to the dev branch
git clone -b dev https://github.com/albertochungvz/msmtp_interactive.git
cd msmtp_interactive

# Make the script executable and run it
chmod +x install_msmtp_armored.sh
sudo ./install_msmtp_armored.sh
```

---

## ⚙️ Healthcheck

The docker-compose.yml includes a healthcheck that waits for SSH to be ready before allowing the helper script to connect. The helper script (`msmtp_dev_env.sh`) will not attempt to connect until the container is marked as `healthy`.

---

## 🔒 Security Notes

- This environment is intended for **local development and testing only**.
- The root and devuser passwords are hardcoded for convenience — **do not use in production**.
- The container runs in `--privileged` mode with `apparmor=unconfined` to allow AppArmor profile management inside.

---

## 📌 Requirements

- Docker Engine and Docker Compose v2 installed on the host.
- Host system with AppArmor support enabled if you want to test full AppArmor functionality.

---

## 🛑 Cleanup

To remove all traces of the container and its volumes:

```bash
cd dev-env
docker compose down -v
```

---

## 🛠 Troubleshooting

### Permission denied when running `./msmtp_dev_env.sh`

This means the script is not marked as executable. Fix:

```bash
chmod +x msmtp_dev_env.sh
```

Then run it again:

```bash
./msmtp_dev_env.sh
```

If the folder is on a filesystem mounted with noexec, run it with:

```bash
bash msmtp_dev_env.sh
```

### Sparse checkout leaves folder empty

If after running the sparse checkout commands the `dev-env` folder is empty:

1. Ensure you are on a branch that contains dev-env.
2. Run:

    ```bash
    git checkout @
    ```

    or:

    ```bash
    git read-tree -mu HEAD
    ```

3.Verify the path is correct and case-sensitive: `dev-env`

Also verify that:

- You are on a branch that contains the dev-env folder.
- The path `dev-env` is correctly spelled.
- Your Git version is 2.25 or newer.

### SSH connection refused

- Ensure the container is running:

    ```bash
    docker ps
    ```

- Check health status:

    ```bash
    docker inspect --format='{{.State.Health.Status}}' msmtp_dev
    ```

- If not healthy, check logs:

    ```bash
    docker logs msmtp_dev
    ```

### Force the entire working tree to the remote version

```bash
git fetch origin
git reset --hard origin/dev
```
