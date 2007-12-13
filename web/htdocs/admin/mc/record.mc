%# $Id: record.mc,v 1.10 2007-12-12 15:16:32 marc Exp $
<%args>
$_class
$id
</%args>
<%perl>
my $site = $m->notes("site");
my $record = $site->db()->find1($_class, id => $id);
</%perl>
   <h2><% encode_entities($_class . ": " . $record->render_name()) %></h2>
   <table class="center">
% my @df = $record->fulldisplay_fields();
% while (@df) {
%   my $field = shift @df;
%   my $fulltype = shift @df;
    <tr>
     <th><% encode_entities($record->label($field)) %></th>
<& /mc/displayfield.mc, context => "l", record => $record,
		 field => $field, fulltype => $fulltype &>
    </tr>
% }
   </table>
% my $user = $m->comp("/mc/utils/user.mc", require => 0);
% if (defined $user && $user->admin() > 0) {
%     my $url = "./edit.html?_class=$_class&amp;id=$id";
%     print qq[     <p><a href="$url">Edit</a></p>\n];
%     $m->comp("/mc/newlink.mc", _class => $_class);
% }
