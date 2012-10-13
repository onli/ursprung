snack.ready(function() {
    
    snack.wrap('.edit').attach('click', function(evt) {
        snack.preventDefault(evt)

        var options = {
            method: 'get',
            url: evt.srcElement.parentNode.href,
        }
        snack.request(options, function (err, res){
            if (err) {
                alert('error fetching option');
                return;
            }
            var parent = evt.srcElement.parentNode.parentNode;
            while (! parent.className.match(/\bcontainer\b/)) {
                var parent = parent.parentNode;
            }
            var form = document.createElement();
            form.innerHTML = res;
            var original = parent;
            parent.parentNode.replaceChild(form, parent);

            /* TODO: Find a way to use this and to get the actual page afterwards */
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
            url: evt.srcElement.parentNode.action,
        }
        snack.request(options, function (err, res) {
            if (err) {
                alert('error fetching option');
                return;
            }
            var parent = evt.srcElement.parentNode.parentNode;
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
    
});