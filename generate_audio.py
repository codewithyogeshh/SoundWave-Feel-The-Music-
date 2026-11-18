import math
import struct
import wave
import os

SAMPLE_RATE = 44100

def create_wave(filename, duration, synth_func):
    path = os.path.join("assets", "audio", filename)
    num_samples = int(duration * SAMPLE_RATE)
    with wave.open(path, 'w') as wav_file:
        wav_file.setnchannels(2)  # Stereo
        wav_file.setsampwidth(2)  # 16-bit
        wav_file.setframerate(SAMPLE_RATE)
        
        frames = bytearray()
        for i in range(num_samples):
            t = float(i) / SAMPLE_RATE
            left, right = synth_func(t, duration)
            
            # Clamp and convert to 16-bit signed int
            left_val = int(max(-1.0, min(1.0, left)) * 32767.0)
            right_val = int(max(-1.0, min(1.0, right)) * 32767.0)
            
            frames.extend(struct.pack('<hh', left_val, right_val))
            
        wav_file.writeframes(frames)
    print(f"Generated {path} ({duration}s)")

# 1. Dreams Tonight (Synthwave Dream chords: Eb - Bb - Cm - Ab)
def synth_dreams_tonight(t, dur):
    chord_dur = 3.0
    chords = [
        [311.13, 392.00, 466.16],  # Eb maj
        [233.08, 349.23, 466.16],  # Bb maj
        [261.63, 311.13, 392.00],  # C min
        [207.65, 261.63, 311.13],  # Ab maj
    ]
    chord_idx = int(t / chord_dur) % len(chords)
    notes = chords[chord_idx]
    
    # Pad sound with slow chorus
    sig = 0.0
    for n in notes:
        sig += 0.15 * math.sin(2 * math.pi * n * t)
        sig += 0.08 * math.sin(2 * math.pi * (n * 1.003) * t)
        sig += 0.05 * math.sin(2 * math.pi * (n * 0.997) * t)
        
    # Arpeggio lead
    arp_rate = 4.0  # 4 notes per second
    arp_idx = int(t * arp_rate) % len(notes)
    arp_freq = notes[arp_idx] * 2.0
    arp_env = math.exp(-6.0 * ((t * arp_rate) % 1.0))
    lead = 0.18 * math.sin(2 * math.pi * arp_freq * t) * arp_env
    
    # Sub bass
    bass_freq = notes[0] / 2.0
    bass = 0.22 * math.sin(2 * math.pi * bass_freq * t)
    
    # Gentle fade in / out
    fade = min(1.0, t / 0.5) * min(1.0, (dur - t) / 0.5)
    
    left = (sig * 0.8 + lead * 0.9 + bass) * fade
    right = (sig * 0.8 + lead * 0.7 + bass) * fade
    return left, right

# 2. Chill Lo-Fi Beat (Fm7 - Bbm7 - Eb7 - Abmaj7)
def synth_chill_lofi(t, dur):
    chord_dur = 2.5
    chords = [
        [174.61, 207.65, 261.63, 311.13], # Fm7
        [233.08, 277.18, 349.23, 415.30], # Bbm7
        [155.56, 196.00, 233.08, 277.18], # Eb7
        [207.65, 261.63, 311.13, 392.00], # Abmaj7
    ]
    chord_idx = int(t / chord_dur) % len(chords)
    notes = chords[chord_idx]
    
    # Electric piano sound with vibrato
    vib = 1.0 + 0.004 * math.sin(2 * math.pi * 5.0 * t)
    sig = 0.0
    for n in notes:
        sig += 0.12 * math.sin(2 * math.pi * n * vib * t)
        sig += 0.04 * math.sin(4 * math.pi * n * vib * t)
        
    # Lo-fi kick / snare beat (100 BPM -> 0.6s per beat)
    beat_time = t % 0.6
    beat_num = int(t / 0.6) % 4
    drum = 0.0
    if beat_num in (0, 2):  # Kick
        drum_freq = max(40.0, 120.0 * math.exp(-25.0 * beat_time))
        drum = 0.3 * math.sin(2 * math.pi * drum_freq * beat_time) * math.exp(-8.0 * beat_time)
    elif beat_num in (1, 3): # Snare
        drum = 0.15 * (math.sin(2 * math.pi * 180.0 * beat_time) + (math.sin(1000.0 * beat_time) * 0.5)) * math.exp(-12.0 * beat_time)
        
    fade = min(1.0, t / 0.4) * min(1.0, (dur - t) / 0.4)
    return (sig + drum) * fade, (sig * 0.95 + drum) * fade

# 3. Neon Drive (Synth pulse 120 BPM)
def synth_neon_drive(t, dur):
    bass_freq = 65.41 # C2
    step = int(t * 8.0) % 8
    bass_notes = [65.41, 65.41, 77.78, 65.41, 87.31, 65.41, 98.00, 77.78]
    bf = bass_notes[step]
    b_env = math.exp(-10.0 * ((t * 8.0) % 1.0))
    bass = 0.35 * (math.sin(2 * math.pi * bf * t) + 0.3 * math.sin(4 * math.pi * bf * t)) * b_env
    
    # Pluck melody
    lead_notes = [261.63, 311.13, 392.00, 466.16, 523.25]
    l_idx = int(t * 4.0) % len(lead_notes)
    lf = lead_notes[l_idx]
    l_env = math.exp(-8.0 * ((t * 4.0) % 1.0))
    lead = 0.2 * math.sin(2 * math.pi * lf * t) * l_env
    
    fade = min(1.0, t / 0.3) * min(1.0, (dur - t) / 0.3)
    return (bass + lead * 0.7) * fade, (bass + lead * 0.9) * fade

# 4. Deep Focus (Ambient drone C - G)
def synth_deep_focus(t, dur):
    f1, f2, f3 = 130.81, 196.00, 261.63 # C3, G3, C4
    w1 = 0.18 * math.sin(2 * math.pi * f1 * t + 0.2 * math.sin(0.4 * t))
    w2 = 0.14 * math.sin(2 * math.pi * f2 * t + 0.3 * math.sin(0.3 * t))
    w3 = 0.10 * math.sin(2 * math.pi * f3 * t + 0.1 * math.sin(0.5 * t))
    fade = min(1.0, t / 1.0) * min(1.0, (dur - t) / 1.0)
    sig = (w1 + w2 + w3) * fade
    return sig * 0.9, sig * 1.0

# 5. Workout Energy (128 BPM pulse)
def synth_workout(t, dur):
    beat_t = (t * 2.133) % 1.0 # 128 BPM
    kick_f = max(45.0, 150.0 * math.exp(-30.0 * beat_t))
    kick = 0.45 * math.sin(2 * math.pi * kick_f * beat_t) * math.exp(-6.0 * beat_t)
    
    hihat_t = (t * 4.266) % 1.0
    hihat = 0.08 * math.sin(3500.0 * hihat_t) * math.exp(-35.0 * hihat_t)
    
    synth_f = 220.0 if (int(t * 2.133) % 4 < 2) else 261.63
    synth = 0.18 * math.sin(2 * math.pi * synth_f * t) * math.exp(-4.0 * beat_t)
    
    fade = min(1.0, t / 0.3) * min(1.0, (dur - t) / 0.3)
    out = (kick + hihat + synth) * fade
    return out, out

create_wave("dreams_tonight.wav", 18.0, synth_dreams_tonight)
create_wave("chill_lofi_beat.wav", 20.0, synth_chill_lofi)
create_wave("neon_drive.wav", 16.0, synth_neon_drive)
create_wave("deep_focus.wav", 22.0, synth_deep_focus)
create_wave("workout_energy.wav", 15.0, synth_workout)
print("All audio files generated successfully.")

 ''