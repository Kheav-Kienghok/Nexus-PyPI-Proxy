# Projects and robot accounts

Give one project (for example `speedtest`) its own images that only chosen users and one robot account can see, pull and push. Every project user and the robot can also `pip install` through the Nexus Python mirror by default. Everything below is plain `curl` against the Nexus REST API. `nexus.example.com` is an example name, use your own.

## What a project is in Nexus

Nexus has no Harbor-style "project" object. A project is an image namespace plus a permission on that namespace:

- Images of the project are named `speedtest/<image>`, for example `nexus.example.com:5002/speedtest/api:1.0`.
- A content selector matches the path `/v2/speedtest/`, which covers every image, tag and layer of the project.
- Two privileges use that selector: pull (view and pull on `docker-all`) and push (view, pull, add and edit on `docker-hosted`).
- Two roles bundle them: `speedtest-viewer` (view and pull) and `speedtest-developer` (view, pull and push).
- Both roles also include read access to the Python mirror `pypi-all`, so `pip install` works for every project user and the robot.
- A user gets a role. The robot account is a normal Nexus user with a long generated password that only CI knows.

Users with only the `speedtest-*` roles cannot see, pull or push images of any other project. They can read the Python mirror, which is public PyPI content through the cache.

## Rules that make the isolation real

1. Turn anonymous access off. Anonymous users can read every repository, including the project.

```bash
./scripts/server/anonymous.sh off
```

2. Do not give project users the repo-wide roles `docker-puller` or `docker-pusher` (docs/roles-users.md). They grant read or write on all of `docker-all` or `docker-hosted`, which includes every project. Give people project roles only.
3. The `admin` user sees everything. Do not use it for daily work.
4. Everybody uses the endpoints Caddy serves: pull on `:5000`, push on `:5002`.

## Quick way

```bash
# Create the selector, the pull and push privileges, and the viewer and developer roles (both with pip pull)
./scripts/server/project.sh speedtest

# Robot account for CI: pull and push (the generated password is printed once)
./scripts/server/user.sh robot-speedtest speedtest-developer

# A person who may view, pull and push
./scripts/server/user.sh alice speedtest-developer

# A person who may only view and pull
./scripts/server/user.sh bob speedtest-viewer
```

A second project is the same with another name: `./scripts/server/project.sh billing`.

Running `project.sh` again updates the two roles, so it also adds the Python privileges to a project you created before. Selector and privileges that already exist are left alone.

## The same with curl

### 0. Variables

```bash
# Your DNS name, for example nexus.example.com
H=nexus.example.com

# Nexus admin password
PASS='<admin-password>'

NEXUS=https://$H

# Helper: call the Nexus API through Caddy on this VM, logged in as admin
nexus() { curl -fsS -k --resolve "$H:443:127.0.0.1" -u "admin:$PASS" "$@"; }

# The project name: lowercase letters, digits and dashes
P=speedtest
```

### 1. Content selector

```bash
nexus -X POST "$NEXUS/service/rest/v1/security/content-selectors" \
  -H 'Content-Type: application/json' -d "{
  \"name\": \"docker-$P\",
  \"description\": \"docker images of project $P\",
  \"expression\": \"format == \\\"docker\\\" and path =^ \\\"/v2/$P/\\\"\"
}"
```

### 2. Privileges

```bash
# View and pull: docker-all (what port 5000 serves)
nexus -X POST "$NEXUS/service/rest/v1/security/privileges/repository-content-selector" \
  -H 'Content-Type: application/json' -d "{
  \"name\": \"docker-$P-pull\",
  \"description\": \"view and pull images of project $P\",
  \"actions\": [\"BROWSE\", \"READ\"],
  \"format\": \"docker\",
  \"repository\": \"docker-all\",
  \"contentSelector\": \"docker-$P\"
}"

# Push: docker-hosted (what port 5002 serves). A push also reads, so READ is included.
nexus -X POST "$NEXUS/service/rest/v1/security/privileges/repository-content-selector" \
  -H 'Content-Type: application/json' -d "{
  \"name\": \"docker-$P-push\",
  \"description\": \"push images of project $P\",
  \"actions\": [\"BROWSE\", \"READ\", \"ADD\", \"EDIT\"],
  \"format\": \"docker\",
  \"repository\": \"docker-hosted\",
  \"contentSelector\": \"docker-$P\"
}"
```

Add `"DELETE"` to the push actions if the project may delete its own tags and layers.

### 3. Roles

```bash
# Viewer: view and pull images, pip install from pypi-all
nexus -X POST "$NEXUS/service/rest/v1/security/roles" \
  -H 'Content-Type: application/json' -d "{
  \"id\": \"$P-viewer\",
  \"name\": \"$P-viewer\",
  \"description\": \"view and pull images of project $P, pip install from pypi-all\",
  \"privileges\": [
    \"docker-$P-pull\",
    \"nx-repository-view-pypi-pypi-all-browse\",
    \"nx-repository-view-pypi-pypi-all-read\"
  ],
  \"roles\": []
}"

# Developer: view, pull and push images, pip install from pypi-all
nexus -X POST "$NEXUS/service/rest/v1/security/roles" \
  -H 'Content-Type: application/json' -d "{
  \"id\": \"$P-developer\",
  \"name\": \"$P-developer\",
  \"description\": \"view, pull and push images of project $P, pip install from pypi-all\",
  \"privileges\": [
    \"docker-$P-pull\",
    \"docker-$P-push\",
    \"nx-repository-view-pypi-pypi-all-browse\",
    \"nx-repository-view-pypi-pypi-all-read\"
  ],
  \"roles\": []
}"
```

### 4. Users and the robot account

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

# Robot account for the project: pull and push
newuser robot-$P $P-developer

# People
newuser alice $P-developer
newuser bob $P-viewer
```

Store the robot password in your CI secret store right away. Nexus does not show it again. As far as I know, Nexus user tokens are a Pro feature, so on Community the robot is a normal user with a long random password.

## Use it

Push (robot or developer), port 5002:

```bash
echo '<password>' | docker login nexus.example.com:5002 -u robot-speedtest --password-stdin
docker tag speedtest-api:1.0 nexus.example.com:5002/speedtest/api:1.0
docker push nexus.example.com:5002/speedtest/api:1.0
```

Pull (robot, developer or viewer), port 5000:

```bash
echo '<password>' | docker login nexus.example.com:5000 -u robot-speedtest --password-stdin
docker pull nexus.example.com:5000/speedtest/api:1.0
```

View: log in to the Nexus UI as the user, then Browse. A user with only `speedtest-*` roles sees only the components of that project.

In CI, for example GitLab CI with masked variables `NEXUS_ROBOT_USER` and `NEXUS_ROBOT_PASS`:

```yaml
build:
  script:
    - echo "$NEXUS_ROBOT_PASS" | docker login nexus.example.com:5002 -u "$NEXUS_ROBOT_USER" --password-stdin
    - docker build -t nexus.example.com:5002/speedtest/api:$CI_COMMIT_SHORT_SHA .
    - docker push nexus.example.com:5002/speedtest/api:$CI_COMMIT_SHORT_SHA
```

Python packages (pip), for the robot, developers and viewers:

```bash
export NEXUS_URL=https://nexus.example.com
NEXUS_USER=robot-speedtest NEXUS_PASS='<password>' ./scripts/client/client.sh
./scripts/client/verify.sh
pip install -r requirements.txt
```

In CI, install through the mirror with the same robot:

```yaml
test:
  script:
    - pip install --index-url "https://$NEXUS_ROBOT_USER:$NEXUS_ROBOT_PASS@nexus.example.com/repository/pypi-all/simple" -r requirements.txt
```

For Kubernetes (RKE2), pull with the robot or a viewer through an image pull secret:

```bash
kubectl create secret docker-registry nexus-speedtest -n <namespace> \
  --docker-server=nexus.example.com:5000 \
  --docker-username=robot-speedtest \
  --docker-password='<password>'
```

Then reference `nexus.example.com:5000/speedtest/api:1.0` in the pod and add `imagePullSecrets: [{name: nexus-speedtest}]`.

## Test the isolation

```bash
# the project user can push and pull speedtest/...
docker login nexus.example.com:5002 -u robot-speedtest
docker push nexus.example.com:5002/speedtest/api:1.0

# ... but cannot push into another project (denied)
docker tag speedtest-api:1.0 nexus.example.com:5002/billing/api:1.0
docker push nexus.example.com:5002/billing/api:1.0

# a user of project billing cannot pull speedtest (denied)
docker login nexus.example.com:5000 -u robot-billing
docker pull nexus.example.com:5000/speedtest/api:1.0

# anonymous cannot pull (needs a login)
docker logout nexus.example.com:5000
docker pull nexus.example.com:5000/speedtest/api:1.0
```

Check in the UI before you depend on it: Settings > Repository > Content Selectors > `docker-speedtest` > preview against `docker-hosted`. If the path format differs on your Nexus version, adjust the expression and send it again with `PUT /service/rest/v1/security/content-selectors/docker-speedtest`.

## Manage

```bash
# Who has what
nexus "$NEXUS/service/rest/v1/security/users" | grep -E '"userId"|"roles"'

# Rotate the robot password
nexus -X PUT "$NEXUS/service/rest/v1/security/users/robot-$P/change-password" \
  -H 'Content-Type: text/plain' -d '<new-password>'

# Take access away from a person
nexus -X DELETE "$NEXUS/service/rest/v1/security/users/alice"

# Remove the whole project access (images stay in docker-hosted)
nexus -X DELETE "$NEXUS/service/rest/v1/security/roles/$P-developer"
nexus -X DELETE "$NEXUS/service/rest/v1/security/roles/$P-viewer"
nexus -X DELETE "$NEXUS/service/rest/v1/security/privileges/docker-$P-pull"
nexus -X DELETE "$NEXUS/service/rest/v1/security/privileges/docker-$P-push"
nexus -X DELETE "$NEXUS/service/rest/v1/security/content-selectors/docker-$P"
```

## Python mirror access

The project roles include `browse` and `read` on `pypi-all`, the group that serves the PyPI cache and your internal Python packages. That means project users can also install internal packages from `pypi-hosted`. To give them the public PyPI cache only, use `pypi-proxy` instead:

```bash
PYPI_REPO=pypi-proxy ./scripts/server/project.sh speedtest
REPO=pypi-proxy NEXUS_USER=robot-speedtest NEXUS_PASS='<password>' ./scripts/client/client.sh
```

The index URL is then `https://nexus.example.com/repository/pypi-proxy/simple`. To remove Python access from a project, delete the two `nx-repository-view-pypi-...` privileges from its roles with `PUT /service/rest/v1/security/roles/<id>` and the full role body.

Uploading Python packages is a separate permission: add `nx-repository-view-pypi-pypi-hosted-add` (see the `pypi-publisher` role in docs/roles-users.md).

## Base images from Docker Hub

A project robot only sees its own namespace, so it cannot pull `library/python` through Nexus. A build can still pull base images straight from Docker Hub. To let a project pull official images through the Nexus cache, add a selector for `library/` and a role for it:

```bash
nexus -X POST "$NEXUS/service/rest/v1/security/content-selectors" \
  -H 'Content-Type: application/json' -d '{
  "name": "docker-hub-library",
  "description": "official Docker Hub images",
  "expression": "format == \"docker\" and path =^ \"/v2/library/\""
}'

nexus -X POST "$NEXUS/service/rest/v1/security/privileges/repository-content-selector" \
  -H 'Content-Type: application/json' -d '{
  "name": "docker-hub-library-pull",
  "description": "pull official Docker Hub images",
  "actions": ["BROWSE", "READ"],
  "format": "docker",
  "repository": "docker-all",
  "contentSelector": "docker-hub-library"
}'

nexus -X POST "$NEXUS/service/rest/v1/security/roles" \
  -H 'Content-Type: application/json' -d '{
  "id": "docker-hub-library-reader",
  "name": "docker-hub-library-reader",
  "description": "pull official Docker Hub images through the cache",
  "privileges": ["docker-hub-library-pull"],
  "roles": []
}'
```

Roles can include roles: send the robot a second role, or use `PUT /service/rest/v1/security/users/robot-speedtest` with `"roles": ["speedtest-developer", "docker-hub-library-reader"]`. Other Docker Hub namespaces need their own selector.

## Limits

- No per-project quota, project page or project-level audit view like Harbor. A project is a naming rule plus permissions.
- The first part of the image name is the project. Anyone with push rights to that path can use it, so create the roles before you tell teams to push.
- `docker search` and the registry catalog are not filtered per project.
- Admins see everything.
- The Python mirror access is read-only and repo-wide, not per project.
