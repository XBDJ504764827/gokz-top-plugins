TopMenu gTM_Options;
TopMenuObject gTMO_CatGeneral;
TopMenuObject gTMO_ItemFinishSummary;

void ResetOptionsMenu()
{
	gTM_Options = null;
	gTMO_CatGeneral = INVALID_TOPMENUOBJECT;
	gTMO_ItemFinishSummary = INVALID_TOPMENUOBJECT;
}

void OnOptionsMenuReady_OptionsMenu(TopMenu topMenu)
{
	if (gTM_Options == topMenu && gTMO_ItemFinishSummary != INVALID_TOPMENUOBJECT)
	{
		return;
	}

	gTM_Options = topMenu;
	gTMO_CatGeneral = gTM_Options.FindCategory(GENERAL_OPTION_CATEGORY);

	if (gTMO_CatGeneral == INVALID_TOPMENUOBJECT)
	{
		return;
	}

	gTMO_ItemFinishSummary = gTM_Options.AddItem(EXAMPLE_OPTION_FINISH_SUMMARY, TopMenuHandler_FinishSummary, gTMO_CatGeneral);
}

public void TopMenuHandler_FinishSummary(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength)
{
	if (topobj_id != gTMO_ItemFinishSummary)
	{
		return;
	}

	if (action == TopMenuAction_DisplayOption)
	{
		if (IsFinishSummaryEnabled(param))
		{
			FormatEx(buffer, maxlength, "%T - %T",
				"Options Menu - Example Finish Summary", param,
				"Options Menu - Enabled", param);
		}
		else
		{
			FormatEx(buffer, maxlength, "%T - %T",
				"Options Menu - Example Finish Summary", param,
				"Options Menu - Disabled", param);
		}
	}
	else if (action == TopMenuAction_SelectOption)
	{
		GOKZ_CycleOption(param, EXAMPLE_OPTION_FINISH_SUMMARY);
		gTM_Options.Display(param, TopMenuPosition_LastCategory);
	}
}

