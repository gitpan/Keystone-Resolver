%# $Id: textbox.mc,v 1.2 2007-06-21 14:19:09 mike Exp $
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
		value="<% defined $r->param($name) ? utf8param($r, $name) : "" %>"/>
