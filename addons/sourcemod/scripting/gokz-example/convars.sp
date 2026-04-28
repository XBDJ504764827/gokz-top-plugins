void CreateConVars()
{
	AutoExecConfig_SetFile("gokz-example", "sourcemod/gokz");
	AutoExecConfig_SetCreateFile(true);

	gCV_gokz_example_broadcast_to_specs = AutoExecConfig_CreateConVar(
		"gokz_example_broadcast_to_specs",
		"0",
		"Broadcast example finish summaries to spectators following the player. 0 = disabled, 1 = enabled.",
		_,
		true,
		0.0,
		true,
		1.0
	);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
}

