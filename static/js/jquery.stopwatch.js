/*
 * StopWatch for jQuery v1.2
 *
 * Display a stopwatch timer (with control buttons) for a text field.
 * Attach it with like so: $('input selector').StopWatch();
 *
 * Written by Thomas Sibley <trs@bestpractical.com>.
 * Copyright Best Practical, LLC, 2008.
 *
 * Based on the MIT-licensed Countdown plugin for jQuery v1.2.0,
 * written by Keith Wood, 2008 - http://keith-wood.name/countdown.html
 *
 */

(function($) {

/* StopWatch manager. */
function StopWatch() {
    this._nextId = 0; // Next ID for a stopwatch instance
    this._inst = []; // List of instances indexed by ID
    this._defaults = {
        autoStart: true,      // Whether or not to autostart on init
        countFrom: 0,         // How many seconds to start the count from
        countFromInput: true, // Set countFrom to the value in the <input>
        onTick: null          // Callback when the stopwatch is updated
    };
}

$.extend(StopWatch.prototype, {
    /* Class name added to elements to indicate already configured with stopwatch. */
    markerClassName: 'hasStopWatch',
    
    /* Register a new stopwatch instance - with custom settings. */
    _register: function(inst) {
        var id = this._nextId++;
        this._inst[id] = inst;
        return id;
    },

    /* Retrieve a particular stopwatch instance based on its ID. */
    _getInst: function(id) {
        return this._inst[id] || id;
    },

    /* Override the default settings for all instances of the stopwatch widget.
       @param  settings  object - the new settings to use as defaults
       @return void */
    setDefaults: function(settings) {
        extendRemove(this._defaults, settings || {});
    },

    /* Attach the stopwatch widget to an input. */
    _attachStopWatch: function(target, inst) {
        target = $(target);
        if (target.is('.' + this.markerClassName)) {
            return;
        }
        target.addClass(this.markerClassName);
        target[0]._swId = inst._id;
        inst._target = target;
        inst._button = inst._get("autoStart")
                            ? $("<button>Pause</button>").addClass('sw-pause')
                            : $("<button>Start</button>").addClass('sw-resume');

        // Wire up our start/stop button
        target.after(
            inst._button.bind('click',
                inst._id, function(ev) {
                    if ( $(this).hasClass('sw-resume') ) {
                        ev.preventDefault();
                        jQuery.StopWatch._startStopWatch(ev.data);
                        jQuery(this).text("Pause");
                    }
                    else if ( $(this).hasClass('sw-pause') ) {
                        ev.preventDefault();
                        jQuery.StopWatch.__pauseStopWatch(ev.data);
                        jQuery(this).text("Resume");
                    }
                    
                    jQuery(ev.target).toggleClass('sw-resume').toggleClass('sw-pause');
                }
            )
        );

        if ( inst._get("countFromInput") ) {
            var value = target.val();
            var seconds = inst._parseDuration(value);
            if (seconds) {
                inst._set("countFrom", seconds);
            }
        }

        target.focus(function(ev) {
            jQuery(this).StopWatch('pause');
        });

        if ( inst._get("autoStart") ) {
            // Fire it up
            this._startStopWatch(inst._id);
        }
    },

    /* Start/resume a stopwatch widget. */
    _startStopWatch: function(id) {
        var inst = this._getInst(id);

        var value = inst._target.val();

        // if we're unpausing..
        if (value) {
            var duration = inst._parseDuration(value);
            var previous = inst._previous;
            var previous_sec = parseInt(previous / 1000);

            // If the display does not match what we expect, then the user
            // changed the input; adjust accordingly
            if (duration != previous_sec) {
                inst._previous = duration * 1000;
            }
        }

        // Set the start time
        inst._start = new Date();
        
        // Do our first update (which makes the rest happen)
        this._updateStopWatch(inst._id);
    },

    /* Redisplay the stopwatch with an updated display. */
    _updateStopWatch: function(id) {
        var inst  = this._getInst(id);
        var units = inst._calculateElapsedUntil(new Date());

        // Update <input>
        inst._target.val(inst._generateDuration(units));

        // Tick
        var onTick = inst._get('onTick');
        if ( onTick )
            onTick.apply(this, [inst, units]);

        inst._timer = setTimeout("jQuery.StopWatch._updateStopWatch(" + inst._id + ")", 500);
    },

    _pauseStopWatch: function(target) {
        target = $(target);
        if (!target.is('.' + this.markerClassName)) {
            return;
        }
        this.__pauseStopWatch( target[0]._swId );

        var inst = this._getInst( target[0]._swId );
        inst._button.text("Resume");
        inst._button.toggleClass('sw-resume').toggleClass('sw-pause');
    },

    /* Pause the stopwatch (which enables it to be resumed again) */
    __pauseStopWatch: function(id) {
        var inst = this._getInst(id);
        
        // Save our current elapsed time + any previously elapsed time
        var now = new Date();
        inst._previous = (now.getTime() - inst._start.getTime()) + inst._previous;
        
        // Stop the timer
        clearTimeout(inst._timer);
        
        // Clear the previous start time
        inst._start = null;
    },

    /* Remove the stopwatch widget from an element. */
    _destroyStopWatch: function(target) {
        target = $(target);
        if (!target.is('.' + this.markerClassName)) {
            return;
        }
        target.removeClass(this.markerClassName);
        target.empty();
        this._inst[target[0]._swId]._button.remove();
        clearTimeout(this._inst[target[0]._swId]._timer);
        this._inst[target[0]._swId] = null;
        target[0]._swId = undefined;
    }
});

var H = 0; // Hours
var M = 1; // Minutes
var S = 2; // Seconds

/* Individualised settings for stopwatch widgets applied to one or more inputs.
   Instances are managed and manipulated through the StopWatch manager. */
function StopWatchInstance(settings) {
    this._id        = $.StopWatch._register(this);
    this._target    = null; // jQuery wrapped target element
    this._button    = null; // jQuery wrapped button
    this._timer     = null; // The active timer for this countdown
    this._start     = null; // The start time
    this._previous  = 0;    // The duration (in ms) at the last pause
    // Customise the stopwatch object - uses manager defaults if not overridden
    this._settings = extendRemove({}, settings || {}); // clone
}

$.extend(StopWatchInstance.prototype, {
    /* Get a settings value, defaulting if necessary. */
    _get: function(name) {
        return (this._settings[name] != null ? this._settings[name] : $.StopWatch._defaults[name]);
    },

    /* Set a settings values */
    _set: function(name, value) {
        this._settings[name] = value;
    },
    
    /* Generate the text to display the stopwatch widget. */
    _generateDuration: function(units) {
        var twoDigits = function(value) {
            return (value < 10 ? '0' : '') + value;
        };
        return twoDigits(units[H]) + ":" + twoDigits(units[M]) + ":" + twoDigits(units[S]);
    },

    _parseDuration: function(value) {
        if ( value.match(/^\d+:\d+:\d+$/) ) {
            var parts = value.split(":", 3);
            var from  = parseInt(parts[0]) * 3600
                      + parseInt(parts[1]) * 60
                      + parseInt(parts[2]);
            return from;
        }

        if ( value.match(/^\d+$/) ) {
            return parseInt(value);
        }

        return false;
    },

    /* Calculate elapsed between the start and now plus any previously elapsed time. */
    _calculateElapsedUntil: function(now) {
        var millis  = now.getTime() - this._start.getTime();
            millis += this._previous + (this._get("countFrom") * 1000);
        var elapsed = Math.floor(millis / 1000);
        return this._extractHMS( elapsed );
    },

    _extractHMS: function(seconds) {
        var units = [0, 0, 0];
        var extractElapsed = function(unit, numSecs) {
            units[unit] = Math.floor(seconds / numSecs);
            seconds    -= units[unit] * numSecs;
        };
        extractElapsed(H, 3600);
        extractElapsed(M, 60);
        extractElapsed(S, 1);
        return units;
    }
});

/* jQuery extend now ignores nulls! */
function extendRemove(target, props) {
    $.extend(target, props);
    for (var name in props) {
        if (props[name] == null) {
            target[name] = null;
        }
    }
    return target;
}

/* Attach the stopwatch functionality to a jQuery selection.
   @param  command  string - the command to run (optional, default 'attach')
   @param  options  object - the new settings to use for these stopwatch instances
   @return  jQuery object - for chaining further calls */
$.fn.StopWatch = function(options) {
    var otherArgs = Array.prototype.slice.call(arguments, 1);
    return this.each(function() {
        if (typeof options == 'string') {
            $.StopWatch['_' + options + 'StopWatch'].apply($.StopWatch, [this].concat(otherArgs));
        }
        else {
            $.StopWatch._attachStopWatch(this, new StopWatchInstance(options));
        }
    });
};

/* Initialise the stopwatch functionality. */
//$(function() {
   $.StopWatch = new StopWatch(); // singleton instance manager
//});

})(jQuery);

