void TryRefreshPublicIPIfNeeded()
{
	if (HasFreshPublicIP())
	{
		return;
	}

	if (gB_PublicIPRefreshInFlight || GetTime() < gI_NextPublicIPRefreshAttemptAt)
	{
		return;
	}

	ClearPublicIPCache();
	StartPublicIPRequest(PublicIPProvider_IPAPI);
}

bool HasFreshPublicIP()
{
	return gC_PublicIP[0] != '\0'
		&& gI_PublicIPLastRefresh > 0
		&& (GetTime() - gI_PublicIPLastRefresh) < GOKZ_TOP_PUBLIC_IP_MAX_AGE;
}

void StartPublicIPRequest(PublicIPProvider provider)
{
	char url[128];
	switch (provider)
	{
		case PublicIPProvider_IPAPI:
		{
			strcopy(url, sizeof(url), "http://ip-api.com/json");
		}
		case PublicIPProvider_MyIPWTF:
		{
			strcopy(url, sizeof(url), "https://myip.wtf/json");
		}
	}

	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, url);
	if (request == null)
	{
		OnPublicIPRequestFailed(provider);
		return;
	}

	gB_PublicIPRefreshInFlight = true;
	SteamWorks_SetHTTPRequestContextValue(request, view_as<int>(provider));
	SteamWorks_SetHTTPCallbacks(request, OnPublicIPHTTPComplete);
	SteamWorks_SetHTTPRequestHeaderValue(request, "Accept", "application/json");
	SteamWorks_SetHTTPRequestHeaderValue(request, "User-Agent", "gokz-top-servers/" ... GOKZ_TOP_SERVERS_VERSION);
	SteamWorks_SetHTTPRequestUserAgentInfo(request, "gokz-top-servers/" ... GOKZ_TOP_SERVERS_VERSION);
	SteamWorks_SetHTTPRequestAbsoluteTimeoutMS(request, GOKZ_TOP_PUBLIC_IP_TIMEOUT_MS);

	if (!SteamWorks_SendHTTPRequest(request))
	{
		delete request;
		OnPublicIPRequestFailed(provider);
	}
}

public void OnPublicIPHTTPComplete(Handle request, bool failure, bool requestSuccessful, EHTTPStatusCode statusCode, any data)
{
	PublicIPProvider provider = view_as<PublicIPProvider>(data);

	if (!failure
		&& requestSuccessful
		&& statusCode >= k_EHTTPStatusCode200OK
		&& statusCode < k_EHTTPStatusCode300MultipleChoices)
	{
		char response[512];
		int responseSize;
		if (SteamWorks_GetHTTPResponseBodySize(request, responseSize) && responseSize > 0)
		{
			SteamWorks_GetHTTPResponseBodyData(request, response, sizeof(response));

			char publicIP[GOKZ_TOP_PUBLIC_IP_LENGTH];
			if (ExtractPublicIPFromResponse(provider, response, publicIP, sizeof(publicIP)))
			{
				gB_PublicIPRefreshInFlight = false;
				gI_NextPublicIPRefreshAttemptAt = 0;
				SetPublicIPCache(publicIP, GetTime());
				QueueImmediateHeartbeat();
				delete request;
				return;
			}
		}
	}

	delete request;
	OnPublicIPRequestFailed(provider);
}

void OnPublicIPRequestFailed(PublicIPProvider provider)
{
	if (provider == PublicIPProvider_IPAPI)
	{
		StartPublicIPRequest(PublicIPProvider_MyIPWTF);
		return;
	}

	gB_PublicIPRefreshInFlight = false;
	gI_NextPublicIPRefreshAttemptAt = GetTime() + GOKZ_TOP_PUBLIC_IP_FAILURE_COOLDOWN;
	LogError("[gokz-top-servers] Unable to refresh public IP from all providers");
}

bool ExtractPublicIPFromResponse(PublicIPProvider provider, const char[] response, char[] buffer, int maxLength)
{
	buffer[0] = '\0';
	switch (provider)
	{
		case PublicIPProvider_IPAPI:
		{
			ExtractJSONStringField(response, "query", buffer, maxLength);
		}
		case PublicIPProvider_MyIPWTF:
		{
			ExtractJSONStringField(response, "YourFuckingIPAddress", buffer, maxLength);
		}
	}

	return IsUsablePublicIPv4(buffer);
}

bool IsUsablePublicIPv4(const char[] candidate)
{
	if (candidate[0] == '\0')
	{
		return false;
	}

	char octets[4][4];
	if (ExplodeString(candidate, ".", octets, sizeof(octets), sizeof(octets[])) != 4)
	{
		return false;
	}

	int values[4];
	for (int i = 0; i < sizeof(octets); i++)
	{
		if (octets[i][0] == '\0')
		{
			return false;
		}

		values[i] = StringToInt(octets[i]);
		if (values[i] < 0 || values[i] > 255)
		{
			return false;
		}
	}

	if (values[0] == 10
		|| (values[0] == 172 && values[1] >= 16 && values[1] <= 31)
		|| (values[0] == 192 && values[1] == 168)
		|| values[0] == 127
		|| values[0] == 0)
	{
		return false;
	}

	return true;
}
