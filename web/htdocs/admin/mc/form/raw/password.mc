%# $Id: password.mc,v 1.2.2.1 2008-01-17 12:49:21 mike Exp $
<%args>
$name
$size => 40
$maxlength => undef
</%args>
	 <input type="password" name="<% $name %>" size="<% $size %>"
% if (defined $maxlength) {
		maxlength="<% $maxlength %>"
% }
% my $val = utf8param($r, $name);
		value="<% defined $val ? $val : "" %>"/>
