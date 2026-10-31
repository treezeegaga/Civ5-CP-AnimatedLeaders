----------------------------------------------------------------
-- MP LEADERHEADS DIAGNOSTICS
-- Testing aid for the patched Community Patch DLL. Logs to Lua.log:
--   - the game state for 8s after every leader message
--     (CIV5_GS_LEADER_HEAD_VIEW means the EXE entered the 3D leader view)
--   - preload requests it sends itself at the start of the local player's turn
-- With the patched DLL the EXE's preload handler accepts requests in MP, so no
-- game type spoofing is needed here.
----------------------------------------------------------------

local g_TraceTimer = -1;
local g_TraceNext = 0;

function DiagLog( text )
	print( "[MPLeaderDiag] " .. text );
end

function DiagTraceState( label )
	local iState = UI.GetCurrentGameState();
	local name = tostring( iState );
	for k, v in pairs( GameStates ) do
		if v == iState then
			name = k;
		end
	end
	DiagLog( label .. ": game state " .. name .. ", network MP " .. tostring( Game.IsNetworkMultiPlayer() ) );
end

function DiagPreloadAll( reason )
	for iPlayer = 0, GameDefines.MAX_MAJOR_CIVS - 1 do
		local pPlayer = Players[iPlayer];
		if pPlayer ~= nil and pPlayer:IsAlive() and not pPlayer:IsHuman() and iPlayer ~= Game.GetActivePlayer() then
			local leaderInfo = GameInfo.Leaders[pPlayer:GetLeaderType()];
			if leaderInfo ~= nil and leaderInfo.ArtDefineTag ~= nil then
				Events.NotifyAILeaderInGame.CallImmediate( iPlayer, leaderInfo.ArtDefineTag );
				DiagLog( "preload requested (" .. reason .. "): player " .. iPlayer .. " " .. leaderInfo.ArtDefineTag );
			end
		end
	end
end

DiagTraceState( "loaded" );

Events.AILeaderMessage.Add( function( iPlayer, iDiploUIState )
	DiagTraceState( "leader message from player " .. iPlayer .. " (diplo state " .. iDiploUIState .. ")" );
	g_TraceTimer = 0;
	g_TraceNext = 0.5;
end );

Events.LeavingLeaderViewMode.Add( function() DiagTraceState( "leaving leader view" ); end );

-- Preload is gated by a global so a test run can compare with and without it.
-- Set to false (edit this file) to test the DLL's own preload on its own.
local g_bDiagPreload = true;

Events.ActivePlayerTurnStart.Add( function()
	DiagTraceState( "active player turn start" );
	if g_bDiagPreload then
		DiagPreloadAll( "turn start" );
	end
end );

-- LocalMachineAppUpdate ticks even while this context is hidden.
Events.LocalMachineAppUpdate.Add( function( tickCount, timeIncrement )
	if g_TraceTimer < 0 then
		return;
	end
	g_TraceTimer = g_TraceTimer + timeIncrement;
	if g_TraceTimer >= g_TraceNext then
		DiagTraceState( string.format( "t+%.1fs", g_TraceTimer ) );
		g_TraceNext = g_TraceNext + 1;
	end
	if g_TraceTimer > 8 then
		g_TraceTimer = -1;
	end
end );
