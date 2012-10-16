snack.ready(function() {
    
    snack.wrap('.edit').attach('click', function(evt) {
        snack.preventDefault(evt)

        var options = {
            method: 'get',
            url: evt.target.parentNode.href,
        }
        snack.request(options, function (err, res){
            if (err) {
                alert('error fetching option');
                return;
            }
            var parent = evt.target.parentNode.parentNode;
            while (! parent.className.match(/\bcontainer\b/)) {
                var parent = parent.parentNode;
            }

            if (navigator.userAgent.match(/.*Firefox.*/)) {
                // detect firefox here, because in firefox you cant create an empty element and chrome can't add the form as inner/outerhtml without errors
                var form = document.createElement("form");
            } else {
                var form = document.createElement();
            }
            form.innerHTML = res;
            var original = parent;
            parent.parentNode.replaceChild(form, parent);


            /* TODO: Find a way to use this and to get the new content afterwards */
            /*var params = {
                node: form.firstChild,
                event: 'submit'
            }
            
            snack.listener(params, function(evt) {
                snack.preventDefault(evt)
                elements = evt.srcElement.elements;
                var data = {};
                for(var i=0;i < elements.length; i++) {
                    if (elements[i].name != "") {
                        data[elements[i].name] = elements[i].value;
                    }
                }
                var options = {
                    method: 'post',
                    url: evt.srcElement.action,
                }
                options["data"] = data;
                snack.request(options, function (err, res){
                     if (err) {
                        alert('error setting option');
                        return;
                    }
                    evt.srcElement.parentNode.replaceChild(original, evt.srcElement);
                });
            })*/
        });
    });

    snack.wrap('.delete').attach('click', function(evt) {
        snack.preventDefault(evt)
        
        var options = {
            method: 'post',
            url: evt.target.parentNode.action,
        }
        snack.request(options, function (err, res) {
            if (err) {
                alert('error fetching option');
                return;
            }
            var parent = evt.target.parentNode.parentNode;
            while (! parent.className.match(/\bcontainer\b/)) {
                var parent = parent.parentNode;
            }

            events = ["animationend", "webkitAnimationEnd", "oanimationend", "MSAnimationEnd"];
            events.forEach(function(event) {
                snack.wrap(parent.parentNode).addClass("fadeout").attach(event, function() {
                    parent.parentNode.removeChild(parent);
                });
            });
            
        });
    });

    // support for the hover-menu, dont vanish directly

    if (snack.wrap('.adminOptionsMoreSign').length > 1) {
        // start this only on a page with comments, else snack throws errors
        var fadeout;
        snack.wrap('.adminOptionsMoreSign').attach('mouseover', function(evt) {
            parent = evt.target.parentNode.querySelectorAll(".adminOptionsMoreOptions")[0];
            parent.style["display"] = "block";
            snack.wrap(parent).removeClass("fadeout");
            clearTimeout(fadeout);
            if (! navigator.userAgent.match(/.*Firefox.*/)) {
                // detect firefox here, because in firefox the animation leads to the menu vanishing immediately
                snack.wrap(evt.target.parentNode.querySelectorAll(".adminOptionsMoreOptions")[0]).addClass("fadein");
            }
        });

        snack.wrap('.adminOptionsMoreSign').attach('mouseout', function(evt) {
            fadeOutMenut(parent);
        });
        
        snack.wrap('.adminOptionsMoreOptions').attach('mouseout', function(evt) {
            var parent = evt.target
            while (! parent.className.match(/\badminOptionsMoreOptions\b/)) {
                var parent = parent.parentNode;
            }
            fadeOutMenut(parent);
        });

        function fadeOutMenut(parent) {
            fadeout = setTimeout(function() {
                                    snack.wrap(parent).removeClass("fadein");
                                    snack.wrap(parent).addClass("fadeout");
                                    clearTimeout(fadeout);
                                }, 300);
        }

        snack.wrap('.adminOptionsMoreOptions').attach('mouseover', function(evt) {
            parent.style["background-color"] = "white";
            clearTimeout(fadeout);
        });
    }
    
});