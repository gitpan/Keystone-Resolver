%# $Id: layout.mc,v 1.17 2007-12-01 13:45:13 mike Exp $
<%args>
$debug => undef
$title
$component
</%args>
<%once>
use Encode;
use URI::Escape qw(uri_escape_utf8 uri_unescape);
use HTML::Entities;
use Apache::Cookie;
use Keystone::Resolver::Admin;
use Keystone::Resolver::Utils qw(encode_hash decode_hash utf8param);
</%once>
<%perl>
$r->content_type("text/html; charset=utf-8");
my $admin = Keystone::Resolver::Admin->admin();
my $host = $ENV{HTTP_HOST}; # Or we could use SERVER_NAME
my $tag = $admin->hostname2tag($host);
my $site = $admin->site($tag);
die "unknown Keystone Resolver site '$tag' (host $host)" if !defined $site;
$m->notes(site => $site);

my $cookies = Apache::Cookie->fetch();
my $cookie = $cookies->{session};
my $session = undef;
my $user = undef;

if (defined $cookie) {
    my $cval = $cookie->value();
    $session = $site->session1(cookie => $cval);
    if (!defined $session) {
	# Old cookie for a session that's no longer around.  We just
	# delete the cookie, silently logging the user out if he was
	# logged in.
	$site->log(1, "expiring old session $cval");
	my $cookie = new Apache::Cookie($r, -name => "session",
					-value => $cval, -expires => '-1d');
	$cookie->bake();
    }
}

if (!defined $session) {
    $session = $site->create_session();
    my $cookie = new Apache::Cookie($r, -name => "session",
				    -value => $session->cookie());
    $cookie->bake();
}
$m->notes(session => $session);

my $uid = $session->user_id();
if ($uid) {
    $user = $site->user1(id => $uid);
    die "Invalid user-ID '$uid'" if !defined $user;
    $m->notes(user => $user);
}

# Generate the text of the client area before emitting the framework:
# this allows it to affect the state, so that for example a login or
# logout $component can set or unset $user.
my $text = $m->scomp($component, %ARGS);
$user = $m->notes("user");
</%perl>
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html 
     PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <title>Keystone Resolver: <% encode_entities($title) %></title>
  <link rel="stylesheet" type="text/css" href="/admin/style.css"/>
 </head>
 <body>
% $m->comp("/mc/debug/cookies.mc", cookies => $cookies) if $debug;
  <div id="prologue">
   <h1><a href="/admin/">Keystone Resolver</a>: <% $title %></h1>
  </div>
   <div id="usermenu">
% if ($user) {
    <div id="umleft">
     <a href="/admin/user.html"><% encode_entities($user->name()) %></a>
     |
     <a href="/admin/details.html">Details</a>
     |	
     <a href="/admin/password.html">Password</a>
    </div>
    <div id="umright">
     <a href="/admin/logout.html">Logout</a>
    </div>
% } else {
    <div id="umright">
     <a href="/admin/login.html">Login</a>
     or
     <a href="/admin/register.html">Register</a>
    </div>
% }
   </div>
  <div id="menu">
   <a href="/admin/"><b>Home</b></a>
   <p>
    Search:
   </p>
   <ul class="tight">
    <li><a href="/admin/search.html?_class=MetadataFormat">Metadata&nbsp;Format</a></li>
    <li><a href="/admin/search.html?_class=Genre">Genre</a></li>
    <li><a href="/admin/search.html?_class=ServiceType">Service Type</a></li>
    <li><a href="/admin/search.html?_class=Service">Service</a></li>
    <li><a href="/admin/search.html?_class=Serial">Serial</a></li>
    <li><a href="/admin/search.html?_class=Domain">Domain</a></li>
    <li><a href="/admin/search.html?_class=Provider">Provider</a></li>
    <li><a href="/admin/search.html?_class=ServiceTypeRule">Service Type Rule</a></li>
    <li><a href="/admin/search.html?_class=ServiceRule">Service Rule</a></li>
% if ($user && $user->admin() > 1) {
    <li><a href="/admin/search.html?_class=User"><b>User</b></a></li>
% }
   </ul>
   <p>
    Browse:
   </p>
   <ul class="tight">
    <li><a href="/admin/search.html?_class=MetadataFormat&_submit=Search">Metadata&nbsp;Format</a></li>
    <li><a href="/admin/search.html?_class=Genre&_submit=Search">Genre</a></li>
    <li><a href="/admin/search.html?_class=ServiceType&_submit=Search">Service Type</a></li>
    <li><a href="/admin/search.html?_class=Service&_submit=Search">Service</a></li>
    <li><a href="/admin/search.html?_class=Serial&_submit=Search">Serial</a></li>
    <li><a href="/admin/search.html?_class=Domain&_submit=Search">Domain</a></li>
    <li><a href="/admin/search.html?_class=Provider&_submit=Search">Provider</a></li>
    <li><a href="/admin/search.html?_class=ServiceTypeRule&_submit=Search">Service Type Rule</a></li>
    <li><a href="/admin/search.html?_class=ServiceRule&_submit=Search">Service Rule</a></li>
% if ($user && $user->admin() > 1) {
    <li><a href="/admin/search.html?_class=User&_submit=Search"><b>User</b></a></li>
% }
   </ul>
   <br/>
   <p>
    <a href="http://validator.w3.org/check?uri=referer"><img
	src="/admin/valid-xhtml10.png"
	alt="Valid XHTML 1.0 Strict" height="31" width="88" /></a>
    <br/>
    <a href="http://jigsaw.w3.org/css-validator/"><img
	src="/admin/vcss.png"
	alt="Valid CSS!" height="31" width="88" /></a>
   </p>
  </div>
  <div id="main">
<% $text %>
  </div>
  <div id="epilogue">
   <a href="http://indexdata.com/">Index Data</a>
  </div>
 </body>
</html>
