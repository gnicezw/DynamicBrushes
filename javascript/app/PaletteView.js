//PaletteView.js
'use strict';
define(["jquery", "jquery-ui", "handlebars", "hbs!app/templates/palette", 'app/id'],

    function($, jqueryui, Handlebars, paletteTemplate, ID) {

        var live_btn, recordings_btn, datasets_btn, generator_btn;

        var PaletteView = class {

            constructor(model, element) {
                this.el = $(element);
                this.model = model;
                var self = this;
                self.updateSelectedPalette(model.data[model.selected]);

                live_btn = this.el.find('#live_input');
                recordings_btn = this.el.find('#recordings');
                datasets_btn = this.el.find('#datasets');
                generator_btn = this.el.find('#generators');
                this.btn_list = [live_btn, recordings_btn, datasets_btn, generator_btn];

                /* old buttons
                // states_btn = this.el.find('#states');
                generator_btn = this.el.find('#generators');
                brush_properties_btn = this.el.find('#brush_properties');
                sensor_properties_btn = this.el.find('#sensor_properties');
                ui_properties_btn = this.el.find('#ui_properties');
                brush_actions_btn = this.el.find('#brush_actions');
                transitions_btn = this.el.find('#transitions');
                datasets_btn = this.el.find('#datasets');
                this.btn_list = [states_btn, generator_btn, datasets_btn, brush_properties_btn, sensor_properties_btn, ui_properties_btn, brush_actions_btn, transitions_btn];
                */

                this.el.droppable({
                    drop: function(event, ui) {
                        console.log("dropped on canvas", ui);
                        $(ui.helper).remove(); //destroy clone
                        $(ui.draggable).remove(); //remove from list
                    }
                });

                this.generatePalette();

               this.model.addListener("ON_DATA_READY",function(data) {
                    this.updateSelectedPalette(data);
                }.bind(this));
            }


            generatePalette(){
                console.log("generate palette called");
                var self = this;
                for (var i = 0; i < this.btn_list.length; i++) {
                   this.btn_list[i].click(function(event) {
                        for (var j = 0; j < self.btn_list.length; j++) {
                            self.btn_list[j].removeClass("selected");
                        }
                        self.model.selected = $(event.target).attr('id');
                        $(event.target).addClass("selected");
                        console.log("model selected",self.model.selected,self.model.data);
                        self.updateSelectedPalette(self.model.data[self.model.selected]);
                    });
                }
            }

            updateSelectedPalette(data) {
                var html = paletteTemplate(data);
                this.el.find('#selected_palette').html(html);
                this.el.find(".palette").mousedown(function(event) {
                    if (!$(event.target).hasClass("tooltiptext")) {
                        var clone = $("<div id=" + $(event.target).attr('id') + "></div>");


                        clone.html($(event.target).attr('display_name'));
                        clone.attr("type", $(event.target).attr('type'));
                        clone.attr("name", $(event.target).attr('name'));
                        clone.attr("class", $(event.target).attr('class'));

                        clone.addClass("drag-n-drop");
                        console.log("cloning", clone);

                        clone.draggable();
                        clone.offset($(event.target).offset());
                        clone.prependTo("body").css('position', 'absolute');
                        clone.trigger(event);
                    }


                });
            }


        };

        return PaletteView;

    });