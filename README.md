# WoW 3.3.5a AzerothCore Server with Playerbots

[![License](https://img.shields.io/badge/License-AGPLv3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0.html)
[![Platform](https://img.shields.io/badge/platform-Arch%20Linux-blue.svg)](https://archlinux.org/)
[![Docker](https://img.shields.io/badge/docker-required-blue.svg)](https://www.docker.com/)

A complete setup for running a World of Warcraft 3.3.5a private server using AzerothCore with the Playerbots module on Arch Linux. This setup uses Docker containers and includes comprehensive management scripts.

## Credits

This project uses:
- **AzerothCore** - The open-source World of Warcraft server core. Copyright (c) AzerothCore developers. Licensed under AGPLv3.
- **Playerbots Module** - Created by liyunfan1223 and contributors, based on the original work by ike3.
- **Docker Setup** - Based on the official AzerothCore Docker implementation.

This repository contains only management scripts. The AzerothCore server code is downloaded separately and remains under its original license.

## Prerequisites

- Arch Linux (other distributions may work with modifications)
- Docker and Docker Compose
- Git
- At least 8GB RAM (16GB recommended)
- 30GB free disk space
- WoW 3.3.5a client on a separate Windows machine (or Wine)

## Quick Start

Clone this repository and run the setup script:

```bash
git clone https://github.com/YOUR_USERNAME/wow.git
cd wow
chmod +x *.sh
./setup.sh
