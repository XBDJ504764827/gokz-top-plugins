void RegisterCommands()
{
	RegConsoleCmd("sm_example", CommandExample, "[GOKZ] Toggle or inspect the gokz-example finish summary option.");
	RegConsoleCmd("sm_gokzexample", CommandExample, "[GOKZ] Toggle or inspect the gokz-example finish summary option.");
}

public Action CommandExample(int client, int args)
{
	if (!IsValidClient(client))
	{
		ReplyToCommand(client, "[GOKZ Example] This command can only be used in-game.");
		return Plugin_Handled;
	}

	if (!gB_GOKZCoreReady)
	{
		ReplyToCommand(client, "[GOKZ Example] gokz-core is not available.");
		return Plugin_Handled;
	}

	if (args >= 1)
	{
		char arg[16];
		GetCmdArg(1, arg, sizeof(arg));

		if (StrEqual(arg, "status", false))
		{
			PrintExampleStatus(client);
			return Plugin_Handled;
		}

		if (!StrEqual(arg, "toggle", false))
		{
			GOKZ_PrintToChat(client, true, "%t", "Example Command - Usage");
			GOKZ_PlayErrorSound(client);
			return Plugin_Handled;
		}
	}

	GOKZ_CycleOption(client, EXAMPLE_OPTION_FINISH_SUMMARY);
	return Plugin_Handled;
}

void PrintExampleStatus(int client)
{
	if (IsFinishSummaryEnabled(client))
	{
		GOKZ_PrintToChat(client, true, "%t", "Example Command - Status Enabled");
	}
	else
	{
		GOKZ_PrintToChat(client, true, "%t", "Example Command - Status Disabled");
	}

	GOKZ_PrintToChat(client, false, "%t", "Example Command - Hint");
}

