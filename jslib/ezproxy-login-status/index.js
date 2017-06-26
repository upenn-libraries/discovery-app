var LOGIN = require('login-status');

var modules = {};

var wrapper = {
  getTimestamp: LOGIN.getTimestamp,
  getModule: function getModule(cacheKey) {
    var ret = modules[cacheKey];
    if (ret !== undefined) {
      return ret;
    }
    ret = LOGIN.getModule(cacheKey);
    modules[cacheKey] = ret;
    ret.requestSubmit = requestSubmit;
    return ret;
  }
}

var requestSubmit = function requestSubmit(fail, fun, instance) {
  var callFactory = function callFactory(loggedIn) {
    return function(data, lastLoggedInStatus) {
      if (lastLoggedInStatus === null || lastLoggedInStatus === undefined
            || lastLoggedInStatus !== loggedIn) { 
        fun.call(instance, fail, data);
      }
    };
  };
  this.addOnLoggedIn('summonRequest', callFactory(true));
  this.addOnNotLoggedIn('summonRequest', callFactory(false));
};

module.exports = wrapper;

