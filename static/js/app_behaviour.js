/*
    IMPORTANT: if you make DOM changes that mean that an element
               ought to gain or lose a behaviour, call Behaviour.apply()!
*/

var round = function(e) {
    /* Check to see if the element is already rounded */
    if (!jQuery(e).hasClass("rounded")) {
        try {
            jQuery(e).corner("round");
        } catch (e) {}
        jQuery(e).addClass("rounded");
    }
};

var roundCompact = function(e) {
    /* Check to see if the element is already rounded */
    if (!jQuery(e).hasClass("rounded")) {
        jQuery(e).corner("round 5px");
        jQuery(e).addClass("rounded");
    }
};


var roundTop = function(e) {
    /* Check to see if the element is already rounded or if it's inline */
    if (   !jQuery(e).hasClass("rounded")
        && !jQuery(e).hasClass("inline"))
    {
        jQuery(e).corner("round top");
        jQuery(e).addClass("rounded");
    }
};

var roundTopCompact = function(e) {
    /* Check to see if the element is already rounded or if it's inline */
    if ( !jQuery(e).hasClass("rounded") )
    {
        jQuery(e).corner("round top 5px");
        jQuery(e).addClass("rounded");
    }
};


var roundBottom = function(e) {
    /* Check to see if the element is already rounded or if it's inline */
    if (   !jQuery(e).hasClass("rounded")
        && !jQuery(e).hasClass("inline"))
    {
        jQuery(e).corner("round bottom");
        jQuery(e).addClass("rounded");
    }
};

var roundBottomCompact = function(e) {
    /* Check to see if the element is already rounded or if it's inline */
    if ( !jQuery(e).hasClass("rounded") )
    {
        jQuery(e).corner("round bottom 5px");
        jQuery(e).addClass("rounded");
    }
};




function openLinkInParent(href) {
    if ( window.opener ) {
        window.opener.location.href = href;
        return false;
    }
    return true;
};

var makeLinksOpenInParent = function(e) {
    if ( !e.onclick && !e.getAttribute("target") ) {
        jQuery(e).click(function(ev) {
            var pass_thru = openLinkInParent(ev.target.href);
            if ( !pass_thru )
                ev.preventDefault();
            return pass_thru;
        });
    }
};

var resize = function(e) {
    if (e.style.display == "none") return;

    e = jQuery(e);
    var line    = e.parent().parent();
    var therest = line.children(":not(div.argument-summary)").width();
    // 125 is just a value that "makes it work"
    e.width( line.width() - therest - 125 );
};

var baserules = {
    "input.ajaxduplicates" : function(element) {
        jQuery(element).hide();
    },
    /* We always want this rounding rule to run */
/*    "#navigation ul.menu": roundTopCompact,*/
    "#help-system a.external": makeLinksOpenInParent,
    "dl.tasklist": function(e) {
        var cookie = new HTTP.Cookies;
        var state  = cookie.read(e.id);

        if ( state == "brief" )
            jQuery(e).addClass("brief_tasklist");
    },
    "div.create input.argument-summary": resize,
    "input.stopwatch": function(e) {
        var countdown = jQuery(e).parents(".stopwatch-widget")
                                 .find("input.countdown");
        
        countdown.bind('focus', e, function(ev) {
            jQuery(ev.data).StopWatch('pause');
        });

        jQuery(e).StopWatch({
            _countDownTarget: countdown,
            _initialLeft: countdown.val(),
            countFromInput: false,
            onTick: function(inst, units) {
                var countdown   = jQuery(inst._get("_countDownTarget"));
                var parts       = inst._get("_initialLeft").split(":");

                // Make sure we're dealing with Numbers, not Strings
                parts = jQuery.map( parts, function(a){ return Number(a) } );

                var secondsLeft    = (parts[0] * 3600) + (parts[1] * 60) + (parts[2]);
                var secondsElapsed = (units[0] * 3600) + (units[1] * 60) + (units[2]);

                var nowLeft = secondsLeft - secondsElapsed;

                if ( nowLeft >= 0 ) {
                    countdown.val( inst._generateDuration(inst._extractHMS(nowLeft)) );
                }
                else {
                    countdown.val("");
                }
            }
        });
    },
    "span.task span.task_by span.unaccepted": function(e) {
        jQuery(e).attr( 'title', 'Waiting to be accepted or declined' );
    },
    "span.task span.task_by span.declined": function(e) {
        jQuery(e).attr( 'title', 'Task was declined' );
    }
};

Behaviour.register( baserules );

/* these rounded corners are handled by css for firefox/safari */
/* css for #page_nav in ff seems to only work well in ff3.  unfortunately,
   the js looks ugly in ff2 and ff3 */
if ( Jifty.Utils.browser() != "mozilla" && Jifty.Utils.browser() != "safari" ) {
    var roundingrules = {
        "#main h2, #help-system h2": roundTop,
/*        "#tagcloud div.tagcloud h3, #braindump h3, #invite_new_user h3": roundTop,
        "#feedback": round, */
        "#signupplea": round,
        "div.round": round,
        "#actions_container ul": roundTop,
        "#page_nav li": roundTopCompact,
        ".task_container .tools": roundBottomCompact
    };

    Behaviour.register( roundingrules );
}
