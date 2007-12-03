%# $Id: search.mc,v 1.2 2007-05-24 21:48:57 mike Exp $
<%perl>
    if (defined $r->param("_submit") || defined $r->param("_query")) {
	$m->comp("submitted.mc", %ARGS);
    } else {
	$m->comp("form.mc", %ARGS);
    }
</%perl>
