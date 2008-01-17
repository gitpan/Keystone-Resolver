%# $Id: textbox.mc,v 1.2.2.1 2008-01-17 12:49:21 mike Exp $
<%args>
$id => undef
$name
$size => 40
$maxlength => undef
</%args>
	 <input type="text" name="<% $name %>" size="<% $size %>"
% if (defined $maxlength) {
		maxlength="<% $maxlength %>"
% }
% if (defined $id) {
		id="<% $id %>"
% }
% my $val = utf8param($r, $name);
		value="<% defined $val ? $val : "" %>"/>
