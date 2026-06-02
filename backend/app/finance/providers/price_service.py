"""Price provider base and implementations for financial data.

Supports:
- Alpha Vantage: A股 + 美股
- CoinGecko: 加密货币
- Yahoo Finance: 基金/ETF
"""

import asyncio
import http.client
import ssl
from abc import ABC, abstractmethod
from typing import Any, ClassVar

import httpx

from app.common.logging import get_logger
from app.common.utils import utcnow
from app.config import get_settings

logger = get_logger("price_provider")
settings = get_settings()


class PriceProvider(ABC):
    """Base class for price providers."""

    @abstractmethod
    async def get_price(self, symbol: str, currency: str = "USD") -> dict[str, Any] | None:
        """Get current price for a symbol.

        Returns:
            {"price": float, "currency": str, "source": str, "timestamp": datetime} or None
        """

    @abstractmethod
    async def get_batch_prices(self, symbols: list[str]) -> dict[str, float]:
        """Get prices for multiple symbols."""


class AlphaVantageProvider(PriceProvider):
    """Alpha Vantage provider for stocks (A股 + 美股)."""

    BASE_URL = "https://www.alphavantage.co/query"

    async def get_price(self, symbol: str, currency: str = "USD") -> dict[str, Any] | None:
        api_key = settings.ALPHAVANTAGE_API_KEY
        if not api_key:
            logger.warning("alphavantage_no_api_key")
            return None

        try:
            async with httpx.AsyncClient(timeout=10) as client:
                resp = await client.get(self.BASE_URL, params={
                    "function": "GLOBAL_QUOTE",
                    "symbol": symbol,
                    "apikey": api_key,
                })
                data = resp.json()

                if "Global Quote" not in data:
                    logger.warning("alphavantage_no_data", symbol=symbol)
                    return None

                quote = data["Global Quote"]
                price = float(quote.get("05. price", 0))

                return {
                    "price": price,
                    "currency": currency,
                    "source": "alphavantage",
                    "timestamp": utcnow(),
                }
        except Exception as e:
            logger.error("alphavantage_error", symbol=symbol, error=str(e))
            return None

    async def get_batch_prices(self, symbols: list[str]) -> dict[str, float]:
        results = {}
        for symbol in symbols:
            price_info = await self.get_price(symbol)
            if price_info:
                results[symbol] = price_info["price"]
            await asyncio.sleep(0.5)  # Rate limiting: 5 requests/minute
        return results


class CoinGeckoProvider(PriceProvider):
    """CoinGecko provider for cryptocurrencies."""

    BASE_URL = "https://api.coingecko.com/api/v3"

    # Common crypto symbol to CoinGecko ID mapping
    SYMBOL_MAP: ClassVar[dict[str, str]] = {
        "BTC": "bitcoin",
        "ETH": "ethereum",
        "BNB": "binancecoin",
        "SOL": "solana",
        "XRP": "ripple",
        "ADA": "cardano",
        "DOGE": "dogecoin",
        "DOT": "polkadot",
        "AVAX": "avalanche-2",
        "MATIC": "matic-network",
    }

    async def get_price(self, symbol: str, currency: str = "USD") -> dict[str, Any] | None:
        coin_id = self.SYMBOL_MAP.get(symbol.upper(), symbol.lower())

        try:
            async with httpx.AsyncClient(timeout=10) as client:
                resp = await client.get(f"{self.BASE_URL}/simple/price", params={
                    "ids": coin_id,
                    "vs_currencies": currency.lower(),
                    "include_last_updated_at": "true",
                })
                data = resp.json()

                if coin_id not in data:
                    logger.warning("coingecko_no_data", symbol=symbol)
                    return None

                price = data[coin_id].get(currency.lower(), 0)

                return {
                    "price": price,
                    "currency": currency,
                    "source": "coingecko",
                    "timestamp": utcnow(),
                }
        except Exception as e:
            logger.error("coingecko_error", symbol=symbol, error=str(e))
            return None

    async def get_batch_prices(self, symbols: list[str]) -> dict[str, float]:
        coin_ids = [self.SYMBOL_MAP.get(s.upper(), s.lower()) for s in symbols]
        ids_str = ",".join(coin_ids)

        try:
            async with httpx.AsyncClient(timeout=10) as client:
                resp = await client.get(f"{self.BASE_URL}/simple/price", params={
                    "ids": ids_str,
                    "vs_currencies": "usd",
                })
                data = resp.json()

                results = {}
                for symbol, coin_id in zip(symbols, coin_ids, strict=False):
                    if coin_id in data:
                        results[symbol] = data[coin_id].get("usd", 0)
                return results
        except Exception as e:
            logger.error("coingecko_batch_error", error=str(e))
            return {}


class YahooFinanceProvider(PriceProvider):
    """Yahoo Finance provider for funds/ETFs."""

    async def get_price(self, symbol: str, currency: str = "USD") -> dict[str, Any] | None:
        try:
            import yfinance as yf

            ticker = yf.Ticker(symbol)
            info = ticker.info
            price = info.get("regularMarketPrice") or info.get("navPrice")

            if not price:
                logger.warning("yahoo_no_data", symbol=symbol)
                return None

            return {
                "price": price,
                "currency": currency,
                "source": "yahoo",
                "timestamp": utcnow(),
            }
        except Exception as e:
            logger.error("yahoo_error", symbol=symbol, error=str(e))
            return None

    async def get_batch_prices(self, symbols: list[str]) -> dict[str, float]:
        results = {}
        for symbol in symbols:
            price_info = await self.get_price(symbol)
            if price_info:
                results[symbol] = price_info["price"]
        return results


class ChinaFundProvider(PriceProvider):
    """Provider for Chinese mutual funds using eastmoney API.

    Supports:
    - 场外基金 (open-end fund): 获取最新净值
    - 场内基金 (ETF/LOF): 使用股票API获取实时价格
    """

    async def get_price(self, symbol: str, currency: str = "CNY") -> dict[str, Any] | None:
        # 场内基金（ETF/LOF）通常以 5 开头，使用股票API
        if symbol.startswith('5'):
            return await self._get_etf_price(symbol)

        # 场外基金获取最新净值
        return await self._get_fund_nav(symbol)

    async def _get_etf_price(self, symbol: str) -> dict[str, Any] | None:
        """获取场内基金（ETF）的实时价格，使用股票API。"""
        provider = ChinaStockProvider()
        return await provider.get_price(symbol)

    async def _get_fund_nav(self, symbol: str) -> dict[str, Any] | None:
        """获取场外基金的最新净值。"""
        try:
            # 先尝试获取最新净值
            nav_data = await asyncio.to_thread(self._fetch_fund_nav, symbol)
            if nav_data:
                return nav_data

            # 如果获取失败，尝试获取估值数据
            return await self._get_fund_estimate(symbol)
        except Exception as e:
            logger.error("china_fund_error", symbol=symbol, error=str(e))
            return None

    async def _get_fund_estimate(self, symbol: str) -> dict[str, Any] | None:
        """获取基金估值数据（盘中参考）。"""
        try:
            text = await asyncio.to_thread(self._fetch_fund_estimate, symbol)

            if not text:
                return None

            import json
            start = text.find("{")
            end = text.rfind("}") + 1
            if start < 0 or end <= 0:
                return None

            data = json.loads(text[start:end])
            price = float(data.get("gsz", 0))
            name = data.get("name", "")

            if not price:
                return None

            return {
                "price": price,
                "currency": "CNY",
                "source": "eastmoney_estimate",
                "name": name,
                "timestamp": utcnow(),
                "is_estimate": True,  # 标记为估值
            }
        except Exception as e:
            logger.error("china_fund_estimate_error", symbol=symbol, error=str(e))
            return None

    @staticmethod
    def _fetch_fund_estimate(symbol: str) -> str | None:
        """获取基金估值数据。"""
        try:
            ctx = ssl._create_unverified_context()
            conn = http.client.HTTPSConnection("fundgz.1234567.com.cn", timeout=15, context=ctx)
            conn.request("GET", f"/js/{symbol}.js", headers={"Referer": "https://fund.eastmoney.com/"})
            resp = conn.getresponse()
            if resp.status != 200:
                return None
            return resp.read().decode("utf-8", errors="replace")
        except Exception as e:
            logger.error("china_fund_estimate_fetch_error", symbol=symbol, error=str(e))
            return None
        finally:
            conn.close()

    @staticmethod
    def _fetch_fund_nav(symbol: str) -> dict[str, Any] | None:
        """获取基金最新净值。"""
        import json
        try:
            ctx = ssl._create_unverified_context()
            # 使用东方财富的基金详情API获取最新净值
            conn = http.client.HTTPSConnection("fund.eastmoney.com", timeout=15, context=ctx)
            conn.request("GET", f"/pingzhongdata/{symbol}.js", headers={
                "Referer": "https://fund.eastmoney.com/",
                "User-Agent": "Mozilla/5.0"
            })
            resp = conn.getresponse()
            if resp.status != 200:
                return None

            text = resp.read().decode("utf-8", errors="replace")

            # 提取基金名称
            name = ""
            if 'fS_name = "' in text:
                name_start = text.find('fS_name = "') + 11
                name_end = text.find('"', name_start)
                name = text[name_start:name_end]

            # 提取最新净值（从 Data_netWorthTrend 中获取最后一个）
            if 'Data_netWorthTrend' in text:
                trend_start = text.find('Data_netWorthTrend') + len('Data_netWorthTrend') + 3
                trend_end = text.find('];', trend_start) + 1
                trend_text = text[trend_start:trend_end]

                # 解析净值趋势数据
                import re
                # 查找所有净值数据点
                matches = re.findall(r'\{"x":(\d+),"y":([\d.]+),"equityReturn"?:[\d.]*,"unitMoney"?:[\d.]*\}', trend_text)
                if matches:
                    # 获取最后一个数据点
                    last_match = matches[-1]
                    timestamp = int(last_match[0])
                    nav = float(last_match[1])

                    # 转换时间戳
                    from datetime import datetime
                    nav_date = datetime.fromtimestamp(timestamp / 1000)

                    return {
                        "price": nav,
                        "currency": "CNY",
                        "source": "eastmoney",
                        "name": name,
                        "timestamp": utcnow(),
                        "nav_date": nav_date.strftime("%Y-%m-%d"),
                        "is_estimate": False,
                    }

            return None
        except Exception as e:
            logger.error("china_fund_nav_fetch_error", symbol=symbol, error=str(e))
            return None
        finally:
            conn.close()

    async def get_batch_prices(self, symbols: list[str]) -> dict[str, float]:
        results = {}
        for symbol in symbols:
            price_info = await self.get_price(symbol)
            if price_info:
                results[symbol] = price_info["price"]
        return results


class ChinaStockProvider(PriceProvider):
    """Provider for Chinese A-share stocks and ETFs using Sina Finance API.

    自动处理交易所前缀：
    - 6开头：上海股票 (sh)
    - 0/3开头：深圳股票 (sz)
    - 5开头：上海场内基金/ETF (sh)
    - 1开头：深圳场内基金/ETF (sz)
    """

    async def get_price(self, symbol: str, currency: str = "CNY") -> dict[str, Any] | None:
        try:
            # 自动添加交易所前缀
            code = self._add_market_prefix(symbol)

            text = await asyncio.to_thread(self._fetch_sina, code)

            if not text:
                return None

            # Parse response: var hq_str_sh600519="贵州茅台,1800.00,..."
            parts = text.split('"')
            if len(parts) < 2:
                logger.warning("china_stock_parse_error", symbol=symbol, text=text)
                return None

            data = parts[1].split(',')
            if len(data) < 4:
                logger.warning("china_stock_parse_error", symbol=symbol, data=data)
                return None

            name = data[0]
            price = float(data[3])  # Current price

            if not price:
                logger.warning("china_stock_no_price", symbol=symbol)
                return None

            return {
                "price": price,
                "currency": "CNY",
                "source": "sina",
                "name": name,
                "timestamp": utcnow(),
            }
        except Exception as e:
            logger.error("china_stock_error", symbol=symbol, error=str(e))
            return None

    @staticmethod
    def _add_market_prefix(symbol: str) -> str:
        """自动添加交易所前缀。

        规则：
        - 已有前缀的直接返回
        - 6开头：上海 (sh)
        - 0/3开头：深圳 (sz)
        - 5开头：上海场内基金 (sh)
        - 1开头：深圳场内基金 (sz)
        """
        # 如果已经有前缀，直接返回
        if symbol.startswith(('sh', 'sz')):
            return symbol

        # 根据代码首字母判断市场
        if symbol.startswith('6') or symbol.startswith('5'):
            return f'sh{symbol}'
        elif symbol.startswith(('0', '3', '1')):
            return f'sz{symbol}'
        else:
            # 默认上海
            return f'sh{symbol}'

    @staticmethod
    def _fetch_sina(code: str) -> str | None:
        """Fetch stock data from Sina Finance API using http.client (works with system proxy)."""
        try:
            ctx = ssl._create_unverified_context()
            conn = http.client.HTTPSConnection("hq.sinajs.cn", timeout=15, context=ctx)
            conn.request("GET", f"/list={code}", headers={"Referer": "https://finance.sina.com.cn/"})
            resp = conn.getresponse()
            if resp.status != 200:
                logger.warning("china_stock_no_data", code=code, status=resp.status)
                return None
            return resp.read().decode("gbk", errors="replace")
        except Exception as e:
            logger.error("china_stock_fetch_error", code=code, error=str(e))
            return None
        finally:
            conn.close()

    async def get_batch_prices(self, symbols: list[str]) -> dict[str, float]:
        results = {}
        for symbol in symbols:
            price_info = await self.get_price(symbol)
            if price_info:
                results[symbol] = price_info["price"]
        return results


class ChinaStockUSProvider(PriceProvider):
    """Provider for US stocks using Sina Finance API (accessible from China)."""

    async def get_price(self, symbol: str, currency: str = "USD") -> dict[str, Any] | None:
        try:
            code = f'gb_{symbol.lower()}'

            text = await asyncio.to_thread(ChinaStockProvider._fetch_sina, code)

            if not text:
                return None

            # Parse response: var hq_str_gb_aapl="苹果,312.0600,..."
            parts = text.split('"')
            if len(parts) < 2:
                logger.warning("china_stock_us_parse_error", symbol=symbol)
                return None

            data = parts[1].split(',')
            if len(data) < 2:
                logger.warning("china_stock_us_parse_error", symbol=symbol)
                return None

            name = data[0]
            price = float(data[1])  # Current price for US stocks

            if not price:
                logger.warning("china_stock_us_no_price", symbol=symbol)
                return None

            return {
                "price": price,
                "currency": "USD",
                "source": "sina",
                "name": name,
                "timestamp": utcnow(),
            }
        except Exception as e:
            logger.error("china_stock_us_error", symbol=symbol, error=str(e))
            return None

    async def get_batch_prices(self, symbols: list[str]) -> dict[str, float]:
        results = {}
        for symbol in symbols:
            price_info = await self.get_price(symbol)
            if price_info:
                results[symbol] = price_info["price"]
        return results


class PriceProviderFactory:
    """Factory to get the appropriate price provider."""

    _providers: ClassVar[dict[str, type]] = {
        "alphavantage": AlphaVantageProvider,
        "coingecko": CoinGeckoProvider,
        "yahoo": YahooFinanceProvider,
        "china_fund": ChinaFundProvider,
        "china_stock": ChinaStockProvider,
        "china_stock_us": ChinaStockUSProvider,
    }

    @classmethod
    def get_provider(cls, source: str) -> PriceProvider:
        provider_class = cls._providers.get(source)
        if not provider_class:
            raise ValueError(f"Unknown price provider: {source}")
        return provider_class()

    @classmethod
    async def get_price_with_fallback(
        cls, symbol: str, providers: list[str], currency: str = "USD"
    ) -> dict[str, Any] | None:
        """Try providers in order, return first successful result."""
        for source in providers:
            provider = cls.get_provider(source)
            result = await provider.get_price(symbol, currency)
            if result:
                return result
        return None
