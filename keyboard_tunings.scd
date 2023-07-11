// TO RUN

// place cursor on line 18 and hit cmd + enter (ctrl + enter on windows)

// to connect hardware, enter correct midi channels in text boxes and then click "connect".

// need to press enter after changing a tuning for it to update the value of the text field.
// "update tuning" send this value to the keyboard's current tuning.
// "reset tuning" reverts to the values in the data file
// "save to file" replaces the old data file with a new version.

/// TO DO
// fix text boxes so you dont need to hit enter when updating values
// add in sampler - to retune samples to correct pitches: if you know hz of sample e.g. 440 and you want to retune to 442.5 then 442.5/440 = 1.000568534... 1.000568534 is the RATE arg for the playbuf that will play the sample.
// organ/harmonium sounds
// 1/3 tone view highlighting

(
s.waitForBoot({

	// vars for keyboard drawing
	var white_keys = [0,2,3,5,7,8,10];
	var black_keys = [1,4,6,9,11];
	var bk_placement = [0,2,3,5,6];
	var key_count = 0;

	q = ();
	q.data = ();
	q.keyb_channel = 0;
	q.pedal_channel = 6;
	q.headers = [];
	q.keyboards = ();
	q.keyboards.names = []; //, "JI Euharmonic Organ", "JI Harmonical", "MT Carrillo Piano"];
	q.keyboards.info = ();
	q.sounds = ();
	q.sounds.names = ["Piano", "Organ", "Harmonium", "Sine", "Triangle"];
	q.guis = ();
	q.guis.views = ();
	q.images = ["images/image1.png".resolveRelative,"images/nifty.thirdtone.png".resolveRelative, "images/nifty.tonnetz.png".resolveRelative];
	q.midi = ();
	q.midi.notes = Array.newClear(128);    // array has one slot per possible MIDI note
	q.operators = ();
	q.operators.kboard_select = 0;
	q.operators.sound_select = 0;
	q.operators.tuning_select = 0;
	q.operators.pedal = Array.fill(8, false);
	q.funcs = ();
	q.active_key = false!88;
	q.keyboard_drawing = [];
	q.samps = ();
	q.samps.piano = SoundFile.collectIntoBuffers("samples/21055__samulis__vsco-2-ce-keys-upright-piano/*".resolveRelative);
	q.samps.organ = SoundFile.collectIntoBuffers("samples/21034__samulis__vsco-2-ce-keys-organ-loud/*".resolveRelative);
	q.samps.harmonium = SoundFile.collectIntoBuffers("samples/29512__cabled_mess__harmonium/*".resolveRelative);
	q.sampnotes = ();
	q.sampnotes.piano = ["A0", "C1", "E1", "A1", "C2", "E2", "A2", "C3", "E3", "A3", "C4", "E4", "A4", "C5", "E5", "A5", "C6", "E6", "A6", "C7", "E7", "A7", "C8"];
	q.sampnotes.organ = ["C2", "F2", "A2", "C3", "F3", "A3", "C4", "F4", "A4", "C5", "F5", "A5", "C6", "F6", "A6", "C7"];
	q.sampnotes.harmonium = ["C2", "E2", "A2", "C3", "E3", "A3", "C4, ""E4", "A4", "C5"];
	q.tonn = ();
	q.tonn.data = CSVFileReader.read("./tonnetz.readable.csv".resolveRelative);
	q.tonn.x = 460;
	q.tonn.y = 270;
	q.tonn.active = false;

	q.path = "data/".resolveRelative;
	q.pathname = PathName.new(q.path).files;
	q.files = q.pathname.collect{|file| file.fullPath;};

	q.data.fromFile = q.files.collect{|file|
		CSVFileReader.read(file);
	};


	// q.funcs.gen_data()
	q.funcs.gen_data = {

		q.keyboards.info(); // trash .info if there's already data there and generate from file.
		q.keyboards.names = []; // trash keyboard names and replace from file.

		q.data.new = q.data.fromFile.deepCopy;

		q.data.new.collect{|item, i|
			q.headers = q.headers ++ [item[0..3]]; // save the top lines to an array for later.
		};

		q.data.new.do{|item, i|
			q.keyboards.names = q.keyboards.names.add(item[0][0]++" "++item[0][1]);
		};

		q.data.keynames = q.data.new[0].flop[1][4..];// this will always be the same;

		q.keyboards.names.collect{|keyb, i|

			var info = q.data.new[i][0].select{|item| item!=""};
			var alt_tuning = q.data.new[i][1].select{|item| item!=""};
			var tunings = [];
			var t_names = [];

			info[3].postln;

			if ((info[3].asInteger) > 0, { // if there's alternate tunings...
				tunings = (info[3].asInteger+1).collect{|val, j|
					var col = (val.asInteger*2)+2;
					var tun = q.data.new[i].flop[col][4..];
					val.postln;
					tun = tun.collect{|hz| hz.asFloat};
					tun;
				};
				t_names = (info[3].asInteger+1).collect{|val, j| // something wrong here...
					var col = (val.asInteger*2)+3;
					var tnam = q.data.new[i].flop[col][4..];
					val.postln;
					tnam;
				};
			}, { // if no alternate tunings...
				tunings = [q.data.new[i].flop[2][4..]];
				t_names = [q.data.new[i].flop[3][4..]]
			});

			tunings.postln;

			q.keyboards.info.put(keyb.asSymbol, [q.data.new[i][0].select{|item| item!=""}]);
			q.keyboards.info.at(keyb.asSymbol).add("tunings" -> tunings);
			q.keyboards.info.at(keyb.asSymbol).add("t_names" -> t_names);
			q.keyboards.info.at(keyb.asSymbol).add("alt_names" -> alt_tuning);
		};
	};

	q.funcs.gen_data(); // collate data from spreadsheets
	q.current_tuning = q.keyboards.info.at(q.keyboards.names[0].asSymbol)[1].value[0].asFloat;

	q.et_data = ();
	q.et_data.hz = q.keyboards.info.at(q.keyboards.names[0].asSymbol)[1].value[0];
	q.et_data.note_names = q.keyboards.info.at(q.keyboards.names[0].asSymbol)[2].value[0];

	q.samp_exists = q.et_data.note_names.collect{|item i|
		var ptest, otest, htest;
		ptest = q.sampnotes.piano.indexOfEqual(item);
		otest = q.sampnotes.organ.indexOfEqual(item);
		htest = q.sampnotes.harmonium.indexOfEqual(item);

		[item, q.et_data.hz[i], ptest, otest, htest]
	};

	q.funcs.nearest_samp = {|func, instr, freq|
		var diffs, result, chosen;
		var ind = (instr+2).asInt;
		var exists = q.samp_exists.select{|item| item[ind].class == Integer };
		exists = exists.collect{|item| item[1].asFloat;};
		diffs = (freq - exists).abs;
		result = diffs.indexOfEqual(diffs.minItem);
		chosen = q.samp_exists.select{|item| item[1].asFloat == exists[result] }.flatten.postln;
		q.curr_samp_index = chosen[ind];
		q.curr_samp_freq = chosen[1];
	};

	q.funcs.play_samp = {|func, instr, freq, amp|
		var instrument = q.sounds.names[instr].toLower.asSymbol;
		q.funcs.nearest_samp(instr, freq);
		Synth(\buf, [
			\bufnum, q.samps.at(instrument)[q.curr_samp_index].bufnum,
			\sampfreq, q.curr_samp_freq,
			\retunefreq, freq,
			\amp, amp,
		])
	};

	q.funcs.connect_midi = {
		/*var inPorts = 2;
		var outPorts = 2;
		MIDIClient.init(inPorts,outPorts);    // explicitly intialize the client
		inPorts.do({ arg i;
		MIDIIn.connect(i, MIDIClient.sources.at(i));
		});*/

		MIDIClient.init;
		MIDIIn.connectAll;

		q.midi.noteon_k = MIDIFunc.noteOn({ |vel, num, chan, src|
			var key = num-21;
			("keyboard"++[chan,num,vel/127]).postln;
			q.active_key[key] = true;
			// find the note name of current key
			if ( q.tonn.active, { q.funcs.gen_tonnpos(key) });
			{ q.funcs.gen_image(q.operators.kboard_select); w.refresh}.defer; // 0 needs to be current keyboard.
			q.midi.notes[key] = case
			{ q.operators.sound_select == 0 } {
				Synth(\default, [\freq, q.current_tuning[key], \amp, vel * 0.00315]); // PIANO synth
				// q.funcs.play_samp(0, q.current_tuning[key], vel * 0.00315); // PIANO SAMPLES
			}
			{ q.operators.sound_select == 1 } {
				q.funcs.play_samp(1, q.current_tuning[key], vel * 0.00315); // ORGAN SAMPLES
			}
			//{ Synth(\default, [\freq, q.current_tuning[key], \amp, vel * 0.00315]); }// ORGAN
			{ q.operators.sound_select == 2 } {
				q.funcs.play_samp(2, q.current_tuning[key], vel * 0.00315); // HARMONIUM SAMPLES
			}
			//Synth(\default, [\freq, q.current_tuning[key], \amp, vel * 0.00315]); } // HARMONIUM
			{ q.operators.sound_select == 3 } { Synth(\sn, [\freq, q.current_tuning[key], \sustain, 1, \amp, vel * 0.00315]); } // SINE
			{ q.operators.sound_select == 4 } { Synth(\sw, [\freq, q.current_tuning[key], \sustain, 1, \amp, vel * 0.00315]); }; // SAW
			q.midi.notes[key].postln;
		}, chan: q.keyb_channel);

		q.midi.noteoff_k = MIDIFunc.noteOff({ |veloc, num, chan, src|
			var key = num-21;
			q.active_key[key] = false;
			{ q.funcs.gen_image(q.operators.kboard_select); w.refresh}.defer;
			"noteoff".postln;
			q.midi.notes[key].release(1); //(releaseTime: 0.1);
		}, chan: q.keyb_channel);

		q.midi.noteon_p = MIDIFunc.noteOn({arg vel, num, chan;
			("pedal"++[chan,num]).postln;
			if (num < q.guis.t_select.items.size, {
				if ( q.operators.pedal[num-1] == false, {
					q.operators.pedal = Array.fill(8, false); // cancel any current true settings
					q.operators.pedal[num-1] = true; // set current pedal to true
					{ q.guis.t_select.valueAction = num; }.defer;
					q.operators.pedal.postln;
				}, {
					q.operators.pedal = Array.fill(8, false); // cancel any current true settings
					{ q.guis.t_select.valueAction = 0; }.defer; // set back to standard tuning.
					q.operators.pedal.postln;
				} );
			});
			// x = Pbind(\freq, Pseq([num.midicps], 1), \amp, vel / 127).play
		}, chan: q.pedal_channel)
	};

	q.funcs.writefile = {|func, keyb|

		var filepath;
		var selected_keyboard = q.keyboards.names[keyb];
		var heads = q.headers[keyb];
		var hz_vals = q.keyboards.info.at(selected_keyboard.asSymbol)[1].value;
		var tn_vals = q.keyboards.info.at(selected_keyboard.asSymbol)[2].value;

		q.new_arr = hz_vals.collect{|item, i|
			[item, tn_vals[i]]
		}.flatten;
		q.new_arr = [(1..88)] ++ [q.data.keynames] ++ q.new_arr;
		q.new_arr = q.new_arr.flop;
		q.new_arr.size.postln;
		q.new_arr = heads ++ q.new_arr;
		q.new_arr.postln;

		// to write
		/*		CSVFileWriter.use("./csv.csv".resolveRelative, "w", { |file|
		q.new_arr.do({ |line| file.writeLine(line) })
		}); // requires FileLog Quark
		*/

		filepath = q.path ++ q.files[keyb].basename;

		File.use(filepath, "w", { |file|
			q.new_arr.do({ |line|
				line.do({ |it,i|
					file.write( it.asString );
					if ( i < ( line.size - 1) ){
						file.write( $, );
					};
				});
				file.write("\n");
			})
		});
	};

	// GRAPHICS

	q.funcs.which_note = {|func, key|
		var notes, note_name;
		note_name = q.keyboards.info.at(q.keyboards.names[2].asSymbol)[2].value[q.operators.tuning_select][key];
		"note_name".postln;
		note_name.postln;
		notes = q.tonn.data.select{|item| item[0].asString == note_name.asString; };
		"notes".postln;
		notes.postln;
	};

	q.funcs.gen_tonnpos = {|func, key| // generate tonnetz highlighting dimensions // DOT PLACEMENT IS WRONG - fix it!
		var x_ind, y_ind;
		var diagram_x = 460;
		var diagram_y = 270;
		var circle_size = 25;
		var x_spacing = 41; // between items in row
		var y_spacing = 21; // between items in column
		var row_offset = [120, 100, 80, 60, 40, 20, 0];
		var x_offset = 9; // need to check
		var y_offset = 5; // need to check
		// x spacing =  41; y spacing... 20, row x offset = 20;
		var key_data = q.funcs.which_note(key);

		x_ind = key_data[0][1].asInteger;
		y_ind = key_data[0][2].asInteger;

		q.tonn.x = diagram_x + x_offset + row_offset[y_ind] + (x_spacing * (x_ind));
		q.tonn.y = diagram_y + y_offset + (y_spacing * (y_ind));

		q.tonn.x.postln; q.tonn.y.postln;
	};

	// generate keyboard drawing dimensions
	8.do{|octave|
		12.do{|num|
			var x_dimension_w = 14;
			var y_dimension_w = 60;
			var x_dimension_b = ((x_dimension_w/3)*2 + (x_dimension_w*0.2));
			var y_dimension_b = (y_dimension_w/3)*2;
			var b_key_offset = ((x_dimension_w/3)*2)-(x_dimension_w*0.1);
			var x_pos = 5;
			var y_pos = 650;
			var x_margin = 140;
			var	x_key = 0;
			var x_block = x_dimension_w * 1.2;
			var key_fill = false;
			var x_dim, y_dim;
			if ( black_keys.includes(num),
				{
					x_dim = x_dimension_b; y_dim = y_dimension_b;
					x_key = ((bk_placement[black_keys.indexOf(num)]+1+(octave*white_keys.size)));
					x_pos = ((x_block * x_key) + x_margin)-b_key_offset+x_block;
					key_fill = true;
				},
				{
					x_key = white_keys.indexOf(num) + (octave*white_keys.size);
					x_dim = x_dimension_w; y_dim = y_dimension_w;
					x_pos = ((x_key+1)*(x_block)+x_margin);
					key_fill = false;

				}

			);
			if (key_count < 88, {
				q.keyboard_drawing = q.keyboard_drawing.add([x_pos, y_pos, x_dim, y_dim, key_fill]);
			});
			key_count = key_count + 1;
		};
	};

	// SOUNDS

	SynthDef(\buf, { |out=0,amp=0.1,sustain=0.01,rel = 8,sampfreq=440, retunefreq=440, bufnum =0, gate=1|
		var snd, env, ctrl;
		var playrate;
		playrate = retunefreq/sampfreq;
		snd = PlayBuf.ar(2, bufnum, BufRateScale.kr(bufnum)*playrate, doneAction: Done.freeSelf);
		snd = Pan2.ar(snd);
		env = EnvGen.kr(Env.new([0, 1, 1, 0], [0.01, sustain, rel]), gate, doneAction: 2);
		// env = EnvGen.ar(Env.linen(0.01,sustain,rel),doneAction:2);
		OffsetOut.ar(out, snd * env * amp);
	}).add;

	SynthDef(\sn, { |out=0,amp=0.1,sustain=0.01,freq=440, dist=1|
		var snd, env, ctrl;
		snd = SinOsc.ar(freq, 0.5pi, dist).tanh;
		snd = Pan2.ar(snd);
		env = EnvGen.ar(Env.perc(0.01,sustain),doneAction:2);
		OffsetOut.ar(out, snd * env * amp);
	}).add;

	SynthDef(\sw, { |out=0,amp=0.1,sustain=0.01,freq=440,dist=1|
		var snd, env, ctrl;
		snd = Saw.ar(freq, dist).tanh;
		snd = Pan2.ar(snd);
		env = EnvGen.ar(Env.perc(0.01,sustain),doneAction:2);
		OffsetOut.ar(out, snd * env * amp);
	}).add;



	/// GUI below here
	w = Window.new(bounds: 1200@750).front;
	// w.view.decorator = FlowLayout(w.view.bounds);

	q.guis.views.setup = CompositeView(w, Rect(550, 0, 600, 200));
	q.guis.views.setup.decorator = FlowLayout(q.guis.views.setup.bounds, 5@5, 10@5);

	EZText(q.guis.views.setup, 160@30, "Keyboard Channel:", initVal: q.keyb_channel, labelWidth: 125);
	EZText(q.guis.views.setup, 160@30, "Pedal Channel:", initVal: q.pedal_channel, labelWidth: 125);

	q.guis.connect = Button(q.guis.views.setup, Rect(0, 20, 135, 30))
	.states_([
		["Connect", Color.black, Color.red],
		["MIDI Connected", Color.white, Color.black]
	])
	.action_({ arg butt;
		butt.value.postln;

		q.funcs.connect_midi();
		if (MIDIClient.sources.notNil, { q.guis.connect.value = 1 }, { q.guis.connect.value = 0 } )
	});

	q.guis.views.main = CompositeView(w, Rect(50, 0, 500, 500));
	q.guis.views.main.decorator = FlowLayout(q.guis.views.main.bounds);

	q.guis.k_select = EZPopUpMenu.new(q.guis.views.main, 300@30, "Select Keyboard: ", labelWidth: 160);

	q.keyboards.names.do{|keyb, i|
		// q.guis.k_select.addItem(\item0, { |a| ("this is item 0 of " ++ a).postln });
		q.guis.k_select.addItem(keyb, {|a|
			(keyb++" selected").postln;
			q.operators.kboard_select = i;
			if ( q.operators.kboard_select == 2, { q.tonn.active = true }, { q.tonn.active = false });
			q.funcs.gen_t_select(i);
			q.funcs.gen_t_edit(i, 0);
			q.funcs.gen_image(i);
		});
	};
	q.guis.k_select.value = 0;

	q.guis.o_select = EZPopUpMenu.new(q.guis.views.main, 300@30, "Select Output Sound: ", labelWidth: 160);
	q.sounds.names.do{|snd, i|
		// q.guis.k_select.addItem(\item0, { |a| ("this is item 0 of " ++ a).postln });
		q.guis.o_select.addItem(snd, {|a|
			("Output sound "++snd.toUpper++" selected").postln;
			q.operators.sound_select = i;
		});
	};
	q.guis.o_select.value = 0;
	q.guis.views.main.decorator.nextLine;

	q.guis.views.tuningselect = CompositeView(w, Rect(20, 80, 450, 300));
	q.guis.views.tuningselect.decorator = FlowLayout(q.guis.views.tuningselect.bounds);

	q.guis.t_select = EZPopUpMenu.new(q.guis.views.tuningselect, 390@30, "Select Tuning: ", labelWidth: 160);

	q.funcs.gen_t_select = {|func, num|

		var selected_keyboard = q.keyboards.names[num.asInteger];
		var keyboard_data = q.keyboards.info.at(selected_keyboard.asSymbol);
		var num_tunings = keyboard_data[0][3].asInteger;
		var alt_tunings = q.keyboards.info.at(q.keyboards.names[num].asSymbol)[3].value[1..];

		q.guis.t_select.items.size.do{|i|
			q.guis.t_select.removeItemAt(0);
		};

		q.guis.t_select.addItem("Standard Tuning", { |a| "Standard Tuning selected".postln; q.funcs.gen_t_edit(num, 0); });

		if (num_tunings > 0, {
			num_tunings.do{|tun, i|
				alt_tunings[i].postln;i.postln;
				q.guis.t_select.addItem(alt_tunings[i], {|a|
					(alt_tunings[i].toUpper++" selected").postln;
					q.operators.tuning_select = i;
					q.funcs.gen_t_edit(num, (i+1)); // generate the table
				});
			};
		});


	};

	q.funcs.gen_t_select(0);

	q.guis.views.main.decorator.nextLine;

	q.guis.t_submit = Button(q.guis.views.tuningselect, Rect(0, 0, 135, 30))
	.states_([
		["Update Tuning", Color.black, Color.green]
	])
	.action_({ arg butt;
		var keyb = q.keyboards.names[q.operators.kboard_select];
		butt.value.postln;

		88.do{|num|
			// update the data
			q.keyboards.info.at(keyb.asSymbol)[1].value[q.operators.tuning_select].put(num, q.guis.t_edit.at(("tuning"++num).asSymbol).value.asFloat);
			q.keyboards.info.at(keyb.asSymbol)[2].value[q.operators.tuning_select].put(num, q.guis.t_edit.at(("notation"++num).asSymbol).value);
		};
		// switch current tuning to the edited version
		q.current_tuning = q.keyboards.info.at(keyb.asSymbol)[1].value[q.operators.tuning_select];
	});

	q.guis.t_reset = Button(q.guis.views.tuningselect, Rect(0, 0, 135, 30))
	.states_([
		["Reset Tuning", Color.black, Color.red]
	])
	.action_({ arg butt;
		butt.value.postln;
		q.funcs.gen_data();
		q.funcs.gen_t_edit(q.operators.kboard_select,q.operators.tuning_select);
	});

	q.guis.t_save = Button(q.guis.views.tuningselect, Rect(0, 0, 135, 30))
	.states_([
		["Save to File", Color.white, Color.blue]
	])
	.action_({ arg butt;
		"writing file".postln;
		q.funcs.writefile(q.operators.kboard_select); // write the data to a new file
	});

	q.guis.views.scroll = ScrollView(w, Rect(20, 160, 430, 470)).hasBorder_(true);
	q.guis.views.scroll.hasHorizontalScroller = false;
	q.guis.views.scroll.autohidesScrollers = false;
	q.guis.views.tuning = CompositeView(q.guis.views.scroll, Rect(0, 0, 430, 2150));
	q.guis.views.tuning.decorator = FlowLayout(q.guis.views.tuning.bounds);

	q.guis.views.tuning.decorator.nextLine;

	q.funcs.gen_t_edit = {|func, keyb, alt|

		var selected_keyboard = q.keyboards.names[keyb];
		var hz_vals = q.keyboards.info.at(selected_keyboard.asSymbol)[1].value;
		var tn_vals = q.keyboards.info.at(selected_keyboard.asSymbol)[2].value;

		q.current_tuning = hz_vals[alt].asFloat;
		// var keyboard_data = q.keyboards.info.at(selected_keyboard.asSymbol);
		// var num_tunings = keyboard_data[0][3].asInteger;
		//var alt_tunings = q.keyboards.info.at(q.keyboards.names[num].asSymbol)[3].value[1..];

		// q.guis.t_edit.collect{|item| item.remove; "item gone".postln; };
		q.guis.t_edit = ();
		q.guis.views.tuning.remove;

		q.guis.views.tuning = CompositeView(q.guis.views.scroll, Rect(0, 0, 430, 2150));
		q.guis.views.tuning.decorator = FlowLayout(q.guis.views.tuning.bounds);

		88.do{|num, i|

			// var g.textField.keyUpAction = { arg field; field.value.postln; }
			q.guis.t_edit.put(("notename"++i).asSymbol, StaticText(q.guis.views.tuning, 80@20).string_("Key "++(i+1)++": "++q.data.keynames[i])); // this is always the same
			q.guis.t_edit.put(("tuning"++i).asSymbol, EZText(q.guis.views.tuning, 160@20, "Frequency (Hz) ", initVal: hz_vals[alt][i].asFloat, labelWidth: 100));
			q.guis.t_edit.put(("notation"++i).asSymbol, EZText(q.guis.views.tuning, 160@20, "Tuning Name ", initVal: tn_vals[alt][i], labelWidth: 100));
			q.guis.views.tuning.decorator.nextLine;
		};

	};
	q.funcs.gen_t_edit(0,0);

	q.funcs.gen_image = {|func, keyb|

		var selected_keyboard = q.keyboards.names[keyb];

		if ( q.guis.image.notNil, { q.guis.image.free });

		if (keyb > 0, {
			q.guis.image = Image.new(q.images[keyb], 100);
			q.guis.image.scalesWhenResized_(true);
			q.guis.image.setSize(700, (700 / (q.guis.image.width / q.guis.image.height)).asInteger);
		} );

		// keyboard view
		w.drawFunc = {
			if ( q.guis.image.notNil, { q.guis.image.drawAtPoint(460@270); }); // draw image.
			Pen.use{

				q.keyboard_drawing.collect{|vals, i|
					Pen.color = Color.blue;
					Pen.addRect(
						Rect(vals[0], vals[1], vals[2], vals[3])
					);
					if (vals[4], {
						Pen.perform(\fill);
					}, { Pen.perform(\stroke) }
					);
				};


				q.active_key.collect{|val, i|
					if ( val, {
						var active = q.keyboard_drawing[i];
						if ( q.tonn.active, {
							Color.new(1, 0, 0, 0.3).setFill;
							// Pen.addOval(Rect(460,270,25,25));
							Pen.addOval(Rect(q.tonn.x,q.tonn.y,25,25));
							Pen.fill;
						});
						// var note_name = q.current_tuning //// find the key name here...
						Pen.color = Color.red;
						Pen.addRect( Rect(active[0], active[1], active[2], active[3]));
						Pen.perform(\fill);
					});
				}

			};
		};
		w.refresh;
	};
	q.funcs.gen_image(0);
	// keyboard view end
	w.onClose_({ q.guis.image.free; }); // free the image when the window is closed

})
);


(
w = Window.new(bounds: 1200@750).front;
// w.view.decorator = FlowLayout(w.view.bounds);

q.guis.views.setup = CompositeView(w, Rect(550, 0, 600, 200));
q.guis.views.setup.decorator = FlowLayout(q.guis.views.setup.bounds, 5@5, 10@5);

EZText(q.guis.views.setup, 160@30, "Keyboard Channel:", initVal: q.keyb_channel, labelWidth: 125);
EZText(q.guis.views.setup, 160@30, "Pedal Channel:", initVal: q.pedal_channel, labelWidth: 125);

q.guis.connect = Button(q.guis.views.setup, Rect(0, 20, 135, 30))
.states_([
	["Connect", Color.black, Color.red],
	["MIDI Connected", Color.white, Color.black]
])
.action_({ arg butt;
	butt.value.postln;

	q.funcs.connect_midi();
	if (MIDIClient.sources.notNil, { q.guis.connect.value = 1 }, { q.guis.connect.value = 0 } )
});

q.guis.views.main = CompositeView(w, Rect(50, 0, 500, 500));
q.guis.views.main.decorator = FlowLayout(q.guis.views.main.bounds);

q.guis.k_select = EZPopUpMenu.new(q.guis.views.main, 300@30, "Select Keyboard: ", labelWidth: 160);

q.keyboards.names.do{|keyb, i|
	// q.guis.k_select.addItem(\item0, { |a| ("this is item 0 of " ++ a).postln });
	q.guis.k_select.addItem(keyb, {|a|
		(keyb++" selected").postln;
		q.operators.kboard_select = i;
		if ( q.operators.kboard_select == 2, { q.tonn.active = true }, { q.tonn.active = false });
		q.funcs.gen_t_select(i);
		q.funcs.gen_t_edit(i, 0);
		q.funcs.gen_image(i);
	});
};
q.guis.k_select.value = 0;

q.guis.o_select = EZPopUpMenu.new(q.guis.views.main, 300@30, "Select Output Sound: ", labelWidth: 160);
q.sounds.names.do{|snd, i|
	// q.guis.k_select.addItem(\item0, { |a| ("this is item 0 of " ++ a).postln });
	q.guis.o_select.addItem(snd, {|a|
		("Output sound "++snd.toUpper++" selected").postln;
		q.operators.sound_select = i;
	});
};
q.guis.o_select.value = 0;
q.guis.views.main.decorator.nextLine;

q.guis.views.tuningselect = CompositeView(w, Rect(20, 80, 450, 300));
q.guis.views.tuningselect.decorator = FlowLayout(q.guis.views.tuningselect.bounds);

q.guis.t_select = EZPopUpMenu.new(q.guis.views.tuningselect, 390@30, "Select Tuning: ", labelWidth: 160);

q.funcs.gen_t_select = {|func, num|

	var selected_keyboard = q.keyboards.names[num.asInteger];
	var keyboard_data = q.keyboards.info.at(selected_keyboard.asSymbol);
	var num_tunings = keyboard_data[0][3].asInteger;
	var alt_tunings = q.keyboards.info.at(q.keyboards.names[num].asSymbol)[3].value[1..];

	q.guis.t_select.items.size.do{|i|
		q.guis.t_select.removeItemAt(0);
	};

	q.guis.t_select.addItem("Standard Tuning", { |a| "Standard Tuning selected".postln; q.funcs.gen_t_edit(num, 0); });

	if (num_tunings > 0, {
		num_tunings.do{|tun, i|
			alt_tunings[i].postln;i.postln;
			q.guis.t_select.addItem(alt_tunings[i], {|a|
				(alt_tunings[i].toUpper++" selected").postln;
				q.operators.tuning_select = i;
				q.funcs.gen_t_edit(num, (i+1)); // generate the table
			});
		};
	});


};
// q.keyboards.info.at(q.keyboards.names[2].asSymbol)[0][3]

q.funcs.gen_t_select(0);

q.guis.views.main.decorator.nextLine;

q.guis.t_submit = Button(q.guis.views.tuningselect, Rect(0, 0, 135, 30))
.states_([
	["Update Tuning", Color.black, Color.green]
])
.action_({ arg butt;
	var keyb = q.keyboards.names[q.operators.kboard_select];
	var tuning = q.keyboards.info.at(keyb.asSymbol)[1].value[q.operators.tuning_select].asFloat;
	var notation = q.keyboards.info.at(keyb.asSymbol)[2].value[q.operators.tuning_select];

	butt.value.postln;

	88.do{|num|
		// update the data
		tuning[num].postln;

		tuning[num] = q.guis.t_edit.at(("tuning"++num).asSymbol).value.asFloat;
		notation[num] = q.guis.t_edit.at(("notation"++num).asSymbol).value;

		tuning[num].postln;
	};
	// switch current tuning to the edited version
	q.current_tuning = tuning;
});

q.guis.t_reset = Button(q.guis.views.tuningselect, Rect(0, 0, 135, 30))
.states_([
	["Reset Tuning", Color.black, Color.red]
])
.action_({ arg butt;
	butt.value.postln;
	q.funcs.gen_data();
});

q.guis.t_save = Button(q.guis.views.tuningselect, Rect(0, 0, 135, 30))
.states_([
	["Save to File", Color.white, Color.blue]
])
.action_({ arg butt;
	"writing file".postln;
	q.funcs.writefile(q.operators.kboard_select); // write the data to a new file
});

q.guis.views.scroll = ScrollView(w, Rect(20, 160, 430, 470)).hasBorder_(true);
q.guis.views.scroll.hasHorizontalScroller = false;
q.guis.views.scroll.autohidesScrollers = false;
q.guis.views.tuning = CompositeView(q.guis.views.scroll, Rect(0, 0, 430, 2150));
q.guis.views.tuning.decorator = FlowLayout(q.guis.views.tuning.bounds);

q.guis.views.tuning.decorator.nextLine;


// q.guis.t_edit.value.remove


q.funcs.gen_t_edit = {|func, keyb, alt|

	var selected_keyboard = q.keyboards.names[keyb];
	var hz_vals = q.keyboards.info.at(selected_keyboard.asSymbol)[1].value;
	var tn_vals = q.keyboards.info.at(selected_keyboard.asSymbol)[2].value;

	q.current_tuning = hz_vals[alt].asFloat;
	// var keyboard_data = q.keyboards.info.at(selected_keyboard.asSymbol);
	// var num_tunings = keyboard_data[0][3].asInteger;
	//var alt_tunings = q.keyboards.info.at(q.keyboards.names[num].asSymbol)[3].value[1..];

	// q.guis.t_edit.collect{|item| item.remove; "item gone".postln; };
	q.guis.t_edit = ();
	q.guis.views.tuning.remove;

	q.guis.views.tuning = CompositeView(q.guis.views.scroll, Rect(0, 0, 430, 2150));
	q.guis.views.tuning.decorator = FlowLayout(q.guis.views.tuning.bounds);

	88.do{|num, i|

		// var g.textField.keyUpAction = { arg field; field.value.postln; }
		q.guis.t_edit.put(("notename"++i).asSymbol, StaticText(q.guis.views.tuning, 80@20).string_("Key "++(i+1)++": "++q.data.keynames[i])); // this is always the same
		q.guis.t_edit.put(("tuning"++i).asSymbol, EZText(q.guis.views.tuning, 160@20, "Frequency (Hz) ", initVal: hz_vals[alt][i].asFloat, labelWidth: 100));
		q.guis.t_edit.put(("notation"++i).asSymbol, EZText(q.guis.views.tuning, 160@20, "Tuning Name ", initVal: tn_vals[alt][i], labelWidth: 100));
		q.guis.views.tuning.decorator.nextLine;
	};

};
q.funcs.gen_t_edit(0,0);

// q.keyboards.names[0].asSymbol
// q.keyboards.info.at(q.keyboards.names[0].asSymbol)[0];
//
q.funcs.gen_image = {|func, keyb|

	var selected_keyboard = q.keyboards.names[keyb];

	if ( q.guis.image.notNil, { q.guis.image.free });

	if (keyb > 0, {
		q.guis.image = Image.new(q.images[keyb], 100);
		q.guis.image.scalesWhenResized_(true);
		q.guis.image.setSize(700, (700 / (q.guis.image.width / q.guis.image.height)).asInteger);
	} );

	// keyboard view
	w.drawFunc = {
		if ( q.guis.image.notNil, { q.guis.image.drawAtPoint(460@270); }); // draw image.
		Pen.use{

			q.keyboard_drawing.collect{|vals, i|
				Pen.color = Color.blue;
				Pen.addRect(
					Rect(vals[0], vals[1], vals[2], vals[3])
				);
				if (vals[4], {
					Pen.perform(\fill);
				}, { Pen.perform(\stroke) }
				);
			};


			q.active_key.collect{|val, i|
				if ( val, {
					var active = q.keyboard_drawing[i];
					if ( q.tonn.active, {
						Color.new(1, 0, 0, 0.3).setFill;
						// Pen.addOval(Rect(460,270,25,25));
						Pen.addOval(Rect(q.tonn.x,q.tonn.y,25,25));
						Pen.fill;
					});
					// var note_name = q.current_tuning //// find the key name here...
					Pen.color = Color.red;
					Pen.addRect( Rect(active[0], active[1], active[2], active[3]));
					Pen.perform(\fill);
				});
			}

		};
	};
	w.refresh;
};
q.funcs.gen_image(0);
// keyboard view end
w.onClose_({ q.guis.image.free; }); // free the image when the window is closed
);