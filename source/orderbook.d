module auscoin.orderbook;

import auscoin.currency;
import auscoin.account;

import std.datetime;
import std.algorithm;


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
			std.typecons.swap(currency[0], currency[1]);

		market = (buy*Currency.max + sell - 1) | (bReverse ? 0x8000_0000 : 0);

		assert(market < Currency.NumMarkets);
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
		int buy = market / Currency.max;
		int sell = market % Currency.max + 1;
		if(reverse)
			return CurrencyPair(sell, buy);
		return CurrencyPair(buy, sell);
	}

	private uint market;
}


struct Order
{
	SysTime time;
	Account accountId;

	OrderType type;
	double amount;
	double perUnit;

	this(Account account, OrderType type, double amount, double perUnit)
	{
		this.time = Clock.currTime;
		this.accountId = account;
		this.type = type;
		this.amount = amount;
		this.perUnit = perUnit;
	}
}

struct Transaction
{
	SysTime time;
	Account buyerId;
	Account sellerId;

	OrderType type;

	double amount;
	double perUnit;

	this(Account buyer, Account seller, OrderType type, double amount, double perUnit)
	{
		this.time = Clock.currTime;
		this.buyer = buyer;
		this.seller = seller;
		this.amount = amount;
		this.perUnit = perUnit;
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
			return placeBuyOrder(account, market, amount, perUnit);
		else
			return placeSellOrder(account, market, amount, perUnit);
	}

	bool placeBuyOrder(Account account, Market market, double amount, double perUnit, bool bMarketPrice)
	{
		if(amount == 0.0 || perUnit == 0.0)
			return false;

		Order order = Order(account, OrderType.buy, amount, perUnit);

		Order[] sellOrders = markets[market].sellOrders;

		// if this offer fills any orders
		for(size_t i = 0; i < sellOrders.length && order.perUnit >= sellOrders[i].perUnit; )
		{
			// lookup the serller
			Account seller = findUser(sellOrder[i].accountId);

			// perform the transaction
			if(!performTransaction(market, OrderType.buy, account, seller, order, sellOrder[i]))
				break;

			if(sellOrder[i].amount <= 0)
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
			for(size_t i = 0; i < buyOrders.length; ++i)
			{
				if(buyOrders[i].perUnit < order.perUnit)
				{
					markets[market].buyOrders = buyOrders[0 .. i] ~ order ~ buyOrders[i .. $];
					break;
				}
			}
		}
	}

	bool placeSellOrder(Account account, Market market, uint amount, uint perUnit)
	{
		if(amount == 0.0 || perUnit == 0.0)
			return false;

		Order order = Order(account, OrderType.sell, amount, perUnit);

		Order[] buyOrders = markets[market].buyOrders;

		// if this offer fills any orders
		for(size_t i = 0; i < buyOrders.length && order.perUnit <= buyOrders[i].perUnit; )
		{
			// lookup the buyer
			Account buyer = findUser(buyOrders[i].accountId);

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
			for(size_t i = 0; i < sellOrders.length; ++i)
			{
				if(sellOrders[i].perUnit > order.perUnit)
				{
					markets[market].sellOrders = sellOrders[0 .. i] ~ order ~ sellOrders[i .. $];
					break;
				}
			}
		}
	}

	bool deleteOrder(Account account, OrderType type, uint amount, uint perUnit)
	{
		findOrder(user, type, amount, perUnit);
	}

	OrderBook orderBook(Market market) pure nothrow
	{
		return markets[market];
	}

private:
	bool performTransaction(Market market, OrderType type, Account buyer, Account Seller, ref Order buy, ref Order sell)
	{
		// amount buyer is to pay for the complete order
		double orderTotal = buy.amount * sell.perUnit;

		// maximum amount buyer can pay
		double canPay = min(orderTotal, buyer.accounts[market.sellCurrency]);

		// if the buyer can't actually pay anything, then we can bail out
		if(canPay == 0)
			return false;

		// amount buyer can buy with available funds
		double canBuy = buy.amount * (canPay/orderTotal);

		// final amount to buy
		double toBuy = min(canBuy, seller.accounts[market.buyCurrency]);
		// final amount to pay
		double toPay = toBuy * sell.perUnit;

		if(toBuy > 0)
		{
			// ****** SENSITIVE ******
			// this needs to be atomic
			immutable transaction = Transaction(buyer, seller, type, toBuy, sell.perUnit);
			markets[market].filledOrders ~= transaction;

			buyer.accounts[market.buyCurrency] += toBuy;
			seller.accounts[market.buyCurrency] -= toBuy;
			buyer.accounts[market.sellCurrency] -= toPay;
			seller.accounts[market.sellCurrency] += toPay;

			buy.amount -= toBuy;
			sell.amount -= toBuy;
			// ***********************
		}

		return true;
	}

	OrderBook[Currency.NumMarkets] markets;
}
