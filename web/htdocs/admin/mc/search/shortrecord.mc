%# $Id: shortrecord.mc,v 1.2 2007-09-12 13:08:33 mike Exp $
<%args>
$record
</%args>
<%perl>
my @df = $record->display_fields();
print "       <tr>\n";
while (@df) {
    my $field = shift @df;
    my $fulltype = shift @df;
    $m->comp("/mc/displayfield.mc", context => "s", record => $record,
	     field => $field, fulltype => $fulltype);
}
my $user = $m->comp("/mc/utils/user.mc", require => 0);
if (defined $user && $user->admin() > 0) {
    my $linkclass = $record->class();
    my $linkid = $record->id();
    my $url = "/admin/edit.html?_class=$linkclass&amp;id=$linkid";
    print qq[     <td class="td-admin"><a href="$url">Edit</a></td>\n];
}
print "       </tr>\n";
</%perl>
