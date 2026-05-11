void FindRequiredConVars()
{
	gCV_Hostname = FindConVar("hostname");
	gCV_HostPort = FindConVar("hostport");
}

void CreateConVars()
{
	gCV_PushInterval = CreateConVar("gokz_top_servers_push_interval", "4.0",
		"Interval in seconds between gokz-top server status heartbeats.", _, true, 2.0, true, 10.0);
	gCV_PushInterval.AddChangeHook(OnPushIntervalChanged);

	AutoExecConfig(true, "gokz-top-servers");
}

public void OnPushIntervalChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	CreateHeartbeatTimer();
}
