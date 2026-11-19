# Roles, users and permissions

Give each person or machine only the access it needs: pip installs, Docker pulls, publishing, or one single image. Everything below is plain `curl` against the Nexus REST API. `nexus.example.com` is an example name, use your own.

## How permissions work in Nexus

- A privilege is one action on one repository, for example `nx-repository-view-docker-docker-all-read`. Nexus creates these automatically for every repository and action: `browse`, `read`, `add`, `edit`, `delete`.
- A role is a list of privileges. A user has one or more roles.
- A content selector narrows a privilege to a path, for example one Docker image.

| Action | Allows |
|--------|--------|
| `browse` | list and search components, see them in the UI |
| `read` | download: `pip install`, `docker pull` |
| `add` | upload something new: `twine upload`, `docker push` of a new tag |
| `edit` | overwrite something that exists: `docker push` to an existing tag such as `latest` |
| `delete` | remove components |

Pull and install go through the group repositories `pypi-all` and `docker-all`, so the read privileges are on the groups. Uploads go to the hosted repositories `pypi-hosted` and `docker-hosted`.

Roles created here:

| Role | Python | Docker |
|------|--------|--------|
| `pypi-reader` | browse, read on `pypi-all` | none |
| `pypi-publisher` | `pypi-reader` plus browse, read, add on `pypi-hosted` | none |
| `docker-puller` | none | browse, read on `docker-all` |
| `docker-pusher` | none | `docker-puller` plus browse, read, add, edit on `docker-hosted` |
| `pull-docker-<image>` | none | read of one image only (content selector) |

Important: roles only limit users who log in. While anonymous access is on, anyone can read every repository. Turn it off before you rely on roles:

```bash
./scripts/server/anonymous.sh off
```

## 0. Variables

```bash
# Your DNS name, for example nexus.example.com
H=nexus.example.com

# Nexus admin password
PASS='<admin-password>'

NEXUS=https://$H

# Helper: call the Nexus API through Caddy on this VM, logged in as admin
nexus() { curl -fsS -k --resolve "$H:443:127.0.0.1" -u "admin:$PASS" "$@"; }
```

Check that the privileges exist for your repositories:

```bash
nexus "$NEXUS/service/rest/v1/security/privileges" | grep -oE '"name" *: *"nx-repository-view-(pypi|docker)-[a-z-]+-(browse|read|add|edit)"'
```

## 1. Roles for Python

```bash
# pip install from pypi-all
nexus -X POST "$NEXUS/service/rest/v1/security/roles" \
  -H 'Content-Type: application/json' -d '{
  "id": "pypi-reader",
  "name": "pypi-reader",
  "description": "pip install from pypi-all",
  "privileges": [
    "nx-repository-view-pypi-pypi-all-browse",
    "nx-repository-view-pypi-pypi-all-read"
  ],
  "roles": []
}'

# pip install and upload internal packages to pypi-hosted
nexus -X POST "$NEXUS/service/rest/v1/security/roles" \
  -H 'Content-Type: application/json' -d '{
  "id": "pypi-publisher",
  "name": "pypi-publisher",
  "description": "pip install from pypi-all and upload to pypi-hosted",
  "privileges": [
    "nx-repository-view-pypi-pypi-all-browse",
    "nx-repository-view-pypi-pypi-all-read",
    "nx-repository-view-pypi-pypi-hosted-browse",
    "nx-repository-view-pypi-pypi-hosted-read",
    "nx-repository-view-pypi-pypi-hosted-add"
  ],
  "roles": []
}'
```

`pypi-hosted` uses the write policy `allow_once`, so `add` is enough. If you change the policy to `allow`, also grant `nx-repository-view-pypi-pypi-hosted-edit`.

## 2. Roles for Docker

```bash
# docker pull from docker-all (Docker Hub cache and internal images)
nexus -X POST "$NEXUS/service/rest/v1/security/roles" \
  -H 'Content-Type: application/json' -d '{
  "id": "docker-puller",
  "name": "docker-puller",
  "description": "docker pull from docker-all",
  "privileges": [
    "nx-repository-view-docker-docker-all-browse",
    "nx-repository-view-docker-docker-all-read"
  ],
  "roles": []
}'

# docker pull from docker-all and push to docker-hosted
nexus -X POST "$NEXUS/service/rest/v1/security/roles" \
  -H 'Content-Type: application/json' -d '{
  "id": "docker-pusher",
  "name": "docker-pusher",
  "description": "docker pull from docker-all and push to docker-hosted",
  "privileges": [
    "nx-repository-view-docker-docker-all-browse",
    "nx-repository-view-docker-docker-all-read",
    "nx-repository-view-docker-docker-hosted-browse",
    "nx-repository-view-docker-docker-hosted-read",
    "nx-repository-view-docker-docker-hosted-add",
    "nx-repository-view-docker-docker-hosted-edit"
  ],
  "roles": []
}'
```

Pushing needs an endpoint for `docker-hosted`. It listens on port 5002 inside the compose network and Caddy does not expose it yet, so the pusher role is ready but clients cannot push until that is added.

## 3. Users

```bash
# Helper: create a user with a generated password and print it once
newuser() {
  PW=$(openssl rand -base64 18 | tr -d '/+=')
  nexus -X POST "$NEXUS/service/rest/v1/security/users" \
    -H 'Content-Type: application/json' -d "{
    \"userId\": \"$1\",
    \"firstName\": \"$1\",
    \"lastName\": \"service\",
    \"emailAddress\": \"$1@example.com\",
    \"password\": \"$PW\",
    \"status\": \"active\",
    \"roles\": [\"$2\"]
  }" && echo "$1 / $PW"
}

# Machines that only run pip install
newuser pip-ro pypi-reader

# CI that publishes internal Python packages
newuser ci-python pypi-publisher

# Servers and RKE2 nodes that only pull images
newuser docker-pull docker-puller

# CI that builds and pushes internal images
newuser ci-docker docker-pusher
```

Store each password in your password manager right away. Nexus does not show it again.

## 4. Pull permission for one image only

A content selector limits a privilege to a path. For Docker, the path is `/v2/<image>/`, which covers the manifests and layers of that image.

```bash
# Selector: only library/nginx
nexus -X POST "$NEXUS/service/rest/v1/security/content-selectors" \
  -H 'Content-Type: application/json' -d '{
  "name": "docker-library-nginx",
  "description": "docker image library/nginx",
  "expression": "format == \"docker\" and path =^ \"/v2/library/nginx/\""
}'

# Privilege: browse and read on docker-all, only for that selector
nexus -X POST "$NEXUS/service/rest/v1/security/privileges/repository-content-selector" \
  -H 'Content-Type: application/json' -d '{
  "name": "docker-library-nginx-read",
  "description": "pull docker image library/nginx",
  "actions": ["BROWSE", "READ"],
  "format": "docker",
  "repository": "docker-all",
  "contentSelector": "docker-library-nginx"
}'

# Role with that privilege
nexus -X POST "$NEXUS/service/rest/v1/security/roles" \
  -H 'Content-Type: application/json' -d '{
  "id": "pull-docker-library-nginx",
  "name": "pull-docker-library-nginx",
  "description": "docker pull of library/nginx only",
  "privileges": ["docker-library-nginx-read"],
  "roles": []
}'

# User with that role
newuser nginx-only pull-docker-library-nginx
```

For another image, change `library/nginx` in the expression and the names. Internal images look like `myteam/myapp`, so the expression becomes `path =^ "/v2/myteam/myapp/"`. A whole namespace works the same way: `path =^ "/v2/myteam/"`.

Shortcut for the selector, privilege and role in one command:

```bash
./scripts/server/image-role.sh library/nginx
```

Check the selector in the UI before you depend on it: Settings > Repository > Content Selectors > the selector > preview against `docker-all`. If the path format differs on your Nexus version, adjust the expression and send it again with `PUT /service/rest/v1/security/content-selectors/<name>`.

## 5. Manage

```bash
# List
nexus "$NEXUS/service/rest/v1/security/roles" | grep -E '"id"'
nexus "$NEXUS/service/rest/v1/security/users" | grep -E '"userId"'
nexus "$NEXUS/service/rest/v1/security/content-selectors" | grep -E '"name"'

# Change a password
nexus -X PUT "$NEXUS/service/rest/v1/security/users/pip-ro/change-password" \
  -H 'Content-Type: text/plain' -d '<new-password>'

# Disable a user (send the user back with a new status or roles; no password field)
nexus -X PUT "$NEXUS/service/rest/v1/security/users/pip-ro" \
  -H 'Content-Type: application/json' -d '{
  "userId": "pip-ro",
  "firstName": "pip-ro",
  "lastName": "service",
  "emailAddress": "pip-ro@example.com",
  "status": "disabled",
  "roles": ["pypi-reader"]
}'

# Delete a user, a role, a selector
nexus -X DELETE "$NEXUS/service/rest/v1/security/users/pip-ro"
nexus -X DELETE "$NEXUS/service/rest/v1/security/roles/pypi-reader"
nexus -X DELETE "$NEXUS/service/rest/v1/security/content-selectors/docker-library-nginx"
```

To change what a role can do, send `PUT /service/rest/v1/security/roles/<id>` with the full role body.

## 6. Use the credentials

pip, with the user from step 3:

```bash
export NEXUS_URL=https://nexus.example.com
NEXUS_USER=pip-ro NEXUS_PASS='<password>' ./scripts/client/client.sh
./scripts/client/verify.sh
```

Publish a Python package:

```bash
NEXUS_USER=ci-python NEXUS_PASS='<password>' ./scripts/client/upload.sh dist/*
```

Docker and Podman: log in, then pull with the Nexus name in front of the image:

```bash
docker login nexus.example.com -u docker-pull
docker pull nexus.example.com/library/nginx:1.27

podman login nexus.example.com -u docker-pull
podman pull nexus.example.com/library/nginx:1.27
```

RKE2 / containerd: add the credentials to `/etc/rancher/rke2/registries.yaml` on every node, then restart RKE2 one node at a time:

```yaml
mirrors:
  docker.io:
    endpoint:
      - "https://nexus.example.com"
configs:
  "nexus.example.com":
    auth:
      username: docker-pull
      password: <password>
    tls:
      ca_file: /usr/local/share/ca-certificates/nexus-ca.crt
```

The Docker daemon setting `registry-mirrors` has no place for credentials, as far as I know. With anonymous access off, a plain `docker pull nginx` through the mirror setting is therefore rejected by Nexus and Docker falls back to Docker Hub. Pull with the explicit `nexus.example.com/...` name after `docker login`, or keep anonymous read on until every client can authenticate.

## 7. Test the permissions

```bash
# pip-ro can read (200) ...
curl -s -o /dev/null -w '%{http_code}\n' -u pip-ro:'<password>' https://nexus.example.com/repository/pypi-all/simple/requests/

# ... but cannot upload (401 or 403)
curl -s -o /dev/null -w '%{http_code}\n' -u pip-ro:'<password>' -X POST -F ':action=file_upload' https://nexus.example.com/repository/pypi-hosted/

# the nginx-only user can pull nginx ...
docker login nexus.example.com -u nginx-only
docker pull nexus.example.com/library/nginx:1.27

# ... but not another image (denied)
docker pull nexus.example.com/library/alpine:3.20
```

Wrong password gives `401`. A valid user without the privilege gives `403`.

## Shortcuts

```bash
# Create pypi-reader, pypi-publisher, docker-puller and docker-pusher (skips existing)
./scripts/server/roles.sh

# Create a user with a generated password: <userId> <role[,role]> [email]
./scripts/server/user.sh pip-ro pypi-reader

# Create the selector, privilege and role for one image
./scripts/server/image-role.sh library/nginx
```