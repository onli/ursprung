snack.ready(function() {
    
    snack.wrap('.edit').attach('click', function(evt) {
        snack.preventDefault(evt)

        var options = {
            method: 'get',
            url: evt.target.parentNode.href,
        }
        snack.request(options, function (err, res){
            if (err) {
                alert('error fetching option: ' + err);
                return;
            }
            var parent = getParent(evt.target, 'container')

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
                alert('error fetching option: ' + err);
                return;
            }
            var parent = getParent(evt.target, 'container')

            events = ["animationend", "webkitAnimationEnd", "oanimationend", "MSAnimationEnd"];
            events.forEach(function(event) {
                snack.wrap(parent.parentNode).addClass("fadeout").attach(event, function() {
                    parent.parentNode.removeChild(parent);
                });
            });
            
        });
    });

    // preview-button
    var publish;
    if ((publish = document.getElementById('entryPublish')) != null) {
        var previewButton = document.createElement('button');
        previewButton.innerHTML = "Preview";
        previewButton['id'] = "previewButton";
        previewButton.setAttribute('type', 'button');
        publish.parentNode.insertBefore(previewButton, publish);
        snack.wrap(previewButton).attach('click', function(evt) {
            var options = {
                method: 'post',
                url: '/preview',
                data: {
                    body: document.getElementById('entryInput').value,
                    title: document.getElementById('entryTitleInput').value
                }
            }
            snack.request(options, function (err, res) {
                if (err) {
                    alert('error getting preview: ' + err);
                    return;
                }
                var entry = document.createElement('div');
                entry.innerHTML = res;
                entry['id'] = "preview";
                var preview;
                if ((preview = document.getElementById("preview")) != null) {
                    publish.parentNode.replaceChild(entry, preview);
                } else {
                    publish.parentNode.appendChild(entry);
                }
                preview = document.getElementById("preview");
                var adminOptions = preview.querySelectorAll('.adminOptions')[0];
                adminOptions.parentNode.removeChild(adminOptions);
            });
        });
    }

    // support for the hover-menu, dont vanish directly
    if (snack.wrap('.adminOptionsMoreSign').length > 1) {
        // start this only on a page with comments, else snack throws errors
        var fadeouts = {};
        snack.wrap('.adminOptionsMoreSign').attach('mouseover', function(evt) {
            var parent = evt.target.parentNode.querySelectorAll(".adminOptionsMoreOptions")[0];
            parent.style["display"] = "block";
            snack.wrap(parent).removeClass("fadeout");
            clearTimeout(fadeouts[parent.innerHTML]);
            if (! navigator.userAgent.match(/.*Firefox.*/)) {
                // detect firefox here, because in firefox the animation leads to the menu vanishing immediately
                snack.wrap(evt.target.parentNode.querySelectorAll(".adminOptionsMoreOptions")[0]).addClass("fadein");
            }
        });

        snack.wrap('.adminOptionsMoreSign').attach('mouseout', function(evt) {
            var parent = evt.target.parentNode.querySelectorAll(".adminOptionsMoreOptions")[0];
            fadeOutMenut(parent);
        });
        
        snack.wrap('.adminOptionsMoreOptions').attach('mouseout', function(evt) {
            var parent = getParent(evt.target, 'adminOptionsMoreOptions'); 
            fadeOutMenut(parent);
        });

        function fadeOutMenut(parent) {
            var fadeout = setTimeout(function() {
                                    snack.wrap(parent).removeClass("fadein");
                                    snack.wrap(parent).addClass("fadeout");
                                    clearTimeout(fadeout);
                                }, 300);
            fadeouts[parent.innerHTML] = fadeout
        }

        snack.wrap('.adminOptionsMoreOptions').attach('mouseover', function(evt) {
            var parent = getParent(evt.target, 'adminOptionsMoreOptions'); 
            clearTimeout(fadeouts[parent.innerHTML]);
        });
    }

    // markup-buttons
    if (snack.wrap('#entryInput').length == 1) {
        editor = document.getElementById('entryInput');
        buttonBar = document.createElement("div");
        buttonBar.className = "buttonBar";
        boldButton = document.createElement("span");
        boldButton.innerHTML = "B";
        boldButton.className = "markupButton boldButton";
        italicButton = document.createElement("span");
        italicButton.innerHTML = "I";
        italicButton.className = "markupButton italicButton";
        linkButton = document.createElement("img");
        linkButton["alt"] = "Link";
        linkButton["src"] = "/link.png";
        linkButton.className = "markupButton linkButton";
        buttonBar.innerHTML += boldButton.outerHTML;
        buttonBar.innerHTML += italicButton.outerHTML;
        buttonBar.innerHTML += linkButton.outerHTML;
        editor.parentNode.insertBefore(buttonBar, editor);
        snack.wrap('.boldButton').attach('click', function(evt) {
            var sel = getTextSelection(editor);
            var replace = "*"+sel+"*";
            replaceSelection(editor, replace);
        });
        snack.wrap('.italicButton').attach('click', function(evt) {
            var sel = getTextSelection(editor);
            var replace = "_"+sel+"_";
            replaceSelection(editor, replace);
        });
        snack.wrap('.linkButton').attach('click', function(evt) {
            var sel = getTextSelection(editor);
            var replace = '"'+sel+'":http://';
            replaceSelection(editor, replace);
        });
    }

    function getTextSelection(textarea){
        var startPos = textarea.selectionStart;
        var endPos = textarea.selectionEnd;        
        var field_value = textarea.value;
        var selectedText = field_value.substring(startPos,endPos);
        return selectedText;
    }

    function replaceSelection(editor, text) {
        var start = editor.selectionStart;
        var end = editor.selectionEnd;
        var len = editor.value.length;
        editor.value =  editor.value.substring(0,start) + text + editor.value.substring(end,len);
        editor.selectionEnd = start + text.length;
    }
    

    function getParent(start, classname) {
        while (! start.className.match(new RegExp('\\b'+classname+'\\b'))) {
            var start = start.parentNode;
        }
        return start
    }
    
});