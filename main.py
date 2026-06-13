from tkinter import filedialog, messagebox
from sys import argv
import tkinter as tk
import numpy as np
import threading
import pygame
import queue
import nes
import os

SCREEN_W, SCREEN_H = 512, 480

root = tk.Tk()
root.title("NEIP")
root.resizable(False, False)

nes_lock  = threading.Lock()
running   = threading.Event()
running.set()

heldKeys = set()
keysLock = threading.Lock()

def onKeyDown(event):
    with keysLock:
        heldKeys.add(event.keysym)

def onKeyUp(event):
    with keysLock:
        heldKeys.discard(event.keysym)

emuThreadHandle = None

def startEmuThread(loadPath=None):
    """Stop the current emu thread (if any) then start a fresh one.
    Must NOT be called on the Tkinter main thread because of the join."""
    global emuThreadHandle

    # Signal the running thread to stop and wait for it
    running.clear()
    if emuThreadHandle and emuThreadHandle.is_alive():
        emuThreadHandle.join()

    # Load the new ROM before the thread starts (no race)
    if loadPath:
        with nes_lock:
            nes.loadRom(loadPath)
            nes.reset()

    running.set()
    emuThreadHandle = threading.Thread(target=emuThread, daemon=True)
    emuThreadHandle.start()

def openRom():
    path = filedialog.askopenfilename(
        title="Open ROM",
        filetypes=[("NES ROMs", "*.nes"), ("All files", "*.*")]
    )
    if path:
        # Do the stop/start in a background thread so Tkinter doesn't freeze
        threading.Thread(target=startEmuThread, args=(path,), daemon=True).start()

def resetNes():
    with nes_lock:
        nes.reset()

def quitApp():
    running.clear()
    root.after(200, root.destroy)

def about():
    messagebox.showinfo("About NEIP:", "NEIP stands for NES Emulator in Python.\nCreated by Donovan Black (FloppyDisk) in 2026.")

menubar = tk.Menu(root)
root.config(menu=menubar)

file_menu = tk.Menu(menubar, tearoff=0)
file_menu.add_command(label="Open ROM…", accelerator="Ctrl+O", command=openRom)
file_menu.add_separator()
file_menu.add_command(label="Exit", command=quitApp)
menubar.add_cascade(label="File", menu=file_menu)

emulator_menu = tk.Menu(menubar, tearoff=0)
emulator_menu.add_command(label="Reset", accelerator="Ctrl+R", command=resetNes)
menubar.add_cascade(label="Emulator", menu=emulator_menu)

help_menu = tk.Menu(menubar, tearoff=0)
help_menu.add_command(label="About", command=about)
menubar.add_cascade(label="Help", menu=help_menu)

root.bind("<KeyPress>",   onKeyDown)
root.bind("<KeyRelease>", onKeyUp)

root.bind("<Control-o>", lambda e: (openRom(),  "break")[1])
root.bind("<Control-r>", lambda e: (resetNes(), "break")[1])
root.protocol("WM_DELETE_WINDOW", quitApp)

embed_frame = tk.Frame(root, width=SCREEN_W, height=SCREEN_H)
embed_frame.pack()
embed_frame.update()

os.environ["SDL_WINDOWID"] = str(embed_frame.winfo_id())
# Uncomment to work on Linux
# os.environ["SDL_VIDEODRIVER"] = "x11"

pygame.init()
screen = pygame.display.set_mode((SCREEN_W, SCREEN_H))
clock  = pygame.time.Clock()
screen.fill((0, 0, 0))
pygame.display.flip()

CONTROLLER_MAP = {
    "x":         0x80,
    "z":         0x40,
    "Shift_R":   0x20,
    "Return":    0x10,
    "Up":        0x08,
    "Down":      0x04,
    "Left":      0x02,
    "Right":     0x01,
}

def setTitle(fps):
    root.title(f"NEIP - {fps:.1f} fps")

def emuThread():
    fb = nes.getFrameBuffer()   # fetch after loadRom so pointer is fresh

    while running.is_set():
        c1 = 0
        with keysLock:
            for keysym, bit in CONTROLLER_MAP.items():
                if keysym in heldKeys:
                    c1 |= bit

        try:
            with nes_lock:
                nes.writeController1(c1)
                nes.run()
        except Exception as e:
            print(f"[NEIP] Emulator crashed: {e}")
            screen.fill((0, 0, 0))
            pygame.display.flip()
            root.after(0, setTitle, 0)
            return

        pygame.event.pump()

        buf  = np.frombuffer(fb, dtype=np.uint8).reshape((240, 256, 3))
        surf = pygame.surfarray.make_surface(buf.swapaxes(0, 1))
        screen.blit(pygame.transform.scale(surf, (SCREEN_W, SCREEN_H)), (0, 0))
        pygame.display.flip()

        clock.tick(60)
        root.after(0, setTitle, clock.get_fps())

# Load ROM from CLI arg if provided, then start
if len(argv) >= 2:
    nes.loadRom(argv[1])
    nes.reset()

emuThreadHandle = threading.Thread(target=emuThread, daemon=True)
emuThreadHandle.start()

root.mainloop()
running.clear()
pygame.quit()