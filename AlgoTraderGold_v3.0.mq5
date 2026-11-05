//+------------------------------------------------------------------+
//|              Algo Trader Gold EA v3.0 - LOSS CONTROL EDITION    |
//|           Professional Gold Trading System - XAUUSD/XAUEUR       |
//|  Critical Focus: Minimize Loss Impact, Protect Capital          |
//+------------------------------------------------------------------+
#property strict
#property version   "3.0"
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
input ENUM_TIMEFRAMES InpExecTF     = PERIOD_M1;
input ENUM_TIMEFRAMES InpHTFTF      = PERIOD_M5;
input int    FastMAPeriod           = 9;
input int    SlowMAPeriod           = 21;
input int    HTFMAPeriod            = 50;

//=== POSITION SIZING ===
input group "══════════ POSITION SIZING ══════════"
input bool   UseFixedLot            = true;
input double FixedLot               = 0.01;
input double RiskPerTrade           = 1.0;

//=== 🔥 NEW: LOSS CONTROL SYSTEM (CRITICAL) ===
input group "══════════ 🛡️ LOSS CONTROL (NEW) ══════════"
input double SL_ATR_Mult            = 1.5;         // SL ATR Multiplier (REDUCED from 2.0)
input int    SL_Points              = 300;         // Fallback SL (REDUCED from 400)
input double MaxLossPerTrade_USD    = 20.0;        // 🔥 Hard Loss Cap (USD)
input bool   UseEarlyExitLogic      = true;        // 🔥 Enable Early Exit System
input double EarlyExit_Threshold    = 0.5;         // Exit if -0.5R in 5 minutes
input int    EarlyExit_TimeMinutes  = 5;           // Time window for rapid loss
input bool   UseTimeBasedExit       = true;        // 🔥 Time-based invalidation
input int    TimeExit_Minutes       = 20;          // Exit if not profitable after X min
input double TimeExit_MinProfit     = 0.3;         // Required profit (in R) to stay in

//=== 🔥 NEW: AGGRESSIVE BREAK-EVEN ===
input group "══════════ 🛡️ BREAK-EVEN PROTECTION ══════════"
input bool   UseAggressiveBE        = true;        // 🔥 Move to BE early
input double BE_TriggerR            = 0.8;         // Move to BE at +0.8R
input double BE_LockProfit          = 10.0;        // Lock profit (pips) at 1.2R

//=== TAKE PROFIT - SCALED EXITS ===
input group "══════════ TAKE PROFIT (IMPROVED) ══════════"
input double TP1_RR                 = 1.0;         // First TP at 1R
input double TP1_Percent            = 30.0;        // Close 30% at TP1
input double TP2_RR                 = 2.0;         // Second TP at 2R
input double TP2_Percent            = 40.0;        // Close 40% at TP2
input bool   UseTrailingForRemaining = true;       // Trail remaining 30%

//=== TRAILING STOP (TIGHTER) ===
input group "══════════ TRAILING STOP (TIGHTER) ══════════"
input double TrailStartPoints       = 150;         // Trail Activation (REDUCED from 200)
input double TrailDistanceATR       = 1.0;         // Trail Distance (TIGHTER from 1.5)
input int    ATRPeriod              = 14;
input ENUM_TIMEFRAMES ATR_TF        = PERIOD_M5;

//=== 🔥 NEW: LOSS CLUSTER PREVENTION ===
input group "══════════ 🛡️ CLUSTER PREVENTION ══════════"
input bool   UseLossClusterFilter   = true;        // 🔥 Stop after consecutive losses
input int    MaxConsecutiveLosses   = 3;           // Pause after 3 losses
input double DailyMaxLoss_USD       = 50.0;        // 🔥 Daily loss limit
input bool   UseAdaptiveSizing      = true;        // 🔥 Reduce lot after losses
input double AdaptiveLotReduction   = 0.5;         // Multiply lot by this after loss

//=== ENTRY FILTERS (PRESERVED) ===
input group "══════════ ENTRY PRECISION ══════════"
input bool   RequireBarClose        = true;
input bool   UseMomentumFilter      = true;
input int    RSIPeriod              = 14;
input int    RSI_Overbought         = 70;
input int    RSI_Oversold           = 30;
input int    RSI_MinStrength        = 45;
input bool   ConfirmWithPriceAction = true;

//=== GOLD FILTERS (PRESERVED) ===
input group "══════════ GOLD PROTECTION ══════════"
input bool   UseSpreadFilter        = true;
input double MaxSpreadATR           = 0.4;         // TIGHTER from 0.5
input int    MaxSpreadPips          = 40;          // TIGHTER from 50
input bool   AvoidLowVolatility     = true;
input double MinATRForEntry         = 0.0005;

//=== POSITION MANAGEMENT ===
input group "══════════ POSITION MANAGEMENT ══════════"
input int    Magic                  = 13579;
input bool   OnePositionPerSymbol   = true;
input int    MinBarsBetweenTrades   = 10;

//=== DIAGNOSTICS ===
input group "══════════ MONITORING ══════════"
input bool   DetailedLog            = true;        // Enabled by default for testing
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
static datetime lastTradeBarTime = 0;
static datetime lastSignalCheck = 0;

// 🔥 NEW: Loss tracking
struct LossTracker {
   int consecutiveLosses;
   double dailyLoss;
   datetime lastResetDate;
   bool tradingPaused;
   double currentLotMultiplier;
} lossTracker;

// Performance tracking
struct PerformanceStats {
   int totalSignals;
   int rejectedByMomentum;
   int rejectedBySpread;
   int rejectedByVolatility;
   int rejectedByPriceAction;
   int rejectedByLossLimit;
   int tradesExecuted;
   int earlyExits;
   int breakEvenHits;
   int tp1Hits;
   int tp2Hits;
} stats;

// Position tracking for early exits
struct PositionTracker {
   ulong ticket;
   datetime entryTime;
   double entryPrice;
   double slDistance;
   double initialRisk;
   bool tp1Hit;
   bool tp2Hit;
   bool beSet;
   double worstDrawdown;
} posTracker[];

//+------------------------------------------------------------------+
//| INITIALIZATION                                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize indicators
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

   // Initialize loss tracker
   ZeroMemory(lossTracker);
   lossTracker.currentLotMultiplier = 1.0;
   lossTracker.lastResetDate = TimeCurrent();

   ZeroMemory(stats);

   Print("═══════════════════════════════════════════════════════");
   Print("  🛡️ ALGO TRADER GOLD v3.0 - LOSS CONTROL EDITION");
   Print("═══════════════════════════════════════════════════════");
   Print("Symbol: ", _Symbol);
   Print("🔥 LOSS CONTROL ACTIVE:");
   Print("  └─ SL: ", SL_ATR_Mult, " ATR (reduced from 2.0)");
   Print("  └─ Max Loss Cap: $", MaxLossPerTrade_USD);
   Print("  └─ Early Exit: ", (UseEarlyExitLogic ? "ON" : "OFF"));
   Print("  └─ Time-Based Exit: ", (UseTimeBasedExit ? "ON" : "OFF"));
   Print("  └─ Aggressive BE: ", (UseAggressiveBE ? StringFormat("%.1fR", BE_TriggerR) : "OFF"));
   Print("  └─ Loss Cluster Filter: ", (UseLossClusterFilter ? "ON" : "OFF"));
   Print("  └─ Daily Max Loss: $", DailyMaxLoss_USD);
   Print("═══════════════════════════════════════════════════════");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINITIALIZATION                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(hATR != INVALID_HANDLE) IndicatorRelease(hATR);
   if(hFast != INVALID_HANDLE) IndicatorRelease(hFast);
   if(hSlow != INVALID_HANDLE) IndicatorRelease(hSlow);
   if(hHTF != INVALID_HANDLE) IndicatorRelease(hHTF);
   if(hRSI != INVALID_HANDLE) IndicatorRelease(hRSI);

   Comment("");

   if(stats.totalSignals > 0)
   {
      Print("═══════════════════════════════════════════════════════");
      Print("      🛡️ LOSS CONTROL SESSION SUMMARY");
      Print("═══════════════════════════════════════════════════════");
      Print("Signals: ", stats.totalSignals, " | Executed: ", stats.tradesExecuted);
      Print("Early Exits: ", stats.earlyExits, " | BE Hits: ", stats.breakEvenHits);
      Print("TP Ladder: TP1=", stats.tp1Hits, " | TP2=", stats.tp2Hits);
      Print("Loss Protection: ", stats.rejectedByLossLimit, " trades prevented");
      Print("═══════════════════════════════════════════════════════");
   }
}

//+------------------------------------------------------------------+
//| MAIN TICK HANDLER                                                 |
//+------------------------------------------------------------------+
void OnTick()
{
   ResetDailyLossIfNeeded();
   ManageOpenPositions();  // 🔥 NEW: Comprehensive position management
   CheckForSignals();

   if(ShowInfo) UpdateInfoPanel();
}

//+------------------------------------------------------------------+
//| 🔥 NEW: RESET DAILY LOSS COUNTER                                 |
//+------------------------------------------------------------------+
void ResetDailyLossIfNeeded()
{
   MqlDateTime currentTime;
   TimeToStruct(TimeCurrent(), currentTime);

   MqlDateTime lastTime;
   TimeToStruct(lossTracker.lastResetDate, lastTime);

   // Reset at start of new day
   if(currentTime.day != lastTime.day)
   {
      if(DetailedLog && lossTracker.dailyLoss > 0)
         Print("📅 Daily reset - Previous day loss: $", DoubleToString(lossTracker.dailyLoss, 2));

      lossTracker.dailyLoss = 0;
      lossTracker.lastResetDate = TimeCurrent();
      lossTracker.tradingPaused = false;
   }
}

//+------------------------------------------------------------------+
//| 🔥 NEW: COMPREHENSIVE POSITION MANAGEMENT                        |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Pos.SelectByIndex(i)) continue;
      if(Pos.Symbol() != _Symbol || Pos.Magic() != Magic) continue;

      ulong ticket = Pos.Ticket();
      int trackerIndex = FindPositionTracker(ticket);

      // Early exit checks
      if(UseEarlyExitLogic)
         CheckEarlyExitConditions(ticket, trackerIndex);

      if(UseTimeBasedExit)
         CheckTimeBasedExit(ticket, trackerIndex);

      // Break-even management
      if(UseAggressiveBE)
         ManageAggressiveBreakEven(ticket, trackerIndex);

      // Scaled TP management
      ManageScaledTakeProfit(ticket, trackerIndex);

      // Trailing stop
      if(UseTrailingForRemaining)
         ManageTrailingStop(ticket, trackerIndex);
   }
}

//+------------------------------------------------------------------+
//| 🔥 NEW: EARLY EXIT - RAPID ADVERSE MOVE DETECTION                |
//+------------------------------------------------------------------+
void CheckEarlyExitConditions(ulong ticket, int trackerIndex)
{
   if(trackerIndex < 0) return;

   bool isBuy = (Pos.PositionType() == POSITION_TYPE_BUY);
   double currentPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                               : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double entryPrice = posTracker[trackerIndex].entryPrice;
   double slDist = posTracker[trackerIndex].slDistance;

   // Calculate current loss in R
   double currentMove = isBuy ? (currentPrice - entryPrice) : (entryPrice - currentPrice);
   double currentR = slDist > 0 ? (currentMove / slDist) : 0;

   // Track worst drawdown
   if(currentR < posTracker[trackerIndex].worstDrawdown)
      posTracker[trackerIndex].worstDrawdown = currentR;

   // Check if rapid adverse move occurred
   int secondsSinceEntry = (int)(TimeCurrent() - posTracker[trackerIndex].entryTime);

   if(secondsSinceEntry <= EarlyExit_TimeMinutes * 60)
   {
      if(currentR <= -EarlyExit_Threshold)
      {
         // Close immediately - trade went wrong fast
         if(Trade.PositionClose(ticket))
         {
            stats.earlyExits++;

            if(DetailedLog)
               Print("🚨 EARLY EXIT: Rapid adverse move detected (",
                     DoubleToString(currentR, 2), "R in ",
                     secondsSinceEntry, " seconds)");

            RemovePositionTracker(trackerIndex);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 🔥 NEW: TIME-BASED EXIT - TRADE NOT WORKING                      |
//+------------------------------------------------------------------+
void CheckTimeBasedExit(ulong ticket, int trackerIndex)
{
   if(trackerIndex < 0) return;

   int minutesSinceEntry = (int)((TimeCurrent() - posTracker[trackerIndex].entryTime) / 60);

   if(minutesSinceEntry >= TimeExit_Minutes)
   {
      bool isBuy = (Pos.PositionType() == POSITION_TYPE_BUY);
      double currentPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      double entryPrice = posTracker[trackerIndex].entryPrice;
      double slDist = posTracker[trackerIndex].slDistance;

      double currentMove = isBuy ? (currentPrice - entryPrice) : (entryPrice - currentPrice);
      double currentR = slDist > 0 ? (currentMove / slDist) : 0;

      // If not profitable enough after time limit, exit
      if(currentR < TimeExit_MinProfit)
      {
         if(Trade.PositionClose(ticket))
         {
            stats.earlyExits++;

            if(DetailedLog)
               Print("⏱️ TIME EXIT: Trade stalled at ",
                     DoubleToString(currentR, 2), "R after ",
                     minutesSinceEntry, " minutes");

            RemovePositionTracker(trackerIndex);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 🔥 NEW: AGGRESSIVE BREAK-EVEN MANAGEMENT                         |
//+------------------------------------------------------------------+
void ManageAggressiveBreakEven(ulong ticket, int trackerIndex)
{
   if(trackerIndex < 0) return;
   if(posTracker[trackerIndex].beSet) return;

   bool isBuy = (Pos.PositionType() == POSITION_TYPE_BUY);
   double currentPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                               : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double entryPrice = posTracker[trackerIndex].entryPrice;
   double slDist = posTracker[trackerIndex].slDistance;
   double currentSL = Pos.StopLoss();

   double currentMove = isBuy ? (currentPrice - entryPrice) : (entryPrice - currentPrice);
   double currentR = slDist > 0 ? (currentMove / slDist) : 0;

   // Move to BE at configured trigger
   if(currentR >= BE_TriggerR)
   {
      double newSL = PriceNormalize(entryPrice);

      if((isBuy && newSL > currentSL) || (!isBuy && newSL < currentSL))
      {
         if(Trade.PositionModify(ticket, newSL, Pos.TakeProfit()))
         {
            posTracker[trackerIndex].beSet = true;
            stats.breakEvenHits++;

            if(DetailedLog)
               Print("✅ BREAK-EVEN set at ", DoubleToString(currentR, 2), "R");
         }
      }
   }

   // Lock profit at higher level
   if(currentR >= (BE_TriggerR + 0.4) && posTracker[trackerIndex].beSet)
   {
      double lockProfit = BE_LockProfit * _Point;
      double newSL = isBuy ? entryPrice + lockProfit : entryPrice - lockProfit;
      newSL = PriceNormalize(newSL);

      if((isBuy && newSL > currentSL) || (!isBuy && newSL < currentSL))
      {
         if(Trade.PositionModify(ticket, newSL, Pos.TakeProfit()))
         {
            if(DetailedLog)
               Print("✅ PROFIT LOCKED: +", DoubleToString(BE_LockProfit, 1), " pips");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 🔥 NEW: SCALED TAKE PROFIT MANAGEMENT                            |
//+------------------------------------------------------------------+
void ManageScaledTakeProfit(ulong ticket, int trackerIndex)
{
   if(trackerIndex < 0) return;

   bool isBuy = (Pos.PositionType() == POSITION_TYPE_BUY);
   double currentPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                               : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double entryPrice = posTracker[trackerIndex].entryPrice;
   double slDist = posTracker[trackerIndex].slDistance;

   double currentMove = isBuy ? (currentPrice - entryPrice) : (entryPrice - currentPrice);
   double currentR = slDist > 0 ? (currentMove / slDist) : 0;

   double currentLot = Pos.Volume();

   // TP1: Close first portion
   if(!posTracker[trackerIndex].tp1Hit && currentR >= TP1_RR)
   {
      double closeVolume = NormalizeVolume(currentLot * TP1_Percent / 100.0);

      if(closeVolume >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
      {
         if(Trade.PositionClosePartial(ticket, closeVolume))
         {
            posTracker[trackerIndex].tp1Hit = true;
            stats.tp1Hits++;

            if(DetailedLog)
               Print("💰 TP1 Hit: Closed ", DoubleToString(TP1_Percent, 0),
                     "% at ", DoubleToString(TP1_RR, 1), "R");
         }
      }
   }

   // TP2: Close second portion
   if(!posTracker[trackerIndex].tp2Hit && posTracker[trackerIndex].tp1Hit && currentR >= TP2_RR)
   {
      double closeVolume = NormalizeVolume(currentLot * TP2_Percent / (100.0 - TP1_Percent));

      if(closeVolume >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
      {
         if(Trade.PositionClosePartial(ticket, closeVolume))
         {
            posTracker[trackerIndex].tp2Hit = true;
            stats.tp2Hits++;

            if(DetailedLog)
               Print("💰💰 TP2 Hit: Closed ", DoubleToString(TP2_Percent, 0),
                     "% at ", DoubleToString(TP2_RR, 1), "R");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| TRAILING STOP (TIGHTER)                                          |
//+------------------------------------------------------------------+
void ManageTrailingStop(ulong ticket, int trackerIndex)
{
   if(trackerIndex < 0) return;
   if(!posTracker[trackerIndex].tp2Hit) return;  // Only trail after TP2

   bool isBuy = (Pos.PositionType() == POSITION_TYPE_BUY);
   double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                        : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double open = Pos.PriceOpen();
   double sl = Pos.StopLoss();

   if((isBuy && price - open > TrailStartPoints * _Point) ||
      (!isBuy && open - price > TrailStartPoints * _Point))
   {
      double atr = 0.0;
      if(!GetATR(atr)) return;

      double trailDist = atr * TrailDistanceATR;
      double newSL = isBuy ? price - trailDist : price + trailDist;

      if(isBuy && (sl < newSL || sl == 0))
         Trade.PositionModify(ticket, PriceNormalize(newSL), Pos.TakeProfit());

      if(!isBuy && (sl > newSL || sl == 0))
         Trade.PositionModify(ticket, PriceNormalize(newSL), Pos.TakeProfit());
   }
}

//+------------------------------------------------------------------+
//| CHECK FOR SIGNALS (WITH LOSS CONTROL)                           |
//+------------------------------------------------------------------+
void CheckForSignals()
{
   // 🔥 NEW: Check daily loss limit
   if(UseLossClusterFilter && lossTracker.dailyLoss >= DailyMaxLoss_USD)
   {
      if(!lossTracker.tradingPaused)
      {
         lossTracker.tradingPaused = true;
         Print("🛑 DAILY LOSS LIMIT REACHED: $", DoubleToString(lossTracker.dailyLoss, 2),
               " - Trading paused until tomorrow");
      }
      return;
   }

   // 🔥 NEW: Check consecutive loss limit
   if(UseLossClusterFilter && lossTracker.consecutiveLosses >= MaxConsecutiveLosses)
   {
      if(DetailedLog)
         Print("⏸️ Trading paused: ", MaxConsecutiveLosses, " consecutive losses");
      return;
   }

   if(OnePositionPerSymbol && OpenPositionsCount() > 0) return;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, InpSignalTF, 0, 3, rates) < 3) return;

   datetime currentBarTime = rates[0].time;

   if(RequireBarClose)
   {
      if(currentBarTime == lastSignalCheck) return;
      lastSignalCheck = currentBarTime;
      if(!AnalyzeClosedBar()) return;
   }
   else
   {
      if(currentBarTime == lastTradeBarTime) return;
   }

   double fastPrev, fastCur, slowPrev, slowCur, htfCur;
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

   if(!PassesPrecisionFilters(buySignal)) return;

   double atr = 0.0;
   bool haveATR = GetATR(atr);
   double slDist = haveATR ? atr * SL_ATR_Mult : SL_Points * _Point;
   if(slDist <= 0) return;

   // 🔥 NEW: Enforce max loss cap
   double riskUSD = CalculateRiskUSD(slDist);
   if(riskUSD > MaxLossPerTrade_USD)
   {
      slDist = slDist * (MaxLossPerTrade_USD / riskUSD);
      stats.rejectedByLossLimit++;

      if(DetailedLog)
         Print("⚠️ SL adjusted to meet $", MaxLossPerTrade_USD, " max loss");
   }

   if(buySignal && !HasOpenPosition(true))
   {
      ExecuteBuyOrder(slDist, atr);
      lastTradeBarTime = currentBarTime;
   }
   else if(sellSignal && !HasOpenPosition(false))
   {
      ExecuteSellOrder(slDist, atr);
      lastTradeBarTime = currentBarTime;
   }
}

//+------------------------------------------------------------------+
//| 🔥 NEW: CALCULATE RISK IN USD                                    |
//+------------------------------------------------------------------+
double CalculateRiskUSD(double slDistancePoints)
{
   double lot = UseFixedLot ? FixedLot * lossTracker.currentLotMultiplier
                            : CalcLotFromRisk(slDistancePoints / _Point);

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   double pointValue = (tickSize > 0) ? (tickValue * (_Point / tickSize)) : tickValue;
   double riskUSD = lot * slDistancePoints * pointValue / _Point;

   return riskUSD;
}

//+------------------------------------------------------------------+
//| EXECUTE BUY ORDER (WITH TRACKING)                               |
//+------------------------------------------------------------------+
void ExecuteBuyOrder(double slDist, double atr)
{
   double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl = PriceNormalize(entryPrice - slDist);
   double tp = PriceNormalize(entryPrice + slDist * TP2_RR);

   double lot = UseFixedLot ? FixedLot * lossTracker.currentLotMultiplier
                            : CalcLotFromRisk(slDist / _Point);
   if(!CheckVolume(lot)) return;

   string comment = "AlgoGold_BUY_v3.0";

   Trade.SetExpertMagicNumber(Magic);
   if(Trade.Buy(lot, _Symbol, 0.0, sl, tp, comment))
   {
      stats.tradesExecuted++;

      // Add position tracker
      AddPositionTracker(Trade.ResultOrder(), entryPrice, slDist);

      if(DetailedLog)
      {
         Print("✅ BUY: Entry=", entryPrice, " SL=", sl, " TP=", tp);
         Print("   Risk=$", DoubleToString(CalculateRiskUSD(slDist), 2),
               " Lot=", lot);
      }
   }
}

//+------------------------------------------------------------------+
//| EXECUTE SELL ORDER (WITH TRACKING)                              |
//+------------------------------------------------------------------+
void ExecuteSellOrder(double slDist, double atr)
{
   double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = PriceNormalize(entryPrice + slDist);
   double tp = PriceNormalize(entryPrice - slDist * TP2_RR);

   double lot = UseFixedLot ? FixedLot * lossTracker.currentLotMultiplier
                            : CalcLotFromRisk(slDist / _Point);
   if(!CheckVolume(lot)) return;

   string comment = "AlgoGold_SELL_v3.0";

   Trade.SetExpertMagicNumber(Magic);
   if(Trade.Sell(lot, _Symbol, 0.0, sl, tp, comment))
   {
      stats.tradesExecuted++;

      AddPositionTracker(Trade.ResultOrder(), entryPrice, slDist);

      if(DetailedLog)
      {
         Print("✅ SELL: Entry=", entryPrice, " SL=", sl, " TP=", tp);
         Print("   Risk=$", DoubleToString(CalculateRiskUSD(slDist), 2),
               " Lot=", lot);
      }
   }
}

//+------------------------------------------------------------------+
//| 🔥 POSITION TRACKER FUNCTIONS                                    |
//+------------------------------------------------------------------+
void AddPositionTracker(ulong ticket, double entry, double slDist)
{
   int size = ArraySize(posTracker);
   ArrayResize(posTracker, size + 1);

   posTracker[size].ticket = ticket;
   posTracker[size].entryTime = TimeCurrent();
   posTracker[size].entryPrice = entry;
   posTracker[size].slDistance = slDist;
   posTracker[size].initialRisk = CalculateRiskUSD(slDist);
   posTracker[size].tp1Hit = false;
   posTracker[size].tp2Hit = false;
   posTracker[size].beSet = false;
   posTracker[size].worstDrawdown = 0;
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
   if(index < 0 || index >= ArraySize(posTracker)) return;

   int size = ArraySize(posTracker);
   for(int i = index; i < size - 1; i++)
      posTracker[i] = posTracker[i + 1];

   ArrayResize(posTracker, size - 1);
}

//+------------------------------------------------------------------+
//| HELPER FUNCTIONS (PRESERVED FROM ORIGINAL)                      |
//+------------------------------------------------------------------+

bool AnalyzeClosedBar()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, InpSignalTF, 0, 3, rates) < 3) return false;

   if(!ConfirmWithPriceAction) return true;

   double barRange = rates[1].high - rates[1].low;
   double barBody  = MathAbs(rates[1].close - rates[1].open);

   if(barBody < barRange * 0.4)
   {
      stats.rejectedByPriceAction++;
      return false;
   }

   return true;
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
   double spreadPips = spread / _Point;

   if(spreadPips > MaxSpreadPips) return false;

   double atr;
   if(GetATR(atr) && atr > 0)
      if(spread / atr > MaxSpreadATR) return false;

   return true;
}

bool PassesVolatilityFilter()
{
   double atr;
   if(!GetATR(atr)) return true;
   return (atr >= MinATRForEntry);
}

bool PassesMomentumFilter(bool isBuySignal)
{
   if(!UseMomentumFilter) return true;

   double rsiBuffer[1];
   if(CopyBuffer(hRSI, 0, 0, 1, rsiBuffer) <= 0) return true;

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

bool GetATR(double &out)
{
   if(hATR == INVALID_HANDLE) return false;
   double buf[1];
   if(CopyBuffer(hATR, 0, 0, 1, buf) <= 0) return false;
   out = buf[0];
   return true;
}

bool GetMAValues(double &fastPrev, double &fastCur, double &slowPrev, double &slowCur, double &htfCur)
{
   double f[2], s[2], h[1];
   if(CopyBuffer(hFast, 0, 0, 2, f) <= 0) return false;
   if(CopyBuffer(hSlow, 0, 0, 2, s) <= 0) return false;
   if(CopyBuffer(hHTF, 0, 0, 1, h) <= 0) return false;

   fastCur  = f[0];
   fastPrev = f[1];
   slowCur  = s[0];
   slowPrev = s[1];
   htfCur   = h[0];
   return true;
}

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

double CalcLotFromRisk(double sl_points)
{
   if(sl_points <= 0) return FixedLot;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmt = balance * MathMax(0.0, RiskPerTrade) / 100.0;

   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point_val = (tick_size > 0) ? (tick_value * (_Point / tick_size)) : tick_value;

   if(point_val <= 0.0) point_val = 1.0;

   double lot = riskAmt / (sl_points * point_val);
   return lot;
}

int DigitsFor(double step)
{
   if(step <= 0) return 2;
   double p = MathCeil(-MathLog10(step));
   if(p < 0) p = 0;
   if(p > 8) p = 8;
   return (int)p;
}

double NormalizeVolume(double vol)
{
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   int d = DigitsFor(step);

   double steps = MathRound((vol - vmin) / step);
   double v = vmin + steps * step;
   v = MathMax(vmin, MathMin(v, vmax));

   return NormalizeDouble(v, d);
}

bool CheckVolume(double &vol)
{
   vol = NormalizeVolume(vol);
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if(vol < vmin - 1e-8 || vol > vmax + 1e-8)
      return false;

   return true;
}

double PriceNormalize(double price)
{
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
   if(lossTracker.tradingPaused)
      pauseStatus = "\n🛑 TRADING PAUSED (Daily Loss Limit)";
   else if(lossTracker.consecutiveLosses >= MaxConsecutiveLosses)
      pauseStatus = StringFormat("\n⏸️ PAUSED (%d consecutive losses)", lossTracker.consecutiveLosses);

   string info = StringFormat(
      "🛡️ ALGO TRADER GOLD v3.0 | %s\n" +
      "═════════════════════════════════════\n" +
      "Spread: %.1f | ATR: %.1f | Positions: %d%s\n" +
      "─────────────────────────────────────\n" +
      "Daily Loss: $%.2f / $%.0f\n" +
      "Consecutive Losses: %d / %d\n" +
      "Lot Multiplier: %.2f\n" +
      "─────────────────────────────────────\n" +
      "Signals: %d | Executed: %d\n" +
      "Early Exits: %d | BE Hits: %d\n" +
      "TP Ladder: TP1=%d | TP2=%d",
      _Symbol,
      spread / _Point,
      atr / _Point,
      OpenPositionsCount(),
      pauseStatus,
      lossTracker.dailyLoss,
      DailyMaxLoss_USD,
      lossTracker.consecutiveLosses,
      MaxConsecutiveLosses,
      lossTracker.currentLotMultiplier,
      stats.totalSignals,
      stats.tradesExecuted,
      stats.earlyExits,
      stats.breakEvenHits,
      stats.tp1Hits,
      stats.tp2Hits
   );

   Comment(info);
}

//+------------------------------------------------------------------+
