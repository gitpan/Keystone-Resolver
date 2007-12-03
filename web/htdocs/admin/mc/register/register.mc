%# $Id: register.mc,v 1.2 2007-06-21 14:19:09 mike Exp $
<%perl>
my $p1 = utf8param($r, "password1");
my $p2 = utf8param($r, "password2");
if ($r->param("email_address") &&
    $r->param("name") &&
    ($p1 && $p2 && $p1 eq $p2)) {
    $m->comp("submitted.mc", %ARGS);
} else {
    $m->comp("form.mc", %ARGS);
}
</%perl>
