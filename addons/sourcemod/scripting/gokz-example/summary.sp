void OnTimerEnd_Summary(int client, int course, float time, int teleportsUsed)
{
	if (!IsValidClient(client) || !IsFinishSummaryEnabled(client))
	{
		return;
	}

	char courseName[32];
	char formattedTime[16];

	FormatCourseName(course, courseName, sizeof(courseName));
	FormatSeconds(time, formattedTime, sizeof(formattedTime));

	GOKZ_PrintToChat(client, true, "%t", "Example Finish Summary", courseName, formattedTime, teleportsUsed);

	if (gCV_gokz_example_broadcast_to_specs.BoolValue)
	{
		PrintSummaryToSpectators(client, courseName, formattedTime, teleportsUsed);
	}
}

void PrintSummaryToSpectators(int target, const char[] courseName, const char[] formattedTime, int teleportsUsed)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsValidClient(client) || client == target || !IsClientObserver(client))
		{
			continue;
		}

		if (GetEntPropEnt(client, Prop_Send, "m_hObserverTarget") != target)
		{
			continue;
		}

		GOKZ_PrintToChat(client, true, "%t", "Example Finish Summary - Spectator", target, courseName, formattedTime, teleportsUsed);
	}
}

void FormatCourseName(int course, char[] buffer, int maxlength)
{
	if (course == 0)
	{
		strcopy(buffer, maxlength, "main course");
	}
	else
	{
		FormatEx(buffer, maxlength, "bonus %d", course);
	}
}

void FormatSeconds(float time, char[] buffer, int maxlength)
{
	int roundedTime = RoundFloat(time * 100.0);
	int centiseconds = roundedTime % 100;
	roundedTime = (roundedTime - centiseconds) / 100;
	int seconds = roundedTime % 60;
	roundedTime = (roundedTime - seconds) / 60;
	int minutes = roundedTime % 60;
	int hours = (roundedTime - minutes) / 60;

	if (hours == 0)
	{
		FormatEx(buffer, maxlength, "%02d:%02d.%02d", minutes, seconds, centiseconds);
	}
	else
	{
		FormatEx(buffer, maxlength, "%d:%02d:%02d.%02d", hours, minutes, seconds, centiseconds);
	}
}

