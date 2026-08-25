<!--
SPDX-FileCopyrightText: 2018-2026 Slavi Pantaleev
SPDX-FileCopyrightText: 2019-2022 Aaron Raimist
SPDX-FileCopyrightText: 2019-2023 MDAD project contributors
SPDX-FileCopyrightText: 2023 QEDeD
SPDX-FileCopyrightText: 2024 Fabio Bonelli
SPDX-FileCopyrightText: 2024 Nikita Chernyi
SPDX-FileCopyrightText: 2024-2026 Suguru Hirahara
SPDX-FileCopyrightText: 2026 spatterlight

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Molecule Testing

This role supports [Molecule](https://docs.ansible.com/projects/molecule/), an Ansible testing framework designed for developing and testing Ansible collections, playbooks, and roles.

## Prerequisites

To utilize Molecule you need to prepare several requirements:

- **x86** computer running one of these operating systems that make use of [systemd](https://systemd.io/):
  - **Archlinux**
  - **CentOS**, **Rocky Linux**, **AlmaLinux**, or possibly other RHEL alternatives (although your mileage may vary)
  - **Debian** (10/Buster or newer)
  - **Ubuntu** (18.04 or newer, although [20.04 may be problematic](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/ansible.md#supported-ansible-versions) if you run the Ansible playbook on it)
- `root` access on the computer which Molecule runs against
- [Ansible](http://ansible.com/) program
- [Python](https://www.python.org/)
  - Most distributions install Python by default, but some don't (e.g. Ubuntu 18.04) and require manual installation (something like `apt-get install python3`)
- [Docker](https://www.docker.com)
  - Access to Docker UNIX socket (`/var/run/docker.sock`) is required by default

## Installation

To set up the environment for using Molecule, run the command below on the terminal:

```bash
python3 -m venv ./molecule/venv
source ./molecule/venv/bin/activate
pip3 install -r ./molecule/requirements.txt
```

## Scenarios

There are two testing scenarios available.

### `default`

Tests a standard Autobrr installation, and is where the substance of the suite lives.

It first runs the same container image with none of the role's configuration, to establish what an Autobrr that nobody configured chooses for itself — it starts happily, migrates a database and serves the same web UI, so nothing else in the scenario is allowed to rest on Autobrr merely answering. The scenario then checks that:

- the readiness endpoint, which pings Autobrr's database, answers — rather than only that the systemd unit reads `active`, which `Restart=always` makes true for a crash-looping container as well;
- unauthenticated calls and forged sessions are refused (403), forged API tokens are refused (401), and an invented path is a 404 rather than the single-page-application shell that would make a 200 unfalsifiable;
- a freshly installed Autobrr can still be claimed by an unauthenticated onboarding call (204), and refuses further ones (503) once it has been;
- the running process reports the version `autobrr_version` pins, matching the image tag and the image's OCI version label;
- the port, log level, update-check setting and timezone Autobrr is running with are the ones the role rendered into its env file — all of them deliberately different from what Autobrr picks for itself;
- a filter created over the API reads back by id, does not read back under an id nothing created, reads back through an API key Autobrr issued, and exists as a row in the SQLite file at the host path the role bind-mounts;
- the service does not restart during a window longer than the unit's `RestartSec`.

### `uninstall`

Installs Autobrr, lets it write its database, and then runs the role again with `autobrr_enabled: false` — the uninstallation path that the `default` scenario never touches. It checks that the systemd unit, its service file, the rendered `env` and `labels` files, the container and the container network are all gone, and that the operator's data is not.

## Running

By default it is configured to run the scenarios on Ubuntu 26.04.

```bash
molecule test --scenario-name default
molecule test --scenario-name uninstall
```

You can utilize other distributions by setting one to the `MOLECULE_DISTRO` environment variable:

```bash
# Ubuntu 24.04
MOLECULE_DISTRO=ubuntu2404 molecule test --scenario-name default

# Debian 13
MOLECULE_DISTRO=debian13 molecule test --scenario-name default

# Debian 12
MOLECULE_DISTRO=debian12 molecule test --scenario-name default
```
