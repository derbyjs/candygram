# This is a basic VCL configuration file for varnish.  See the vcl(7)
# man page for details on VCL syntax and semantics.

import std;

# static
backend default {
  .host = "127.0.0.1";
  .port = "4000";
}
backend examples {
  .host = "127.0.0.1";
  .port = "8080";
}
backend components {
  .host = "127.0.0.1";
  .port = "3330";
}

sub vcl_recv {
  if (!req.http.Host) {
    error 404 "Need a host header";
  }

  set req.http.Host = regsub(req.http.Host, "^www\.", "");
  set req.http.Host = regsub(req.http.Host, ":80$", "");

  if (
    req.http.Host ~ "^chat\." ||
    req.http.Host ~ "^charts\." ||
    req.http.Host ~ "^directory\." ||
    req.http.Host ~ "^codemirror\." ||
    req.http.Host ~ "^hello\." ||
    req.http.Host ~ "^sink\." ||
    req.http.Host ~ "^todos\." ||
    req.http.Host ~ "^widgets\."
  ) {
    set req.backend = examples;
  } else if (req.http.Host ~ "^components\.") {
    set req.backend = components;
  }

  if (req.http.upgrade ~ "(?i)websocket" || req.url ~ "^/channel") {
    return (pipe);
  }

  if (req.restarts == 0) {
    if (req.http.x-forwarded-for) {
      set req.http.X-Forwarded-For =
        req.http.X-Forwarded-For + ", " + client.ip;
    } else {
      set req.http.X-Forwarded-For = client.ip;
    }
  }
  if (req.request != "GET" &&
      req.request != "HEAD" &&
      req.request != "PUT" &&
      req.request != "POST" &&
      req.request != "TRACE" &&
      req.request != "OPTIONS" &&
      req.request != "DELETE") {
    /* Non-RFC2616 or CONNECT which is weird. */
    return (pipe);
  }
  if (req.request != "GET" && req.request != "HEAD") {
    /* We only deal with GET and HEAD by default */
    return (pass);
  }
  if (req.http.Authorization || req.http.Cookie) {
    /* Not cacheable by default */
    return (pass);
  }
  return (lookup);
}

sub vcl_pipe {
  # Websockets
  if (req.http.upgrade) {
    set bereq.http.upgrade = req.http.upgrade;
  }
  return (pipe);
}
