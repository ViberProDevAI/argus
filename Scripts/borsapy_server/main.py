"""
Borsapy FastAPI Backend
Argus iOS uygulaması için BIST veri sağlayıcı microservice.
borsapy Python kütüphanesini REST API olarak sunar.
"""

# ---------------------------------------------------------------------------
# SSL Sertifika Düzeltmesi (macOS + Python 3.13+)
# Python'un varsayılan SSL bağlamı macOS sistem sertifikalarını bulamıyor.
# certifi paketinin CA bundle'ını ortam değişkeni ile ayarlıyoruz.
# Bu satırlar HER ŞEY'den önce çalışmalı.
# ---------------------------------------------------------------------------
import os
try:
    import certifi
    os.environ.setdefault("SSL_CERT_FILE", certifi.where())
    os.environ.setdefault("REQUESTS_CA_BUNDLE", certifi.where())
except ImportError:
    pass  # certifi yoksa sistem sertifikalarına güven

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
import borsapy as bp
import traceback
from datetime import datetime

app = FastAPI(title="Argus Borsapy API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def safe_val(v):
    """NaN/Inf/None güvenli dönüştürücü."""
    if v is None:
        return None
    try:
        import math
        if math.isnan(v) or math.isinf(v):
            return None
    except (TypeError, ValueError):
        pass
    return v


def df_to_candles(df):
    """DataFrame → candle listesi."""
    rows = []
    for idx, row in df.iterrows():
        ts = idx if isinstance(idx, datetime) else datetime.now()
        rows.append({
            "date": ts.isoformat(),
            "open": safe_val(row.get("Open", row.get("open", 0))),
            "high": safe_val(row.get("High", row.get("high", 0))),
            "low": safe_val(row.get("Low", row.get("low", 0))),
            "close": safe_val(row.get("Close", row.get("close", 0))),
            "volume": safe_val(row.get("Volume", row.get("volume", 0))),
        })
    return rows


def df_to_records(df):
    """DataFrame → dict listesi (generic)."""
    if df is None or (hasattr(df, 'empty') and df.empty):
        return []
    records = []
    for idx, row in df.iterrows():
        rec = {"index": str(idx)}
        for col in df.columns:
            rec[col] = safe_val(row[col])
        records.append(rec)
    return records


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------

@app.get("/health")
async def health():
    return {"status": "ok", "service": "borsapy-backend", "version": "1.0.0"}


# ---------------------------------------------------------------------------
# Ticker - Quote (fast_info)
# ---------------------------------------------------------------------------

@app.get("/ticker/{symbol}/quote")
async def ticker_quote(symbol: str):
    try:
        t = bp.Ticker(symbol.upper())
        fi = t.fast_info

        # fast_info is an object, not dict - use getattr
        return {
            "symbol": symbol.upper(),
            "last": safe_val(getattr(fi, "last_price", None)),
            "open": safe_val(getattr(fi, "open", None)),
            "high": safe_val(getattr(fi, "day_high", None)),
            "low": safe_val(getattr(fi, "day_low", None)),
            "previousClose": safe_val(getattr(fi, "previous_close", None)),
            "volume": safe_val(getattr(fi, "volume", None)),
            "change": safe_val(getattr(fi, "last_price", None)),  # Fallback
            "marketCap": safe_val(getattr(fi, "market_cap", None)),
            "pe": safe_val(getattr(fi, "pe_ratio", None)),
            "freeFloat": safe_val(getattr(fi, "free_float", None)),
            "foreignRatio": safe_val(getattr(fi, "foreign_ratio", None)),
            "timestamp": datetime.now().isoformat(),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ---------------------------------------------------------------------------
# Ticker - History (OHLCV)
# ---------------------------------------------------------------------------

@app.get("/ticker/{symbol}/history")
async def ticker_history(
    symbol: str,
    period: str = Query("1ay", description="1g, 1h, 1ay, 3ay, 1y, max"),
    interval: str = Query("1d", description="1m, 5m, 15m, 1h, 1d"),
):
    try:
        t = bp.Ticker(symbol.upper())
        df = t.history(period=period, interval=interval)
        return {"symbol": symbol.upper(), "candles": df_to_candles(df)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ---------------------------------------------------------------------------
# Ticker - Financials (Bilanço + Gelir Tablosu)
# ---------------------------------------------------------------------------

@app.get("/ticker/{symbol}/financials")
async def ticker_financials(symbol: str, quarterly: bool = Query(False)):
    try:
        t = bp.Ticker(symbol.upper())

        if quarterly:
            bs = t.quarterly_balance_sheet
            inc = t.quarterly_income_stmt
        else:
            bs = t.balance_sheet
            inc = t.income_stmt

        # Ayrıca info'dan temel oranları alalım
        info = {}
        try:
            fi = t.fast_info
            info = {
                "pe": safe_val(getattr(fi, "pe_ratio", None)),
                "marketCap": safe_val(getattr(fi, "market_cap", None)),
            }
        except Exception:
            pass

        return {
            "symbol": symbol.upper(),
            "balanceSheet": df_to_records(bs),
            "incomeStatement": df_to_records(inc),
            "ratios": info,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ---------------------------------------------------------------------------
# Ticker - Cashflow
# ---------------------------------------------------------------------------

@app.get("/ticker/{symbol}/cashflow")
async def ticker_cashflow(symbol: str, quarterly: bool = Query(False)):
    try:
        t = bp.Ticker(symbol.upper())
        cf = t.quarterly_cashflow if quarterly else t.cashflow
        return {"symbol": symbol.upper(), "cashflow": df_to_records(cf)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ---------------------------------------------------------------------------
# Ticker - Dividends
# ---------------------------------------------------------------------------

@app.get("/ticker/{symbol}/dividends")
async def ticker_dividends(symbol: str):
    try:
        t = bp.Ticker(symbol.upper())
        div = t.dividends
        if div is None or (hasattr(div, 'empty') and div.empty):
            return {"symbol": symbol.upper(), "dividends": []}
        records = []
        for idx, row in div.iterrows():
            rec = {"date": str(idx)}
            for col in div.columns:
                rec[col] = safe_val(row[col])
            records.append(rec)
        return {"symbol": symbol.upper(), "dividends": records}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ---------------------------------------------------------------------------
# Ticker - Splits (Sermaye Artırımları)
# ---------------------------------------------------------------------------

@app.get("/ticker/{symbol}/splits")
async def ticker_splits(symbol: str):
    try:
        t = bp.Ticker(symbol.upper())
        sp = t.splits
        return {"symbol": symbol.upper(), "splits": df_to_records(sp) if sp is not None else []}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ---------------------------------------------------------------------------
# Ticker - Analyst Price Targets
# ---------------------------------------------------------------------------

@app.get("/ticker/{symbol}/analysts")
async def ticker_analysts(symbol: str):
    try:
        t = bp.Ticker(symbol.upper())
        targets = t.analyst_price_targets
        rec_summary = t.recommendations_summary

        result = {"symbol": symbol.upper()}

        if targets is not None:
            if hasattr(targets, 'to_dict'):
                result["priceTargets"] = targets.to_dict()
            elif isinstance(targets, dict):
                result["priceTargets"] = {k: safe_val(v) for k, v in targets.items()}
            else:
                result["priceTargets"] = str(targets)

        if rec_summary is not None:
            if hasattr(rec_summary, 'to_dict'):
                result["recommendations"] = rec_summary.to_dict()
            elif isinstance(rec_summary, dict):
                result["recommendations"] = {k: safe_val(v) for k, v in rec_summary.items()}
            else:
                result["recommendations"] = str(rec_summary)

        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ---------------------------------------------------------------------------
# Ticker - News (KAP Bildirimleri)
# ---------------------------------------------------------------------------

@app.get("/ticker/{symbol}/news")
async def ticker_news(symbol: str):
    try:
        t = bp.Ticker(symbol.upper())
        news = t.news
        if news is None:
            return {"symbol": symbol.upper(), "news": []}
        if hasattr(news, 'to_dict'):
            return {"symbol": symbol.upper(), "news": df_to_records(news)}
        return {"symbol": symbol.upper(), "news": news if isinstance(news, list) else []}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ---------------------------------------------------------------------------
# Ticker - Info (Detaylı Bilgiler)
# ---------------------------------------------------------------------------

@app.get("/ticker/{symbol}/info")
async def ticker_info(symbol: str):
    try:
        t = bp.Ticker(symbol.upper())
        info = t.info
        if isinstance(info, dict):
            return {"symbol": symbol.upper(), "info": {k: safe_val(v) for k, v in info.items()}}
        return {"symbol": symbol.upper(), "info": {}}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ---------------------------------------------------------------------------
# FX - Döviz Kurları
# ---------------------------------------------------------------------------

@app.get("/fx/{currency}")
async def fx_current(currency: str):
    try:
        fx = bp.FX(currency.upper())
        current = fx.current
        result = {"symbol": currency.upper(), "timestamp": datetime.now().isoformat()}
        if isinstance(current, dict):
            result.update({k: safe_val(v) for k, v in current.items()})
        else:
            result["last"] = safe_val(current)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/fx/{currency}/history")
async def fx_history(
    currency: str,
    period: str = Query("1ay"),
    interval: str = Query("1d"),
):
    try:
        fx = bp.FX(currency.upper())
        df = fx.history(period=period, interval=interval)
        return {"symbol": currency.upper(), "candles": df_to_candles(df)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ---------------------------------------------------------------------------
# Gold - Altın Fiyatları
# ---------------------------------------------------------------------------

@app.get("/gold/{gold_type}")
async def gold_price(gold_type: str):
    try:
        fx = bp.FX(gold_type)
        current = fx.current
        result = {"type": gold_type, "timestamp": datetime.now().isoformat()}
        if isinstance(current, dict):
            result.update({k: safe_val(v) for k, v in current.items()})
        else:
            result["last"] = safe_val(current)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ---------------------------------------------------------------------------
# Index - Endeksler (XU100, XU030 vb.)
# ---------------------------------------------------------------------------

@app.get("/index/{code}")
async def index_data(code: str):
    try:
        idx = bp.Index(code.upper())
        info = {}
        try:
            info_data = idx.info
            if isinstance(info_data, dict):
                info = {k: safe_val(v) for k, v in info_data.items()}
        except Exception:
            pass
        return {"code": code.upper(), "info": info, "timestamp": datetime.now().isoformat()}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/index/{code}/history")
async def index_history(
    code: str,
    period: str = Query("1ay"),
    interval: str = Query("1d"),
):
    try:
        idx = bp.Index(code.upper())
        df = idx.history(period=period, interval=interval)
        return {"code": code.upper(), "candles": df_to_candles(df)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/index/{code}/components")
async def index_components(code: str):
    try:
        idx = bp.Index(code.upper())
        comps = idx.components
        if comps is not None and hasattr(comps, 'tolist'):
            return {"code": code.upper(), "components": comps.tolist()}
        elif isinstance(comps, list):
            return {"code": code.upper(), "components": comps}
        return {"code": code.upper(), "components": df_to_records(comps) if comps is not None else []}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ---------------------------------------------------------------------------
# Inflation - Enflasyon
# ---------------------------------------------------------------------------

@app.get("/inflation")
async def inflation():
    try:
        enf = bp.Inflation()
        latest = enf.latest()
        if isinstance(latest, dict):
            return {k: safe_val(v) for k, v in latest.items()}
        if hasattr(latest, 'to_dict'):
            return latest.to_dict()
        return {"data": str(latest)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ---------------------------------------------------------------------------
# Bond - Tahvil Faizleri
# ---------------------------------------------------------------------------

@app.get("/bond")
async def bond_yields():
    try:
        bond = bp.Bond()
        y = bond.yields()
        if y is not None and hasattr(y, 'to_dict'):
            return {"yields": df_to_records(y)}
        return {"yields": str(y) if y else []}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ---------------------------------------------------------------------------
# Crypto
# ---------------------------------------------------------------------------

@app.get("/crypto/{pair}")
async def crypto_current(pair: str):
    try:
        c = bp.Crypto(pair.upper())
        current = c.current
        result = {"pair": pair.upper(), "timestamp": datetime.now().isoformat()}
        if isinstance(current, dict):
            result.update({k: safe_val(v) for k, v in current.items()})
        else:
            result["last"] = safe_val(current)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ---------------------------------------------------------------------------
# Multi-ticker download
# ---------------------------------------------------------------------------

@app.get("/download")
async def download_multi(
    symbols: str = Query(..., description="Virgülle ayrılmış semboller, ör: THYAO,GARAN,AKBNK"),
    period: str = Query("1ay"),
):
    try:
        symbol_list = [s.strip().upper() for s in symbols.split(",")]
        df = bp.download(symbol_list, period=period)
        result = {}
        if df is not None:
            for sym in symbol_list:
                try:
                    if sym in df.columns.get_level_values(1):
                        sub = df.xs(sym, level=1, axis=1)
                        result[sym] = df_to_candles(sub)
                except Exception:
                    result[sym] = df_to_candles(df)
                    break
        return {"symbols": symbol_list, "data": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ---------------------------------------------------------------------------
# Teknik Sinyaller (TradingView ta_signals)
# ---------------------------------------------------------------------------

@app.get("/ticker/{symbol}/ta-signals")
async def ticker_ta_signals(
    symbol: str,
    timeframe: str = Query("1d", description="1m, 5m, 15m, 30m, 1h, 4h, 1d, 1W, 1M"),
):
    try:
        t = bp.Ticker(symbol.upper())
        signals = t.ta_signals(interval=timeframe)

        def clean_group(group):
            """Gösterge grubunu JSON-safe dict'e çevir."""
            if group is None:
                return {"recommendation": "NEUTRAL", "values": {}}
            if isinstance(group, dict):
                rec = group.get("recommendation", "NEUTRAL")
                vals = {}
                for k, v in group.items():
                    if k == "recommendation":
                        continue
                    if isinstance(v, dict):
                        vals[k] = {
                            "value": safe_val(v.get("value")),
                            "signal": v.get("signal", "NEUTRAL"),
                        }
                    else:
                        vals[k] = {"value": safe_val(v), "signal": "NEUTRAL"}
                return {"recommendation": rec, "values": vals}
            return {"recommendation": "NEUTRAL", "values": {}}

        summary = {"recommendation": "NEUTRAL", "buy": 0, "sell": 0, "neutral": 0}
        oscillators = {"recommendation": "NEUTRAL", "values": {}}
        moving_averages = {"recommendation": "NEUTRAL", "values": {}}

        if isinstance(signals, dict):
            s = signals.get("summary", {})
            if isinstance(s, dict):
                summary = {
                    "recommendation": s.get("recommendation", "NEUTRAL"),
                    "buy": int(s.get("buy", 0)),
                    "sell": int(s.get("sell", 0)),
                    "neutral": int(s.get("neutral", 0)),
                }
            oscillators = clean_group(signals.get("oscillators"))
            moving_averages = clean_group(signals.get("moving_averages"))

        return {
            "symbol": symbol.upper(),
            "timeframe": timeframe,
            "summary": summary,
            "oscillators": oscillators,
            "movingAverages": moving_averages,
            "timestamp": datetime.now().isoformat(),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ---------------------------------------------------------------------------
# TCMB - Politika Faizi
# ---------------------------------------------------------------------------

@app.get("/tcmb/policy-rate")
async def tcmb_policy_rate():
    try:
        rate = bp.policy_rate()
        return {
            "rate": safe_val(rate),
            "timestamp": datetime.now().isoformat(),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
