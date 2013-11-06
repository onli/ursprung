snack.ready(function() {

    // if it finds no element, it finds a NodeList, resulting in an error which breaks all following js
    if (snack.wrap('.edit')[0].addEventListener != undefined) {
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
                form.querySelector('form').className += ' highlight';

                var cancelButton = document.createElement('button');
                cancelButton.innerHTML = "Cancel";
                cancelButton.setAttribute('type', 'button');
                cancelButton.className = "cancel";
                form.querySelector('.editorSubmitButtons').parentNode.insertBefore(cancelButton, form.querySelector('button').parentNode);
                snack.wrap(cancelButton).attach('click', function(evt) {
                    form.parentNode.replaceChild(parent, form);
                });
    
                parent.parentNode.replaceChild(form, parent);
            });
        });
    }
    
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

    // preview-button
    var publish;
    if ((publish = document.querySelector('.entryPublish')) != null) {
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
                    body: document.querySelector('.entryInput').value,
                    title: document.querySelector('.entryTitleInput').value
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
                entry.className += ' highlight';
                var preview;
                if ((preview = document.getElementById("preview")) != null) {
                    publish.parentNode.parentNode.replaceChild(entry, preview);
                } else {
                    publish.parentNode.parentNode.appendChild(entry);
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
    if (document.querySelector('.entryInput') != null) {
        var editor = document.querySelector('.entryInput');
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
        var imgButton = document.createElement("span");
        imgButton.innerHTML = "IMG";
        imgButton.className = "markupButton imgButton";
        var imgButtonInput = document.createElement("input");
        imgButtonInput.className = "imgButtonInput";
        imgButtonInput.type = "file";
        imgButtonInput.multiple = "multiple";
        imgButtonInput.names = "images";
        imgButtonInput.accept = "image";
        buttonBar.innerHTML += boldButton.outerHTML;
        buttonBar.innerHTML += italicButton.outerHTML;
        buttonBar.innerHTML += linkButton.outerHTML;
        buttonBar.innerHTML += imgButton.outerHTML;
        buttonBar.innerHTML += imgButtonInput.outerHTML;
        editor.parentNode.insertBefore(buttonBar, editor);
        snack.wrap('.boldButton').attach('click', function(evt) {
            var sel = getTextSelection(editor);
            var replace = "**"+sel+"**";
            replaceSelection(editor, replace);
        });
        snack.wrap('.italicButton').attach('click', function(evt) {
            var sel = getTextSelection(editor);
            var replace = "*"+sel+"*";
            replaceSelection(editor, replace);
        });
        snack.wrap('.linkButton').attach('click', function(evt) {
            var sel = getTextSelection(editor);
            var replace = '[http:// '+sel+']';
            replaceSelection(editor, replace);
        });
        snack.wrap('.imgButton').attach('click', function(evt) {
            imgButtonInput.click();
        });
        snack.wrap(imgButtonInput).attach('change', function() {
            var files = imgButtonInput.files
            for (var i = 0, f; f = files[i]; i++) {
                alert(f.name);
            }       
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