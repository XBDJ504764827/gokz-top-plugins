GlobalForward gH_OnRankUpdated;

void CreateNatives()
{
	CreateNative("GOKZ_PF_GetRank", Native_GetRank);
}

void CreateGlobalForwards()
{
	gH_OnRankUpdated = new GlobalForward("GOKZ_PF_OnRankUpdated", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
}

void Call_OnRankUpdated(int client, int mode, int rank)
{
	Call_StartForward(gH_OnRankUpdated);
	Call_PushCell(client);
	Call_PushCell(mode);
	Call_PushCell(rank);
	Call_Finish();
}

public int Native_GetRank(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int mode = GetNativeCell(2);
	if (client <= 0 || client > MaxClients || mode < 0 || mode >= MODE_COUNT)
	{
		return 0;
	}

	return gI_Rank[client][mode];
}
