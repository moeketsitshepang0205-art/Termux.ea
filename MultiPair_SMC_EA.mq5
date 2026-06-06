//+------------------------------------------------------------------+
//| Expert Advisor: MultiPair_SMC_EA                                 |
//+------------------------------------------------------------------+
#property strict

input double RiskPercent = 1.0;
input int RewardRatio = 3;
input double MinLot = 0.10;
input double PartialClosePercent = 50.0;
input int TrailPoints = 100;

// --- Lot calculation ---
double CalculateLot(double riskPercent, double stopLossPrice, string symbol)
  {
   double balance = AccountBalance();
   double riskAmount = balance * riskPercent / 100.0;
   double slDistance = MathAbs(SymbolInfoDouble(symbol, SYMBOL_ASK) - stopLossPrice);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double lot = riskAmount / (slDistance / Point * tickValue);
   return MathMax(NormalizeDouble(lot, 2), MinLot);
  }

// --- Break of Structure ---
bool BreakOfStructure(string symbol, int timeframe)
  {
   double prevHigh = iHigh(symbol, timeframe, 2);
   double lastHigh = iHigh(symbol, timeframe, 1);
   return (lastHigh > prevHigh);
  }

// --- Liquidity Sweep ---
bool LiquiditySweep(string symbol, int timeframe)
  {
   double prevHigh = iHigh(symbol, timeframe, 2);
   double lastHigh = iHigh(symbol, timeframe, 1);
   double prevLow  = iLow(symbol, timeframe, 2);
   double lastLow  = iLow(symbol, timeframe, 1);

   bool sweepHigh = (lastHigh > prevHigh && iClose(symbol, timeframe, 1) < prevHigh);
   bool sweepLow  = (lastLow < prevLow && iClose(symbol, timeframe, 1) > prevLow);

   return (sweepHigh || sweepLow);
  }

// --- Session Filter ---
bool InTradingSession()
  {
   datetime currentTime = TimeCurrent();
   int hour = TimeHour(currentTime);
   if((hour >= 7 && hour <= 11) || (hour >= 13 && hour <= 17))
      return true;
   return false;
  }

// --- Manage Trades ---
void ManageTrades(string symbol)
  {
   for(int i=0; i<PositionsTotal(); i++)
     {
      if(PositionGetString(POSITION_SYMBOL) != symbol) continue;

      ulong ticket = PositionGetTicket(i);
      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double stopLoss   = PositionGetDouble(POSITION_SL);
      double takeProfit = PositionGetDouble(POSITION_TP);
      double lotSize    = PositionGetDouble(POSITION_VOLUME);

      double tp1 = entryPrice + 2 * (entryPrice - stopLoss);
      if(SymbolInfoDouble(symbol, SYMBOL_BID) >= tp1)
        {
         double closeLots = lotSize * (PartialClosePercent/100.0);
         OrderClose(ticket, closeLots, Bid, 10);
        }

      double tp2 = entryPrice + 3 * (entryPrice - stopLoss);
      if(SymbolInfoDouble(symbol, SYMBOL_BID) >= tp2)
        {
         double newSL = SymbolInfoDouble(symbol, SYMBOL_BID) - TrailPoints * Point;
         if(newSL > stopLoss)
           {
            OrderModify(ticket, entryPrice, newSL, takeProfit, 0);
           }
        }
     }
  }

// --- Entry Logic ---
void CheckEntry(string symbol)
  {
   if(!InTradingSession()) return;

   bool bullish4H = iClose(symbol, PERIOD_H4, 1) > iOpen(symbol, PERIOD_H4, 1);
   bool breakout1H = BreakOfStructure(symbol, PERIOD_H1);
   bool sweep1H    = LiquiditySweep(symbol, PERIOD_H1);
   bool bullish15M = iClose(symbol, PERIOD_M15, 1) > iOpen(symbol, PERIOD_M15, 1);

   if(bullish4H && breakout1H && sweep1H && bullish15M && PositionsTotal() == 0)
     {
      double stopLoss = SymbolInfoDouble(symbol, SYMBOL_ASK) - 200 * Point;
      double takeProfit = SymbolInfoDouble(symbol, SYMBOL_ASK) + (RewardRatio * (SymbolInfoDouble(symbol, SYMBOL_ASK) - stopLoss));

      double lotSize = CalculateLot(RiskPercent, stopLoss, symbol);

      OrderSend(symbol, OP_BUY, lotSize, SymbolInfoDouble(symbol, SYMBOL_ASK), 10, stopLoss, takeProfit);
     }
  }

// --- Main Loop ---
void OnTick()
  {
   ManageTrades("GBPUSD");
   ManageTrades("USDJPY");
   ManageTrades("XAUUSD");

   CheckEntry("GBPUSD");
   CheckEntry("USDJPY");
   CheckEntry("XAUUSD");
  }
