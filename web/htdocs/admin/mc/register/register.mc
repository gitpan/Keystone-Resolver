%# $Id: register.mc,v 1.2.2.1 2008-01-17 13:02:28 mike Exp $
<%perl>
my $p1 = utf8param($r, "password1");
my $p2 = utf8param($r, "password2");
if (utf8param($r, "email_address") &&
    utf8param($r, "name") &&
    ($p1 && $p2 && $p1 eq $p2)) {
    $m->comp("submitted.mc", %ARGS);
} else {
    $m->comp("form.mc", %ARGS);
}
</%perl>
