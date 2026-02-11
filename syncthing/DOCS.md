# Home Assistant add-on: Syncthing 🔄 by Fabio Garavini

## Writing to the media folder / mounted drives

If Syncthing reports **"permission denied"** when creating a folder under `/media` (e.g. a mounted drive):

1. **Use this fork** – Add the repo `https://github.com/dig12345/fabio-hassio-addons` and install Syncthing from it (this addon has `full_access` and an AppArmor fix for media).
2. **Turn off Protected mode** – In the addon’s page in HA, ensure **Protected mode** is **off** so `full_access` applies.
3. **Make the path writable on the host** – The addon runs as user `abc` (uid 1000). If your drive or `/media` is owned by root, the process cannot create directories there. On the host (e.g. SSH or “Terminal & SSH” addon), run:
   ```bash
   # Replace /media/test with the path you use in Syncthing (e.g. /media/yourdrive)
   sudo chown -R 1000:1000 /media/test
   ```
   Or, for a whole media mount:
   ```bash
   sudo chown -R 1000:1000 /media/yourmount
   ```
   Then in Syncthing, set the folder path to that location (e.g. `/media/yourmount`).
