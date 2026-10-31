-- TEMPORARY probe: does the game core keep updating while a 3D leader screen is up in MP?
-- Logs once a second to Lua.log: game state, CvGame::update calls in that second (counted via
-- CP's GameCoreUpdateBegin hook), and whether the game reports itself paused.

local g_iUpdates = 0;
local g_fTimer = 0;

GameEvents.GameCoreUpdateBegin.Add( function() g_iUpdates = g_iUpdates + 1; end );

Events.LocalMachineAppUpdate.Add( function( tickCount, timeIncrement )
	g_fTimer = g_fTimer + timeIncrement;
	if g_fTimer < 1 then
		return;
	end
	local iState = UI.GetCurrentGameState();
	local name = tostring( iState );
	for k, v in pairs( GameStates ) do
		if v == iState then
			name = k;
		end
	end
	print( string.format( "[MPLeaderTick] %s: %d core updates/s, paused %s", name, g_iUpdates, tostring( Game.IsPaused() ) ) );
	g_iUpdates = 0;
	g_fTimer = 0;
end );
