import numpy as np
import threading
import pygame
import nes

SAMPLE_RATE = 44100
CPU_RATE = 1_789_773
PYGAME_SAMPLES = 512

_RATIO = CPU_RATE / SAMPLE_RATE

_stop = threading.Event()
_thread: threading.Thread | None = None

def _audio_thread():
    channel = pygame.mixer.find_channel()
    if channel is None:
        pygame.mixer.set_num_channels(pygame.mixer.get_num_channels() + 2)
        channel = pygame.mixer.find_channel()
    while not _stop.is_set():
        n_cpu = int(PYGAME_SAMPLES * _RATIO) + 2
        cpu_samples = nes.audio_drain(n_cpu)
        n_trim = (len(cpu_samples) // PYGAME_SAMPLES) * PYGAME_SAMPLES
        if n_trim == 0:
            continue
        out = cpu_samples[:n_trim].reshape(PYGAME_SAMPLES, -1).mean(axis=1)
        out_i16 = (np.clip(out, -1.0, 1.0) * 32767).astype(np.int16)
        stereo = np.column_stack([out_i16, out_i16])
        sound = pygame.sndarray.make_sound(stereo)
        while channel.get_busy() and not _stop.is_set():
            pygame.time.wait(1)
        channel.play(sound)
    channel.stop()

def init(sample_rate = SAMPLE_RATE, chunk_size = PYGAME_SAMPLES):
    global _thread, SAMPLE_RATE, PYGAME_SAMPLES, _RATIO
    SAMPLE_RATE = sample_rate
    PYGAME_SAMPLES = chunk_size
    _RATIO = CPU_RATE / sample_rate
    if not pygame.mixer.get_init():
        pygame.mixer.pre_init(frequency=sample_rate, size=-16, channels=2, buffer=chunk_size * 4)
        pygame.mixer.init()
    _stop.clear()
    _thread = threading.Thread(target=_audio_thread, daemon=True, name="nes-audio")
    _thread.start()

def quit():
    _stop.set()
    if _thread and _thread.is_alive():
        _thread.join(timeout=0.5)

def reset():
    nes.audio_reset()