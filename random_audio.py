from datetime import datetime
import os
import random
import tkinter as tk
from pydub import AudioSegment
from pydub.playback import play
import argparse

SEGMENT_LENGTH = 60000

class AudioMixer:
    def __init__(self, master, segment_dir, args):
        self.master = master
        self.master.title("Two-Track Audio Mixer")

        self.title = None
        self.track1 = None
        self.track2 = None
        self.directory_path = args.directory_path

        self.title = tk.Label(master, text=f"Segment Directory: {segment_dir}")
        self.title.pack(pady=5)

        self.track1_label = tk.Label(master, text="Track 1: Not loaded")
        self.track1_label.pack(pady=5)

        self.track2_label = tk.Label(master, text="Track 2: Not loaded")
        self.track2_label.pack(pady=5)

        self.volume1 = tk.Scale(master, from_=0, to=100, orient=tk.HORIZONTAL, label="Volume Track 1")
        self.volume1.set(100)
        self.volume1.pack(pady=10)

        self.volume2 = tk.Scale(master, from_=0, to=100, orient=tk.HORIZONTAL, label="Volume Track 2")
        self.volume2.set(100)
        self.volume2.pack(pady=10)

        self.pan1 = tk.Scale(master, from_=-64, to=64, orient=tk.HORIZONTAL, label="Pan Track 1 (Left to Right)")
        self.pan1.set(random.randint(-64, 64))
        self.pan1.pack(pady=10)

        self.pan2 = tk.Scale(master, from_=-64, to=64, orient=tk.HORIZONTAL, label="Pan Track 2 (Left to Right)")
        self.pan2.set(random.randint(-64, 64))
        self.pan2.pack(pady=10)

        self.mix_button = tk.Button(master, text="Mix and Play", command=self.mix_and_play)
        self.mix_button.pack(pady=20)

        if args.ui_only_mode != True:
            # Load directory after UI elements are created
            self.load_directory()
        
    def load_directory(self):
        self.select_random_tracks(self.directory_path, segment_dir)

    def select_random_tracks(self, directory_path, segment_path):
        audio_files = [f for f in os.listdir(directory_path) if f.endswith(('.mp3', '.wav', '.ogg'))]
        if len(audio_files) < 2:
            print("Not enough audio files in the directory.")
            return
        
        track1_file = random.choice(audio_files)
        track2_file = random.choice([f for f in audio_files if f != track1_file])
        
        self.track1 = self.get_random_segment(os.path.join(directory_path, track1_file))
        self.track2 = self.get_random_segment(os.path.join(directory_path, track2_file))
        
        segment_1_filename = f"seg1_{track1_file}"
        segment_2_filename = f"seg2_{track2_file}"

        self.track1.export(os.path.join(segment_path, segment_1_filename))
        self.track2.export(os.path.join(segment_path, segment_2_filename))

        self.track1_label.config(text=f"Track 1: {segment_1_filename}")
        self.track2_label.config(text=f"Track 2: {segment_2_filename}")

    def get_random_segment(self, file_path):
        audio = AudioSegment.from_file(file_path)
        if len(audio) < SEGMENT_LENGTH:
            print(f"Audio file {file_path} is shorter than SEGMENT_LENGTH.")
            return audio
        start_time = random.randint(0, len(audio) - SEGMENT_LENGTH)
        return audio[start_time:start_time + SEGMENT_LENGTH]

    def ensure_stereo(self, track):
        if track.channels == 1:
            return AudioSegment.from_mono_audiosegments(track, track)
        return track

    def apply_pan(self, track, pan):
        pan_value = pan / 100
        track = self.ensure_stereo(track)
        left, right = track.split_to_mono()
        if pan_value < 0:
            right = right - (abs(pan_value) * 20)
        else:
            left = left - (abs(pan_value) * 20)
        return AudioSegment.from_mono_audiosegments(left, right)

    def mix_and_play(self):
        if self.track1 and self.track2:
            track1_vol = self.volume1.get() / 100
            track2_vol = self.volume2.get() / 100
            pan1_val = self.pan1.get()
            pan2_val = self.pan2.get()

            track1 = self.track1 - (1 - track1_vol) * 20
            track2 = self.track2 - (1 - track2_vol) * 20

            track1 = self.apply_pan(track1, pan1_val)
            track2 = self.apply_pan(track2, pan2_val)

            mixed = track1.overlay(track2)

            play(mixed)
        else:
            print("Please load both tracks first.")

if __name__ == "__main__":
    # Set up argument parser
    parser = argparse.ArgumentParser(description="Two-Track Audio Mixer")
    parser.add_argument("directory_path", type=str, help="The directory path containing audio files")
    parser.add_argument("--ui_only_mode", type=bool, help="Flag to run in UI only mode, for testing")

    # Parse arguments
    args = parser.parse_args()

    # Create the segment directory
    now = datetime.now()
    formatted_time = now.strftime("%Y-%m-%d_%H-%M-%S")
    segment_dir = f"./segments/{formatted_time}"
    os.makedirs(segment_dir, exist_ok=True)

    # Create Tkinter root window
    root = tk.Tk()
    app = AudioMixer(root, segment_dir, args)
    root.mainloop()
