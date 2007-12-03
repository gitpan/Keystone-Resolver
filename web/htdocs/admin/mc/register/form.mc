%# $Id: form.mc,v 1.2 2007-06-21 14:19:09 mike Exp $
<%perl>
my @params = (obj => "Keystone::Resolver::DB::User",
	      submitted => defined($r->param("register")));
my $p1 = utf8param($r, "password1");
my $p2 = utf8param($r, "password2");
</%perl>
     <form method="get" action="">
      <p>
       Please enter your details below to register as a user.  The
       fields marked with an asterisk (<span class="error">*</span>)
       are mandatory; the others are optional.
      </p>
      <table>
<& /mc/form/textbox.mc, @params, name => "email_address" &>
<& /mc/form/textbox.mc, @params, name => "name" &>
<& /mc/form/password.mc, @params, name => "password1", mandatory => 1,
	label => "Choose a password" &>
<& /mc/form/password.mc, @params, name => "password2", mandatory => 1,
	label => "Re-type your password" &>
<& /mc/form/error.mc, @params, cond => ($p1 && $p2 && $p1 ne $p2),
	msg => "Your passwords do not match!" &>
       <tr>
        <td></td>
        <td align="right">
	 <input type="submit" name="register" value="Register"/>
        </td>
       </tr>
      </table>
     </form>
