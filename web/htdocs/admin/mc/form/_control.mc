%# $Id: _control.mc,v 1.3 2007-06-21 14:19:09 mike Exp $
<%args>
$which
$obj => undef
$submitted
$name
$label => undef
$nolabel => 0			# When true, suppress label even if provided
$prefix => ""
$suffix => ""
$caption => undef
$mandatory => undef
</%args>
<%perl>
if (!defined $label) {
    die "no label provided and obj not specified" if !defined $obj;
    $label = $obj->label($name, $label);
}
$mandatory = grep { $_ eq $name } $obj->mandatory_fields()
    if !defined $mandatory && defined $obj;
</%perl>
       <tr>
	<td valign="top" align="right">
% if ($label && !$nolabel) {
	 <% $mandatory ? qq[<span class="error">*</span>&nbsp;] : ""
		%><% $label %>: <% $prefix %>
% }
	</td>
	<td>
% $m->comp("/mc/form/raw/$which.mc", %ARGS);
	 <% $suffix %>
% if ($submitted && $mandatory && (!defined $r->param($name) ||
%				   utf8param($r, $name) =~ /^\s*$/)) {
	 <br/><span class="error">Please fill this field in!</span>
% }
% if (defined $caption) {
	 <br/><small class="disabled"><% $caption %></small>
% }
	</td>
       </tr>