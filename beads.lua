-- beads
-- granular processor
-- Emilie Gillet's DSP
--
-- E1 page
-- E2 pick, E3 turn
-- K2 freeze
-- K3 seed (hold=run)

engine.name = "Beads"

local page = 1
local selected = 1
local seed_down = false
local seed_at = nil
local notes_held = 0
local clock_coro = nil
local midi_dev = nil

local pages = {
  {
    name = "grain",
    bipolar = false,
    ids = {"density", "time", "size", "shape", "pitch"},
    labels = {"DENS", "TIME", "SIZE", "SHAP", "PTCH"},
  },
  {
    name = "spread",
    bipolar = true,
    ids = {"time_atten", "size_atten", "shape_atten", "pitch_atten"},
    labels = {"TIME", "SIZE", "SHAP", "PTCH"},
  },
  {
    name = "mix",
    bipolar = false,
    ids = {"feedback", "dry_wet", "beads_reverb", "level"},
    labels = {"FB", "WET", "RVB", "LVL"},
  },
}

local tone_rows = {
  {name = "quality", id = "media"},
  {name = "input", id = "mono"},
  {name = "source", id = "synth"},
  {name = "clock", id = "clock_in"},
  {name = "seed", id = "seed_lock"},
  {name = "right", id = "output_gate"},
}

-- Knob positions from the Beads manual, on a pot that runs from 7 o'clock
-- (0) to 5 o'clock (1). 12 o'clock is 0.5. Pitch is already in semitones:
-- 11 o'clock and 1 o'clock land on the first detent, one semitone.
local presets = {
  {
    name = "init",
    density = 0.22, time = 0.02, size = 0.45, shape = 0.55, pitch = 0,
    time_atten = 0, size_atten = 0, shape_atten = 0, pitch_atten = 0,
    feedback = 0.2, dry_wet = 1, beads_reverb = 0.25,
    media = 4, mono = 1, synth = 1, clock_in = 1, seed_lock = 2, freeze = 1, output_gate = 1,
    time_cv_on = 1, size_cv_on = 1, shape_cv_on = 1, pitch_cv_on = 1,
  },
  {
    -- "Try these settings": dry/wet fully CW, size at noon, density at 9,
    -- shape at 2, time fully CCW, pitch at 1, spreads at noon.
    name = "feedback",
    density = 0.2, time = 0, size = 0.5, shape = 0.7, pitch = 1,
    time_atten = 0, size_atten = 0, shape_atten = 0, pitch_atten = 0,
    feedback = 0.75, dry_wet = 1, beads_reverb = 0.15,
    media = 4, mono = 1, synth = 1, clock_in = 1, seed_lock = 2, freeze = 1, output_gate = 1,
    time_cv_on = 1, size_cv_on = 1, shape_cv_on = 1, pitch_cv_on = 1,
  },
  {
    -- Size fully CW turns Beads into a delay. Shape fully CCW is the plain
    -- repeat. Density at 9 is a shorter delay on the binary side of noon.
    name = "delay",
    density = 0.2, time = 0.5, size = 1, shape = 0, pitch = 0,
    time_atten = 0, size_atten = 0, shape_atten = 0, pitch_atten = 0,
    feedback = 0.4, dry_wet = 1, beads_reverb = 0.2,
    media = 4, mono = 1, synth = 1, clock_in = 1, seed_lock = 2, freeze = 1, output_gate = 1,
    time_cv_on = 1, size_cv_on = 1, shape_cv_on = 1, pitch_cv_on = 1,
  },
  {
    -- The same delay, frozen, so time picks a slice of the buffer.
    name = "slice",
    density = 0.2, time = 0.35, size = 1, shape = 0, pitch = 0,
    time_atten = 0, size_atten = 0, shape_atten = 0, pitch_atten = 0,
    feedback = 0.25, dry_wet = 1, beads_reverb = 0.15,
    media = 4, mono = 1, synth = 1, clock_in = 1, seed_lock = 2, freeze = 2, output_gate = 1,
    time_cv_on = 1, size_cv_on = 1, shape_cv_on = 1, pitch_cv_on = 1,
  },
  {
    -- Size fully CW and density near fully CCW: the short, audio-rate delay
    -- the manual describes as a flanger or comb.
    name = "comb",
    density = 0.05, time = 0.25, size = 1, shape = 0, pitch = 0,
    time_atten = 0, size_atten = 0, shape_atten = 0, pitch_atten = 0,
    feedback = 0.55, dry_wet = 0.65, beads_reverb = 0.1,
    media = 4, mono = 1, synth = 1, clock_in = 1, seed_lock = 2, freeze = 1, output_gate = 1,
    time_cv_on = 1, size_cv_on = 1, shape_cv_on = 1, pitch_cv_on = 1,
  },
  {
    -- Below the short-grain point (about 10:30), size plays the grain backwards.
    name = "reverse",
    density = 0.25, time = 0.08, size = 0.12, shape = 0.65, pitch = 0,
    time_atten = 0, size_atten = 0, shape_atten = 0, pitch_atten = 0,
    feedback = 0.15, dry_wet = 1, beads_reverb = 0.3,
    media = 4, mono = 1, synth = 1, clock_in = 1, seed_lock = 2, freeze = 1, output_gate = 1,
    time_cv_on = 1, size_cv_on = 1, shape_cv_on = 1, pitch_cv_on = 1,
  },
  {
    -- Seed unlatched and density at noon: one grain each time the seed is tapped.
    name = "tap",
    density = 0.5, time = 0.1, size = 0.45, shape = 0.4, pitch = 0,
    time_atten = 0, size_atten = 0, shape_atten = 0, pitch_atten = 0,
    feedback = 0.1, dry_wet = 1, beads_reverb = 0.2,
    media = 4, mono = 1, synth = 1, clock_in = 1, seed_lock = 1, freeze = 1, output_gate = 1,
    time_cv_on = 1, size_cv_on = 1, shape_cv_on = 1, pitch_cv_on = 1,
  },
  {
    -- Nothing patched in: the internal wavetable. Feedback picks the bank,
    -- dry/wet mixes the oscillator with the grains.
    name = "wavetable",
    density = 0.3, time = 0.15, size = 0.45, shape = 0.6, pitch = 0,
    time_atten = 0, size_atten = 0, shape_atten = 0, pitch_atten = 0.4,
    feedback = 0.35, dry_wet = 0.55, beads_reverb = 0.3,
    media = 4, mono = 1, synth = 2, clock_in = 1, seed_lock = 2, freeze = 1, output_gate = 1,
    time_cv_on = 1, size_cv_on = 1, shape_cv_on = 1, pitch_cv_on = 1,
  },
  {
    -- Pitch attenurandomizer fully CW, so a keyboard or sequencer on pitch CV
    -- tracks at 1 volt per octave.
    name = "melody",
    density = 0.35, time = 0.05, size = 0.4, shape = 0.55, pitch = 0,
    time_atten = 0, size_atten = 0, shape_atten = 0, pitch_atten = 1,
    feedback = 0.15, dry_wet = 1, beads_reverb = 0.25,
    media = 4, mono = 1, synth = 1, clock_in = 1, seed_lock = 2, freeze = 1, output_gate = 1,
    time_cv_on = 1, size_cv_on = 1, shape_cv_on = 1, pitch_cv_on = 2,
  },
}

local preset_keys = {
  "density", "time", "size", "shape", "pitch",
  "time_atten", "size_atten", "shape_atten", "pitch_atten",
  "feedback", "dry_wet", "beads_reverb",
  "media", "mono", "synth", "clock_in", "seed_lock", "freeze", "output_gate",
  "time_cv_on", "size_cv_on", "shape_cv_on", "pitch_cv_on",
}

local applying_preset = false

local function apply_preset(index)
  local preset = presets[index]
  if preset == nil or applying_preset then return end
  applying_preset = true
  for _, id in ipairs(preset_keys) do
    params:set(id, preset[id])
  end
  applying_preset = false
end

local function flag(value)
  return value == 2 and 1 or 0
end

local function stop_clock()
  if clock_coro then
    clock.cancel(clock_coro)
    clock_coro = nil
  end
  engine.gate(0)
  engine.clock_in(0)
end

local function start_clock()
  stop_clock()
  engine.clock_in(1)
  clock_coro = clock.run(function()
    while true do
      clock.sync(1)
      engine.gate(1)
      clock.sleep(0.02)
      engine.gate(0)
    end
  end)
end

local function add_control(id, name, spec)
  params:add{
    type = "control",
    id = id,
    name = name,
    controlspec = spec,
    action = function(v) engine[id](v) end,
  }
end

local function build_params()
  params:add_separator("beads")

  add_control("density", "density", controlspec.new(0, 1, "lin", 0, 0.22, "", 0.005))
  add_control("time", "time", controlspec.new(0, 1, "lin", 0, 0.02, "", 0.005))
  add_control("size", "size", controlspec.new(0, 1, "lin", 0, 0.45, "", 0.005))
  add_control("shape", "shape", controlspec.new(0, 1, "lin", 0, 0.55, "", 0.005))
  add_control("pitch", "pitch", controlspec.new(-24, 24, "lin", 0, 0, "st", 1/48))

  params:add_separator("spread")
  add_control("time_atten", "time spread", controlspec.new(-1, 1, "lin", 0, 0, "", 0.02))
  add_control("size_atten", "size spread", controlspec.new(-1, 1, "lin", 0, 0, "", 0.02))
  add_control("shape_atten", "shape spread", controlspec.new(-1, 1, "lin", 0, 0, "", 0.02))
  add_control("pitch_atten", "pitch spread", controlspec.new(-1, 1, "lin", 0, 0, "", 0.02))

  params:add_separator("mix")
  add_control("feedback", "feedback", controlspec.new(0, 1, "lin", 0, 0.2, "", 0.005))
  add_control("dry_wet", "dry/wet", controlspec.new(0, 1, "lin", 0, 1, "", 0.005))
  params:add{
    type = "control",
    id = "beads_reverb",
    name = "reverb",
    controlspec = controlspec.new(0, 1, "lin", 0, 0.25, "", 0.005),
    action = function(v) engine.reverb(v) end,
  }
  params:add{
    type = "control",
    id = "level",
    name = "level",
    controlspec = controlspec.new(0, 1, "lin", 0, 0.8, "", 0.01),
    action = function(v) engine.amp(v) end,
  }

  params:add_separator("tone")
  params:add_option("media", "quality", {"dirty tape", "clean tape", "clouds", "16-bit"}, 4)
  params:set_action("media", function(v) engine.media(v - 1) end)
  params:add_option("mono", "input", {"stereo", "mono"}, 1)
  params:set_action("mono", function(v) engine.mono(flag(v)) end)
  params:add_option("synth", "source", {"audio in", "wavetable"}, 1)
  params:set_action("synth", function(v) engine.synth(flag(v)) end)
  params:add_option("clock_in", "clock in", {"off", "norns clock"}, 1)
  params:set_action("clock_in", function(v)
    if v == 2 then
      params:set("seed_lock", 2)
      start_clock()
    else
      stop_clock()
    end
    redraw()
  end)
  params:add_option("seed_lock", "seed", {"armed", "running"}, 2)
  params:set_action("seed_lock", function(v) engine.seed_lock(flag(v)) end)
  params:add_option("freeze", "freeze", {"off", "on"}, 1)
  params:set_action("freeze", function(v) engine.freeze(flag(v)) end)
  params:add_option("output_gate", "right output", {"audio", "gate"}, 1)
  params:set_action("output_gate", function(v) engine.output_gate(flag(v)) end)

  params:add_separator("cv")
  add_control("density_cv", "density cv", controlspec.new(-1, 1, "lin", 0, 0, "", 0.01))
  add_control("time_cv", "time cv", controlspec.new(-1.6, 1.6, "lin", 0, 0, "", 0.02))
  params:add_option("time_cv_on", "time cv on", {"off", "on"}, 1)
  params:set_action("time_cv_on", function(v) engine.time_cv_on(flag(v)) end)
  add_control("size_cv", "size cv", controlspec.new(-1.6, 1.6, "lin", 0, 0, "", 0.02))
  params:add_option("size_cv_on", "size cv on", {"off", "on"}, 1)
  params:set_action("size_cv_on", function(v) engine.size_cv_on(flag(v)) end)
  add_control("shape_cv", "shape cv", controlspec.new(-1.6, 1.6, "lin", 0, 0, "", 0.02))
  params:add_option("shape_cv_on", "shape cv on", {"off", "on"}, 1)
  params:set_action("shape_cv_on", function(v) engine.shape_cv_on(flag(v)) end)
  add_control("pitch_cv", "pitch cv", controlspec.new(-60, 60, "lin", 0, 0, "st", 1/120))
  params:add_option("pitch_cv_on", "pitch cv on", {"off", "on"}, 1)
  params:set_action("pitch_cv_on", function(v) engine.pitch_cv_on(flag(v)) end)

  params:add_separator("midi")
  params:add_option("midi_mode", "midi", {"off", "pitch", "pitch + seed"}, 2)

  local preset_names = {}
  for i, preset in ipairs(presets) do preset_names[i] = preset.name end
  params:add_separator("recipes")
  params:add_option("beads_preset", "preset", preset_names, 1)
  params:set_action("beads_preset", apply_preset)
end

local function on_midi(data)
  local msg = midi.to_msg(data)
  local mode = params:get("midi_mode")
  if mode == 1 then return end
  local note_on = msg.type == "note_on" and msg.vel > 0
  local note_off = msg.type == "note_off" or (msg.type == "note_on" and msg.vel == 0)
  if note_on then
    notes_held = notes_held + 1
    params:set("pitch_cv", msg.note - 60)
    params:set("pitch_cv_on", 2)
    if mode == 3 then engine.seed(1) end
  elseif note_off then
    notes_held = math.max(0, notes_held - 1)
    if notes_held == 0 then
      params:set("pitch_cv_on", 1)
      if mode == 3 then engine.seed(seed_down and 1 or 0) end
    end
  end
end

local function header(title)
  screen.level(15)
  screen.move(0, 8)
  screen.text(title)

  local quality = ({"tape", "clean", "clouds", "16-bit"})[params:get("media")]
  local state = "arm"
  if seed_down then
    state = "seed"
  elseif params:get("seed_lock") == 2 then
    state = "run"
  end
  local extras = ""
  if params:get("synth") == 2 then extras = extras .. " wt" end
  if params:get("freeze") == 2 then extras = extras .. " frz" end
  if params:get("synth") == 1 and params:get("size") > 0.98 then extras = extras .. " dly" end

  screen.level(6)
  screen.move(128, 8)
  screen.text_right(quality .. " " .. state .. extras)
end

local function shown(id, label, on)
  if not on then return label end
  local value = params:get(id)
  if id == "pitch" then
    return string.format("%+d", math.floor(value + (value < 0 and -0.5 or 0.5)))
  end
  if id:find("atten") then
    return string.format("%+.2f", value)
  end
  return string.format("%.2f", value)
end

local function draw_bars(spec)
  local count = #spec.ids
  local gap = 6
  local width = math.floor((120 - gap * (count - 1)) / count)
  local x0 = math.floor((128 - (count * width + (count - 1) * gap)) / 2)
  local y = 14
  local h = 30
  for i = 1, count do
    local id = spec.ids[i]
    local on = i == selected
    local x = x0 + (i - 1) * (width + gap)
    local value = params:get(id)
    screen.level(on and 12 or 3)
    screen.rect(x, y, width, h)
    screen.stroke()
    screen.level(on and 15 or 8)
    if spec.bipolar or id == "pitch" then
      local norm = id == "pitch" and (value / 24) or value
      norm = util.clamp(norm, -1, 1)
      local mid = y + h / 2
      local mag = math.abs(norm) * (h / 2 - 1)
      if norm >= 0 then
        screen.rect(x + 1, mid - mag, width - 2, math.max(1, mag))
      else
        screen.rect(x + 1, mid, width - 2, math.max(1, mag))
      end
      screen.fill()
    else
      local mag = util.clamp(value, 0, 1) * (h - 2)
      screen.rect(x + 1, y + h - 1 - mag, width - 2, math.max(1, mag))
      screen.fill()
    end
    screen.level(on and 15 or 5)
    screen.move(x + width / 2, 62)
    screen.text_center(shown(id, spec.labels[i], on))
  end
end

local function draw_tone()
  for i, row in ipairs(tone_rows) do
    local y = 16 + i * 8
    screen.level(i == selected and 15 or 5)
    screen.move(2, y)
    screen.text(row.name)
    screen.move(126, y)
    screen.text_right(params:string(row.id))
  end
end

local function draw_presets()
  local window = 6
  local start = 1
  if selected > window then start = selected - window + 1 end
  for i = start, math.min(#presets, start + window - 1) do
    local y = 16 + (i - start + 1) * 8
    local on = i == selected
    screen.level(on and 15 or 5)
    screen.move(2, y)
    screen.text((on and "> " or "  ") .. presets[i].name)
  end
end

function init()
  build_params()
  midi_dev = midi.connect(1)
  midi_dev.event = on_midi
  params:bang()
  redraw()
end

function cleanup()
  if clock_coro then clock.cancel(clock_coro) end
end

function key(n, z)
  if n == 2 and z == 1 then
    params:set("freeze", params:get("freeze") == 1 and 2 or 1)
  elseif n == 3 then
    if z == 1 then
      seed_down = true
      seed_at = util.time()
      params:set("seed_lock", 1)
      engine.seed(1)
    else
      seed_down = false
      local held_note = notes_held > 0 and params:get("midi_mode") == 3
      engine.seed(held_note and 1 or 0)
      if seed_at and (util.time() - seed_at) > 0.4 then
        params:set("seed_lock", 2)
      end
    end
  end
  redraw()
end

function enc(n, d)
  if n == 1 then
    page = util.clamp(page + d, 1, 5)
    if page == 5 then
      selected = params:get("beads_preset")
    else
      selected = 1
    end
  elseif page == 5 then
    if n == 2 or n == 3 then
      local index = util.clamp(params:get("beads_preset") + d, 1, #presets)
      params:set("beads_preset", index)
      selected = index
    end
  elseif page == 4 then
    if n == 2 then
      selected = util.clamp(selected + d, 1, #tone_rows)
    elseif n == 3 then
      params:delta(tone_rows[selected].id, d)
    end
  else
    local ids = pages[page].ids
    if n == 2 then
      selected = util.clamp(selected + d, 1, #ids)
    elseif n == 3 then
      params:delta(ids[selected], d)
    end
  end
  redraw()
end

function redraw()
  screen.clear()
  screen.font_face(1)
  screen.font_size(8)
  if page == 5 then
    header("preset")
    draw_presets()
  elseif page == 4 then
    header("tone")
    draw_tone()
  else
    header(pages[page].name)
    draw_bars(pages[page])
  end
  screen.update()
end
