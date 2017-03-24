//ChartView     
"use strict";
define(["jquery", "jquery-ui", "jsplumb", "editableselect", "app/Expression", "app/Emitter", "app/id", "hbs!app/templates/method", "hbs!app/templates/behavior", "hbs!app/templates/state", "hbs!app/templates/start", "hbs!app/templates/transition", "hbs!app/templates/mapping"],



    function($, ui, jsPlumb, EditableSelect, Expression, Emitter, ID, methodTemplate, behaviorTemplate, stateTemplate, startTemplate, transitionTemplate, mappingTemplate) {

        var block_was_dragged = null;


        console.log("start template", startTemplate);
        console.log("state template", stateTemplate);
        var state_counter = 0;
        var ChartView = class extends Emitter {

            constructor(id, name) {
                super();
                var behavior_data = {
                    id: id,
                    screen_name: name
                };
                this.setupId = null;
                this.dieId = null;
                this.expressions = {};
                var html = behaviorTemplate(behavior_data);
                $("#canvas").append(html);

                $('#' + id).droppable({
                    greedy:true,
                    drop: function(event, ui) {
                        var type = $(ui.draggable).attr('type');
                        console.log("type=", type);
                        var drop_id = ID();
                        var data = {
                            type: type,
                            id: drop_id,
                            behaviorId: id

                        };
                        var x = $(ui.draggable).position().left;
                        var y = $(ui.draggable).position().top;
                        if (type == 'state') {
                            var name = prompt("Please give your state a name", "myState");
                            if (name !== null) {
                                data.name = name;
                                self.trigger("ON_STATE_ADDED", [x, y, data]);
                                $(ui.helper).remove(); //destroy clone
                                $(ui.draggable).remove(); //remove from list
                            }
                        } else if (type == "brush_prop") {
                            var mappingId = $(ui.draggable).attr('mappingId');
                            var stateId = $(ui.draggable).attr('stateId');

                            if (mappingId) {
                                console.log("state found", stateId);
                                $(ui.helper).remove(); //destroy clone
                                $(ui.draggable).remove(); //remove from list
                                self.trigger("ON_MAPPING_RELATIVE_REMOVED", [mappingId, stateId, id]);

                            }


                            //TODO: create mapping reference removed call
                            /* else if (type == "brush_prop") {
                             var mappingId = $(ui.draggable).attr('mappingId');
                             var stateId = $(ui.draggable).attr('stateId');

                             if (mappingId) {
                                 console.log("state found", stateId);
                                 $(ui.helper).remove(); //destroy clone
                                 $(ui.draggable).remove(); //remove from list
                                 self.trigger("ON_MAPPING_REFERENCE_REMOVED", [mappingId, stateId, id]);

                             }
                             */

                        } else if (type == "action") {
                            var methodId = ID();
                            var targetMethod = $(ui.draggable).attr('name');
                            var defaultArgument = $(ui.draggable).attr('defaultArgument');
                            //data.name = name;
                            self.trigger("ON_METHOD_ADDED", [self.id, null, methodId, targetMethod, defaultArgument]);
                            $(ui.helper).remove(); //destroy clone
                            $(ui.draggable).remove(); //remove from list


                        }


                    }
                });

                //queue for storing behavior changes
                this.behavior_queue = [];
                //timer for running behavior changes
                this.behaviorTimer = false;
                this.currrentState = null;
                this.prevState = null;
                this.id = id;
                var self = this;
                jsPlumb.ready(function() {


                    // setup some defaults for jsPlumb.
                    self.instance = jsPlumb.getInstance({
                        Endpoint: ["Rectangle", {
                            width: 10,
                            height: 10,
                            cssClass: "transendpoint"
                        }],
                        Connector: ["StateMachine", {
                            stub: [40, 100],
                            gap: 0,
                            cornerRadius: 5,
                            alwaysRespectStubs: true
                        }],
                        HoverPaintStyle: {
                            strokeStyle: "#eacc96",
                            lineWidth: 10
                        },
                        ConnectionOverlays: [
                            ["Arrow", {
                                location: 1,
                                id: "arrow",
                                length: 14,
                                foldback: 1,
                            }]

                        ],
                        Container: id
                    });

                    self.instance.registerConnectionType("basic", {
                        anchor: "Continuous",
                        connector: "StateMachine"
                    });

                    self.instance.registerConnectionType("state", {
                        anchor: "Continuous",
                        connector: "StateMachine"
                    });

                    self.instance.bind("connection", function(info) {
                        console.log("state transition made", info);
                        self.trigger("ON_STATE_CONNECTION", [info.connection.getId(), info.sourceId, $(info.source).attr("name"), info.targetId, self.id]);
                    });

                    window.jsp = self.instance;
                    var canvas = document.getElementById("canvas");
                    var windows = jsPlumb.getSelector(".statemachine .w");


                    // bind a double click listener to "canvas"; add new node when this occurs.
                    //jsPlumb.on(canvas, "dblclick", function(e) {
                    //    self.newNode(e.offsetX, e.offsetY);
                    // });


                    $(document).on("mouseup", function(e) {
                        if (block_was_dragged !== null) {

                            var styles = {
                                left: "0px",
                                top: "0px"
                            };
                            block_was_dragged.css(styles);
                            block_was_dragged.removeClass("block-draggable");

                            block_was_dragged = null;
                        }
                    });



                    // suspend drawing and initialise.
                    self.instance.batch(function() {
                        for (var i = 0; i < windows.length; i++) {
                            self.initNode(windows[i], true);
                        }
                    });

                });

            }


            //
            // initialise element as connection targets and source.
            //
            initNode(el, name) {

                // initialise draggable elements.
                this.instance.draggable(el);

                this.instance.makeSource(el, {
                    filter: ".ep",
                    anchor: ["Continuous", {
                        faces: ["left", "right"]
                    }],
                    connectorStyle: {
                        strokeStyle: "#efac1f",
                        lineWidth: 6,
                        outlineColor: "transparent",
                        outlineWidth: 4
                    },
                    connectionType: "basic",
                    extract: {
                        "action": "the-action"
                    },
                    maxConnections: 50,
                    onMaxConnections: function(info, e) {
                        alert("Maximum connections (" + info.maxConnections + ") reached");
                    }
                });

                this.instance.makeTarget(el, {
                    dropOptions: {
                        hoverClass: "dragHover"
                    },
                    anchor: ["Continuous", {
                        faces: ["left", "right"]
                    }],
                    allowLoopback: true
                });


            }

            newNode(x, y, state_data) {
                var self = this;

                console.log(x, y, $("#" + this.id).offset(), this.id, state_data.name);
                if (!state_data) {
                    state_data = {
                        name: "state " + state_counter,
                        id: ID(),
                        mappings: []
                    };
                    state_counter++;
                }
                var html;
                var d = document.createElement("div");
                var id = state_data.id;
                d.className = "w";

                if (state_data.name == "setup") {
                    console.log("state data  is setup");
                    d.className = "setup w";
                    html = startTemplate(state_data);
                } else if (state_data.name == "die") {
                    d.className = "die w";
                    html = startTemplate(state_data);
                } else {
                    html = stateTemplate(state_data);
                }
                d.id = id;

                d.innerHTML = html;



                d.style.left = x + "px";
                d.style.top = y + "px";
                this.instance.getContainer().appendChild(d);
                this.initNode(d, state_data.name);
                if (state_data.mappings) {
                    for (var i = 0; i < state_data.mappings.length; i++) {
                        console.log("mapping to add", state_data.mappings[i]);
                        this.addMapping(d.id, state_data.mappings[i]);
                    }
                }

                console.log("state", $('#' + id));
                $("#" + id).attr("name", state_data.name);
                $('#' + id).droppable({
                    greedy:true,
                    drop: function(event, ui) {
                        var type = $(ui.draggable).attr('type');
                        var name = $(ui.draggable).attr('name');
                        var item_name = $(ui.draggable).html();
                        var mapping_id = ID();
                        var data = {
                            type: type,
                            id: mapping_id
                        };
                        var x = $(ui.draggable).position().left;
                        var y = $(ui.draggable).position().top;
                        console.log("dropped on state", x, y, type);
                        if (type == "brush_prop") {
                            console.log("brush prop dropped on state");
                            var expressionId = ID();
                            self.trigger("ON_MAPPING_ADDED", [mapping_id, name, item_name, type, expressionId, id, self.id]);
                            $(ui.helper).remove(); //destroy clone
                            $(ui.draggable).remove(); //remove from list
                        }

                    }
                });


                return d;
            }

            initializeExpression(expressionId, mappingId) {
                var ex_el = $("#" + mappingId + " #reference_expression .text_entry")[0];

                var expression = new Expression(ex_el, mappingId, expressionId);

                this.expressions[mappingId] = expression;
                expression.addListener("ON_TEXT_CHANGED", function(expression) {
                    this.expressionModified(expression);
                }.bind(this));

                return expression;

            }

            expressionModified(expression) {
                this.trigger("ON_EXPRESSION_TEXT_UPDATE", [this.id, expression.id, expression.getText(), expression.getPropertyList()]);

            }

            addReferenceToExpression(mappingId, referenceType, referenceName, referenceProperties, name, itemName) {
                var expression = this.expressions[mappingId];
                var el = expression.addReference(referenceType, referenceName, referenceProperties, name, itemName);
                this.instance.draggable(el);

                return expression;
            }

            addMapping(target_state, mapping_data) {
                var html = mappingTemplate(mapping_data);
                console.log("target_state = ", target_state, mapping_data);
                $("#" + target_state + " .state .mappings").append(html);

                var target = $("#" + mapping_data.mappingId + " #relative_expression .block");

                console.log("expressionId =", mapping_data.expressionId);

                var expression = this.initializeExpression(mapping_data.expressionId, mapping_data.mappingId);

                this.makeDraggable(target);
                var self = this;

                console.log("target droppable", $('#' + mapping_data.mappingId).find("#reference_expression"));
                $($('#' + mapping_data.mappingId).find("#reference_expression")[0]).droppable({
                    greedy:true,
                    drop: function(event, ui) {
                        var type = $(ui.draggable).attr('type');
                        var name = $(ui.draggable).attr('name');
                        var itemName = $(ui.draggable).html();
                        var relativePropertyName = mapping_data.relativePropertyName;
                        var referenceProperty = name.split("_")[0];
                        var referenceNames = name.split("_");
                        referenceNames.shift();

                        console.log("drop on expression", type);

                        var drop_id = ID();
                        var data = {
                            type: type,
                            id: drop_id,
                            behaviorId: self.id

                        };
                        var referenceName, referenceProperties;
                        if (type == 'sensor_prop') {

                            console.log("sensor prop dropped on mapping", itemName);
                            $(ui.helper).remove(); //destroy clone
                            //$(ui.draggable).remove(); //remove from list
                           referenceName = "stylus";
                            referenceProperties = [name.split("_")[1]];
                            console.log("reference properties =", referenceProperties, name.split("_"));
                            expression = self.addReferenceToExpression(mapping_data.mappingId, type, referenceName, referenceProperties, itemName,name);

                            self.trigger("ON_MAPPING_REFERENCE_UPDATE", [mapping_data.mappingId, self.id, target_state, relativePropertyName, expression.id, expression.getText(), expression.getPropertyList(), "active"]);

                        }

                        if (type == 'generator') {

                            console.log("generator dropped on mapping");
                            $(ui.helper).remove(); //destroy clone
                            //$(ui.draggable).remove(); //remove from list
                            referenceName = null;
                            var  generatorId = drop_id;
                            var generatorType = name;
                            referenceProperties = [generatorId];
                            expression = self.addReferenceToExpression(mapping_data.mappingId, type, referenceName, referenceProperties, generatorId, itemName);

                            self.trigger("ON_GENERATOR_ADDED", [mapping_data.mappingId, generatorId, generatorType, self.id, target_state, itemName ,relativePropertyName, expression.id, expression.getText(),expression.getPropertyList()]);

                        }


                    }
                });



            }

            addTransitionEvent(data) {
                var html = "<div name='"+data.eventName+"'type='transition' class='block transition'>" + data.displayName + "</div>";
                $($('#' + data.id).find(".events .event_block")[0]).prepend(html);

                this.instance.draggable($("#" + data.id + " .events .event_block .block"));


                console.log("update event", $("#" + data.id + " .events .event_block .block"), data);

            }

            addMethod(data) {
                var self = this;
                var argumentList = "";

                for (var arg in data.methodArguments) {
                    if (data.methodArguments.hasOwnProperty(arg)) {
                        argumentList += arg + "|" + data.methodArguments[arg] + ";";
                    }
                }


                argumentList = argumentList.slice(0, -1);
                console.log("data.methodArguments", data.methodArguments, argumentList);

                data.argumentList = argumentList;
                data.defaultArgumentName = data.methodArguments[data.defaultArgument];
                data.defaultArgumentId = data.defaultArgument;
                data.methodTextId = data.methodId + "_text";
                if(data.targetMethod == "spawn"){
                    data.methodNumberId = data.methodId + "_num";
                }

                var html = methodTemplate(data);
                if(data.targetTransition){
                $($('#' + data.targetTransition).find(".methods")[0]).prepend(html);

                }
                else{
                  
                    $('#' + self.id).prepend(html);
             
                }
                this.instance.draggable($("#"+data.methodId));

                console.log("get text box by id", document.getElementById(data.methodTextId), data.methodTextId);
                EditableSelect.createEditableSelect(document.getElementById(data.methodTextId));

                console.log("method added event", $("#" + data.targetTransition + " .methods .block"), data, $('#' + data.methodTextId));
                $('#' + data.methodTextId).change(function() {
                    console.log("change!");
                    self.methodArgumentChanged(self.id, data.transitionId, data.methodId, data.targetMethod);
                });
                 $('#' + data.methodId+"_num").change(function() {
                    console.log("change!");
                    self.methodArgumentChanged(self.id, data.transitionId, data.methodId, data.targetMethod);
                });
            }

            methodArgumentChanged(behaviorId, transitionId, methodId, targetMethod) {
                var methodHTML = $('#'+methodId);
              
                var currentArgument = $('#'+methodId+"_text").val();
                console.log("method argument changed for ", methodId,currentArgument);
                var args = [currentArgument];
                if(targetMethod == "spawn"){
                    args.push($('#'+methodId+"_num").val());
                }

                this.trigger("ON_METHOD_ARGUMENT_CHANGE", [behaviorId, transitionId, methodId, targetMethod, args]);
            }

            updateMapping(data) {

            }

            //TODO: I think remove unbinds events of child elements but need to confirm here
            removeMapping(data) {
                console.log("mapping to remove", $("#" + data.mappingId), data.mappingId);
                var mapping = $("#" + data.mappingId);
                mapping.remove();
            }

            makeDraggable(target) {
                target.mousedown(function(event) {
                    var styles = {
                        position: "absolute"
                    };
                    target.css(styles);
                });
                target.mouseup(function(event) {
                    var styles = {
                        position: "relative"
                    };
                    target.css(styles);
                });

                target.draggable();
                this.instance.draggable(target);

            }

            initializeBehavior(data) {
                var self = this;


                for (var i = 0; i < data.states.length; i++) {
                    this.newNode(data.states[i].x, data.states[i].y, data.states[i]);
                }
                for (var j = 0; j < data.transitions.length; j++) {
                    console.log("connecting ", data.transitions[j].toState, "to", data.transitions[j].fromState);
                    var connection = this.instance.connect({
                        source: data.transitions[j].fromState,
                        target: data.transitions[j].toState,
                        type: "basic"
                    });
                    var connection_id = data.transitions[j].id;
                    console.log("connection id", connection_id, name);

                    self.addOverlayToConnection(data.transitions[j]);

                }



            }

            addOverlayToConnection(transition_data) {
                var self = this;

                var id = transition_data.id;
                var connections = this.instance.getConnections();
                var connection = connections.find(function(c) {
                    return c.getId() == id;
                });
                connection.addOverlay(["Custom", {
                    create: function(component) {
                        var html = transitionTemplate(transition_data);
                        return $(html);
                    },
                    location: 0.5,
                    cssClass: "transition_overlay",

                    id: "transition_" + id
                }]);

                connection.addOverlay(["Custom", {
                    create: function(component) {

                        var html = "<div><div class = 'transition_toggle'>+</div></div>";
                        return $(html);
                    },
                    location: 0.5,
                    id: "toggle_" + id,
                    events: {
                        click: function(customOverlay, originalEvent) {
                            console.log("connection", connection);
                            var all_connections = self.instance.getAllConnections();
                            for (var i = 0; i < all_connections.length; i++) {
                                if (connection != all_connections[i]) {
                                    var overlays = all_connections[i].getOverlays();
                                    console.log("overlays =", overlays);
                                    for (var o in overlays) {
                                        if (overlays.hasOwnProperty(o)) {
                                            console.log(o);
                                            if (o.split("_")[0] == "transition") {
                                                overlays[o].hide();
                                            }
                                            if (o.split("_")[0] == "toggle") {
                                                overlays[o].show();
                                            }
                                        }
                                    }

                                }
                            }
                            connection.getOverlay("transition_" + id).show();
                            connection.getOverlay("toggle_" + id).hide();

                        }
                    }
                }]);

                console.log("droppable target:", $('#' + id).find(".events .event_block"));
                console.log("transition_data", transition_data);

                $($('#' + id).find(".events .event_block")[0]).droppable({
                    greedy:true,
                    drop: function(event, ui) {
                        console.log("drop_event_data", transition_data);

                        var eventName = $(ui.draggable).attr('name');
                        var displayName = $(ui.draggable).html();
                        var type = $(ui.draggable).attr('type');
                        var sourceId = transition_data.fromStateId;
                        var targetId = transition_data.toStateId;
                        var sourceName = transition_data.name;

                        console.log("type=", type);

                        if (type == 'transition') {

                            //data.name = name;
                            self.trigger("ON_TRANSITION_EVENT_ADDED", [id, eventName, displayName, sourceId, sourceName, targetId, self.id]);
                            $(ui.helper).remove(); //destroy clone
                            $(ui.draggable).remove(); //remove from list

                        }
                    }
                });

                $($('#' + id).find(".methods")[0]).droppable({
                   greedy: true,
                    drop: function(event, ui) {
                        console.log("drop method");
                        var type = $(ui.draggable).attr('type');
                        var behaviorId = self.id;
                        var transitionId = id;
                        var methodId = ID();
                        var targetMethod = $(ui.draggable).attr('name');
                        console.log("type=", type);

                        if (type == 'action') {

                            //data.name = name;
                            self.trigger("ON_METHOD_ADDED", [behaviorId, transitionId, methodId, targetMethod, null]);
                            $(ui.helper).remove(); //destroy clone
                            $(ui.draggable).remove(); //remove from list

                        }
                    }
                });

                connection.getOverlay("transition_" + id).hide();



            }

            behaviorChange(behaviorEvent, data) {
                var self = this;
                this.behavior_queue.push({
                    event: behaviorEvent,
                    data: data
                });
                if (!this.behaviorTimer) {
                    this.behaviorTimer = setInterval(function() {
                        self.animateBehaviorChange(self);
                    }, 800);
                }

            }

            animateBehaviorChange(self) {
                if (self.prevState) {
                    $("#" + self.prevState).removeClass("active");
                }
                var change = self.behavior_queue.shift();
                // if(change.event == "state"){
                var classes = $("#" + change.data.id).attr('class');
                classes = "active" + ' ' + classes;
                $("#" + change.data.id).attr('class', classes);
                self.currrentState = change.data.id;

                // }



                self.prevState = self.currrentState;

                //}
                console.log("change = ", change);
                if (self.behavior_queue.length < 1) {
                    clearInterval(self.behaviorTimer);
                    self.behaviorTimer = false;
                }
            }

        };



        return ChartView;
    });