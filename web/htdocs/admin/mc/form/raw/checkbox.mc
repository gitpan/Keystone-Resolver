%# $Id: checkbox.mc,v 1.1 2007-05-16 12:41:15 mike Exp $
<%args>
$name
$label
</%args>
	 <input type="checkbox" id="<% $name %>" name="<% $name %>" value="1"
	   <% defined $r->param($name) ? qq[checked="checked"] : "" %>/>
	 <label for="<% $name %>"><% $label %></label>
