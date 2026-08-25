<!--
SPDX-FileCopyrightText: 2020 Aaron Raimist
SPDX-FileCopyrightText: 2020 Chris van Dijk
SPDX-FileCopyrightText: 2020 Dominik Zajac
SPDX-FileCopyrightText: 2020 Mickaël Cornière
SPDX-FileCopyrightText: 2020-2024 MDAD project contributors
SPDX-FileCopyrightText: 2020-2026 Slavi Pantaleev
SPDX-FileCopyrightText: 2022 François Darveau
SPDX-FileCopyrightText: 2022 Julian Foad
SPDX-FileCopyrightText: 2022 Warren Bailey
SPDX-FileCopyrightText: 2023 Antonis Christofides
SPDX-FileCopyrightText: 2023 Felix Stupp
SPDX-FileCopyrightText: 2023 Pierre 'McFly' Marty
SPDX-FileCopyrightText: 2024-2026 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Setting up Autobrr

This is an [Ansible](https://www.ansible.com/) role which installs [Autobrr](https://autobrr.com/) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

Autobrr is a modern autodl-irssi replacement, an easy to use download automator for torrents and Usenet.

See the project's [documentation](https://autobrr.com/introduction) to learn what Autobrr does and why it might be useful to you.

## Adjusting the playbook configuration

To enable Autobrr with this role, add the following configuration to your `vars.yml` file.

**Note**: the path should be something like `inventory/host_vars/mash.example.com/vars.yml` if you use the [MASH Ansible playbook](https://github.com/mother-of-all-self-hosting/mash-playbook).

```yaml
########################################################################
#                                                                      #
# autobrr                                                              #
#                                                                      #
########################################################################

autobrr_enabled: true

########################################################################
#                                                                      #
# /autobrr                                                             #
#                                                                      #
########################################################################
```

### Set the hostname

To enable Autobrr you need to set the hostname as well. To do so, add the following configuration to your `vars.yml` file. Make sure to replace `example.com` with your own value.

```yaml
autobrr_hostname: "example.com"
```

After adjusting the hostname, make sure to adjust your DNS records to point the domain to your server.

### Extending the configuration

There are some additional things you may wish to configure about the service.

Take a look at:

- [`defaults/main.yml`](../defaults/main.yml) for some variables that you can customize via your `vars.yml` file. You can override settings (even those that don't have dedicated playbook variables) using the `autobrr_environment_variables_additional_variables` variable

## Installing

After configuring the playbook, run the installation command of your playbook as below:

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start
```

If you use the MASH playbook, the shortcut commands with the [`just` program](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/just.md) are also available: `just install-all` or `just setup-all`

## Usage

After running the command for installation, Autobrr becomes available at the specified hostname like `https://example.com`. To use it, open the URL on the browser and create an account.

### Create the first account promptly

Autobrr has no default credentials. Instead, a freshly installed instance is in an *onboarding* state: it accepts an unauthenticated `POST /api/auth/onboard` call from anybody who can reach it, and whoever makes that call first becomes the administrator. Autobrr closes onboarding as soon as one account exists (`GET /api/auth/onboard` answers `204 No Content` while it is open and `503 Service Unavailable` once it is not).

Because this role publishes Autobrr on a public hostname, the window between installing it and creating your account is a window in which a stranger can claim the instance. Create your account immediately after installing, and do not leave an un-onboarded instance running overnight.

If you would rather not race anybody, you can create the account on the server before the service is ever reachable, using the `autobrrctl` program that ships inside the same container image. Run it on the server after `just install-service/autobrr` (or `--tags=setup-autobrr`) but before starting the service — it works directly against the database, so Autobrr does not need to be running:

```sh
docker run --rm -i \
  --user=1000:1000 \
  --entrypoint=autobrrctl \
  --mount type=bind,src=/mash/autobrr/data,dst=/config \
  ghcr.io/autobrr/autobrr:v1.84.0 \
  --config /config create-user YOUR_USERNAME
```

The program reads the password from standard input (twice, as a confirmation). The `--entrypoint` is required, because the image's own entrypoint is the Autobrr server. Adjust the image tag, the user/group and the source path to match `autobrr_version`, `autobrr_uid`/`autobrr_gid` and `autobrr_data_path` as your playbook sets them. Afterwards, `GET /api/auth/onboard` answers `503` and the instance can no longer be claimed by anybody else.

## Troubleshooting

### Check the service's logs

You can find the logs in [systemd-journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html) by logging in to the server with SSH and running `journalctl -fu autobrr` (or how you/your playbook named the service, e.g. `mash-autobrr`).
