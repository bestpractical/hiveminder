function getPasswordToken() {
    var url = "/__jifty/webservices/xml";

    var parseToken = function(request, responseStatus) {
        var loginform = new Action("loginbox");
        var myform    = loginform.form;

        var response  = request.documentElement;
        var token     = response.getElementsByTagName("token")[0].firstChild.nodeValue;
        var salt      = response.getElementsByTagName("salt")[0].firstChild.nodeValue;

        var token_field = loginform.getField("token");
        token_field.value = token;

        if (token != "") {  // don't hash passwords if no token
            var password_field = loginform.getField("password");
            var password = password_field.value;
            var hashedpw_field = loginform.getField("hashed_password");
            hashedpw_field.value = Digest.MD5.md5Hex(token + " " + Digest.MD5.md5Hex(password + salt));

            // Clear password so it won't get submitted in cleartext.
            password_field.value = "";
        }
        myform.submit();
    };

    var request = { path: url, actions: {} };
    var a = {};
    a["moniker"] = "loginbox";
    a["class"]   = "BTDT::Action::GeneratePasswordToken";
    a["fields"]  = {};
    a["fields"]["address"]  = new Action("loginbox").getField('address').value;
    a["fields"]["moniker"]  = "loginbox";
    request["actions"]["loginbox"] = a;

    jQuery.ajax({
        url: url,
        type: "post",
        data: JSON.stringify(request),
        contentType: 'text/x-json',
        dataType: 'xml',
        success: parseToken
    });

    return false;
}

