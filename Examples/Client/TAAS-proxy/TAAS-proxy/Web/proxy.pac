// a place-holder, not intended for use (yet!)
function FindProxyForURL(url, host)
{
    var i, plexes;

    if (!dnsDomainIs(host, ".google.com")) return "DIRECT";

    url = url.toLowerCase();
    trigger = [ 'steward', 'trigger' ];
    for (i = 0; i < trigger.length; i++) if (url.indexOf(trigger[i]) >= 0) break;
    if ((i >= trigger.length) || (url.indexOf('search?q=') < 0) || (url.indexOf('&plexignore=true') >= 0)) return "DIRECT";

    return 'PROXY 127.0.0.1:8884';
}
