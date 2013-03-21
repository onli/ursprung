snack.ready(function() {
    
    snack.wrap('.edit').attach('click', function(evt) {
        snack.preventDefault(evt)

        var options = {
            method: 'get',
            url: evt.target.parentNode.href,
        }
        snack.request(options, function(err, res){
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

    // if it finds no element, it finds a NodeList, resulting in an error which breaks all following js
    if (snack.wrap('.delete')[0].addEventListener != undefined) {
        snack.wrap('.delete').attach('click', function(evt) {
            snack.preventDefault(evt)
            
            var options = {
                method: 'post',
                url: evt.target.parentNode.action,
            }
            snack.request(options, function(err, res) {
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
    }
    if (snack.wrap('.messenger')[0].addEventListener != undefined) {
        snack.wrap('.messenger').attach('click', function(evt) {
            snack.wrap('.messenger').removeClass("activeMessenger");
            snack.wrap(evt.target).addClass("activeMessenger");
            var options = {
                    method: 'get',
                    url: "/messageList",
                    data: {
                        participant: evt.target.dataset["name"]
                    }
                }
            snack.request(options, function(err,res) {
                if (navigator.userAgent.match(/.*Firefox.*/)) {
                    // detect firefox here, because in firefox you cant create an empty element and chrome can't add the form as inner/outerhtml without errors
                    var list = document.createElement("ul");
                } else {
                    var list = document.createElement();
                }
                list.innerHTML = res;
                if (document.querySelector('#messageList') != null) {
                    document.querySelector('#messages').replaceChild(list, document.querySelector('#messageEditor').previousSibling);
                } else {
                    document.querySelector('#messages').insertBefore(list, document.querySelector('#messageEditor'));
                }
                
                snack.wrap('#messageEditor').addClass("fadein");
                document.querySelector('#to').value = evt.target.dataset["name"]
            });
        });
        snack.wrap('#messageEditor').attach('submit', function(evt) {
            snack.preventDefault(evt);
            var data = {};
            for (var i=0; i < evt.target.length; i++) {
                if (evt.target.elements[i].name) {
                    data[evt.target.elements[i].name] = evt.target.elements[i].value;
                }
            }
            var activity = document.createElement("progress");
            var sendText = document.querySelector("#messageEditor button span");
            activity.style['width'] = sendText.offsetWidth + 'px';
            document.querySelector("#messageEditor button").replaceChild(activity, sendText);
            var options = {
                method: evt.target.method,
                url: evt.target.action,
                data: data
            }
            snack.request(options, function (err, res) {
                if (err) {
                    alert('error sending message: ' + err);
                    return;
                }
                evt.target.querySelector('textarea').value = "";
                document.querySelector("#messageEditor button").replaceChild(sendText, activity);
                // now the new message has also be displayed in the me4ssage-list, so refresh
                var event = document.createEvent("HTMLEvents");
                event.initEvent("click", true, true);    
                document.querySelector(".activeMessenger").dispatchEvent(event);
            });
            
        });
    }

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
    if (document.getElementById('entryInput') != null) {
        var editor = document.getElementById('entryInput');
        var buttonBar = document.createElement("div");
        buttonBar.className = "buttonBar";
        var boldButton = document.createElement("span");
        boldButton.innerHTML = "B";
        boldButton.className = "markupButton boldButton";
        var italicButton = document.createElement("span");
        italicButton.innerHTML = "I";
        italicButton.className = "markupButton italicButton";
        var linkButton = document.createElement("img");
        linkButton["alt"] = "Link";
        linkButton["src"] = "/img/link.png";
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

    /* toggle-slider-button */
    if  (document.getElementById('entryModerationToggle') != null) {
        var moderationForm = document.getElementById('entryModerationToggle');
        var saveButton = moderationForm.querySelectorAll('.save')[0];
        var toggle = moderationForm.querySelectorAll('input[type="checkbox"]')[0];
        toggle.parentNode.insertBefore(document.createElement('span'), toggle.nextSibling);
        // the css will make a toggle-button out of the span, so the checkbox is no longer needed, as a click on the span triggers the label which triggers the checkbox
        toggle.style['display'] = 'none';
       
        snack.wrap(toggle).attach('change', function() {
                                                var options = {
                                                    method: 'post',
                                                    url: moderationForm.action,
                                                    data: {
                                                        value: toggle.checked
                                                    }
                                                    
                                                }
                                                snack.request(options, function (err, res) {
                                                    if (err) {
                                                        alert('error setting moderation: ' + err);
                                                        return;
                                                    }
                                                });
        });
        moderationForm.removeChild(saveButton);
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