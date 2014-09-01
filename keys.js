var translateCharCode;

(function(){
    var t = function (e) {
        var k = e.charCode;
        var ks = String.fromCharCode(k);
        
        if ((k >= t.aCode && k <= t.zCode) ||
            (k >= t.ACode && k <= t.ZCode) ||
            (k >= t._0Code && k <= t._9Code)) {
            
            return ks;
        }
        
        if (ks in t.etcCodes) {
            return ks;
        }
        
        return '';
    };

    t.aCode = 'a'.charCodeAt(0);
    t.zCode = 'z'.charCodeAt(0);
    t.ACode = 'A'.charCodeAt(0);
    t.ZCode = 'Z'.charCodeAt(0);
    t._0Code = '0'.charCodeAt(0);
    t._9Code = '9'.charCodeAt(0);
    t.etcCodes = {
        ',':true,
        ':':true,
        '=':true,
    }

    translateCharCode = t;

})();

