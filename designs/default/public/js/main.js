snack.ready(function() {
    initEditElements();
    initDeleteElements();

    function initEditElements() {
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
                    try {
                        // is it an entry?
                        form.querySelector('.editorSubmitButtons').parentNode.insertBefore(cancelButton, form.querySelector('button').parentNode);
                    } catch (e) {
                        var possibleOption = form.querySelector('input[type="text"]');
                        if (possibleOption.className == "commentFormTel") {
                            // it is a comment!
                            form.querySelector('.commentFormSubmit').parentNode.insertBefore(cancelButton, form.querySelector('.commentFormSubmit'));
                        } else {
                            // now we know it is not the honeypot of the commentform, so it must be an option
                            possibleOption.addEventListener("blur", function(evt) {
                                if (typeof evt.relatedTarget != null || evt.relatedTarget.type == undefined || evt.relatedTarget.type != "submit") {
                                    form.parentNode.replaceChild(parent, form);
                                }
                            });
                        }
                    }
                    snack.wrap(cancelButton).attach('click', function(evt) {
                        form.parentNode.replaceChild(parent, form);
                    });
        
                    parent.parentNode.replaceChild(form, parent);
                });
            });
        }
    }

    function initDeleteElements() {
    
        if (snack.wrap('.delete')[0].addEventListener != undefined) {
            snack.wrap('.delete').attach('click', function(evt) {
                snack.preventDefault(evt);
                
                var options = {
                    method: 'post',
                    url: evt.target.parentNode.action,
                }
                var entryId = evt.target.parentNode.dataset["entryid"];
                snack.request(options, function(err, res) {
                    if (err) {
                        alert('error deleting entry: ' + err);
                        return;
                    }
                    var parent = getParent(evt.target, 'container')
                    

                    events = ["animationend", "webkitAnimationEnd", "oanimationend", "MSAnimationEnd"];
                    events.forEach(function(event) {
                        snack.wrap(parent).addClass("fadeout").attach(event, function() {
                            parent.removeEventListener(event, arguments.callee, false);
                            var entry = parent.cloneNode();
                            while (parent.hasChildNodes()) {
                                parent.removeChild(parent.lastChild);
                            }
                            var undo = document.createElement("form");
                            undo.action = "/" + entryId + "/restoreEntry"
                            undo.method = "POST";
                            undo.id = "undo";
                            undo.className = "highlight";
                            var submitButton = document.createElement("button");
                            submitButton.type = "submit";
                            submitButton.innerHTML = "undo";
                            undo.appendChild(submitButton);
                            snack.wrap(parent).removeClass("fadeout");
                            snack.wrap(entry).removeClass("fadeout");
                            
                            undo.addEventListener("submit", function(evt) {
                                snack.preventDefault(evt);
                                var options = {
                                    method: evt.target.method,
                                    url: evt.target.action
                                }
                                snack.request(options, function(err, res) {
                                    if (err) {
                                        alert('error restoring entry: ' + err);
                                        return;
                                    }
                                });
                                parent.parentNode.replaceChild(entry, parent);
                                initEditElements();
                                initDeleteElements();
                                
                            });
                            parent.appendChild(undo);
                        });
                    });
                    
                });
            });
        }
    }

    // editor is loaded
    var publish;
    if ((publish = document.querySelector('.entryPublish')) != null) {
        // preview-button
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
                    title: document.querySelector('.entryTitleInput').value,
                    tags: document.querySelector('.entryTagInput').value
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
                entry.className += ' entry highlight';
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
        // tags autocomplete
        var tagInput = document.querySelector('.entryTagInput');
        var rawTags = document.querySelector('#tags').cloneNode();
        var tags = document.querySelector('#tags');
        var oldTagInputValue = "";
        tagInput.addEventListener('input', function(evt) {
            var autocompleteOccured = false;
            if (tagInput.value.length - oldTagInputValue.length > 1) {
                autocompleteOccured = true;
                tagInput.value += ", ";
            }
            if (tagInput.value.substr(-1) == ',' || autocompleteOccured) {
                tagOptions = [];
                for (var i=0;i < rawTags.options.length;i++) {
                    var newTag = document.createElement('option');
                    if (autocompleteOccured) {
                        newTag.value = tagInput.value + rawTags.options[i].value;
                    } else {
                        newTag.value = tagInput.value + " " + rawTags.options[i].value;
                    }
                    tagOptions[i] = newTag;
                }
                while (tags.hasChildNodes()) {
                    tags.removeChild(tags.lastChild);
                }
                for (var i=0;i < tagOptions.length;i++) {
                    tags.appendChild(tagOptions[i]);
                }
            }
            
            if (tagInput.value == "") {
                // user has deleted all tags
                tags.parentNode.appendChild(rawTags);
                tags.parentNode.removeChild(tags);
                tags =  document.querySelector('#tags');
                rawTags = document.querySelector('#tags').cloneNode();
            }
            oldTagInputValue = tagInput.value;
        });

        // file upload using drag & drop
        document.querySelector('.entryInput').addEventListener("dragenter", function(evt) {
            evt.stopPropagation();
            snack.preventDefault(evt);
        });
        document.querySelector('.entryInput').addEventListener("dragover", function(evt) {
            evt.stopPropagation();
            snack.preventDefault(evt);
        });
        document.querySelector('.entryInput').addEventListener("drop", function(evt) {
            evt.stopPropagation();
            snack.preventDefault(evt);

            var dt = evt.dataTransfer;
            uploadFiles(dt.files);
        });

        // Prevent sending the form with Enter while in an input-element
        tagInput.addEventListener("keypress", function(evt) {
            if (evt.which == 13) {
                snack.preventDefault(evt);
            }
        });

        document.querySelector('.entryTitleInput').addEventListener("keypress", function(evt) {
            if (evt.which == 13) {
                snack.preventDefault(evt);
            }
        });
    }

    // markup-buttons
    if (document.querySelector('.entryInput') != null) {
        var editor = document.querySelector('.entryInput');
        var buttonBar = document.createElement("div");
        buttonBar.className = "buttonBar";
        var boldButton = document.createElement("button");
        boldButton.innerHTML = "B";
        boldButton.type = "button";
        boldButton.className = "markupButton boldButton";
        var italicButton = document.createElement("button");
        italicButton.innerHTML = "I";
        italicButton.type = "button";
        italicButton.className = "markupButton italicButton";
        var linkButton = document.createElement("button");
        linkButton.type = "button";
        linkButton.className = "markupButton linkButton";
        linkButton.innerHTML = "Link";
        var imgButton = document.createElement("button");
        imgButton.innerHTML = "IMG";
        imgButton.type = "button";
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
        document.querySelector('.imgButton').addEventListener('click', function(evt) {
            imgButtonInput.click();
        });
        imgButtonInput.addEventListener('change', function() {
            uploadFiles(imgButtonInput.files);
        });
        
    }

    /* toggle-slider-button */
    if  (document.getElementById('entryModerationToggle') != null) {
        var moderationForm = document.getElementById('entryModerationToggle');
        var saveButton = moderationForm.querySelector('button');
        var toggle = moderationForm.querySelectorAll('.moderationStatus');
       
        snack.wrap(toggle).attach('change', function() {
                                                var options = {
                                                    method: 'post',
                                                    url: moderationForm.action,
                                                    data: {
                                                        value: (function() {
                                                                    for (var i = 0; i < toggle.length; i++) {
                                                                        if (toggle[i].checked) {
                                                                            return toggle[i].value
                                                                        }
                                                                    }   
                                                                })()
                                                    }
                                                    
                                                }
                                                snack.request(options, function (err, res) {
                                                    if (err) {
                                                        alert('error setting moderation: ' + err);
                                                        return;
                                                    }
                                                });
        });
        saveButton.parentNode.removeChild(saveButton);
    }

    if  (document.querySelector('.commentFormUrl') != null) {
        var urlInput = document.querySelector('.commentFormUrl');
        urlInput.addEventListener('change', function() {
            if (urlInput.value != "" && ! (urlInput.value.substr(0,7) == "http://" || urlInput.value.substr(0,8) == "https://")) {
                urlInput.value = "http://" + urlInput.value;
            }
        });
    }
    if (document.querySelector(".comment .adminOptions") != null) {
        var replyButton = document.createElement("button");
        replyButton.type = "button";
        replyButton.className = "reply";
        replyButton.title = "reply";
        replyButton.innerHTML = "&#9094";


        if (document.querySelector(".comment .adminOptions .edit") == null ) {
            // will be easier for visitors, and looks better
            replyButton.innerHTML = "Reply";
        }
        
        var replyAreas = document.querySelectorAll(".comment .adminOptions");
        for (var i=0; i < replyAreas.length; i++) {
            replyAreas[i].appendChild(replyButton.cloneNode(replyButton.cloneNode()));
        }
        snack.wrap(".reply").attach("click", function(evt) {
            var replyToCommentInput = document.querySelector('input[name="replyToComment"]');
            var replyToComment = evt.target.parentNode.dataset["id"];
            var commentInput = document.querySelector(".commentInput");
            replyToCommentInput.value = replyToComment;
            commentInput.value += ">>" + replyToComment + "\n";
            commentInput.selectionStart = commentInput.value.length;
            commentInput.selectionEnd = commentInput.value.length;
            commentInput.focus();
            window.location.hash = "commentForm";
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

    function uploadFiles(files) {
        Pace.restart();
        for (var i = 0; i < files.length; i++) {
            var f = files[i];
            (function(f) {
                var reader = new FileReader();
                reader.addEventListener("load", function(event) {
                    object = {};
                    object.filename = f.name;
                    object.data = event.target.result;
                    var options = {
                        method: 'post',
                        url: '/file',
                        data: object
                    }
                    Pace.track(function() {
                        snack.request(options, function (err, res) {
                            if (err) {
                                alert("error uploading file: " + err);
                            }
                            editor.value += "[["+res+"]]\n";
                        });
                    });
                });
                reader.readAsDataURL(f); 
            })(f);
        }
    }
    
});