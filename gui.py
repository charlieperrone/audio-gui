import tkinter as tk
from tkinter import filedialog
from pydub import AudioSegment
from pydub.playback import play
import threading

class AudioMixer:
    def __init__(self, master):
        self.master = master
        self.master.title("Two-Track Audio Mixer")

        self.track1 = None
        self.track2 = None
        self.mixed = None
        self.playback_thread = None
        self.is_playing = False

        self.load_button1 = tk.Button(master, text="Load Track 1", command=self.load_track1)
        self.load_button1.pack(pady=10)

        self.track1_label = tk.Label(master, text="Track 1: Not loaded")
        self.track1_label.pack(pady=5)

        self.load_button2 = tk.Button(master, text="Load Track 2", command=self.load_track2)
        self.load_button2.pack(pady=10)

        self.track2_label = tk.Label(master, text="Track 2: Not loaded")
        self.track2_label.pack(pady=5)

        self.volume1 = tk.Scale(master, from_=0, to=100, orient=tk.HORIZONTAL, label="Volume Track 1")
        self.volume1.set(100)
        self.volume1.pack(pady=10)

        self.volume2 = tk.Scale(master, from_=0, to=100, orient=tk.HORIZONTAL, label="Volume Track 2")
        self.volume2.set(100)
        self.volume2.pack(pady=10)

        self.pan1 = tk.Scale(master, from_=-100, to=100, orient=tk.HORIZONTAL, label="Pan Track 1 (Left to Right)")
        self.pan1.set(0)
        self.pan1.pack(pady=10)

        self.pan2 = tk.Scale(master, from_=-100, to=100, orient=tk.HORIZONTAL, label="Pan Track 2 (Left to Right)")
        self.pan2.set(0)
        self.pan2.pack(pady=10)

        self.mix_button = tk.Button(master, text="Mix", command=self.mix_tracks)
        self.mix_button.pack(pady=20)

        self.start_button = tk.Button(master, text="Start", command=self.start_playback)
        self.start_button.pack(pady=10)

        self.stop_button = tk.Button(master, text="Stop", command=self.stop_playback)
        self.stop_button.pack(pady=10)

    def load_track1(self):
        file_path = filedialog.askopenfilename(filetypes=[("Audio Files", "*.mp3 *.wav *.ogg")])
        if file_path:
            self.track1 = AudioSegment.from_file(file_path)
            self.track1_label.config(text=f"Track 1: {file_path}")

    def load_track2(self):
        file_path = filedialog.askopenfilename(filetypes=[("Audio Files", "*.mp3 *.wav *.ogg")])
        if file_path:
            self.track2 = AudioSegment.from_file(file_path)
            self.track2_label.config(text=f"Track 2: {file_path}")

    def apply_pan(self, track, pan):
        # Pan value ranges from -100 (left) to 100 (right)
        pan_value = pan / 100
        channels = track.split_to_mono()

        if len(channels) == 1:
            left = right = channels[0]
        else:
            left = channels[0]
            right = channels[1]

        # Adjust volumes for panning
        if pan_value < 0:
            left = left + (abs(pan_value) * 20)
            right = right - abs(pan_value) * 20
        else:
            left = left - (pan_value * 20)
            right = right + pan_value * 20

        # Prevent clipping by ensuring the volume does not exceed the maximum
        left = left.normalize()
        right = right.normalize()

        return AudioSegment.from_mono_audiosegments(left, right)

    def mix_tracks(self):
        if self.track1 and self.track2:
            track1_vol = self.volume1.get() / 100
            track2_vol = self.volume2.get() / 100
            pan1_val = self.pan1.get()
            pan2_val = self.pan2.get()

            # Adjust volumes
            track1 = self.track1 - (100 - (track1_vol * 100))
            track2 = self.track2 - (100 - (track2_vol * 100))

            # Apply panning
            track1 = self.apply_pan(track1, pan1_val)
            track2 = self.apply_pan(track2, pan2_val)

            # Make sure tracks are the same length
            if len(track1) < len(track2):
                track1 = track1 + AudioSegment.silent(len(track2) - len(track1))
            elif len(track2) < len(track1):
                track2 = track2 + AudioSegment.silent(len(track1) - len(track2))

            # Mix tracks
            self.mixed = track1.overlay(track2)

    def playback(self):
        if self.mixed:
            play(self.mixed)

    def start_playback(self):
        if self.mixed and not self.is_playing:
            self.is_playing = True
            self.playback_thread = threading.Thread(target=self.playback)
            self.playback_thread.start()

    def stop_playback(self):
        if self.is_playing:
            self.is_playing = False
            self.playback_thread.join()

if __name__ == "__main__":
    root = tk.Tk()
    app = AudioMixer(root)
    root.mainloop()
