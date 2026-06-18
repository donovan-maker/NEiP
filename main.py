from tkinter import filedialog, messagebox
from sys import argv
import tkinter as tk
import numpy as np
import threading
import pygame
import nes
import os
import json
import sounddevice as sd
import collections

SAMPLE_RATE = 44100
BLOCK_SIZE = 735
NES_APU_RATE = 1789773 / 2

audioBuffer = collections.deque(maxlen=BLOCK_SIZE * 2)
audioLock = threading.Lock()

def audioCallback(outdata, frames, time_info, status):
    with audioLock:
        available = len(audioBuffer)
        for i in range(frames):
            if audioBuffer:
                outdata[i, 0] = audioBuffer.popleft()
            else:
                outdata[i, 0] = 0.0

audioStream = sd.OutputStream(samplerate=SAMPLE_RATE, blocksize=BLOCK_SIZE, channels=1, dtype='float32', callback=audioCallback,)
audioStream.start()

SCREEN_W, SCREEN_H = 512, 480

root = tk.Tk()
root.title("NEiP")
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
        powerCycle()

def powerCycle():
    with nes_lock:
        nes.fullReset()
        nes.reset()

def resetNes():
    with nes_lock:
        nes.reset()

def quitApp():
    running.clear()
    audioStream.stop()
    audioStream.close()
    root.after(200, root.destroy)

def about():
    messagebox.showinfo("About NEiP:", "NEiP stands for NES Emulator in Python.\nCreated by Donovan Black (FloppyDisk) in 2026.")

def runSSTs():
    if not os.path.isdir("SSTs/"):
        messagebox.showerror("SSTs Not Found", "Running SSTs requires a folder with all properly formatted SST json files at the relative path SSTs/, and this path was not found.")
        return
    with nes_lock:
        nes.reset()
        for inst in range(256):
            # Skip all unofficial instructions for now
            lowerPart = inst&0xF
            upperPart = inst>>4
            if lowerPart == 3:
                continue
            if lowerPart == 7:
                continue
            if lowerPart == 0xB:
                continue
            if lowerPart == 0xF:
                continue
            if lowerPart == 2:
                if upperPart != 0xA:
                    continue
            if lowerPart == 4:
                if upperPart in [0,1,3,4,5,6,7,0xD,0xF]:
                    continue
            if lowerPart == 0xA:
                if upperPart in [1,3,5,7,0xD,0xF]:
                    continue
            if lowerPart == 0xC:
                if upperPart in [0,1,3,5,7,9,0xD,0xF]:
                    continue
            if inst == 0x80:
                continue
            if inst == 0x89:
                continue
            if inst == 0x9E:
                continue
            f = open(f"SSTs/{inst:02x}.json", "r")
            testJson = json.load(f)
            f.close()
            for entry in testJson:
                try:
                    init = entry["initial"]
                    nes.setRegs(init["a"], init["x"], init["y"], init["pc"], init["s"], init["p"])
                    for ramvals in init["ram"]:
                        nes.setSSTRam(ramvals[0], ramvals[1])
                    nes.setSSTMode()
                    nes.SSTStep()
                    nes.clearSSTMode()
                    final = entry["final"]
                    a, x, y, pc, sp, flags = nes.readRegs()
                    if a != final["a"]:
                        raise Exception(f"In test for opcode 0x{inst:02x}, a={a} when {final["a"]} was expected")
                    if x != final["x"]:
                        raise Exception(f"In test for opcode 0x{inst:02x}, x={x} when {final["x"]} was expected")
                    if y != final["y"]:
                        raise Exception(f"In test for opcode 0x{inst:02x}, y={y} when {final["y"]} was expected")
                    if pc != final["pc"]:
                        raise Exception(f"In test for opcode 0x{inst:02x}, pc={pc} when {final["pc"]} was expected")
                    if sp != final["s"]:
                        raise Exception(f"In test for opcode 0x{inst:02x}, sp={sp} when {final["s"]} was expected")
                    if flags != final["p"]:
                        raise Exception(f"In test for opcode 0x{inst:02x}, flags={flags} when {final["p"]} was expected")
                    for ramvals in final["ram"]:
                        val = nes.readSSTRam(ramvals[0])
                        if val != ramvals[1]:
                            raise Exception(f"In test for opcode 0x{inst:02x}, ram[{ramvals[0]}/0x{ramvals[0]:04x}]={val} when {ramvals[1]} was expected")
                except Exception as e:
                    print(f"Failed on test {entry["name"]}")
                    raise e
            print(f"Instruction 0x{inst:02x} passed!")
        print("Every official instruction passed!")

menubar = tk.Menu(root)
root.config(menu=menubar)

file_menu = tk.Menu(menubar, tearoff=0)
file_menu.add_command(label="Open ROM…", accelerator="Ctrl+O", command=openRom)
file_menu.add_separator()
file_menu.add_command(label="Exit", command=quitApp)
menubar.add_cascade(label="File", menu=file_menu)

emulator_menu = tk.Menu(menubar, tearoff=0)
emulator_menu.add_command(label="Reset", accelerator="Ctrl+R", command=resetNes)
emulator_menu.add_command(label="Power Cycle", command=powerCycle)
menubar.add_cascade(label="Emulator", menu=emulator_menu)

help_menu = tk.Menu(menubar, tearoff=0)
help_menu.add_command(label="About", command=about)
help_menu.add_command(label="SST", command=runSSTs)
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
    root.title(f"NEiP - {fps:.1f} fps")

def emuThread():
    fb = nes.getFrameBuffer()

    while running.is_set():
        c1 = 0
        with keysLock:
            for keysym, bit in CONTROLLER_MAP.items():
                if keysym in heldKeys:
                    c1 |= bit

        rawSamples = []
        try:
            with nes_lock:
                nes.writeController1(c1)
                nes.run()
                rawSamples = nes.drainAudioBuffer()
        except Exception as e:
            print(f"[NEiP] Emulator crashed: {e}")
            print("Note: If two unknown opcodes were reported take the first one only")
            screen.fill((0, 0, 0))
            pygame.display.flip()
            root.after(0, setTitle, 0)
            return

        if rawSamples:
            ratio = len(rawSamples) / BLOCK_SIZE
            downsampled = [
                rawSamples[int(i * ratio)]
                for i in range(min(BLOCK_SIZE, len(rawSamples)))
            ]
            with audioLock:
                audioBuffer.extend(downsampled)

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