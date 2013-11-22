module auscoin.orderbook;

import auscoin.currency;
import auscoin.account;

import std.datetime;
import std.algorithm;

import vibe.data.json;

void saveExchangeDb()
{
//	Json js = serializeToJson(exchange);
//	std.file.write("exchange.json", js.toString());
}

shared static this()
{
	try
	{
		auto bytes = cast(string)std.file.read("exchange.json");
		if(bytes)
		{
//			Json js = parseJsonString(bytes);
//			deserializeJson(exchange, js);
		}
	}
	catch
	{
		exchange = new Exchange();
	}
}


enum OrderType
{
	buy,
	sell
}

struct Market
{
	alias marketId this;

	this(CurrencyPair currency)
	{
		assert(currency[0] != currency[1], "Currencies must be different!");

		bool bReverse = currency[0] > currency[1];
		if(bReverse)
		{
//			std.typecons.swap(currency[0], currency[1]);
			auto t = currency[0];
			currency[0] = currency[1];
			currency[1] = t;
		}

		market = (currency[0]*Currency.max + currency[1] - 1) | (bReverse ? 0x8000_0000 : 0);

		assert(market < NumMarkets);
	}

	this(Currency buy, Currency sell)
	{
		this(CurrencyPair(buy, sell));
	}

	@property uint marketId() const pure nothrow { return market & ~0x8000_0000; }
	@property bool reverse() const pure nothrow { return (market & 0x8000_0000) != 0; }
	@property Currency buyCurrency() const pure nothrow { return currency[0]; }
	@property Currency sellCurrency() const pure nothrow { return currency[1]; }

	@property CurrencyPair currency() const pure nothrow
	{
		Currency buy = cast(Currency)(market / Currency.max);
		Currency sell = cast(Currency)(market % Currency.max + 1);
		if(reverse)
			return CurrencyPair(sell, buy);
		return CurrencyPair(buy, sell);
	}

	private uint market;
}


struct Order
{
	SysTime time;
	uint account;

	OrderType type;
	double amount;
	double price;

	this(Account account, OrderType type, double amount, double perUnit)
	{
		this.time = Clock.currTime;
		this.account = account.accountId;
		this.type = type;
		this.amount = amount;
		this.price = perUnit;
	}
}

struct Transaction
{
	SysTime time;
	uint buyer;
	uint seller;

	OrderType type;

	double amount;
	double price;

	this(Account buyer, Account seller, OrderType type, double amount, double perUnit)
	{
		this.time = Clock.currTime;
		this.buyer = buyer.accountId;
		this.seller = seller.accountId;
		this.amount = amount;
		this.price = perUnit;
	}
}


struct OrderBook
{
	Order[] buyOrders;
	Order[] sellOrders;
	immutable(Transaction)[] filledOrders;
}

class Exchange
{
	bool placeOrder(Account account, Market market, OrderType type, double amount, double perUnit)
	{
		if(type == OrderType.buy)
			return placeBuyOrder(account, market, amount, perUnit, false);
		else
			return placeSellOrder(account, market, amount, perUnit, false);
	}

	bool placeBuyOrder(Account account, Market market, double amount, double perUnit, bool bMarketPrice)
	{
		if(amount == 0.0 || perUnit == 0.0)
			return false;

		Order order = Order(account, OrderType.buy, amount, perUnit);

		Order[] sellOrders = markets[market].sellOrders;

		// if this offer fills any orders
		for(size_t i = 0; i < sellOrders.length && order.price >= sellOrders[i].price; )
		{
			// lookup the serller
			Account seller = findUser(sellOrders[i].account);

			// perform the transaction
			if(!performTransaction(market, OrderType.buy, account, seller, order, sellOrders[i]))
				break;

			if(sellOrders[i].amount <= 0)
			{
				// the order was filled, remove from the market
				markets[market].sellOrders = markets[market].sellOrders[0 .. i] ~ markets[market].sellOrders[i+1 .. $];
				sellOrders = markets[market].sellOrders;
			}
			else
				++i;
		}

		// if the order wasn't satisfied, add it to the market
		if(order.amount > 0)
		{
			Order[] buyOrders = markets[market].buyOrders;
			size_t i = 0;
			for(; i < buyOrders.length; ++i)
			{
				if(buyOrders[i].price < order.price)
				{
					markets[market].buyOrders = buyOrders[0 .. i] ~ order ~ buyOrders[i .. $];
					break;
				}
			}
			if(i == buyOrders.length)
				markets[market].buyOrders ~= order;
		}

		return true;
	}

	bool placeSellOrder(Account account, Market market, double amount, double perUnit, bool bMarketPrice)
	{
		if(amount == 0.0 || perUnit == 0.0)
			return false;

		Order order = Order(account, OrderType.sell, amount, perUnit);

		Order[] buyOrders = markets[market].buyOrders;

		// if this offer fills any orders
		for(size_t i = 0; i < buyOrders.length && order.price <= buyOrders[i].price; )
		{
			// lookup the buyer
			Account buyer = findUser(buyOrders[i].account);

			// perform the transaction
			if(!performTransaction(market, OrderType.sell, buyer, account, buyOrders[i], order))
				break;

			if(buyOrders[i].amount <= 0)
			{
				// the order was filled, remove from the market
				markets[market].buyOrders = markets[market].buyOrders[0 .. i] ~ markets[market].buyOrders[i+1 .. $];
				buyOrders = markets[market].buyOrders;
			}
			else
				++i;
		}

		// if the order wasn't satisfied, add it to the market
		if(order.amount > 0)
		{
			Order[] sellOrders = markets[market].buyOrders;
			size_t i = 0;
			for(; i < sellOrders.length; ++i)
			{
				if(sellOrders[i].price > order.price)
				{
					markets[market].sellOrders = sellOrders[0 .. i] ~ order ~ sellOrders[i .. $];
					break;
				}
			}
			if(i == sellOrders.length)
				markets[market].sellOrders ~= order;
		}

		return true;
	}

	bool deleteOrder(Account account, OrderType type, double amount, double perUnit)
	{
//		findOrder(account, type, amount, perUnit);
		return false;
	}

	OrderBook orderBook(Market market) pure nothrow
	{
		return markets[market];
	}

private:
	bool performTransaction(Market market, OrderType type, Account buyer, Account seller, ref Order buy, ref Order sell)
	{
		// the base transaction
		double amount = min(buy.amount, sell.amount);
		double price = sell.price;
		double total = amount*price;

		// total amount that buyer can buy
		double buyerCanPay = min(total, buyer.accounts(market.sellCurrency));

		// if the buyer can't actually pay anything, then we can bail out
		if(buyerCanPay == 0)
			return false;

		// amount each party has available
		double canBuy = amount * (buyerCanPay/total);
		double canSell = seller.accounts(market.buyCurrency);

		// total amount for the order
		double toBuy = min(canBuy, canSell);
		double toPay = toBuy * price;

		if(toBuy > 0)
		{
			// ****** SENSITIVE ******
			// this needs to be atomic
			immutable transaction = Transaction(buyer, seller, type, toBuy, sell.price);
			markets[market].filledOrders ~= transaction;

			buyer.trade(market.buyCurrency, toBuy, market.sellCurrency, toPay);
			seller.trade(market.sellCurrency, toPay, market.buyCurrency, toBuy);

			buy.amount -= toBuy;
			sell.amount -= toBuy;
			// ***********************
		}

		return true;
	}

	OrderBook[NumMarkets] markets;
}

__gshared Exchange exchange;
