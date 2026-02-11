# Home Assistant add-on: Syncthing 🔄 by Fabio Garavini

## Writing to the media folder / mounted drives

This addon runs Syncthing as **root** so it can write to any path (including `/media` and mounted drives) without host-side `chown`. Use this fork’s image (`ghcr.io/dig12345/hassio-syncthing`) and ensure **Protected mode** is off so `full_access` applies.
