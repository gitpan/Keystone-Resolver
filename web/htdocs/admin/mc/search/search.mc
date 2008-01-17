%# $Id: search.mc,v 1.2.2.1 2008-01-17 12:49:21 mike Exp $
<%perl>
    if (defined utf8param($r, "_submit") || defined utf8param($r, "_query")) {
	$m->comp("submitted.mc", %ARGS);
    } else {
	$m->comp("form.mc", %ARGS);
    }
</%perl>
