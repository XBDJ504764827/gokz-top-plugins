# gokz-top-plugins

SourceMod plugins for integrating a CS:GO GOKZ server with [GOKZ.TOP](https://kzcharm.com).

## Plugins

- `gokz-top-core`: shared API configuration, HTTP helpers, player sessions, and leaderboard/profile data access.
- `gokz-top-servers`: live server status heartbeats for the public server browser.
- `gokz-top-profile`: in-game profile, rating, rank, tag, and scoreboard integrations.
- `gokz-top-reviews`: in-game map review submission.

## Requirements

- CS:GO dedicated server
- SourceMod 1.11
- SteamWorks extension
- Existing GOKZ installation
- A GOKZ.TOP server group API key

## Apply For An API Key

API keys are issued per server group on GOKZ.TOP.

1. Sign in to [kzcharm.com](https://kzcharm.com).
2. Open [Admin Servers](https://kzcharm.com/admin/servers).
3. Open the `Server Group` tab.
4. Create a group for your community, or select an existing group you own.
5. Copy the API key from the `API Key` column.
6. Assign your GlobalAPI or public server rows to the same group.

The API key is sent as `X-Server-Group-Key` by the plugins. Keep it private. If the key is exposed, regenerate it from the `Server Group` tab and update every server using the old key.

## Install

1. Download the latest release package from this repository's GitHub Releases page.
2. Stop the game server or prepare a plugin reload window.
3. Copy the package contents into the CS:GO server root so `addons/`, `cfg/`, and `materials/` merge into the existing installation.
4. Start the server once so `gokz-top-core` can generate its config files.

The API base URL defaults to production GOKZ.TOP. For another deployment, edit:

```text
cfg/sourcemod/gokz-top/gokz-top-core.cfg
```

Set the API origin without a trailing slash:

```cfg
gokz_top_api_base_url "https://kzcharm.com"
```

## Configure The API Key

After `gokz-top-core` starts once, it creates:

```text
cfg/sourcemod/gokz-top/apikey.cfg
```

Paste your server group API key there:

```cfg
gokz_top_api_key "paste-your-server-group-api-key-here"
```

Reload the config or restart the server:

```cfg
exec sourcemod/gokz-top/apikey.cfg
```

## Verify

After the server is running:

1. Check the SourceMod error logs for `gokz-top-core`, `gokz-top-servers`, `gokz-top-profile`, or `gokz-top-reviews` errors.
2. Open [Admin Servers](https://kzcharm.com/admin/servers) and confirm the server is assigned to the group using the same API key.
3. Open the public server browser on [kzcharm.com/servers](https://kzcharm.com/servers) and confirm the server status updates after the heartbeat interval.

## Local Compile

The repository follows the SourceMod `addons/sourcemod/scripting` layout. To compile locally, use a SourceMod 1.11 package with the required includes and run `spcomp` from `addons/sourcemod/scripting`.

Example:

```sh
./spcomp gokz-top-core.sp
./spcomp gokz-top-servers.sp
./spcomp gokz-top-profile.sp
./spcomp gokz-top-reviews.sp
```

The GitHub Actions workflow is the reference release build.
