"""Price provider base and implementations for financial data.

Supports:
- Alpha Vantage: A股 + 美股
- CoinGecko: 加密货币
- Yahoo Finance: 基金/ETF
"""

import asyncio
from abc import ABC, abstractmethod
from datetime import UTC, datetime
from typing import Any, ClassVar

import httpx

from app.common.logging import get_logger
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
                    "timestamp": datetime.now(UTC),
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
                    "timestamp": datetime.now(UTC),
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
                "timestamp": datetime.now(UTC),
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


class PriceProviderFactory:
    """Factory to get the appropriate price provider."""

    _providers: ClassVar[dict[str, type]] = {
        "alphavantage": AlphaVantageProvider,
        "coingecko": CoinGeckoProvider,
        "yahoo": YahooFinanceProvider,
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
