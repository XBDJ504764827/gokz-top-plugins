enum
{
	ExampleFinishSummary_Disabled = 0,
	ExampleFinishSummary_Enabled,
	EXAMPLEFINISHSUMMARY_COUNT
};

#define EXAMPLE_OPTION_FINISH_SUMMARY "GOKZ EX - Finish Summary"
#define EXAMPLE_OPTION_FINISH_SUMMARY_DESCRIPTION "Show an example finish summary in chat after a completed run - 0 = Disabled, 1 = Enabled"

bool gB_OptionRegistered;

void OnOptionsMenuReady_Options()
{
	RegisterOption();
}

void RegisterOption()
{
	if (GOKZ_GetOptionProp(EXAMPLE_OPTION_FINISH_SUMMARY, OptionProp_Type) != -1)
	{
		gB_OptionRegistered = true;
		return;
	}

	gB_OptionRegistered = GOKZ_RegisterOption(
		EXAMPLE_OPTION_FINISH_SUMMARY,
		EXAMPLE_OPTION_FINISH_SUMMARY_DESCRIPTION,
		OptionType_Int,
		ExampleFinishSummary_Enabled,
		0,
		EXAMPLEFINISHSUMMARY_COUNT - 1
	);
}

void OnOptionChanged_Options(int client, const char[] option, any newValue)
{
	if (!StrEqual(option, EXAMPLE_OPTION_FINISH_SUMMARY))
	{
		return;
	}

	switch (newValue)
	{
		case ExampleFinishSummary_Disabled:
		{
			GOKZ_PrintToChat(client, true, "%t", "Option - Example Finish Summary - Disable");
		}
		case ExampleFinishSummary_Enabled:
		{
			GOKZ_PrintToChat(client, true, "%t", "Option - Example Finish Summary - Enable");
		}
	}
}

bool IsFinishSummaryEnabled(int client)
{
	return gB_OptionRegistered && GOKZ_GetOption(client, EXAMPLE_OPTION_FINISH_SUMMARY) == ExampleFinishSummary_Enabled;
}

