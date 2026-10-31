----------------------------------------------------------------
-- MP LEADER BACKDROP
-- In network multiplayer the exe never loads the 3D leader scene, so the
-- diplomacy screens sit on a grey background. Fill it with the leader's
-- Dawn of Man painting instead (or their portrait if the civ has none).
--
-- Needs the MPBackdrop controls from LeaderHeadRoot.xml and IconSupport.
----------------------------------------------------------------

local g_bBackdropEnabled = Game.IsNetworkMultiPlayer();
local g_iBackdropPlayer = -1;

print( "[MPLeaderScreens] loaded, backdrop enabled = " .. tostring( g_bBackdropEnabled ) );

function MPBackdropShow( iPlayer )
	if not g_bBackdropEnabled then
		return;
	end

	-- Already showing this leader: the AI is just moving between diplo states.
	if iPlayer == g_iBackdropPlayer and not Controls.MPBackdrop:IsHidden() then
		return;
	end
	g_iBackdropPlayer = iPlayer;

	local pPlayer = Players[iPlayer];
	local civInfo = GameInfo.Civilizations[pPlayer:GetCivilizationType()];
	local leaderInfo = GameInfo.Leaders[pPlayer:GetLeaderType()];

	Controls.MPBackdropImage:UnloadTexture();
	if civInfo ~= nil and civInfo.DawnOfManImage ~= nil and civInfo.DawnOfManImage ~= "" then
		Controls.MPBackdropImage:SetTexture( civInfo.DawnOfManImage );
		Controls.MPBackdropImage:SetHide( false );
		Controls.MPBackdropPortrait:SetHide( true );
	else
		Controls.MPBackdropImage:SetHide( true );
		Controls.MPBackdropPortrait:SetHide( false );
		if leaderInfo ~= nil then
			IconHookup( leaderInfo.PortraitIndex, 256, leaderInfo.IconAtlas, Controls.MPBackdropPortrait );
		end
	end

	Controls.MPBackdrop:SetHide( false );
	Controls.MPBackdropFade:SetToBeginning();
	Controls.MPBackdropFade:Play();
end

function MPBackdropHide()
	if not g_bBackdropEnabled then
		return;
	end
	g_iBackdropPlayer = -1;
	Controls.MPBackdrop:SetHide( true );
	Controls.MPBackdropImage:UnloadTexture();
end
