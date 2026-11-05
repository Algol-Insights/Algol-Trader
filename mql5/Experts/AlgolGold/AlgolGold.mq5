//+------------------------------------------------------------------+
//|              Algo Trader Gold EA v3.1 - LOSS CONTROL EDITION    |
//|           Professional Gold Trading System - XAUUSD/XAUEUR       |
//|  Critical Focus: Minimize Loss Impact, Protect Capital          |
//+------------------------------------------------------------------+
//| v3.1 BUG-FIX RELEASE (changes vs v3.0)                           |
//|  1. MA cross reads correctly ordered (series) buffers, on closed |
//|     bars when RequireBarClose=true. RSI uses the same bar.       |
//|  2. Loss tracking works: closed positions are detected and their |
//|     net P/L (incl. commission/swap) drives the daily limit, the  |
//|     consecutive-loss pause (with cooldown) and adaptive sizing.  |
//|  3. No array-out-of-range after early/time exits.                |
//|  4. Partial closes never close the whole position; skipped when  |
//|     the position is too small to split.                          |
//|  5. Broker TP moved to FinalTP_RR so TP2 partial + trailing run. |
//|  6. Trackers use the real position ticket and fill price, are    |
//|     removed on close and rebuilt after a restart.                |
//|  7. Profit lock is in R (BE_LockProfitR) and works on later      |
//|     ticks (v3.0 only ran it on the tick BE was set).             |
//|  8. MinATRForEntry is in price units; MinBarsBetweenTrades is    |
//|     enforced; unused InpExecTF removed.                          |
//|  9. Max-loss cap reduces lot size (or skips the trade) instead   |
//|     of shrinking the stop; works with risk-based sizing too.     |
//| 10. Pause messages print once, not every tick.                   |
//+------------------------------------------------------------------+
#property strict
#property version   "3.10"
#property description "Loss Control Edition - Smaller losses, better protection, same frequency"
#property copyright "Professional Gold Trading System 2025"

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

//--- Trade classes
CTrade        Trade;
CPositionInfo Pos;

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+

//=== CORE STRATEGY (PRESERVED) ===
input group "══════════ CORE STRATEGY (ORIGINAL) ══════════"
input ENUM_TIMEFRAMES InpSignalTF   = PERIOD_M1;
input ENUM_TIMEFRAMES InpHTFTF      = PERIOD_M5;
input int    FastMAPeriod           = 9;
input int    SlowMAPeriod           = 21;
input int    HTFMAPeriod            = 50;

//=== POSITION SIZING ===
input group "══════════ POSITION SIZING ══════════"
input bool   UseFixedLot            = true;
input double FixedLot               = 0.01;
input double RiskPerTrade           = 1.0;         // Risk % of balance (when UseFixedLot=false)

//=== LOSS CONTROL SYSTEM ===
input group "══════════ 🛡️ LOSS CONTROL ══════════"
input double SL_ATR_Mult            = 1.5;         // SL ATR Multiplier
input int    SL_Points              = 300;         // Fallback SL in points (if ATR unavailable)
input double MaxLossPerTrade_USD    = 20.0;        // Hard loss cap per trade (account ccy). Lot reduced to fit; trade skipped if min lot doesn't fit. 0 = off
input bool   UseEarlyExitLogic      = true;        // Enable Early Exit System
input double EarlyExit_Threshold    = 0.5;         // Exit if -0.5R within the time window
input int    EarlyExit_TimeMinutes  = 5;           // Time window for rapid loss
input bool   UseTimeBasedExit       = true;        // Time-based invalidation
input int    TimeExit_Minutes       = 20;          // Exit if not profitable after X min
input double TimeExit_MinProfit     = 0.3;         // Required profit (in R) to stay in

//=== BREAK-EVEN ===
input group "══════════ 🛡️ BREAK-EVEN PROTECTION ══════════"
input bool   UseAggressiveBE        = true;        // Move to BE early
input double BE_TriggerR            = 0.8;         // Move SL to entry at +0.8R
input double BE_LockTriggerR        = 1.2;         // Lock profit once trade reaches +1.2R
input double BE_LockProfitR         = 0.2;         // Profit locked (in R) at that point

//=== TAKE PROFIT - SCALED EXITS ===
input group "══════════ TAKE PROFIT - SCALED EXITS ══════════"
input double TP1_RR                 = 1.0;         // First TP at 1R
input double TP1_Percent            = 30.0;        // % of initial volume closed at TP1
input double TP2_RR                 = 2.0;         // Second TP at 2R
input double TP2_Percent            = 40.0;        // % of initial volume closed at TP2
input bool   UseTrailingForRemaining = true;       // Trail the remainder after TP2
input double FinalTP_RR             = 4.0;         // Broker-side TP for the runner when trailing (0 = none)

//=== TRAILING STOP ===
input group "══════════ TRAILING STOP ══════════"
input double TrailStartPoints       = 150;         // Min profit (points) before trailing
input double TrailDistanceATR       = 1.0;         // Trail distance in ATR
input int    ATRPeriod              = 14;
input ENUM_TIMEFRAMES ATR_TF        = PERIOD_M5;

//=== LOSS CLUSTER PREVENTION ===
input group "══════════ 🛡️ CLUSTER PREVENTION ══════════"
input bool   UseLossClusterFilter   = true;        // Enable daily limit + loss-streak pause
input int    MaxConsecutiveLosses   = 3;           // Pause after N losses in a row
input int    PauseMinutesAfterLosses = 60;         // Pause length after a loss streak (0 = until next day)
input double DailyMaxLoss_USD       = 50.0;        // Daily net realized loss limit (account ccy). 0 = off
input bool   UseAdaptiveSizing      = true;        // Reduce lot after losses
input double AdaptiveLotReduction   = 0.5;         // Multiply lot by this after each loss
input double MinLotMultiplier       = 0.25;        // Floor for the adaptive lot multiplier

//=== ENTRY FILTERS ===
input group "══════════ ENTRY PRECISION ══════════"
input bool   RequireBarClose        = true;
input bool   UseMomentumFilter      = true;
input int    RSIPeriod              = 14;
input int    RSI_Overbought         = 70;
input int    RSI_Oversold           = 30;
input int    RSI_MinStrength        = 45;
input bool   ConfirmWithPriceAction = true;

//=== GOLD FILTERS ===
input group "══════════ GOLD PROTECTION ══════════"
input bool   UseSpreadFilter        = true;
input double MaxSpreadATR           = 0.4;         // Max spread as fraction of ATR
input int    MaxSpreadPips          = 40;          // Max spread in POINTS
input bool   AvoidLowVolatility     = true;
input double MinATRForEntry         = 0.50;        // Min ATR in PRICE units (0.50 = $0.50 on XAUUSD)

//=== POSITION MANAGEMENT ===
input group "══════════ POSITION MANAGEMENT ══════════"
input int    Magic                  = 13579;
input bool   OnePositionPerSymbol   = true;
input int    MinBarsBetweenTrades   = 10;          // Signal-TF bars between entries (0 = off)

//=== DIAGNOSTICS ===
input group "══════════ MONITORING ══════════"
input bool   DetailedLog            = true;
input bool   ShowInfo               = true;

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+

// Indicator handles
int hATR     = INVALID_HANDLE;
int hFast    = INVALID_HANDLE;
int hSlow    = INVALID_HANDLE;
int hHTF     = INVALID_HANDLE;
int hRSI     = INVALID_HANDLE;

// Trading state
datetime lastTradeBarTime = 0;
datetime lastSignalCheck  = 0;

// Loss tracking
struct LossTracker
{
   int      consecutiveLosses;
   double   dailyPnL;              // Net realized P/L today (account currency)
   datetime dayStart;              // Server-time start of the tracked day
   bool     dailyLimitHit;         // Used to print the limit message once
   datetime pauseUntil;            // Loss-streak pause end (0 = not paused)
   double   currentLotMultiplier;
};
LossTracker lossTracker;

// Performance tracking
struct PerformanceStats
{
   int totalSignals;
   int rejectedByMomentum;
   int rejectedBySpread;
   int rejectedByVolatility;
   int rejectedByPriceAction;
   int rejectedByLossLimit;        // Trades skipped because min lot exceeded the loss cap
   int lotsReducedByCap;           // Trades whose lot was reduced to fit the loss cap
   int tradesExecuted;
   int earlyExits;
   int timeExits;
   int breakEvenHits;
   int tp1Hits;
   int tp2Hits;
   int wins;
   int losses;
};
PerformanceStats stats;

// Position tracking
#define FLAG_TP1   1
#define FLAG_TP2   2
#define FLAG_BE    4
#define FLAG_LOCK  8

struct PositionTracker
{
   ulong    ticket;                // Position ticket
   datetime entryTime;
   double   entryPrice;            // Actual fill price
   double   slDistance;            // 1R in price units
   double   initialVolume;
   double   initialRisk;
   bool     tp1Hit;
   bool     tp2Hit;
   bool     beSet;
   bool     lockSet;
   double   worstDrawdown;         // In R
   datetime closeSeenAt;           // When the position was first seen closed
};
PositionTracker posTracker[];

//+------------------------------------------------------------------+
//| INITIALIZATION                                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Input validation
   if(TP1_Percent < 0 || TP2_Percent < 0 || TP1_Percent + TP2_Percent > 100.0)
   {
      Print("❌ TP1_Percent + TP2_Percent must be between 0 and 100");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(TP2_RR <= TP1_RR)
   {
      Print("❌ TP2_RR must be greater than TP1_RR");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(UseTrailingForRemaining && FinalTP_RR > 0 && FinalTP_RR <= TP2_RR)
   {
      Print("❌ FinalTP_RR must be greater than TP2_RR (or 0 for no broker TP)");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(BE_LockProfitR >= BE_LockTriggerR)
   {
      Print("❌ BE_LockProfitR must be smaller than BE_LockTriggerR");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(AdaptiveLotReduction <= 0 || AdaptiveLotReduction > 1.0 ||
      MinLotMultiplier <= 0 || MinLotMultiplier > 1.0)
   {
      Print("❌ AdaptiveLotReduction and MinLotMultiplier must be in (0, 1]");
      return INIT_PARAMETERS_INCORRECT;
   }

   //--- Indicators
   hATR  = iATR(_Symbol, ATR_TF, ATRPeriod);
   hFast = iMA(_Symbol, InpSignalTF, FastMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   hSlow = iMA(_Symbol, InpSignalTF, SlowMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   hHTF  = iMA(_Symbol, InpHTFTF, HTFMAPeriod, 0, MODE_EMA, PRICE_CLOSE);

   if(UseMomentumFilter)
      hRSI = iRSI(_Symbol, InpSignalTF, RSIPeriod, PRICE_CLOSE);

   if(hATR == INVALID_HANDLE || hFast == INVALID_HANDLE ||
      hSlow == INVALID_HANDLE || hHTF == INVALID_HANDLE ||
      (UseMomentumFilter && hRSI == INVALID_HANDLE))
   {
      Print("❌ Failed to create indicator handles");
      return INIT_FAILED;
   }

   Trade.SetExpertMagicNumber(Magic);
   Trade.SetTypeFillingBySymbol(_Symbol);

   //--- State
   ZeroMemory(stats);
   ZeroMemory(lossTracker);
   lossTracker.currentLotMultiplier = 1.0;
   lossTracker.dayStart = DayStart(TimeCurrent());
   LoadState();

   ArrayResize(posTracker, 0);
   SyncTrackers();            // Re-adopt positions left open by a previous run
   CleanupOrphanPosState();

   //--- Warnings
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(UseFixedLot && UseAdaptiveSizing && FixedLot * AdaptiveLotReduction < vmin - 1e-8)
      Print("⚠️ Adaptive sizing has no effect: FixedLot x ", AdaptiveLotReduction,
            " is below the broker minimum lot (", vmin, ")");
   if(UseFixedLot && FixedLot * TP1_Percent / 100.0 < vmin - 1e-8)
      Print("⚠️ FixedLot ", FixedLot, " is too small to split at TP1/TP2 - partial closes will be skipped,",
            " the full position runs with BE/lock/trailing protection");

   Print("═══════════════════════════════════════════════════════");
   Print("  🛡️ ALGO TRADER GOLD v3.1 - LOSS CONTROL EDITION");
   Print("═══════════════════════════════════════════════════════");
   Print("Symbol: ", _Symbol);
   Print("🔥 LOSS CONTROL ACTIVE:");
   Print("  └─ SL: ", SL_ATR_Mult, " ATR");
   Print("  └─ Max Loss Cap: ", MaxLossPerTrade_USD);
   Print("  └─ Early Exit: ", (UseEarlyExitLogic ? "ON" : "OFF"));
   Print("  └─ Time-Based Exit: ", (UseTimeBasedExit ? "ON" : "OFF"));
   Print("  └─ Aggressive BE: ", (UseAggressiveBE ? StringFormat("%.1fR (lock %.1fR at %.1fR)", BE_TriggerR, BE_LockProfitR, BE_LockTriggerR) : "OFF"));
   Print("  └─ Loss Cluster Filter: ", (UseLossClusterFilter ? "ON" : "OFF"));
   Print("  └─ Daily Max Loss: ", DailyMaxLoss_USD);
   Print("  └─ Restored state: streak=", lossTracker.consecutiveLosses,
         " lotMult=", DoubleToString(lossTracker.currentLotMultiplier, 2),
         " dayP/L=", DoubleToString(lossTracker.dailyPnL, 2),
         " openTracked=", ArraySize(posTracker));
   Print("═══════════════════════════════════════════════════════");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINITIALIZATION                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(hATR != INVALID_HANDLE)  IndicatorRelease(hATR);
   if(hFast != INVALID_HANDLE) IndicatorRelease(hFast);
   if(hSlow != INVALID_HANDLE) IndicatorRelease(hSlow);
   if(hHTF != INVALID_HANDLE)  IndicatorRelease(hHTF);
   if(hRSI != INVALID_HANDLE)  IndicatorRelease(hRSI);

   Comment("");
   SaveState();
   if(!MQLInfoInteger(MQL_TESTER))
      GlobalVariablesFlush();

   if(stats.totalSignals > 0)
   {
      Print("═══════════════════════════════════════════════════════");
      Print("      🛡️ LOSS CONTROL SESSION SUMMARY");
      Print("═══════════════════════════════════════════════════════");
      Print("Signals: ", stats.totalSignals, " | Executed: ", stats.tradesExecuted,
            " | Wins: ", stats.wins, " | Losses: ", stats.losses);
      Print("Early Exits: ", stats.earlyExits, " | Time Exits: ", stats.timeExits,
            " | BE Hits: ", stats.breakEvenHits);
      Print("TP Ladder: TP1=", stats.tp1Hits, " | TP2=", stats.tp2Hits);
      Print("Rejected: PriceAction=", stats.rejectedByPriceAction, " Spread=", stats.rejectedBySpread,
            " Volatility=", stats.rejectedByVolatility, " Momentum=", stats.rejectedByMomentum);
      Print("Loss Cap: ", stats.rejectedByLossLimit, " trades prevented, ",
            stats.lotsReducedByCap, " lots reduced");
      Print("═══════════════════════════════════════════════════════");
   }
}

//+------------------------------------------------------------------+
//| MAIN TICK HANDLER                                                 |
//+------------------------------------------------------------------+
void OnTick()
{
   ResetDailyLossIfNeeded();
   SyncTrackers();          // Finalize closed positions, adopt untracked ones
   ManageOpenPositions();
   CheckForSignals();

   if(ShowInfo) UpdateInfoPanel();
}

//+------------------------------------------------------------------+
//| STATE PERSISTENCE (terminal global variables)                     |
//+------------------------------------------------------------------+
string StateKey(string field)
{
   return "AG3_" + IntegerToString(Magic) + "_ST_" + _Symbol + "_" + field;
}

string PosKey(ulong ticket, string field)
{
   return "AG3_" + IntegerToString(Magic) + "_POS_" + IntegerToString((long)ticket) + "_" + field;
}

double GVGet(string key, double def)
{
   return GlobalVariableCheck(key) ? GlobalVariableGet(key) : def;
}

void SaveState()
{
   GlobalVariableSet(StateKey("consec"),     lossTracker.consecutiveLosses);
   GlobalVariableSet(StateKey("mult"),       lossTracker.currentLotMultiplier);
   GlobalVariableSet(StateKey("pauseUntil"), (double)(long)lossTracker.pauseUntil);
   GlobalVariableSet(StateKey("dayStart"),   (double)(long)lossTracker.dayStart);
   GlobalVariableSet(StateKey("dailyPnL"),   lossTracker.dailyPnL);
   GlobalVariableSet(StateKey("lastBar"),    (double)(long)lastTradeBarTime);
}

void LoadState()
{
   // The tester always starts from a clean state
   if(MQLInfoInteger(MQL_TESTER)) return;

   lossTracker.consecutiveLosses    = (int)GVGet(StateKey("consec"), 0);
   lossTracker.currentLotMultiplier = GVGet(StateKey("mult"), 1.0);
   if(lossTracker.currentLotMultiplier <= 0 || lossTracker.currentLotMultiplier > 1.0)
      lossTracker.currentLotMultiplier = 1.0;
   lossTracker.pauseUntil = (datetime)(long)GVGet(StateKey("pauseUntil"), 0);
   lastTradeBarTime       = (datetime)(long)GVGet(StateKey("lastBar"), 0);

   // Daily P/L only carries over within the same day
   datetime savedDay = (datetime)(long)GVGet(StateKey("dayStart"), 0);
   if(savedDay == lossTracker.dayStart)
      lossTracker.dailyPnL = GVGet(StateKey("dailyPnL"), 0);
}

void SavePosState(ulong ticket, double slDist, double initVol, int flags)
{
   GlobalVariableSet(PosKey(ticket, "sl"),  slDist);
   GlobalVariableSet(PosKey(ticket, "vol"), initVol);
   GlobalVariableSet(PosKey(ticket, "fl"),  flags);
}

bool LoadPosState(ulong ticket, double &slDist, double &initVol, int &flags)
{
   if(!GlobalVariableCheck(PosKey(ticket, "sl")) || !GlobalVariableCheck(PosKey(ticket, "vol")))
      return false;
   slDist  = GlobalVariableGet(PosKey(ticket, "sl"));
   initVol = GlobalVariableGet(PosKey(ticket, "vol"));
   flags   = (int)GVGet(PosKey(ticket, "fl"), 0);
   return (slDist > 0 && initVol > 0);
}

void DeletePosState(ulong ticket)
{
   GlobalVariableDel(PosKey(ticket, "sl"));
   GlobalVariableDel(PosKey(ticket, "vol"));
   GlobalVariableDel(PosKey(ticket, "fl"));
}

int TrackerFlags(int idx)
{
   int f = 0;
   if(posTracker[idx].tp1Hit)  f |= FLAG_TP1;
   if(posTracker[idx].tp2Hit)  f |= FLAG_TP2;
   if(posTracker[idx].beSet)   f |= FLAG_BE;
   if(posTracker[idx].lockSet) f |= FLAG_LOCK;
   return f;
}

void SaveTrackerFlags(int idx)
{
   GlobalVariableSet(PosKey(posTracker[idx].ticket, "fl"), TrackerFlags(idx));
}

// Remove per-position state left behind by positions that no longer exist
void CleanupOrphanPosState()
{
   if(MQLInfoInteger(MQL_TESTER)) return;

   string prefix = "AG3_" + IntegerToString(Magic) + "_POS_";
   for(int i = GlobalVariablesTotal() - 1; i >= 0; i--)
   {
      string name = GlobalVariableName(i);
      if(StringFind(name, prefix) != 0) continue;

      string rest = StringSubstr(name, StringLen(prefix));
      int us = StringFind(rest, "_");
      if(us <= 0) continue;

      ulong ticket = (ulong)StringToInteger(StringSubstr(rest, 0, us));
      if(ticket == 0) continue;

      if(!PositionSelectByTicket(ticket))
         GlobalVariableDel(name);
   }
}

//+------------------------------------------------------------------+
//| DAILY RESET                                                       |
//+------------------------------------------------------------------+
datetime DayStart(datetime t)
{
   long s = (long)t;
   return (datetime)(s - s % 86400);
}

void ResetDailyLossIfNeeded()
{
   datetime today = DayStart(TimeCurrent());
   if(today == lossTracker.dayStart) return;

   if(DetailedLog)
      Print("📅 New trading day - previous day realized P/L: ",
            DoubleToString(lossTracker.dailyPnL, 2));

   lossTracker.dayStart      = today;
   lossTracker.dailyPnL      = 0;
   lossTracker.dailyLimitHit = false;
   SaveState();
}

//+------------------------------------------------------------------+
//| LOSS CONTROL GATE                                                 |
//+------------------------------------------------------------------+
bool DailyLimitReached()
{
   return (UseLossClusterFilter && DailyMaxLoss_USD > 0 &&
           lossTracker.dailyPnL <= -DailyMaxLoss_USD);
}

void CheckLossStreakPause()
{
   if(!UseLossClusterFilter || MaxConsecutiveLosses <= 0) return;
   if(lossTracker.pauseUntil > 0) return;
   if(lossTracker.consecutiveLosses < MaxConsecutiveLosses) return;

   datetime now = TimeCurrent();
   lossTracker.pauseUntil = (PauseMinutesAfterLosses > 0)
                            ? (datetime)((long)now + (long)PauseMinutesAfterLosses * 60)
                            : (datetime)((long)DayStart(now) + 86400);

   Print("⏸️ ", lossTracker.consecutiveLosses, " consecutive losses - trading paused until ",
         TimeToString(lossTracker.pauseUntil, TIME_DATE | TIME_MINUTES));
   SaveState();
}

bool TradingAllowed()
{
   if(!UseLossClusterFilter) return true;

   if(DailyLimitReached())
   {
      if(!lossTracker.dailyLimitHit)
      {
         lossTracker.dailyLimitHit = true;
         Print("🛑 DAILY LOSS LIMIT REACHED: ", DoubleToString(lossTracker.dailyPnL, 2),
               " - Trading paused until tomorrow");
      }
      return false;
   }

   CheckLossStreakPause();   // Covers a streak restored from saved state

   if(lossTracker.pauseUntil > 0)
   {
      if(TimeCurrent() < lossTracker.pauseUntil) return false;

      // Pause over: start a fresh streak count (lot multiplier stays reduced until a win)
      lossTracker.pauseUntil = 0;
      lossTracker.consecutiveLosses = 0;
      SaveState();
      Print("▶️ Loss-streak pause over - trading resumed (lot multiplier ",
            DoubleToString(lossTracker.currentLotMultiplier, 2), ")");
   }
   return true;
}

//+------------------------------------------------------------------+
//| CLOSED-POSITION ACCOUNTING                                        |
//+------------------------------------------------------------------+
// Net result of a position from history. Returns true when every
// opened lot has a matching closing deal (i.e. history is complete).
bool GetClosedPositionResult(ulong positionId, double &net)
{
   net = 0;
   if(!HistorySelectByPosition(positionId)) return false;

   double inVol = 0, outVol = 0;
   int total = HistoryDealsTotal();
   for(int k = 0; k < total; k++)
   {
      ulong deal = HistoryDealGetTicket(k);
      if(deal == 0) continue;

      long   entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
      double vol   = HistoryDealGetDouble(deal, DEAL_VOLUME);

      if(entry == DEAL_ENTRY_IN)
         inVol += vol;
      else if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
         outVol += vol;

      net += HistoryDealGetDouble(deal, DEAL_PROFIT)
           + HistoryDealGetDouble(deal, DEAL_SWAP)
           + HistoryDealGetDouble(deal, DEAL_COMMISSION)
           + HistoryDealGetDouble(deal, DEAL_FEE);
   }
   return (inVol > 0 && outVol >= inVol - 1e-8);
}

void OnPositionClosed(int idx, double net)
{
   lossTracker.dailyPnL += net;

   if(net < 0)
   {
      stats.losses++;
      lossTracker.consecutiveLosses++;
      if(UseAdaptiveSizing)
         lossTracker.currentLotMultiplier = MathMax(MinLotMultiplier,
                                            lossTracker.currentLotMultiplier * AdaptiveLotReduction);
   }
   else if(net > 0)
   {
      stats.wins++;
      lossTracker.consecutiveLosses = 0;
      lossTracker.currentLotMultiplier = 1.0;
   }

   if(DetailedLog)
      Print("📕 Position #", posTracker[idx].ticket, " closed: net ", DoubleToString(net, 2),
            " | worst ", DoubleToString(posTracker[idx].worstDrawdown, 2), "R",
            " | streak ", lossTracker.consecutiveLosses,
            " | lot mult ", DoubleToString(lossTracker.currentLotMultiplier, 2),
            " | day P/L ", DoubleToString(lossTracker.dailyPnL, 2));

   SaveState();
   CheckLossStreakPause();
}

//+------------------------------------------------------------------+
//| TRACKER SYNC: finalize closed positions, adopt untracked ones     |
//+------------------------------------------------------------------+
void SyncTrackers()
{
   //--- Positions that are gone (SL/TP, early exit, manual close...)
   for(int i = ArraySize(posTracker) - 1; i >= 0; i--)
   {
      ulong ticket = posTracker[i].ticket;
      if(PositionSelectByTicket(ticket))
      {
         posTracker[i].closeSeenAt = 0;
         continue;
      }

      double net = 0;
      bool complete = GetClosedPositionResult(ticket, net);
      if(!complete)
      {
         // History can lag the position list by a moment - wait up to 30s
         if(posTracker[i].closeSeenAt == 0) posTracker[i].closeSeenAt = TimeCurrent();
         if((long)TimeCurrent() - (long)posTracker[i].closeSeenAt < 30) continue;
      }

      OnPositionClosed(i, net);
      DeletePosState(ticket);
      RemovePositionTracker(i);
   }

   //--- Our positions without a tracker (new, or left from a previous run)
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != Magic) continue;
      if(FindPositionTracker(ticket) < 0)
         AdoptPosition(ticket);
   }
}

void AdoptPosition(ulong ticket)
{
   if(FindPositionTracker(ticket) >= 0) return;
   if(!PositionSelectByTicket(ticket)) return;

   bool     isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   double   open  = PositionGetDouble(POSITION_PRICE_OPEN);
   double   sl    = PositionGetDouble(POSITION_SL);
   double   vol   = PositionGetDouble(POSITION_VOLUME);
   datetime t     = (datetime)PositionGetInteger(POSITION_TIME);

   double slDist = 0, initVol = 0;
   int flags = 0;

   if(!LoadPosState(ticket, slDist, initVol, flags))
   {
      // No saved state: reconstruct from the position itself
      bool slOnLossSide = (sl > 0) && ((isBuy && sl < open) || (!isBuy && sl > open));
      if(slOnLossSide)
         slDist = MathAbs(open - sl);
      else
      {
         double atr = 0;
         slDist = (GetATR(atr) && atr > 0) ? atr * SL_ATR_Mult : SL_Points * _Point;
      }
      initVol = vol;
      if(sl > 0 && !slOnLossSide) flags |= FLAG_BE;   // SL already at/after entry

      SavePosState(ticket, slDist, initVol, flags);

      if(DetailedLog)
         Print("🔄 Adopted position #", ticket, " entry=", open, " 1R=",
               DoubleToString(slDist, _Digits), " vol=", vol);
   }

   int n = ArraySize(posTracker);
   ArrayResize(posTracker, n + 1);

   posTracker[n].ticket        = ticket;
   posTracker[n].entryTime     = t;
   posTracker[n].entryPrice    = open;
   posTracker[n].slDistance    = slDist;
   posTracker[n].initialVolume = initVol;
   posTracker[n].initialRisk   = RiskForLot(initVol, slDist);
   posTracker[n].tp1Hit        = ((flags & FLAG_TP1)  != 0);
   posTracker[n].tp2Hit        = ((flags & FLAG_TP2)  != 0);
   posTracker[n].beSet         = ((flags & FLAG_BE)   != 0);
   posTracker[n].lockSet       = ((flags & FLAG_LOCK) != 0);
   posTracker[n].worstDrawdown = 0;
   posTracker[n].closeSeenAt   = 0;
}

int FindPositionTracker(ulong ticket)
{
   for(int i = 0; i < ArraySize(posTracker); i++)
      if(posTracker[i].ticket == ticket)
         return i;
   return -1;
}

void RemovePositionTracker(int index)
{
   int size = ArraySize(posTracker);
   if(index < 0 || index >= size) return;

   for(int i = index; i < size - 1; i++)
      posTracker[i] = posTracker[i + 1];

   ArrayResize(posTracker, size - 1);
}

//+------------------------------------------------------------------+
//| POSITION MANAGEMENT                                               |
//| Trackers are never removed inside this loop (SyncTrackers does    |
//| that next tick), and every step stops once the position closes.   |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!Pos.SelectByTicket(ticket)) continue;
      if(Pos.Symbol() != _Symbol || Pos.Magic() != Magic) continue;

      int idx = FindPositionTracker(ticket);
      if(idx < 0) continue;

      bool isBuy = (Pos.PositionType() == POSITION_TYPE_BUY);
      double r = CurrentR(idx, isBuy);
      if(r < posTracker[idx].worstDrawdown)
         posTracker[idx].worstDrawdown = r;

      if(UseEarlyExitLogic && CheckEarlyExitConditions(ticket, idx)) continue;
      if(UseTimeBasedExit && CheckTimeBasedExit(ticket, idx)) continue;

      if(UseAggressiveBE)
         ManageAggressiveBreakEven(ticket, idx);

      if(!PositionSelectByTicket(ticket)) continue;
      ManageScaledTakeProfit(ticket, idx);

      if(!PositionSelectByTicket(ticket)) continue;
      if(UseTrailingForRemaining)
         ManageTrailingStop(ticket, idx);
   }
}

bool IsBuyPosition(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return false;
   return (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
}

double CurrentR(int idx, bool isBuy)
{
   double px = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                     : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double move = isBuy ? (px - posTracker[idx].entryPrice)
                       : (posTracker[idx].entryPrice - px);
   return (posTracker[idx].slDistance > 0) ? move / posTracker[idx].slDistance : 0.0;
}

bool ResultOK()
{
   uint rc = Trade.ResultRetcode();
   return (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL || rc == TRADE_RETCODE_PLACED);
}

bool ClosePosition(ulong ticket, string reason)
{
   if(Trade.PositionClose(ticket) && ResultOK())
      return true;
   Print("❌ ", reason, " close failed for #", ticket, ": ", Trade.ResultRetcodeDescription());
   return false;
}

//+------------------------------------------------------------------+
//| EARLY EXIT - RAPID ADVERSE MOVE (returns true if closed)          |
//+------------------------------------------------------------------+
bool CheckEarlyExitConditions(ulong ticket, int idx)
{
   long secondsSinceEntry = (long)TimeCurrent() - (long)posTracker[idx].entryTime;
   if(secondsSinceEntry > (long)EarlyExit_TimeMinutes * 60) return false;

   double r = CurrentR(idx, IsBuyPosition(ticket));
   if(r > -EarlyExit_Threshold) return false;

   if(!ClosePosition(ticket, "Early exit")) return false;

   stats.earlyExits++;
   if(DetailedLog)
      Print("🚨 EARLY EXIT: Rapid adverse move detected (",
            DoubleToString(r, 2), "R in ", secondsSinceEntry, " seconds)");
   return true;
}

//+------------------------------------------------------------------+
//| TIME-BASED EXIT - TRADE NOT WORKING (returns true if closed)      |
//+------------------------------------------------------------------+
bool CheckTimeBasedExit(ulong ticket, int idx)
{
   long minutesSinceEntry = ((long)TimeCurrent() - (long)posTracker[idx].entryTime) / 60;
   if(minutesSinceEntry < TimeExit_Minutes) return false;

   double r = CurrentR(idx, IsBuyPosition(ticket));
   if(r >= TimeExit_MinProfit) return false;

   if(!ClosePosition(ticket, "Time exit")) return false;

   stats.timeExits++;
   if(DetailedLog)
      Print("⏱️ TIME EXIT: Trade stalled at ", DoubleToString(r, 2),
            "R after ", minutesSinceEntry, " minutes");
   return true;
}

//+------------------------------------------------------------------+
//| STOP-LOSS HELPERS                                                 |
//+------------------------------------------------------------------+
double TickSize()
{
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   return (ts > 0) ? ts : _Point;
}

// True if the position's SL is already at or beyond 'level' in the profit direction
bool SLAtOrBeyond(ulong ticket, bool isBuy, double level)
{
   if(!PositionSelectByTicket(ticket)) return false;
   double sl = PositionGetDouble(POSITION_SL);
   if(sl <= 0) return false;
   double half = TickSize() * 0.5;
   return isBuy ? (sl >= level - half) : (sl <= level + half);
}

// Move SL only in the protective direction, respecting the broker stop level
bool ModifySL(ulong ticket, bool isBuy, double newSL)
{
   if(!PositionSelectByTicket(ticket)) return false;

   newSL = PriceNormalize(newSL);
   double curSL = PositionGetDouble(POSITION_SL);
   double curTP = PositionGetDouble(POSITION_TP);
   double half  = TickSize() * 0.5;

   if(curSL > 0)
   {
      if(isBuy  && newSL <= curSL + half) return false;
      if(!isBuy && newSL >= curSL - half) return false;
   }

   double minDist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(isBuy  && newSL >= bid - minDist) return false;
   if(!isBuy && newSL <= ask + minDist) return false;

   if(Trade.PositionModify(ticket, newSL, curTP) && ResultOK())
      return true;

   if(DetailedLog)
      Print("⚠️ SL modify failed for #", ticket, ": ", Trade.ResultRetcodeDescription());
   return false;
}

//+------------------------------------------------------------------+
//| AGGRESSIVE BREAK-EVEN + PROFIT LOCK                               |
//+------------------------------------------------------------------+
void ManageAggressiveBreakEven(ulong ticket, int idx)
{
   if(posTracker[idx].beSet && posTracker[idx].lockSet) return;

   bool isBuy   = IsBuyPosition(ticket);
   double r     = CurrentR(idx, isBuy);
   double entry = posTracker[idx].entryPrice;

   // Step 1: move SL to entry
   if(!posTracker[idx].beSet && r >= BE_TriggerR)
   {
      if(SLAtOrBeyond(ticket, isBuy, entry) || ModifySL(ticket, isBuy, entry))
      {
         posTracker[idx].beSet = true;
         stats.breakEvenHits++;
         SaveTrackerFlags(idx);
         if(DetailedLog)
            Print("✅ BREAK-EVEN set at ", DoubleToString(r, 2), "R");
      }
   }

   // Step 2: lock in profit (checked on every tick, not only the BE tick)
   if(posTracker[idx].beSet && !posTracker[idx].lockSet && r >= BE_LockTriggerR)
   {
      double lockDist = BE_LockProfitR * posTracker[idx].slDistance;
      double lockSL   = isBuy ? entry + lockDist : entry - lockDist;

      if(SLAtOrBeyond(ticket, isBuy, lockSL) || ModifySL(ticket, isBuy, lockSL))
      {
         posTracker[idx].lockSet = true;
         SaveTrackerFlags(idx);
         if(DetailedLog)
            Print("✅ PROFIT LOCKED: +", DoubleToString(BE_LockProfitR, 2), "R at ",
                  DoubleToString(r, 2), "R");
      }
   }
}

//+------------------------------------------------------------------+
//| SCALED TAKE PROFIT                                                |
//+------------------------------------------------------------------+
// Close part of a position. Returns true when the level is done: the
// partial was executed, or the position is too small to split.
bool ScaleOut(ulong ticket, double wantVol, string label, double r)
{
   if(!PositionSelectByTicket(ticket)) return false;

   double cur  = PositionGetDouble(POSITION_VOLUME);
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   double vol = NormalizeVolumeDown(wantVol);
   if(vol > cur - vmin + 1e-8)
      vol = NormalizeVolumeDown(cur - vmin);   // Always leave at least the min lot running

   if(wantVol <= 0 || vol < vmin - 1e-8)
   {
      if(DetailedLog)
         Print("ℹ️ ", label, " reached at ", DoubleToString(r, 2), "R - ",
               DoubleToString(cur, 2), " lot is too small to split, full position keeps running");
      return true;
   }

   if(Trade.PositionClosePartial(ticket, vol) && ResultOK())
   {
      if(DetailedLog)
         Print("💰 ", label, " Hit: closed ", DoubleToString(vol, 2), " of ",
               DoubleToString(cur, 2), " lot at ", DoubleToString(r, 2), "R");
      return true;
   }

   Print("❌ ", label, " partial close failed for #", ticket, ": ", Trade.ResultRetcodeDescription());
   return false;
}

void ManageScaledTakeProfit(ulong ticket, int idx)
{
   bool isBuy = IsBuyPosition(ticket);
   double r   = CurrentR(idx, isBuy);

   if(!posTracker[idx].tp1Hit && r >= TP1_RR)
   {
      if(ScaleOut(ticket, posTracker[idx].initialVolume * TP1_Percent / 100.0, "TP1", r))
      {
         posTracker[idx].tp1Hit = true;
         stats.tp1Hits++;
         SaveTrackerFlags(idx);
      }
   }

   if(posTracker[idx].tp1Hit && !posTracker[idx].tp2Hit && r >= TP2_RR)
   {
      if(ScaleOut(ticket, posTracker[idx].initialVolume * TP2_Percent / 100.0, "TP2", r))
      {
         posTracker[idx].tp2Hit = true;
         stats.tp2Hits++;
         SaveTrackerFlags(idx);
      }
   }
}

//+------------------------------------------------------------------+
//| TRAILING STOP (runner after TP2)                                  |
//+------------------------------------------------------------------+
void ManageTrailingStop(ulong ticket, int idx)
{
   if(!posTracker[idx].tp2Hit) return;   // Only trail after TP2

   bool isBuy   = IsBuyPosition(ticket);
   double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                        : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double open  = posTracker[idx].entryPrice;

   double profitDist = isBuy ? (price - open) : (open - price);
   if(profitDist <= TrailStartPoints * _Point) return;

   double atr = 0.0;
   if(!GetATR(atr) || atr <= 0) return;

   double trailDist = atr * TrailDistanceATR;
   double newSL     = isBuy ? price - trailDist : price + trailDist;

   // Avoid modifying on every tick: require a meaningful improvement
   if(!PositionSelectByTicket(ticket)) return;
   double curSL = PositionGetDouble(POSITION_SL);
   double minStep = MathMax(trailDist * 0.1, TickSize());
   if(curSL > 0)
   {
      if(isBuy  && newSL - curSL < minStep) return;
      if(!isBuy && curSL - newSL < minStep) return;
   }

   ModifySL(ticket, isBuy, newSL);
}

//+------------------------------------------------------------------+
//| CHECK FOR SIGNALS (WITH LOSS CONTROL)                             |
//+------------------------------------------------------------------+
void CheckForSignals()
{
   if(!TradingAllowed()) return;
   if(OnePositionPerSymbol && OpenPositionsCount() > 0) return;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, InpSignalTF, 0, 3, rates) < 3) return;

   datetime currentBarTime = rates[0].time;

   if(RequireBarClose)
   {
      if(currentBarTime == lastSignalCheck) return;   // Once per new bar
      lastSignalCheck = currentBarTime;
   }
   else
   {
      if(currentBarTime == lastTradeBarTime) return;
   }

   if(!EnoughBarsSinceLastTrade()) return;

   double fastPrev = 0, fastCur = 0, slowPrev = 0, slowCur = 0, htfCur = 0;
   if(!GetMAValues(fastPrev, fastCur, slowPrev, slowCur, htfCur)) return;

   bool crossUp   = (fastPrev < slowPrev) && (fastCur > slowCur);
   bool crossDown = (fastPrev > slowPrev) && (fastCur < slowCur);

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bool upTrend = (price > htfCur);
   bool dnTrend = (price < htfCur);

   bool buySignal  = crossUp && upTrend;
   bool sellSignal = crossDown && dnTrend;

   if(!buySignal && !sellSignal) return;

   stats.totalSignals++;

   // Price action is checked on the closed signal bar
   if(RequireBarClose && ConfirmWithPriceAction && !PassesPriceAction(rates[1]))
   {
      stats.rejectedByPriceAction++;
      return;
   }

   if(!PassesPrecisionFilters(buySignal)) return;
   if(HasOpenPosition(buySignal)) return;

   //--- Stop distance
   double atr = 0.0;
   bool haveATR = GetATR(atr) && atr > 0;
   double slDist = haveATR ? atr * SL_ATR_Mult : SL_Points * _Point;

   double spread  = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double minStop = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point + spread;
   slDist = MathMax(slDist, minStop);
   if(slDist <= 0) return;

   //--- Lot size (adaptive multiplier + hard loss cap)
   double lot = 0;
   if(!CalculateTradeLot(slDist, lot)) return;

   if(ExecuteOrder(buySignal, slDist, lot))
   {
      lastTradeBarTime = currentBarTime;
      SaveState();
   }
}

bool EnoughBarsSinceLastTrade()
{
   if(MinBarsBetweenTrades <= 0 || lastTradeBarTime == 0) return true;
   int shift = iBarShift(_Symbol, InpSignalTF, lastTradeBarTime, false);
   if(shift < 0) return true;
   return (shift >= MinBarsBetweenTrades);
}

//+------------------------------------------------------------------+
//| RISK & LOT SIZING                                                 |
//+------------------------------------------------------------------+
// Money value of a 1.0 price-unit move for 1 lot (account currency)
double ValuePerPriceUnit()
{
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tickValue <= 0) tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0 || tickSize <= 0) return 0;
   return tickValue / tickSize;
}

double RiskForLot(double lot, double slDist)
{
   return lot * slDist * ValuePerPriceUnit();
}

double CalcLotFromRisk(double slDist)
{
   double vpu = ValuePerPriceUnit();
   if(slDist <= 0 || vpu <= 0) return FixedLot;

   double riskAmt = AccountInfoDouble(ACCOUNT_BALANCE) * MathMax(0.0, RiskPerTrade) / 100.0;
   return riskAmt / (slDist * vpu);
}

bool CalculateTradeLot(double slDist, double &lot)
{
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   double baseLot = UseFixedLot ? FixedLot : CalcLotFromRisk(slDist);
   double mult    = UseAdaptiveSizing ? lossTracker.currentLotMultiplier : 1.0;

   lot = NormalizeVolumeDown(baseLot * mult);
   if(lot < vmin) lot = vmin;
   if(lot > vmax) lot = vmax;

   if(MaxLossPerTrade_USD > 0)
   {
      double risk = RiskForLot(lot, slDist);
      if(risk > MaxLossPerTrade_USD + 1e-9)
      {
         double capped = NormalizeVolumeDown(lot * MaxLossPerTrade_USD / risk);
         if(capped < vmin - 1e-8)
         {
            stats.rejectedByLossLimit++;
            if(DetailedLog)
               Print("⛔ Trade skipped: min lot ", vmin, " would risk ",
                     DoubleToString(RiskForLot(vmin, slDist), 2), " > cap ", MaxLossPerTrade_USD);
            return false;
         }
         stats.lotsReducedByCap++;
         if(DetailedLog)
            Print("⚠️ Lot reduced ", lot, " -> ", capped, " to respect max loss ", MaxLossPerTrade_USD);
         lot = capped;
      }
   }
   return true;
}

//+------------------------------------------------------------------+
//| ORDER EXECUTION (BUY/SELL)                                        |
//+------------------------------------------------------------------+
ulong PositionTicketFromResult()
{
   ulong deal = Trade.ResultDeal();
   if(deal > 0 && HistoryDealSelect(deal))
   {
      ulong id = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
      if(id > 0 && PositionSelectByTicket(id)) return id;
   }
   ulong order = Trade.ResultOrder();
   if(order > 0 && PositionSelectByTicket(order)) return order;
   return 0;
}

bool ExecuteOrder(bool isBuy, double slDist, double lot)
{
   double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = PriceNormalize(isBuy ? price - slDist : price + slDist);

   // With trailing, the broker TP sits beyond TP2 so the EA can scale out and trail
   double tpR = UseTrailingForRemaining ? FinalTP_RR : TP2_RR;
   double tp  = 0;
   if(tpR > 0)
      tp = PriceNormalize(isBuy ? price + slDist * tpR : price - slDist * tpR);

   string comment = isBuy ? "AlgoGold_BUY_v3.1" : "AlgoGold_SELL_v3.1";

   Trade.SetExpertMagicNumber(Magic);
   bool sent = isBuy ? Trade.Buy(lot, _Symbol, 0.0, sl, tp, comment)
                     : Trade.Sell(lot, _Symbol, 0.0, sl, tp, comment);

   if(!sent || !ResultOK())
   {
      Print("❌ ", (isBuy ? "BUY" : "SELL"), " failed: ", Trade.ResultRetcodeDescription());
      return false;
   }

   stats.tradesExecuted++;

   ulong posTicket = PositionTicketFromResult();
   if(posTicket > 0 && PositionSelectByTicket(posTicket))
   {
      // 1R measured from the actual fill, not the quote
      double open   = PositionGetDouble(POSITION_PRICE_OPEN);
      double posSL  = PositionGetDouble(POSITION_SL);
      double vol    = PositionGetDouble(POSITION_VOLUME);
      double realSL = (posSL > 0) ? MathAbs(open - posSL) : slDist;

      SavePosState(posTicket, realSL, vol, 0);
      AdoptPosition(posTicket);

      if(DetailedLog)
      {
         Print("✅ ", (isBuy ? "BUY" : "SELL"), " #", posTicket, ": Entry=", open,
               " SL=", posSL, " TP=", tp);
         Print("   Risk=", DoubleToString(RiskForLot(vol, realSL), 2), " Lot=", vol,
               " LotMult=", DoubleToString(lossTracker.currentLotMultiplier, 2));
      }
   }
   else if(DetailedLog)
   {
      Print("✅ ", (isBuy ? "BUY" : "SELL"), " sent - position will be tracked on the next tick");
   }
   return true;
}

//+------------------------------------------------------------------+
//| FILTERS                                                           |
//+------------------------------------------------------------------+
bool PassesPriceAction(const MqlRates &bar)
{
   double barRange = bar.high - bar.low;
   double barBody  = MathAbs(bar.close - bar.open);
   if(barRange <= 0) return false;
   return (barBody >= barRange * 0.4);
}

bool PassesPrecisionFilters(bool isBuySignal)
{
   if(UseSpreadFilter && !PassesSpreadFilter())
   {
      stats.rejectedBySpread++;
      return false;
   }

   if(AvoidLowVolatility && !PassesVolatilityFilter())
   {
      stats.rejectedByVolatility++;
      return false;
   }

   if(UseMomentumFilter && !PassesMomentumFilter(isBuySignal))
   {
      stats.rejectedByMomentum++;
      return false;
   }

   return true;
}

bool PassesSpreadFilter()
{
   double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spreadPoints = spread / _Point;

   if(spreadPoints > MaxSpreadPips) return false;

   double atr = 0;
   if(GetATR(atr) && atr > 0)
      if(spread / atr > MaxSpreadATR) return false;

   return true;
}

bool PassesVolatilityFilter()
{
   double atr = 0;
   if(!GetATR(atr)) return true;
   return (atr >= MinATRForEntry);
}

bool PassesMomentumFilter(bool isBuySignal)
{
   if(!UseMomentumFilter || hRSI == INVALID_HANDLE) return true;

   int shift = RequireBarClose ? 1 : 0;   // Same bar as the MA cross
   double rsiBuffer[];
   ArraySetAsSeries(rsiBuffer, true);
   if(CopyBuffer(hRSI, 0, shift, 1, rsiBuffer) < 1) return true;

   double rsi = rsiBuffer[0];

   if(isBuySignal)
   {
      if(rsi > RSI_Overbought || rsi < RSI_MinStrength) return false;
   }
   else
   {
      if(rsi < RSI_Oversold || rsi > (100 - RSI_MinStrength)) return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| INDICATOR ACCESS                                                  |
//+------------------------------------------------------------------+
bool GetATR(double &out)
{
   if(hATR == INVALID_HANDLE) return false;
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(hATR, 0, 0, 1, buf) < 1) return false;
   out = buf[0];
   return true;
}

// Series-ordered buffers: index 0 = most recent bar of the copied range.
// With RequireBarClose the cross is read on closed bars 1 and 2.
bool GetMAValues(double &fastPrev, double &fastCur, double &slowPrev, double &slowCur, double &htfCur)
{
   int shift = RequireBarClose ? 1 : 0;

   double f[], s[], h[];
   ArraySetAsSeries(f, true);
   ArraySetAsSeries(s, true);
   ArraySetAsSeries(h, true);

   if(CopyBuffer(hFast, 0, shift, 2, f) < 2) return false;
   if(CopyBuffer(hSlow, 0, shift, 2, s) < 2) return false;
   if(CopyBuffer(hHTF,  0, 0,     1, h) < 1) return false;

   fastCur  = f[0];
   fastPrev = f[1];
   slowCur  = s[0];
   slowPrev = s[1];
   htfCur   = h[0];
   return true;
}

//+------------------------------------------------------------------+
//| POSITION QUERIES                                                  |
//+------------------------------------------------------------------+
bool HasOpenPosition(bool isBuy)
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(!Pos.SelectByIndex(i)) continue;
      if(Pos.Symbol() != _Symbol || Pos.Magic() != Magic) continue;
      if((isBuy && Pos.PositionType() == POSITION_TYPE_BUY) ||
         (!isBuy && Pos.PositionType() == POSITION_TYPE_SELL))
         return true;
   }
   return false;
}

int OpenPositionsCount()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(!Pos.SelectByIndex(i)) continue;
      if(Pos.Symbol() == _Symbol && Pos.Magic() == Magic)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| NORMALIZATION HELPERS                                             |
//+------------------------------------------------------------------+
int DigitsFor(double step)
{
   if(step <= 0) return 2;
   double p = MathCeil(-MathLog10(step));
   if(p < 0) p = 0;
   if(p > 8) p = 8;
   return (int)p;
}

// Round DOWN to the volume step (never rounds up into more risk).
// Result may be below the minimum lot - callers check that.
double NormalizeVolumeDown(double vol)
{
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step <= 0) step = 0.01;
   if(vol <= 0) return 0;

   double v = MathFloor(vol / step + 1e-7) * step;
   if(vmax > 0) v = MathMin(v, vmax);
   return NormalizeDouble(v, DigitsFor(step));
}

double PriceNormalize(double price)
{
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(ts > 0) price = MathRound(price / ts) * ts;
   return NormalizeDouble(price, (int)_Digits);
}

//+------------------------------------------------------------------+
//| INFO PANEL                                                        |
//+------------------------------------------------------------------+
void UpdateInfoPanel()
{
   double atr = 0;
   GetATR(atr);

   double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);

   string pauseStatus = "";
   if(DailyLimitReached())
      pauseStatus = "\n🛑 TRADING PAUSED (Daily Loss Limit) until tomorrow";
   else if(lossTracker.pauseUntil > TimeCurrent())
      pauseStatus = StringFormat("\n⏸️ PAUSED (%d consecutive losses) until %s",
                                 lossTracker.consecutiveLosses,
                                 TimeToString(lossTracker.pauseUntil, TIME_MINUTES));

   string info = StringFormat(
      "🛡️ ALGO TRADER GOLD v3.1 | %s\n" +
      "═════════════════════════════════════\n" +
      "Spread: %.1f | ATR: %.1f | Positions: %d%s\n" +
      "─────────────────────────────────────\n" +
      "Day P/L: %.2f (limit -%.0f)\n" +
      "Consecutive Losses: %d / %d\n" +
      "Lot Multiplier: %.2f\n" +
      "─────────────────────────────────────\n" +
      "Signals: %d | Executed: %d | W/L: %d/%d\n" +
      "Early Exits: %d | Time Exits: %d | BE Hits: %d\n" +
      "TP Ladder: TP1=%d | TP2=%d\n" +
      "Loss Cap: %d skipped | %d reduced",
      _Symbol,
      spread / _Point,
      atr / _Point,
      OpenPositionsCount(),
      pauseStatus,
      lossTracker.dailyPnL,
      DailyMaxLoss_USD,
      lossTracker.consecutiveLosses,
      MaxConsecutiveLosses,
      lossTracker.currentLotMultiplier,
      stats.totalSignals,
      stats.tradesExecuted,
      stats.wins,
      stats.losses,
      stats.earlyExits,
      stats.timeExits,
      stats.breakEvenHits,
      stats.tp1Hits,
      stats.tp2Hits,
      stats.rejectedByLossLimit,
      stats.lotsReducedByCap
   );

   Comment(info);
}

//+------------------------------------------------------------------+
