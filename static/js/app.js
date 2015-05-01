// Normal is 20, but we want one step scrolling
if (Jifty.SmoothScroll) Jifty.SmoothScroll.steps = 1;

// BTDT.Util

if ( typeof BTDT == "undefined" ) BTDT = { };

BTDT.Util = {
    toggleTasklistSavedState: function(id) {
        var e = document.getElementById(id);
        
        jQuery(e).toggleClass("brief_tasklist");
        var cookie = new HTTP.Cookies;

        var button = document.getElementById(id + "-toggle");
        if (jQuery(e).hasClass("brief_tasklist")) {
            if ( button ) button.innerHTML = "Show Details";
            cookie.write(id, "brief", "+1y");
        }
        else {
            /* it _was_ brief, now full */
            if ( button ) button.innerHTML = "Hide Details";
            cookie.write(id, "full", "+1y");
        }
    },
    
    loadTasklistSavedStates: function() {
        var cookies = document.cookie.split(/;\s*/);
        var len     = cookies.length;

        for (var i = 0; i < len; i++) {
            var c = cookies[i].split("=");
            
            if (c[0].match(/^tasklist-/)) {
                var e = document.getElementById(c[0]);
                if (e) {
                    var button = document.getElementById(e.id + "-toggle");
                    if (c[1] == "brief") {
                        if ( button ) button.innerHTML = "Show Details";
                        jQuery(e).addClass("brief_tasklist");
                    }
                    else {
                        if ( button ) button.innerHTML = "Hide Details";
                        jQuery(e).removeClass("brief_tasklist");
                    }
                }
            }
        }
    },

    openHelpWindow: function(href) {
        return BTDT.Util.openWindow(href, "help_system", 500, 450);
    },

    openStopWatch: function(href) {
        var random = Math.floor(Math.random()*10000);
        return BTDT.Util.openWindow(href, "stopwatch"+random, 290, 190, "scrollbars=1,toolbar=0,menubar=0,status=0,location=0,resizeable=yes");
    },

    openWindow: function(href) {
        var name   = arguments[1] || "btdt_popup";
        var width  = arguments[2] || 500;
        var height = arguments[3] || width - 100;
        var extra  = arguments[4] || "scrollbars=1,resizeable=yes";
        
        var objWindow = window.open( href,
                                     name,
                                     "height="+height+",width="+width+","+extra
                                    );
        if ( !objWindow.opener ) objWindow.opener = self;
    
        objWindow.focus();
        return false;
    },

    highlightPageNotifications: function() {
        var errors = document.getElementById("errors");
        if ( errors ) jQuery(errors).shake();
    },

    applyKeyMap: function() {
        var map = new YAHOO.util.KeyListener( document, 
                    { keys: [37,39] },
                    { fn: BTDT.Util._kp, 
                      correctScope: true });
        map.enable();
        var map_ctrl = new YAHOO.util.KeyListener( document, 
                    { ctrl: true, keys: [83] },
                    { fn: BTDT.Util._kp_ctrl, 
                      correctScope: true });
        map_ctrl.enable();
    },
    _keybuffer: "",
    _kp: function(type, args, obj) {
        var allowPattern = /INPUT|TEXTAREA/i;
        var kc = args[0];
        var e = args[1];
        var target = YAHOO.util.Event.getTarget(e);

        if ( target && !allowPattern.test(target.tagName ) ) {

            switch (kc) {
                /* left arrow key = prev.link */
                case 37:
                    YAHOO.util.Event.preventDefault(e);
                    var link = YAHOO.util.Dom.getElementsByClassName('prev');
                    if ( typeof( link[0] ) != "undefined" ) {
                        location.href = link[0];
                    }
                    break;
                /* right arrow key = next.link */
                case 39:
                    var link = YAHOO.util.Dom.getElementsByClassName('next');
                    if ( typeof( link[0] ) != "undefined" ) {
                        location.href = link[0];
                    }
                    YAHOO.util.Event.preventDefault(e);
                    break;
                default:
            }

            BTDT.Util._keybuffer = String.fromCharCode(kc).toLowerCase();
        }
    },
    _kp_ctrl: function(type, args, obj) {
        var allowPattern = /INPUT|TEXTAREA/i;
        var kc = args[0];
        var e = args[1];
        var target = YAHOO.util.Event.getTarget(e);

        if ( target && !allowPattern.test(target.tagName ) ) {

            switch (kc) {
                /* ctrl+s */
                case 83:
                    var search = document.getElementById('search');
                    if ( typeof( search ) != "undefined" ) {
                        search.onclick();
                    }
                    YAHOO.util.Event.preventDefault(e);
                    break;
                default:
            }
        }
    },
    applyDropShadow: function(e) {
        var element = document.getElementById(e);
    
        var wrap1 = document.createElement("div");
        wrap1.setAttribute("class", "dropshadow_wrap1");
        var wrap2 = document.createElement("div");
        wrap2.setAttribute("class", "dropshadow_wrap2");
        var wrap3 = document.createElement("div");
        wrap3.setAttribute("class", "dropshadow_wrap3");

        var outerNode = element.parentNode;
        
        if ( outerNode ) {
            outerNode.insertBefore(wrap1, element);
            outerNode.removeChild(element);
        }
        
        wrap1.appendChild(wrap2);
        wrap2.appendChild(wrap3);
        wrap3.appendChild(element);
        
        return wrap1;
    }
};

jQuery(document).ready( BTDT.Util.loadTasklistSavedStates );
jQuery(document).ready( BTDT.Util.highlightPageNotifications );
jQuery(document).ready( BTDT.Util.applyKeyMap );

