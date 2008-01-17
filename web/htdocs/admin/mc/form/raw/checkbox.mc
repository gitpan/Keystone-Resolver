%# $Id: checkbox.mc,v 1.1.2.1 2008-01-17 12:49:21 mike Exp $
<%args>
$name
$label
</%args>
	 <input type="checkbox" id="<% $name %>" name="<% $name %>" value="1"
	   <% defined utf8param($r, $name) ? qq[checked="checked"] : "" %>/>
	 <label for="<% $name %>"><% $label %></label>
