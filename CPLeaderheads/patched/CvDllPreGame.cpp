/*	-------------------------------------------------------------------------------------------------------
	© 1991-2012 Take-Two Interactive Software and its subsidiaries.  Developed by Firaxis Games.  
	Sid Meier's Civilization V, Civ, Civilization, 2K Games, Firaxis Games, Take-Two Interactive Software 
	and their respective logos are all trademarks of Take-Two interactive Software, Inc.  
	All other marks and trademarks are the property of their respective owners.  
	All rights reserved. 
	------------------------------------------------------------------------------------------------------- */
#include "CvGameCoreDLLPCH.h"
#include "CvDllPreGame.h"
#include "CvDllContext.h"
#include "CvDllDlcPackageInfo.h"
#include "CvDllWorldInfo.h"
#include "CvPreGame.h"

CvDllPreGame::CvDllPreGame()
{
}
//------------------------------------------------------------------------------
CvDllPreGame::~CvDllPreGame()
{
}
//------------------------------------------------------------------------------
void* CvDllPreGame::QueryInterface(GUID guidInterface)
{
	if(guidInterface == ICvUnknown::GetInterfaceId() ||
		guidInterface == ICvPreGame1::GetInterfaceId() ||
		guidInterface == ICvPreGame2::GetInterfaceId())
	{
		return this;
	}

	return NULL;
}
//------------------------------------------------------------------------------
void CvDllPreGame::Destroy()
{
	delete this;
}
//------------------------------------------------------------------------------
void CvDllPreGame::operator delete(void* p)
{
	CvDllGameContext::Free(p);
}
//------------------------------------------------------------------------------
void* CvDllPreGame::operator new(size_t bytes)
{
	return CvDllGameContext::Allocate(bytes);
}
//------------------------------------------------------------------------------
PlayerTypes CvDllPreGame::activePlayer()
{
	return CvPreGame::activePlayer();
}
//------------------------------------------------------------------------------
int CvDllPreGame::advancedStartPoints()
{
	return -1;
}
//------------------------------------------------------------------------------
bool CvDllPreGame::autorun()
{
	return CvPreGame::autorun();
}
//------------------------------------------------------------------------------
float CvDllPreGame::autorunTurnDelay()
{
	return CvPreGame::autorunTurnDelay();
}
//------------------------------------------------------------------------------
int CvDllPreGame::autorunTurnLimit()
{
	return CvPreGame::autorunTurnLimit();
}
//------------------------------------------------------------------------------
CalendarTypes CvDllPreGame::calendar()
{
	return CvPreGame::calendar();
}
//------------------------------------------------------------------------------
bool CvDllPreGame::canReadyLocalPlayer()
{
	return CvPreGame::canReadyLocalPlayer();
}
//------------------------------------------------------------------------------
CvString CvDllPreGame::civilizationAdjective(PlayerTypes p)
{
	return CvPreGame::civilizationAdjective(p);
}
//------------------------------------------------------------------------------
const CvString CvDllPreGame::civilizationAdjectiveKey(PlayerTypes p)
{
	return CvPreGame::civilizationAdjectiveKey(p);
}
//------------------------------------------------------------------------------
CvString CvDllPreGame::civilizationDescription(PlayerTypes p)
{
	return CvPreGame::civilizationDescription(p);
}
//------------------------------------------------------------------------------
const CvString CvDllPreGame::civilizationDescriptionKey(PlayerTypes p)
{
	return CvPreGame::civilizationDescriptionKey(p);
}
//------------------------------------------------------------------------------
CivilizationTypes CvDllPreGame::civilization(PlayerTypes p)
{
	return CvPreGame::civilization(p);
}
//------------------------------------------------------------------------------
const CvString CvDllPreGame::civilizationPassword(PlayerTypes p)
{
	return CvPreGame::civilizationPassword(p);
}
//------------------------------------------------------------------------------
CvString CvDllPreGame::civilizationShortDescription(PlayerTypes p)
{
	return CvPreGame::civilizationShortDescription(p);
}
//------------------------------------------------------------------------------
const CvString CvDllPreGame::civilizationShortDescriptionKey(PlayerTypes p)
{
	return CvPreGame::civilizationShortDescriptionKey(p);
}
//------------------------------------------------------------------------------
const CvString CvDllPreGame::civilizationKey(PlayerTypes p)
{
	return CvPreGame::civilizationKey(p);
}
//------------------------------------------------------------------------------
bool CvDllPreGame::civilizationKeyAvailable(PlayerTypes p)
{
	return CvPreGame::civilizationKeyAvailable(p);
}
//------------------------------------------------------------------------------
const GUID CvDllPreGame:: civilizationKeyPackageID(PlayerTypes p)
{
	return CvPreGame:: civilizationKeyPackageID(p);
}
//------------------------------------------------------------------------------
void CvDllPreGame::clearDLCAllowed()
{
	CvPreGame::clearDLCAllowed();
}
//------------------------------------------------------------------------------
ClimateTypes CvDllPreGame::climate()
{
	return CvPreGame::climate();
}
//------------------------------------------------------------------------------
void CvDllPreGame::closeAllSlots()
{
	CvPreGame::closeAllSlots();
}
//------------------------------------------------------------------------------
void CvDllPreGame::closeInactiveSlots()
{
	CvPreGame::closeInactiveSlots();
}
//------------------------------------------------------------------------------
const CvString CvDllPreGame::emailAddress(PlayerTypes p)
{
	return CvPreGame::emailAddress(p);
}
//------------------------------------------------------------------------------
const CvString CvDllPreGame::emailAddress()
{
	return CvPreGame::emailAddress();
}
//------------------------------------------------------------------------------
float CvDllPreGame::endTurnTimerLength()
{
	return CvPreGame::endTurnTimerLength();
}
//------------------------------------------------------------------------------
EraTypes CvDllPreGame::era()
{
	return CvPreGame::era();
}
//------------------------------------------------------------------------------
PlayerTypes CvDllPreGame::findPlayerByNickname(const char* const name)
{
	return CvPreGame::findPlayerByNickname(name);
}
//------------------------------------------------------------------------------
GameMode CvDllPreGame::gameMode()
{
	return CvPreGame::gameMode();
}
//------------------------------------------------------------------------------
const CvString CvDllPreGame::gameName()
{
	return CvPreGame::gameName();
}
//------------------------------------------------------------------------------
bool CvDllPreGame::gameStarted()
{
	return CvPreGame::gameStarted();
}
//------------------------------------------------------------------------------
bool CvDllPreGame::GetGameOption(const char* szOptionName, int& iValue)
{
	return CvPreGame::GetGameOption(szOptionName, iValue);
}
//------------------------------------------------------------------------------
bool CvDllPreGame::GetGameOption(GameOptionTypes eOption, int& iValue)
{
	return CvPreGame::GetGameOption(eOption, iValue);
}
//------------------------------------------------------------------------------
uint CvDllPreGame::GetGameOptionCount()
{
	return CvPreGame::GetGameOptions().size();
}
//------------------------------------------------------------------------------
bool CvDllPreGame::GetGameOption(uint uiIndex, char* szOptionNameBuffer, uint nOptionNameBufferSize, int& iValue)
{
	const std::vector<CvPreGame::CustomOption>& kOptions = CvPreGame::GetGameOptions();
	if(uiIndex < kOptions.size())
	{
		size_t nSourceBufferSize = 0;
		const char* pszSourceBuffer = kOptions[uiIndex].GetName(nSourceBufferSize);
		if(nOptionNameBufferSize+1 > nSourceBufferSize)
		{
			strcpy(szOptionNameBuffer, pszSourceBuffer);
			iValue = kOptions[uiIndex].GetValue();
			return true;
		}
	}
	return false;
}
//------------------------------------------------------------------------------
uint CvDllPreGame::GetMapOptionCount()
{
	return CvPreGame::GetMapOptions().size();
}
//------------------------------------------------------------------------------
bool CvDllPreGame::GetMapOption(uint uiIndex, char* szOptionNameBuffer, uint nOptionNameBufferSize, int& iValue)
{
	const std::vector<CvPreGame::CustomOption>& kOptions = CvPreGame::GetMapOptions();
	if(uiIndex < kOptions.size())
	{
		size_t nSourceBufferSize = 0;
		const char* pszSourceBuffer = kOptions[uiIndex].GetName(nSourceBufferSize);
		if(nOptionNameBufferSize+1 > nSourceBufferSize)
		{
			strcpy(szOptionNameBuffer, pszSourceBuffer);
			iValue = kOptions[uiIndex].GetValue();
			return true;
		}
	}
	return false;
}
//------------------------------------------------------------------------------
bool CvDllPreGame::GetMapOption(const char* szOptionName, int& iValue)
{
	return CvPreGame::GetMapOption(szOptionName, iValue);
}
//------------------------------------------------------------------------------
bool CvDllPreGame::GetPersistSettings()
{
	return CvPreGame::GetPersistSettings();
}
//------------------------------------------------------------------------------
GameSpeedTypes CvDllPreGame::gameSpeed()
{
	return CvPreGame::gameSpeed();
}
//------------------------------------------------------------------------------
int CvDllPreGame::gameTurn()
{
	return CvPreGame::gameTurn();
}
//------------------------------------------------------------------------------
GameTypes CvDllPreGame::gameType()
{
	return CvPreGame::gameType();
}
//------------------------------------------------------------------------------
GameStartTypes CvDllPreGame::gameStartType()
{
	return CvPreGame::gameStartType();
}
//------------------------------------------------------------------------------
HandicapTypes CvDllPreGame::handicap(PlayerTypes p)
{
	return CvPreGame::handicap(p);
}
//------------------------------------------------------------------------------
bool CvDllPreGame::isDLCAllowed(const GUID& kDLCID)
{
	return CvPreGame::isDLCAllowed(kDLCID);
}
//------------------------------------------------------------------------------
bool CvDllPreGame::isDLCAvailable(PlayerTypes p, const GUID& kDLCID)
{
	return CvPreGame::isDLCAvailable(p, kDLCID);
}
//------------------------------------------------------------------------------
bool CvDllPreGame::isEarthMap()
{
	//This function is no longer used, it only exists for interface compatibility.
	return false;
}
//------------------------------------------------------------------------------
bool CvDllPreGame::isHotSeat()
{
	return CvPreGame::isHotSeat();
}
//------------------------------------------------------------------------------
bool CvDllPreGame::isHotSeatGame()
{
	return CvPreGame::isHotSeatGame();
}
//------------------------------------------------------------------------------
bool CvDllPreGame::isHuman(PlayerTypes p)
{
	return CvPreGame::isHuman(p);
}
//------------------------------------------------------------------------------
bool CvDllPreGame::isInternetGame()
{
	return CvPreGame::isInternetGame();
}
//------------------------------------------------------------------------------
bool CvDllPreGame::isMinorCiv(PlayerTypes p)
{
	return CvPreGame::isMinorCiv(p);
}
//------------------------------------------------------------------------------
#if defined(__clang__)
#define LEADERHEAD_RETURN_ADDRESS() __builtin_return_address(0)
#elif defined(_MSC_VER)
#define LEADERHEAD_RETURN_ADDRESS() _ReturnAddress()
#endif

// MP_LEADERHEADS: the EXE's leaderhead system refuses to load or show 3D leader scenes when this
// returns true. Four call sites decide that (all four "call [PreGame vtable + 0xD4]"):
//   - GameplayDiplomacyAILeaderMessage: enter the leader view, or only open the 2D UI
//   - the RequestLeaveLeader handler: return to the previous game state, or not
//   - the NotifyAILeaderInGame handler: load a leader's scene file
//   - the leader message handler: activate a loaded scene and play its animation
// Answering "not network MP" to just these call sites enables 3D leaders in MP. Gameplay code
// reads CvPreGame directly and never comes through here, so nothing synced is affected.
//
// Taking the single player path when entering the leader view also pauses the game core thread:
// the EXE increments a counter (InterlockedIncrement) that the game core update loop checks
// before calling CvDllGame::Update, and the leader view's End decrements it again if it is
// non-zero. The increment follows the enter site directly with no call back into the DLL in
// between, so in network MP the counter is set to -1 there and the increment brings it back to 0.
// As a safety net it is also cleared at the activate and leave sites.
//
// That alone is not enough: only the map view's Update (GameViewState) runs the game core. Each
// frame it adds the frame time to a timer and, once the timer passes the update interval, calls
// the EXE function that schedules the "Game Core" task (or runs CvGame::update directly on a
// single core). The leader view never does, so in network MP this player's simulation would stop
// for as long as they talk. UpdateGameCoreInLeaderScene does the same thing while a leader scene
// is up; the in-game UI calls it every frame through Game.UpdateCoreInLeaderScene.
//
// Addresses are at the EXE's preferred image base (0x400000), one entry per binary variant: the
// return addresses of the four call sites, ordered as above, the pause counter, the application
// global (the map view object is at +0x1460), the map view's game core timer, and the function
// that runs the game core.
enum LeaderheadCallSite
{
	LEADERHEAD_SITE_ENTER,
	LEADERHEAD_SITE_LEAVE,
	LEADERHEAD_SITE_PRELOAD,
	LEADERHEAD_SITE_ACTIVATE,
	NUM_LEADERHEAD_SITES
};
struct LeaderheadExeAddresses
{
	DWORD aCallSites[NUM_LEADERHEAD_SITES];
	DWORD uiPauseCounter;
	DWORD uiAppGlobal;
	DWORD uiGameCoreTimer;
	DWORD uiRunGameCore;
};
static const LeaderheadExeAddresses s_kLeaderheadDX11 = { { 0x0051b2cc, 0x005db1ab, 0x005985d1, 0x006ec841 }, 0x02de044c, 0x00cc8e74, 0x00ccf91c, 0x0053af10 };
static const LeaderheadExeAddresses s_kLeaderheadDX9 = { { 0x007b24ac, 0x00428ecb, 0x00460781, 0x0049d3e1 }, 0x02dd024c, 0x00cb8cf4, 0x00cbf764, 0x00535b30 };
static const LeaderheadExeAddresses s_kLeaderheadTablet = { { 0x006ce90c, 0x0079977b, 0x004f15c1, 0x0072d6e1 }, 0x02de2434, 0x00cca8f0, 0x00cd139c, 0x005ddc50 };

static const LeaderheadExeAddresses* s_pLeaderheadAddresses = NULL;
static DWORD s_uiLeaderheadExeBase = 0;
// Set at the enter site and cleared at the leave site, in network MP only.
static bool s_bInLeaderScene = false;

static void InitLeaderheadAddresses()
{
#ifdef WIN32
	// The EXE can't change while the DLL is loaded, so work out the variant once.
	static bool s_bInitialized = false;
	if (s_bInitialized)
		return;
	char moduleName[1024];
	if (GetModuleFileName(NULL, moduleName, sizeof(moduleName)))
	{
		size_t len = strlen(moduleName);
		if (len >= 17 && _stricmp(moduleName + len - 17, "CivilizationV.exe") == 0)
			s_pLeaderheadAddresses = &s_kLeaderheadDX9;
		else if (len >= 22 && _stricmp(moduleName + len - 22, "CivilizationV_DX11.exe") == 0)
			s_pLeaderheadAddresses = &s_kLeaderheadDX11;
		else if (len >= 24 && _stricmp(moduleName + len - 24, "CivilizationV_Tablet.exe") == 0)
			s_pLeaderheadAddresses = &s_kLeaderheadTablet;
	}
	s_uiLeaderheadExeBase = (DWORD)GetModuleHandleA(NULL);
	s_bInitialized = true;
#endif
}

// Same rebasing as CvDllGame::InitExeStuff: preferred-base address -> RVA -> actual address.
static DWORD RebaseLeaderheadAddress(DWORD uiPreferred)
{
	return s_uiLeaderheadExeBase + (uiPreferred - 0x400000);
}

// Which leaderhead call site (LeaderheadCallSite) a return address belongs to, or -1.
static int GetLeaderheadCallSite(void* pReturnAddress)
{
	InitLeaderheadAddresses();
	if (s_pLeaderheadAddresses == NULL)
		return -1;

	DWORD uiReturnAddr = (DWORD)pReturnAddress;
	for (int i = 0; i < NUM_LEADERHEAD_SITES; i++)
	{
		if (uiReturnAddr == RebaseLeaderheadAddress(s_pLeaderheadAddresses->aCallSites[i]))
			return i;
	}
	return -1;
}

bool CvDllPreGame::isNetworkMultiplayerGame()
{
	// Check the call site first: it is cheap and false for every caller but four, so
	// gCustomMods is only read from inside a running game.
	int iSite = GetLeaderheadCallSite(LEADERHEAD_RETURN_ADDRESS());
	if (iSite >= 0 && MOD_MP_LEADERHEADS)
	{
		if (iSite != LEADERHEAD_SITE_PRELOAD && CvPreGame::isNetworkMultiplayerGame())
		{
			volatile LONG* pPauseCounter = reinterpret_cast<volatile LONG*>(RebaseLeaderheadAddress(s_pLeaderheadAddresses->uiPauseCounter));
			InterlockedExchange(pPauseCounter, iSite == LEADERHEAD_SITE_ENTER ? -1 : 0);
			if (iSite == LEADERHEAD_SITE_ENTER)
				s_bInLeaderScene = true;
			else if (iSite == LEADERHEAD_SITE_LEAVE)
				s_bInLeaderScene = false;
		}
		return false;
	}

	return CvPreGame::isNetworkMultiplayerGame();
}

// Runs the game core the way the map view's Update does (see above). Main thread only.
void UpdateGameCoreInLeaderScene(float fDeltaTime)
{
#ifdef WIN32
	if (!s_bInLeaderScene || s_pLeaderheadAddresses == NULL || !MOD_MP_LEADERHEADS || !CvPreGame::isNetworkMultiplayerGame())
		return;

	char* pApp = *reinterpret_cast<char**>(RebaseLeaderheadAddress(s_pLeaderheadAddresses->uiAppGlobal));
	if (pApp == NULL)
		return;
	void* pGameView = *reinterpret_cast<void**>(pApp + 0x1460);
	if (pGameView == NULL)
		return;

	// __thiscall functions, called as __fastcall with an unused edx.
	typedef float (__fastcall *GetIntervalFn)(void* pThis, void* pUnused);
	typedef bool (__fastcall *IsBlockedFn)(void* pThis, void* pUnused);
	typedef void (__fastcall *RunGameCoreFn)(void* pThis, void* pUnused, int bArg);
	void** pVtable = *reinterpret_cast<void***>(pGameView);
	GetIntervalFn pGetInterval = reinterpret_cast<GetIntervalFn>(pVtable[0x198 / sizeof(void*)]);
	IsBlockedFn pIsBlocked = reinterpret_cast<IsBlockedFn>(pVtable[0x3a4 / sizeof(void*)]);
	RunGameCoreFn pRunGameCore = reinterpret_cast<RunGameCoreFn>(RebaseLeaderheadAddress(s_pLeaderheadAddresses->uiRunGameCore));

	float* pfTimer = reinterpret_cast<float*>(RebaseLeaderheadAddress(s_pLeaderheadAddresses->uiGameCoreTimer));
	bool bBlocked = pIsBlocked(pGameView, NULL);
	*pfTimer += fDeltaTime;
	if (*pfTimer > pGetInterval(pGameView, NULL))
	{
		if (!bBlocked)
			pRunGameCore(pGameView, NULL, 1);
		*pfTimer = 0.0f;
	}
#else
	(void)fDeltaTime;
#endif
}
//------------------------------------------------------------------------------
bool CvDllPreGame::isPitBoss()
{
	return CvPreGame::isPitBoss();
}
//------------------------------------------------------------------------------
bool CvDllPreGame::isPlayable(PlayerTypes p)
{
	return CvPreGame::isPlayable(p);
}
//------------------------------------------------------------------------------
bool CvDllPreGame::isPlayByEmail()
{
	return CvPreGame::isPlayByEmail();
}
//------------------------------------------------------------------------------
bool CvDllPreGame::isReady(PlayerTypes p)
{
	return CvPreGame::isReady(p);
}
//------------------------------------------------------------------------------
bool CvDllPreGame::isVictory(VictoryTypes v)
{
	return CvPreGame::isVictory(v);
}
//------------------------------------------------------------------------------
bool CvDllPreGame::isWBMapScript()
{
	return CvPreGame::isWBMapScript();
}
//------------------------------------------------------------------------------
bool CvDllPreGame::isWhiteFlag(PlayerTypes p)
{
	return CvPreGame::isWhiteFlag(p);
}
//------------------------------------------------------------------------------
LeaderHeadTypes CvDllPreGame::leaderHead(PlayerTypes p)
{
	return CvPreGame::leaderHead(p);
}
//------------------------------------------------------------------------------
CvString CvDllPreGame::leaderName(PlayerTypes p)
{
	return CvPreGame::leaderName(p);
}
//------------------------------------------------------------------------------
const CvString CvDllPreGame::leaderNameKey(PlayerTypes p)
{
	return CvPreGame::leaderNameKey(p);
}
//------------------------------------------------------------------------------
const CvString CvDllPreGame::leaderKey(PlayerTypes p)
{
	return CvPreGame::leaderKey(p);
}
//------------------------------------------------------------------------------
bool CvDllPreGame::leaderKeyAvailable(PlayerTypes p)
{
	return CvPreGame::leaderKeyAvailable(p);
}
//------------------------------------------------------------------------------
const GUID CvDllPreGame::leaderKeyPackageID(PlayerTypes p)
{
	return CvPreGame::leaderKeyPackageID(p);
}
//------------------------------------------------------------------------------
const CvString CvDllPreGame::loadFileName()
{
	return CvPreGame::loadFileName();
}
//------------------------------------------------------------------------------
void CvDllPreGame::loadFromIni(FIGameIniParser& iniParser)
{
	CvPreGame::loadFromIni(iniParser);
}
//------------------------------------------------------------------------------
bool CvDllPreGame::mapNoPlayers()
{
	return CvPreGame::mapNoPlayers();
}
//------------------------------------------------------------------------------
unsigned int CvDllPreGame::mapRandomSeed()
{
	return CvPreGame::mapRandomSeed();
}
//------------------------------------------------------------------------------
bool CvDllPreGame::loadWBScenario()
{
	return CvPreGame::loadWBScenario();
}
//------------------------------------------------------------------------------
bool CvDllPreGame::overrideScenarioHandicap()
{
	return CvPreGame::overrideScenarioHandicap();
}
//------------------------------------------------------------------------------
const CvString CvDllPreGame::mapScriptName()
{
	return CvPreGame::mapScriptName();
}
//------------------------------------------------------------------------------
int CvDllPreGame::maxCityElimination()
{
	return CvPreGame::maxCityElimination();
}
//------------------------------------------------------------------------------
int CvDllPreGame::maxTurns()
{
	return CvPreGame::maxTurns();
}
//------------------------------------------------------------------------------
MinorCivTypes CvDllPreGame::minorCivType(PlayerTypes p)
{
	return CvPreGame::minorCivType(p);
}
//------------------------------------------------------------------------------
bool CvDllPreGame::multiplayerAIEnabled()
{
	return CvPreGame::multiplayerAIEnabled();
}
//------------------------------------------------------------------------------
int CvDllPreGame::netID(PlayerTypes p)
{
	return CvPreGame::netID(p);
}
//------------------------------------------------------------------------------
const CvString CvDllPreGame::nickname(PlayerTypes p)
{
	return CvPreGame::nickname(p);
}
//------------------------------------------------------------------------------
const CvString CvDllPreGame::nicknameDisplayed(PlayerTypes p)
{
	return CvPreGame::nicknameDisplayed(p);
}
//------------------------------------------------------------------------------
int CvDllPreGame::numMinorCivs()
{
	return CvPreGame::numMinorCivs();
}
//------------------------------------------------------------------------------
PlayerColorTypes CvDllPreGame::playerColor(PlayerTypes p)
{
	return CvPreGame::playerColor(p);
}
//------------------------------------------------------------------------------
bool CvDllPreGame::privateGame()
{
	return CvPreGame::privateGame();
}
//------------------------------------------------------------------------------
bool CvDllPreGame::quickCombat()
{
	return CvPreGame::quickCombat();
}
//------------------------------------------------------------------------------
bool CvDllPreGame::quickMovement()
{
	return CvPreGame::quickMovement();
}
//------------------------------------------------------------------------------
bool CvDllPreGame::quickstart()
{
	return CvPreGame::quickstart();
}
//------------------------------------------------------------------------------
bool CvDllPreGame::randomWorldSize()
{
	return CvPreGame::randomWorldSize();
}
//------------------------------------------------------------------------------
bool CvDllPreGame::randomMapScript()
{
	return CvPreGame::randomMapScript();
}
//------------------------------------------------------------------------------
void CvDllPreGame::read(FDataStream& loadFrom, bool bReadVersion)
{
	CvPreGame::read(loadFrom, bReadVersion);
}
//------------------------------------------------------------------------------
bool CvDllPreGame::readPlayerSlotInfo(FDataStream& loadFrom, bool bReadVersion)
{
	return CvPreGame::readPlayerSlotInfo(loadFrom, bReadVersion);
}
//------------------------------------------------------------------------------
void CvDllPreGame::resetGame()
{
	CvPreGame::resetGame();
}
//------------------------------------------------------------------------------
void CvDllPreGame::ResetGameOptions()
{
	CvPreGame::ResetGameOptions();
}
//------------------------------------------------------------------------------
void CvDllPreGame::ResetMapOptions()
{
	CvPreGame::ResetMapOptions();
}
//------------------------------------------------------------------------------
void CvDllPreGame::resetPlayer(PlayerTypes p)
{
	CvPreGame::resetPlayer(p);
}
//------------------------------------------------------------------------------
void CvDllPreGame::resetPlayers()
{
	CvPreGame::resetPlayers();
}
//------------------------------------------------------------------------------
void CvDllPreGame::resetSlots()
{
	CvPreGame::resetSlots();
}
//------------------------------------------------------------------------------
void CvDllPreGame::restoreSlots()
{
	CvPreGame::restoreSlots();
}
//------------------------------------------------------------------------------
void CvDllPreGame::saveSlots()
{
	CvPreGame::saveSlots();
}
//------------------------------------------------------------------------------
SeaLevelTypes CvDllPreGame::seaLevel()
{
	return CvPreGame::seaLevel();
}
//------------------------------------------------------------------------------
void CvDllPreGame::setActivePlayer(PlayerTypes p)
{
	CvPreGame::setActivePlayer(p);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setAdminPassword(const CvString& p)
{
	CvPreGame::setAdminPassword(p);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setAdvancedStartPoints(int a)
{
	// Disabled
}
//------------------------------------------------------------------------------
void CvDllPreGame::setAlias(const CvString& a)
{
	CvPreGame::setAlias(a);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setAutorun(bool isAutoStart)
{
	CvPreGame::setAutorun(isAutoStart);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setAutorunTurnDelay(float turnDelay)
{
	CvPreGame::setAutorunTurnDelay(turnDelay);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setAutorunTurnLimit(int turnLimit)
{
	CvPreGame::setAutorunTurnLimit(turnLimit);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setBandwidth(BandwidthType b)
{
	CvPreGame::setBandwidth(b);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setBandwidth(const CvString& b)
{
	CvPreGame::setBandwidth(b);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setCalendar(CalendarTypes c)
{
	CvPreGame::setCalendar(c);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setCalendar(const CvString& c)
{
	CvPreGame::setCalendar(c);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setCivilization(PlayerTypes p, CivilizationTypes c)
{
	CvPreGame::setCivilization(p, c);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setCivilizationAdjective(PlayerTypes p, const CvString& a)
{
	CvPreGame::setCivilizationAdjective(p, a);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setCivilizationDescription(PlayerTypes p, const CvString& d)
{
	CvPreGame::setCivilizationDescription(p, d);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setCivilizationPassword(PlayerTypes p, const CvString& pwd)
{
	CvPreGame::setCivilizationPassword(p, pwd);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setCivilizationShortDescription(PlayerTypes p, const CvString& d)
{
	CvPreGame::setCivilizationShortDescription(p, d);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setCivilizationKey(PlayerTypes p, const CvString& d)
{
	CvPreGame::setCivilizationKey(p, d);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setCivilizationKeyPackageID(PlayerTypes p, const GUID& kKey)
{
	CvPreGame::setCivilizationKeyPackageID(p, kKey);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setClimate(ClimateTypes c)
{
	CvPreGame::setClimate(c);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setClimate(const CvString& c)
{
	CvPreGame::setClimate(c);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setCustomWorldSize(int iWidth, int iHeight, int iPlayers, int iMinorCivs)
{
	CvPreGame::setCustomWorldSize(iWidth, iHeight, iPlayers, iMinorCivs);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setDLCAllowed(const GUID& kDLCID, bool bState)
{
	CvPreGame::setDLCAllowed(kDLCID, bState);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setEarthMap(bool bIsEarthMap)
{
	//This function is no longer used, it only exists for interface compatibility.
}
//------------------------------------------------------------------------------
void CvDllPreGame::setEmailAddress(PlayerTypes p, const CvString& a)
{
	CvPreGame::setEmailAddress(p, a);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setEmailAddress(const CvString& a)
{
	CvPreGame::setEmailAddress(a);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setEndTurnTimerLength(float f)
{
	CvPreGame::setEndTurnTimerLength(f);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setEra(EraTypes e)
{
	CvPreGame::setEra(e);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setEra(const CvString& e)
{
	CvPreGame::setEra(e);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setGameMode(GameMode g)
{
	CvPreGame::setGameMode(g);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setGameName(const CvString& g)
{
	CvPreGame::setGameName(g);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setGameSpeed(GameSpeedTypes g)
{
	CvPreGame::setGameSpeed(g);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setGameSpeed(const CvString& g)
{
	CvPreGame::setGameSpeed(g);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setGameStarted(bool bStarted)
{
	CvPreGame::setGameStarted(bStarted);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setGameTurn(int turn)
{
	CvPreGame::setGameTurn(turn);
}
//------------------------------------------------------------------------------
bool CvDllPreGame::SetGameOption(const char* szOptionName, int iValue)
{
	return CvPreGame::SetGameOption(szOptionName, iValue);
}
//------------------------------------------------------------------------------
bool CvDllPreGame::SetGameOption(GameOptionTypes eOption, int iValue)
{
	return CvPreGame::SetGameOption(eOption, iValue);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setGameType(GameTypes g)
{
	CvPreGame::setGameType(g);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setGameType(GameTypes g, GameStartTypes eStartType)
{
	CvPreGame::setGameType(g, eStartType);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setGameType(const CvString& g)
{
	CvPreGame::setGameType(g);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setGameStartType(GameStartTypes g)
{
	CvPreGame::setGameStartType(g);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setGameUpdateTime(int updateTime)
{
	CvPreGame::setGameUpdateTime(updateTime);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setHandicap(PlayerTypes p, HandicapTypes h)
{
	CvPreGame::setHandicap(p, h);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setInternetGame(bool isInternetGame)
{
	CvPreGame::setInternetGame(isInternetGame);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setLeaderHead(PlayerTypes p, LeaderHeadTypes l)
{
	CvPreGame::setLeaderHead(p, l);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setLeaderName(PlayerTypes p, const CvString& n)
{
	CvPreGame::setLeaderName(p, n);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setLeaderKey(PlayerTypes p, const CvString& n)
{
	CvPreGame::setLeaderKey(p, n);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setLeaderKeyPackageID(PlayerTypes p, const GUID& n)
{
	CvPreGame::setLeaderKeyPackageID(p, n);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setLoadFileName(const CvString& fileName)
{
	CvPreGame::setLoadFileName(fileName);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setMapNoPlayers(bool p)
{
	CvPreGame::setMapNoPlayers(p);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setMapRandomSeed(unsigned int newSeed)
{
	CvPreGame::setMapRandomSeed(newSeed);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setLoadWBScenario(bool b)
{
	CvPreGame::setLoadWBScenario(b);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setOverrideScenarioHandicap(bool b)
{
	CvPreGame::setOverrideScenarioHandicap(b);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setMapScriptName(const CvString& s)
{
	CvPreGame::setMapScriptName(s);
}
//------------------------------------------------------------------------------
bool CvDllPreGame::SetMapOption(const char* szOptionName, int iValue)
{
	return CvPreGame::SetMapOption(szOptionName, iValue);
}
//------------------------------------------------------------------------------
//bool CvDllPreGame::SetMapOptions(const std::vector<CustomOption>& mapOptions)
//{
//	CvPreGame::SetMapOptions();
//}
//------------------------------------------------------------------------------
void CvDllPreGame::setMaxCityElimination(int m)
{
	CvPreGame::setMaxCityElimination(m);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setMaxTurns(int maxTurns)
{
	CvPreGame::setMaxTurns(maxTurns);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setMinorCivType(PlayerTypes p, MinorCivTypes m)
{
	CvPreGame::setMinorCivType(p, m);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setMinorCiv(PlayerTypes p, bool isMinor)
{
	CvPreGame::setMinorCiv(p, isMinor);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setMultiplayerAIEnabled(bool isEnabled)
{
	CvPreGame::setMultiplayerAIEnabled(isEnabled);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setNetID(PlayerTypes p, int id)
{
	CvPreGame::setNetID(p, id);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setNickname(PlayerTypes p, const CvString& n)
{
	CvPreGame::setNickname(p, n);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setNumMinorCivs(int n)
{
	CvPreGame::setNumMinorCivs(n);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setPersistSettings(bool bPersist)
{
	CvPreGame::setPersistSettings(bPersist);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setPlayable(PlayerTypes p, bool playable)
{
	CvPreGame::setPlayable(p, playable);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setPlayerColor(PlayerTypes p, PlayerColorTypes c)
{
	CvPreGame::setPlayerColor(p, c);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setPrivateGame(bool isPrivateGame)
{
	CvPreGame::setPrivateGame(isPrivateGame);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setQuickCombat(bool isQuickCombat)
{
	CvPreGame::setQuickCombat(isQuickCombat);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setQuickMovement(bool isQuickMovement)
{
	CvPreGame::setQuickMovement(isQuickMovement);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setQuickHandicap(HandicapTypes h)
{
	CvPreGame::setQuickHandicap(h);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setQuickHandicap(const CvString& h)
{
	CvPreGame::setQuickHandicap(h);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setQuickstart(bool isQuickStart)
{
	CvPreGame::setQuickstart(isQuickStart);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setRandomWorldSize(bool isRandomWorldSize)
{
	CvPreGame::setRandomWorldSize(isRandomWorldSize);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setRandomMapScript(bool isRandomWorldScript)
{
	CvPreGame::setRandomMapScript(isRandomWorldScript);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setReady(PlayerTypes p, bool bIsReady)
{
	CvPreGame::setReady(p, bIsReady);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setSeaLevel(SeaLevelTypes s)
{
	CvPreGame::setSeaLevel(s);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setSeaLevel(const CvString& s)
{
	CvPreGame::setSeaLevel(s);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setSlotClaim(PlayerTypes p, SlotClaim c)
{
	CvPreGame::setSlotClaim(p, c);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setSlotStatus(PlayerTypes eID, SlotStatus eSlotStatus)
{
	CvPreGame::setSlotStatus(eID, eSlotStatus);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setSyncRandomSeed(unsigned int newSeed)
{
	CvPreGame::setSyncRandomSeed(newSeed);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setTeamType(PlayerTypes p, TeamTypes t)
{
	CvPreGame::setTeamType(p, t);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setTransferredMap(bool transferred)
{
	CvPreGame::setTransferredMap(transferred);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setTurnTimer(TurnTimerTypes t)
{
	CvPreGame::setTurnTimer(t);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setTurnTimer(const CvString& t)
{
	CvPreGame::setTurnTimer(t);
}
//------------------------------------------------------------------------------
void CvDllPreGame::SetCityScreenBlocked(bool bCityScreenBlocked)
{
	CvPreGame::SetCityScreenBlocked(bCityScreenBlocked);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setVersionString(const std::string& v)
{
	CvPreGame::setVersionString(v);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setVictory(VictoryTypes v, bool isValid)
{
	CvPreGame::setVictory(v, isValid);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setVictories(const std::vector<bool>& v)
{
	CvPreGame::setVictories(v);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setWhiteFlag(PlayerTypes p, bool flag)
{
	CvPreGame::setWhiteFlag(p, flag);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setWorldSize(WorldSizeTypes w, bool bResetSlots)
{
	CvPreGame::setWorldSize(w, bResetSlots);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setWorldSize(const CvString& w)
{
	CvPreGame::setWorldSize(w);
}
//------------------------------------------------------------------------------
SlotClaim CvDllPreGame::slotClaim(PlayerTypes p)
{
	return CvPreGame::slotClaim(p);
}
//------------------------------------------------------------------------------
SlotStatus CvDllPreGame::slotStatus(PlayerTypes eID)
{
	return CvPreGame::slotStatus(eID);
}
//------------------------------------------------------------------------------
unsigned int CvDllPreGame::syncRandomSeed()
{
	return CvPreGame::syncRandomSeed();
}
//------------------------------------------------------------------------------
bool CvDllPreGame::transferredMap()
{
	return CvPreGame::transferredMap();
}
//------------------------------------------------------------------------------
TeamTypes CvDllPreGame::teamType(PlayerTypes p)
{
	return CvPreGame::teamType(p);
}
//------------------------------------------------------------------------------
TurnTimerTypes CvDllPreGame::turnTimer()
{
	return CvPreGame::turnTimer();
}
//------------------------------------------------------------------------------
const std::string CvDllPreGame::versionString()
{
	return CvPreGame::versionString();
}
//------------------------------------------------------------------------------
WorldSizeTypes CvDllPreGame::worldSize()
{
	return CvPreGame::worldSize();
}
//------------------------------------------------------------------------------
ICvWorldInfo1* CvDllPreGame::GetWorldInfo()
{
	const CvWorldInfo& kWorldInfo = CvPreGame::worldInfo();
	const CvWorldInfo* pWorldInfo = &(kWorldInfo);
	return new CvDllWorldInfo(const_cast<CvWorldInfo*>(pWorldInfo));
}
//------------------------------------------------------------------------------
void CvDllPreGame::write(FDataStream& saveTo)
{
	CvPreGame::write(saveTo);
}
//------------------------------------------------------------------------------
int CvDllPreGame::getActiveSlotCount()
{
	return CvPreGame::getActiveSlotCount();
}
//------------------------------------------------------------------------------
int CvDllPreGame::readActiveSlotCountFromSaveGame(FDataStream& loadFrom, bool bReadVersion)
{
	return CvPreGame::readActiveSlotCountFromSaveGame(loadFrom, bReadVersion);
}
//------------------------------------------------------------------------------
StorageLocation CvDllPreGame::LoadFileStorage()
{
	return CvPreGame::loadFileStorage();
}
//------------------------------------------------------------------------------
void CvDllPreGame::SetLoadFileName(const char* szFileName, StorageLocation eStorage)
{
	CvString strFileName = szFileName;
	CvPreGame::setLoadFileName(strFileName, eStorage);
}
//------------------------------------------------------------------------------
ICvEnumerator* CvDllPreGame::GetDLCAllowed()
{
	return new CvDllDlcPackageInfoList(CvPreGame::getDLCAllowed());
}
//------------------------------------------------------------------------------
ICvEnumerator* CvDllPreGame::GetDLCAvailable(PlayerTypes p)
{
	return new CvDllDlcPackageInfoList(CvPreGame::getDLCAvailable(p));
}
//------------------------------------------------------------------------------
void CvDllPreGame::SetDLCAvailable(PlayerTypes p, ICvEnumerator* pList)
{
	PackageIDList kDLCList;

	// Because CvEnumerator OWNS the pointer it's passed, use QueryInterface to
	// construct a new pointer.
	CvEnumerator<ICvDlcPackageInfo1> kEnum(pList->QueryInterface<ICvEnumerator>());
	while(kEnum.MoveNext())
	{
		CvInterfacePtr<ICvDlcPackageInfo1> pPackageInfo(kEnum.GetCurrent());
		if(pPackageInfo)
		{
			kDLCList.push_back(pPackageInfo->GetPackageID());
		}
	}

	CvPreGame::setDLCAvailable(p, kDLCList);
}
//------------------------------------------------------------------------------
int CvDllPreGame::pitBossTurnTime()
{
	return CvPreGame::pitBossTurnTime();
}
//------------------------------------------------------------------------------
void CvDllPreGame::setPitBossTurnTime(int turnTime)
{
	CvPreGame::setPitBossTurnTime(turnTime);
}
//------------------------------------------------------------------------------
bool CvDllPreGame::isTurnNotifySteamInvite(PlayerTypes p) const
{
	return CvPreGame::isTurnNotifySteamInvite(p);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setTurnNotifySteamInvite(PlayerTypes p, bool wantsSteamInvite)
{
	CvPreGame::setTurnNotifySteamInvite(p, wantsSteamInvite);
}
//------------------------------------------------------------------------------
bool CvDllPreGame::isTurnNotifyEmail(PlayerTypes p) const
{
	return CvPreGame::isTurnNotifyEmail(p);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setTurnNotifyEmail(PlayerTypes p, bool wantsEmail)
{
	CvPreGame::setTurnNotifyEmail(p, wantsEmail);
}
//------------------------------------------------------------------------------
const CvString& CvDllPreGame::getTurnNotifyEmailAddress(PlayerTypes p) const
{
	return CvPreGame::getTurnNotifyEmailAddress(p);
}
//------------------------------------------------------------------------------
void CvDllPreGame::setTurnNotifyEmailAddress(PlayerTypes p, const CvString& emailAddress)
{
	CvPreGame::setTurnNotifyEmailAddress(p, emailAddress);
}
//------------------------------------------------------------------------------
void CvDllPreGame::VerifyHandicap(PlayerTypes p)
{
	CvPreGame::VerifyHandicap(p);
}
//------------------------------------------------------------------------------
void CvDllPreGame::ReseatConnectedPlayers()
{
	CvPreGame::ReseatConnectedPlayers();
}


