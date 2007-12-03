%# $Id: password.mc,v 1.2 2007-06-21 14:19:09 mike Exp $
<%args>
$name
$size => 40
$maxlength => undef
</%args>
	 <input type="password" name="<% $name %>" size="<% $size %>"
% if (defined $maxlength) {
		maxlength="<% $maxlength %>"
% }
		value="<% defined $r->param($name) ? utf8param($r, $name) : "" %>"/>
