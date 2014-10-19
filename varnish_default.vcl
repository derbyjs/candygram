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

  if (req.restarts == 0) {
    if (req.http.x-forwarded-for) {
      set req.http.X-Forwarded-For =
        req.http.X-Forwarded-For + ", " + client.ip;
    } else {
      set req.http.X-Forwarded-For = client.ip;
    }
  }

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
  if (req.http.Upgrade ~ "(?i)websocket") {
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

sub vcl_hash {
  hash_data(req.url);
  if (req.http.host) {
    hash_data(req.http.host);
  } else {
    hash_data(server.ip);
  }
  if (req.http.Origin) {
    hash_data(req.http.Origin);
  }
  return (hash);
}

sub vcl_pipe {
  # Websockets
  if (req.http.upgrade) {
    set bereq.http.upgrade = req.http.upgrade;
  } else {
    # Note that only the first request to the backend will have
    # X-Forwarded-For set.  If you use X-Forwarded-For and want to
    # have it set for all requests, make sure to have:
    set bereq.http.connection = "close";
    # here.  It is not set by default as it might break some broken web
    # applications, like IIS with NTLM authentication.
  }

  return (pipe);
}

sub vcl_fetch {
  # Compress responses
  if (beresp.http.content-type ~ "text"
      || beresp.http.content-type ~ "json"
      || beresp.http.content-type ~ "javascript") {
    set beresp.do_gzip = true;
  }
}

sub vcl_error {
  if (obj.status == 750) {
    # moved permanently
    set obj.http.Location = req.http.Location;
    set obj.status = 301;
  } else if (obj.status == 752) {
    # moved temporarily
    set obj.http.Location = req.http.Location;
    set obj.status = 302;
  } else {
    set obj.http.Content-Type = "text/html; charset=utf-8";
    set obj.http.Retry-After = "5";
    synthetic std.fileread("/etc/varnish/503.html");
  }
  return (deliver);
}
