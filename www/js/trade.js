var buyamount, buyprice, buytotal;
var sellamount, sellprice, selltotal;

function addListener (item, event, handler) {
    function add (item, event, handler) {
        if (item.addEventListener) {
            item.addEventListener(event, handler, false);
            return true;
        }
        else if (item.attachEvent) {
            item.attachEvent('on' + event, handler);
            return true;
        }
        else
            return false;
    }

    if (event instanceof Array) {
        for (i = 0; i < event.length; ++i) {
            if (!add(item, event[i], handler))
                return false;
        }
        return true;
    }
    else {
        return add(item, event, handler);
    }
}

function updateBuyTotal () {
    var value = (parseFloat(buyamount.value) * parseFloat(buyprice.value)).toString();
    buytotal.value = value != "NaN" ? value : "";
    // if > AUD, make it red?
}
function updateSellTotal () {
    var value = (parseFloat(sellamount.value) * parseFloat(sellprice.value)).toString();
    selltotal.value = value != "NaN" ? value : "";
    // if > BTC, make it red?
}

var onLoad = function () {
    buyamount = document.getElementById('buyamount');
    buyprice = document.getElementById('buyprice');
    buytotal = document.getElementById('buytotal');
    sellamount = document.getElementById('sellamount');
    sellprice = document.getElementById('sellprice');
    selltotal = document.getElementById('selltotal');

    addListener(buyamount, ["keydown", "keyup", "keypress", "change"], updateBuyTotal);
    addListener(buyprice, ["keydown", "keyup", "keypress", "change"], updateBuyTotal);

    addListener(sellamount, ["keydown", "keyup", "keypress", "change"], updateSellTotal);
    addListener(sellprice, ["keydown", "keyup", "keypress", "change"], updateSellTotal);

    if (highestBuy > 0) {
        sellprice.value = highestBuy.toString();
    }
    if (lowestSell > 0) {
        buyprice.value = lowestSell.toString();
    }
};

if (window.addEventListener)
	window.addEventListener('load', onLoad, false);
else if (window.attachEvent)
	window.attachEvent('onload', onLoad);
else
    window.onload = onLoad;
