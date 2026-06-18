# cython: cdivision=True

import numpy as np

cdef int PC = 0
cdef unsigned char SP = 0
cdef int A = 0
cdef int X = 0
cdef int Y = 0

cdef bool CPUHalted = False
cdef bool drawNewFrame = False
cdef int frames = 0

cdef bool carry = False
cdef bool zero = False
cdef bool interruptDisable = True
cdef bool decimal = False
cdef bool overflow = False
cdef bool negative = False

cdef unsigned char RAM[0x800]
cdef unsigned char VRAM[0x800]
cdef unsigned char PaletteRAM[32]
cdef unsigned char OAM[0x100]
cdef unsigned char SecondaryOAM[0x20]
cdef unsigned char ROM[0x8000]
cdef unsigned char ROMHeader[0x10]
cdef unsigned char CHRData[0x2000]

cdef bool PPUwriteLatch = False
cdef int PPUtransferAddress = 0
cdef int PPUVRAMAddress = 0
cdef bool PPUVRAMInc32 = False
cdef int PPUReadBuffer = 0
cdef int PPUDot = 0
cdef int PPUScanline = 0
cdef bool PPUVBlank = False
cdef bool PPUMask8pxMaskBG = False
cdef bool PPUMask8pxMaskSprites = False
cdef bool PPUMaskRenderBG = False
cdef bool PPUMaskRenderSprites = False
cdef int PPUNametableSelect = 0
cdef bool PPUSpritePatternTable = False
cdef bool PPUBGPatternTable = False
cdef bool PPUUse8x16Sprites = False
cdef bool PPUEnableNMI = False
cdef bool NMILevelDetector = False
cdef bool DoNMI = False
cdef bool previousNMILevelDetector = False
cdef int PPUShiftRegisterPatternL = 0
cdef int PPUShiftRegisterPatternH = 0
cdef int PPUShiftRegisterAttributeL = 0
cdef int PPUShiftRegisterAttributeH = 0
cdef int PPU8StepPatternLowBitPlane = 0
cdef int PPU8StepPatternHighBitPlane = 0
cdef int PPU8StepAttribute = 0
cdef int PPUAddressBus = 0
cdef int PPU8StepTemp = 0
cdef int PPU8StepNextCharacter = 0
cdef int PPUScrollFineX = 0
cdef int PPUtempVRAMAddress = 0
cdef int PPUSpriteEvalTemp = 0
cdef int PPUSecondaryOAMAddress = 0
cdef bool PPUSecondaryOAMFull = False
cdef int PPUOAMAddress = 0
cdef int PPUSpriteEvalTick = 0
cdef bool PPUStatusOverflow = False
cdef bool PPUStatusSprZeroHit = False
cdef bool PPUScanlineContainsSpriteZero = False
cdef bool PPUSpriteEvaluationOAMOverflowed = False
cdef int PPUSecondaryOAMSize = 0
cdef unsigned char PPUSpriteShiftRegisterL[8]
cdef unsigned char PPUSpriteShiftRegisterH[8]
cdef unsigned char PPUSpriteAttribute[8]
cdef unsigned char PPUSpritePattern[8]
cdef unsigned char PPUSpriteXPosition[8]
cdef unsigned char PPUSpriteYPosition[8]

cdef int Controller1ShiftRegister = 0
cdef int Controller2ShiftRegister = 0
cdef int controller1 = 0
cdef int controller2 = 0

cdef bool APUIRQEnabled = False

cdef bool APUFrameMode5 = False
cdef bool APUFrameIRQEnable = False
cdef int APUFrameCount = 0
cdef int APUPulse1Waveform = 0
cdef int APUPulse1Timer = 0
cdef int APUPulse1TimerReset = 0
cdef int APUPulse1Length = 0
cdef bool APUPulse1ClockEn = False
cdef bool APUPulse1Enable = False
cdef int APUPulse2Waveform = 0
cdef int APUPulse2Timer = 0
cdef int APUPulse2TimerReset = 0
cdef int APUPulse2Length = 0
cdef bool APUPulse2ClockEn = False
cdef bool APUPulse2Enable = False

cdef list APULengthValues = [10,254,20,2,40,4,80,6,160,8,60,10,14,12,26,14,12,16,24,18,48,20,96,22,192,24,72,26,16,28,32,30]

cdef list audioBatch = []

cpdef list drainAudioBuffer():
    global audioBatch
    cdef list out = audioBatch
    audioBatch = []
    return out

cdef bool SSTMode = False
cdef unsigned char SSTRAM[0x10000]

cdef int NROMPRGSize = 0

cdef float APUFinalValue = 0.0

cpdef writeController1(value):
    global controller1
    controller1 = value

cpdef writeController2(value):
    global controller2
    controller2 = value

cpdef setRegs(a, x, y, pc, sp, flags):
    global A, X, Y, PC, SP, carry, zero, interruptDisable
    global decimal, overflow, negative
    A = a
    X = x
    Y = y
    PC = pc
    SP = sp
    carry = (flags&1)!=0
    zero = (flags&2)!=0
    interruptDisable = (flags&4)!=0
    decimal = (flags&8)!=0
    overflow = (flags&0x40)!=0
    negative = (flags&0x80)!=0

cpdef readRegs():
    global A, X, Y, PC, SP, carry, zero, interruptDisable
    global decimal, overflow, negative
    flags = 0
    flags += 1 if carry else 0
    flags += 2 if zero else 0
    flags += 4 if interruptDisable else 0
    flags += 8 if decimal else 0
    flags += 0x20
    flags += 0x40 if overflow else 0
    flags += 0x80 if negative else 0
    return A, X, Y, PC, SP, flags

cpdef setSSTRam(pos, value):
    global SSTRAM
    SSTRAM[pos] = value

cpdef readSSTRam(pos):
    global SSTRAM
    return SSTRAM[pos]

cpdef setSSTMode():
    global SSTMode
    SSTMode = True

cpdef clearSSTMode():
    global SSTMode
    SSTMode = False

cpdef SSTStep():
    emulateCPU()

cdef paletteColorsRaw = [0x65, 0x65, 0x65, 0x00, 0x2A, 0x84, 0x15, 0x13, 0xA2, 0x3A, 0x01, 0x9E, 0x59, 0x00, 0x7A, 0x6A, 0x00, 0x3E, 0x68, 0x08, 0x00, 0x53, 0x1D, 0x00, 0x32, 0x34, 0x00, 0x0D, 0x46, 0x00, 0x00, 0x4F, 0x00, 0x00, 0x4C, 0x09, 0x00, 0x3F, 0x4B, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xAE, 0xAE, 0xAE, 0x17, 0x5F, 0xD6, 0x43, 0x41, 0xFF, 0x75, 0x29, 0xFA, 0x9E, 0x1D, 0xCA, 0xB4, 0x20, 0x7B, 0xB1, 0x33, 0x22, 0x96, 0x4E, 0x00, 0x6A, 0x6C, 0x00, 0x39, 0x84, 0x00, 0x0F, 0x90, 0x00, 0x00, 0x8D, 0x33, 0x00, 0x7B, 0x8C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFE, 0xFE, 0xFE, 0x66, 0xAF, 0xFF, 0x93, 0x90, 0xFF, 0xC5, 0x78, 0xFF, 0xEE, 0x6C, 0xFF, 0xFF, 0x6F, 0xCA, 0xFF, 0x82, 0x71, 0xE6, 0x9E, 0x25, 0xBA, 0xBC, 0x00, 0x88, 0xD5, 0x01, 0x5E, 0xE1, 0x32, 0x47, 0xDD, 0x82, 0x4A, 0xCB, 0xDC, 0x4E, 0x4E, 0x4E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFE, 0xFE, 0xFE, 0xC0, 0xDE, 0xFF, 0xD2, 0xD1, 0xFF, 0xE7, 0xC7, 0xFF, 0xF8, 0xC2, 0xFF, 0xFF, 0xC3, 0xE9, 0xFF, 0xCB, 0xC4, 0xF5, 0xD7, 0xA5, 0xE2, 0xE3, 0x94, 0xCE, 0xED, 0x96, 0xBC, 0xF2, 0xAA, 0xB3, 0xF1, 0xCB, 0xB4, 0xE9, 0xF0, 0xB6, 0xB6, 0xB6, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
cdef unsigned char paletteColorsC[64*3]
cdef int _i
_i = 0
for _ in range(64):
    paletteColorsC[_i]   = paletteColorsRaw[_i]
    paletteColorsC[_i+1] = paletteColorsRaw[_i+1]
    paletteColorsC[_i+2] = paletteColorsRaw[_i+2]
    _i += 3

cdef int cycles = 0

frameBufferBA = bytearray(256*240*3)
cdef unsigned char[:] frameBuffer = frameBufferBA

cpdef getFrameBuffer():
    return frameBufferBA

cpdef get_frames():
    global frames
    return frames

cpdef fullReset():
    global PC, SP, A, X, Y
    global CPUHalted, drawNewFrame, frames
    global carry, zero, interruptDisable, decimal
    global overflow, negative
    global PPUwriteLatch, PPUtransferAddress, PPUVRAMAddress
    global PPUVRAMInc32, PPUReadBuffer, PPUDot, PPUScanline
    global PPUVBlank, PPUMask8pxMaskBG, PPUMask8pxMaskSprites
    global PPUMaskRenderBG, PPUMaskRenderSprites
    global PPUNametableSelect, PPUSpritePatternTable
    global PPUBGPatternTable, PPUUse8x16Sprites, PPUEnableNMI
    global NMILevelDetector, DoNMI, previousNMILevelDetector
    global PPUShiftRegisterPatternH, PPUShiftRegisterPatternL
    global PPUShiftRegisterAttributeH, PPUShiftRegisterAttributeL
    global PPU8StepPatternLowBitPlane, PPU8StepPatternHighBitPlane
    global PPU8StepAttribute, PPUAddressBus, PPU8StepTemp
    global PPU8StepNextCharacter, PPUScrollFineX, PPUtempVRAMAddress
    global PPUSpriteEvalTemp, PPUSecondaryOAMAddress
    global PPUSecondaryOAMFull, PPUOAMAddress, PPUSpriteEvalTick
    global PPUStatusOverflow, PPUStatusSprZeroHit
    global PPUScanlineContainsSpriteZero
    global PPUSpriteEvaluationOAMOverflowed, PPUSecondaryOAMSize
    global Controller1ShiftRegister, Controller2ShiftRegister
    global Controller1, Controller2
    global APUIRQEnabled
    global RAM, VRAM, PaletteRAM, OAM, SecondaryOAM
    global ROM, ROMHeader, CHRData
    global PPUSpriteShiftRegisterL, PPUSpriteShiftRegisterH
    global PPUSpriteAttribute, PPUSpritePattern
    global PPUSpriteXPosition, PPUSpriteYPosition
    global APUFrameMode5, APUFrameIRQEnable, APUFrameCount
    global APUPulse1Waveform, APUPulse1Timer, APUPulse1TimerReset
    global APUPulse1Length, APUPulse1ClockEn, APUPulse1Enable
    global APUPulse2Waveform, APUPulse2Timer, APUPulse2TimerReset
    global APUPulse2Length, APUPulse2ClockEn, APUPulse2Enable
    PC = 0xFFFC
    SP = 0xFD
    A = 0
    X = 0
    Y = 0

    CPUHalted = False
    drawNewFrame = False
    frames = 0

    carry = False
    zero = False
    interruptDisable = True
    decimal = False
    overflow = False
    negative = False

    PPUwriteLatch = False
    PPUtransferAddress = 0
    PPUVRAMAddress = 0
    PPUVRAMInc32 = False
    PPUReadBuffer = 0
    PPUDot = 0
    PPUScanline = 0
    PPUVBlank = False
    PPUMask8pxMaskBG = False
    PPUMask8pxMaskSprites = False
    PPUMaskRenderBG = False
    PPUMaskRenderSprites = False
    PPUNametableSelect = 0
    PPUSpritePatternTable = False
    PPUBGPatternTable = False
    PPUUse8x16Sprites = False
    PPUEnableNMI = False
    NMILevelDetector = False
    DoNMI = False
    previousNMILevelDetector = False
    PPUShiftRegisterPatternL = 0
    PPUShiftRegisterPatternH = 0
    PPUShiftRegisterAttributeL = 0
    PPUShiftRegisterAttributeH = 0
    PPU8StepPatternLowBitPlane = 0
    PPU8StepPatternHighBitPlane = 0
    PPU8StepAttribute = 0
    PPUAddressBus = 0
    PPU8StepTemp = 0
    PPU8StepNextCharacter = 0
    PPUScrollFineX = 0
    PPUtempVRAMAddress = 0
    PPUSpriteEvalTemp = 0
    PPUSecondaryOAMAddress = 0
    PPUSecondaryOAMFull = False
    PPUOAMAddress = 0
    PPUSpriteEvalTick = 0
    PPUStatusOverflow = False
    PPUStatusSprZeroHit = False
    PPUScanlineContainsSpriteZero = False
    PPUSpriteEvaluationOAMOverflowed = False
    PPUSecondaryOAMSize = 0

    Controller1ShiftRegister = 0
    Controller2ShiftRegister = 0
    controller1 = 0
    controller2 = 0

    APUIRQEnabled = False

    for i in range(0x800):
        RAM[i] = 0xFF
        VRAM[i] = 0
    for i in range(0x20):
        PaletteRAM[i] = 0
        SecondaryOAM[i] = 0
    for i in range(0x100):
        OAM[i] = 0
    for i in range(8):
        PPUSpriteShiftRegisterL[i] = 0
        PPUSpriteShiftRegisterH[i] = 0
        PPUSpriteAttribute[i] = 0
        PPUSpritePattern[i] = 0
        PPUSpriteXPosition[i] = 0
        PPUSpriteYPosition[i] = 0
    
    APUFrameMode5 = False
    APUFrameIRQEnable = False
    APUFrameCount = 0
    APUPulse1Waveform = 0
    APUPulse1Timer = 0
    APUPulse1TimerReset = 0
    APUPulse1Length = 0
    APUPulse1ClockEn = False
    APUPulse1Enable = False
    APUPulse2Waveform = 0
    APUPulse2Timer = 0
    APUPulse2TimerReset = 0
    APUPulse2Length = 0
    APUPulse2ClockEn = False
    APUPulse2Enable = False
    
    clearSSTMode()

cpdef loadRom(path):
    global ROMHeader, ROM, CHRData
    global NROMPRGSize
    f = open(path, 'rb')
    for i in range(0x10):
        ROMHeader[i] = int.from_bytes(f.read(1))
    NROMPRGSize = ROMHeader[4]
    for i in range(NROMPRGSize*0x4000):
        ROM[i] = int.from_bytes(f.read(1))
    for i in range(ROMHeader[5]*0x2000):
        CHRData[i] = int.from_bytes(f.read(1))
    f.close()

cpdef reset():
    global PC, SP, interruptDisable, cycles
    global APUPulse1Enable, APUPulse1ClockEn
    global APUPulse2Enable, APUPulse2ClockEn
    global APUFrameCount
    PC = (read(0xFFFD)<<8)|read(0xFFFC)
    SP = 0xFD
    interruptDisable = True

    APUFrameCount = 0
    APUPulse1Enable = False
    APUPulse1ClockEn = False
    APUPulse2Enable = False
    APUPulse2ClockEn = False

    cycles = 0

cdef int read(int address):
    global RAM, PPUVBlank, PPUwriteLatch, PPUReadBuffer
    global PPUVRAMAddress, ROM, PPUStatusOverflow
    global PPUStatusSprZeroHit, Controller1ShiftRegister
    global Controller2ShiftRegister, NROMPRGSize
    global APUPulse1Length, APUPulse2Length
    global SSTMode, SSTRAM
    cdef int temp, ppustatus, controllerBit
    address &= 0xFFFF
    if SSTMode:
        return SSTRAM[address]
    if address < 0x2000:
        return RAM[address&0x7FF]
    elif address < 0x4000:
        address &= 0x2007
        if address == 0x2002:
            ppustatus = 0
            if PPUVBlank:
                ppustatus |= 0x80
            if PPUStatusSprZeroHit:
                ppustatus |= 0x40
            if PPUStatusOverflow:
                ppustatus |= 0x20
            PPUVBlank = False
            PPUwriteLatch = False
            return ppustatus
        elif address == 0x2007:
            temp = PPUReadBuffer
            if PPUVRAMAddress >= 0x3F00:
                temp = ReadPPU(PPUVRAMAddress)
            else:
                PPUReadBuffer = ReadPPU(PPUVRAMAddress)
            if PPUVRAMInc32:
                PPUVRAMAddress += 32
            else:
                PPUVRAMAddress += 1
            PPUVRAMAddress &= 0x3FFF
            return temp
        else:
            return 0
    elif address == 0x4015:
        temp = 0
        if APUPulse1Length > 0:
            temp |= 1
        if APUPulse2Length > 0:
            temp |= 2
        return temp
    elif address == 0x4016:
        controllerBit = ((Controller1ShiftRegister&0x80)>>7)&0xFF
        Controller1ShiftRegister <<= 1
        Controller1ShiftRegister &= 0xFF
        return controllerBit
    elif address == 0x4017:
        controllerBit = ((Controller2ShiftRegister&0x80)>>7)&0xFF
        Controller2ShiftRegister <<= 1
        Controller2ShiftRegister &= 0xFF
        return controllerBit
    elif address >= 0x8000:
        return ROM[(address-0x8000) & ((NROMPRGSize*0x4000)-1)]
    else:
        return 0

cdef void write(int address, int value):
    global RAM, PPUNametableSelect, PPUVRAMInc32, PPUSpritePatternTable
    global PPUBGPatternTable, PPUUse8x16Sprites, PPUEnableNMI, PPUVRAMAddress
    global PPUMask8pxMaskBG, PPUMask8pxMaskSprites, PPUMaskRenderBG
    global PPUMaskRenderSprites, PPUwriteLatch, PPUScrollFineX
    global PPUtempVRAMAddress, ROMHeader, CHRData, VRAM, PaletteRAM
    global Controller1ShiftRegister, Controller2ShiftRegister
    global controller1, controller2, SSTMode, SSTRAM, APULengthValues
    global APUPulse1Waveform, APUPulse1Timer, APUPulse1TimerReset
    global APUPulse2Waveform, APUPulse2Timer, APUPulse2TimerReset
    global APUPulse1ClockEn, APUPulse1Length
    global APUPulse2ClockEn, APUPulse2Length
    global APUPulse1Enable, APUPulse2Enable
    global APUFrameMode5, APUFrameIRQEnable, APUFrameCount
    cdef int i, dutyCycle
    address &= 0xFFFF
    value &= 0xFF
    if SSTMode:
        SSTRAM[address] = value
        return
    if address < 0x2000:
        RAM[address&0x7FF] = value
    elif address < 0x4000:
        address &= 0x2007
        if address == 0x2000:
            # PPUCTRL
            PPUNametableSelect = value&3
            PPUtempVRAMAddress = (PPUtempVRAMAddress & (~0x0C00 & 0xFFFF)) | ((value & 3) << 10)
            PPUVRAMInc32 = (value&4) != 0
            PPUSpritePatternTable = (value&8) != 0
            PPUBGPatternTable = (value&0x10) != 0
            PPUUse8x16Sprites = (value&0x20) != 0
            PPUEnableNMI = (value&0x80) != 0
        elif address == 0x2001:
            # PPUMASK
            PPUMask8pxMaskBG = (value&2) != 0
            PPUMask8pxMaskSprites = (value&4) != 0
            PPUMaskRenderBG = (value&8) != 0
            PPUMaskRenderSprites = (value&0x10) != 0
        elif address == 0x2002:
            # PPUSTATUS
            pass
        elif address == 0x2003:
            # OAMADDR
            pass
        elif address == 0x2004:
            # OAMDATA
            pass
        elif address == 0x2005:
            # PPUSCROLL
            if not PPUwriteLatch:
                PPUScrollFineX = value & 7
                PPUtempVRAMAddress = (PPUtempVRAMAddress & ~0x001F) | (value >> 3)
            else:
                PPUtempVRAMAddress = (PPUtempVRAMAddress & (~0x73E0 & 0x7FFF)) | ((value & 0xF8) << 2) | ((value & 0x07) << 12)
            PPUwriteLatch = not PPUwriteLatch
        elif address == 0x2006:
            # PPUADDR
            if not PPUwriteLatch:
                PPUtempVRAMAddress = ((PPUtempVRAMAddress & 0x00FF) | ((value & 0x3F) << 8)) & 0xFFFF
            else:
                PPUtempVRAMAddress = (PPUtempVRAMAddress & 0xFF00) | value
                PPUVRAMAddress = PPUtempVRAMAddress
            PPUwriteLatch = not PPUwriteLatch
        elif address == 0x2007:
            # PPUDATA
            if PPUVRAMAddress < 0x2000:
                # Pattern table if supported
                if ROMHeader[5] == 0:
                    CHRData[PPUVRAMAddress] = value
            elif PPUVRAMAddress < 0x3F00:
                # Nametables
                if (ROMHeader[6]&1) == 0:
                    # horiz mirroring
                    VRAM[(PPUVRAMAddress&0x3FF)|(PPUVRAMAddress&0x800)>>1] = value
                else:
                    # vert mirroring
                    VRAM[PPUVRAMAddress&0x7FF] = value
            else:
                # Palette RAM
                if (PPUVRAMAddress&3) == 0:
                    PaletteRAM[PPUVRAMAddress&0xF] = value
                else:
                    PaletteRAM[PPUVRAMAddress&0x1F] = value
            if PPUVRAMInc32:
                PPUVRAMAddress += 32
            else:
                PPUVRAMAddress += 1
            PPUVRAMAddress &= 0x3FFF
    elif address == 0x4000:
        dutyCycle = value>>6
        if dutyCycle == 0:
            APUPulse1Waveform = 0b00000001
        elif dutyCycle == 1:
            APUPulse1Waveform = 0b00000011
        elif dutyCycle == 2:
            APUPulse1Waveform = 0b00001111
        else:
            APUPulse1Waveform = 0b11111100
        APUPulse1ClockEn = (value&0x20) == 0
    elif address == 0x4002:
        APUPulse1TimerReset = (APUPulse1TimerReset&0x700)|value
        APUPulse1Timer = APUPulse1TimerReset
    elif address == 0x4003:
        APUPulse1TimerReset = ((value&7)<<8)|(APUPulse1TimerReset&0xFF)
        APUPulse1Timer = APUPulse1TimerReset
        APUPulse1Length = APULengthValues[value>>3]
    elif address == 0x4004:
        dutyCycle = value>>6
        if dutyCycle == 0:
            APUPulse2Waveform = 0b00000001
        elif dutyCycle == 1:
            APUPulse2Waveform = 0b00000011
        elif dutyCycle == 2:
            APUPulse2Waveform = 0b00001111
        else:
            APUPulse2Waveform = 0b11111100
        APUPulse2ClockEn = (value&0x20) == 0
    elif address == 0x4006:
        APUPulse2TimerReset = (APUPulse2TimerReset&0x700)|value
        APUPulse2Timer = APUPulse2TimerReset
    elif address == 0x4007:
        APUPulse2TimerReset = ((value&7)<<8)|(APUPulse2TimerReset&0xFF)
        APUPulse2Timer = APUPulse2TimerReset
        APUPulse2Length = APULengthValues[value>>3]
    elif address == 0x4014:
        # OAM DMA
        # This is an extreme corner cut
        #  but it works
        for i in range(256):
            OAM[i] = read(((value<<8)+i)&0xFFFF)
    elif address == 0x4015:
        APUPulse1Enable = (value&1) != 0
        APUPulse2Enable = (value&2) != 0
    elif address == 0x4016:
        # Controller
        Controller1ShiftRegister = controller1
        Controller2ShiftRegister = controller2
    elif address == 0x4017:
        APUFrameMode5 = (value&0x80) != 0
        APUFrameIRQEnable = (value&0x40) == 0
        APUFrameCount = 0

cdef int ReadPPU(int address):
    global VRAM, ROMHeader, PaletteRAM
    if address < 0x2000:
        return CHRData[address]
    elif address < 0x3F00:
        if (ROMHeader[6]&1) == 0:
            return VRAM[(address&0x3FF)|(address&0x800)>>1]
        else:
            return VRAM[address&0x7FF]
    else:
        if (address&3) == 0:
            return PaletteRAM[address&0xF]
        else:
            return PaletteRAM[address&0x1F]

cdef void push(int value):
    global SP
    value &= 0xFF
    write(0x100+SP, value)
    SP = SP-1

cdef void pushWord(int value):
    value &= 0xFFFF
    push(value>>8)
    push(value&0xFF)

cdef int pull():
    global SP
    SP = SP+1
    return read(0x100+SP)

cdef int pullWord():
    cdef int low, high
    low = pull()
    high = pull()
    return (high<<8)|low

cpdef run():
    global CPUHalted, drawNewFrame, frames
    while not CPUHalted:
        emulateCPU()
        if drawNewFrame:
            drawNewFrame = False
            break
    frames += 1

cdef int readPCByte():
    global PC
    PC = PC+1
    return read(PC-1)

cdef int readPCWord():
    cdef int low
    low = readPCByte()
    return (readPCByte()<<8)|low

cdef void ZNFlags(int value):
    global zero, negative
    value &= 0xFF
    zero = value == 0
    negative = value > 127

cdef void branch(int to, bool condition):
    global PC, cycles
    cdef int oldPC
    if condition:
        to &= 0xFF
        oldPC = PC
        if to > 127:
            to -= 256
        PC = PC + to
        cycles += 3
        if (oldPC&0xFF00) != (PC&0xFF00):
            cycles += 1
    else:
        cycles += 2

cdef int asl(int value):
    global carry
    carry = value > 127
    value <<= 1
    ZNFlags(value)
    return value

cdef int rol(int value):
    global carry
    cdef bool futureCarry
    futureCarry = value > 127
    value <<= 1
    if carry:
        value |= 1
    carry = futureCarry
    ZNFlags(value)
    return value

cdef int lsr(int value):
    global carry
    carry = (value&1) != 0
    value >>= 1
    ZNFlags(value)
    return value

cdef int ror(int value):
    global carry
    cdef bool futureCarry
    futureCarry = (value&1) != 0
    value >>= 1
    if carry:
        value |= 0x80
    carry = futureCarry
    ZNFlags(value)
    return value

cdef int inc(int value):
    value += 1
    value &= 0xFF
    ZNFlags(value)
    return value

cdef int dec(int value):
    value -= 1
    value &= 0xFF
    ZNFlags(value)
    return value

cdef void ora(int value):
    global A
    A = A | value
    ZNFlags(A)

cdef void andop(int value):
    global A
    A = A & value
    ZNFlags(A)

cdef void eor(int value):
    global A
    A = A ^ value
    ZNFlags(A)

cdef void adc(int value):
    global A, overflow, carry
    cdef int intSum
    intSum = value + A + (1 if carry else 0)
    overflow = (~(A^value)&(A^intSum)&0x80) != 0
    carry = intSum > 0xFF
    A = intSum&0xFF
    ZNFlags(A)

cdef void sbc(int value):
    global A, overflow, carry
    cdef int intSum
    intSum = A - value - (0 if carry else 1)
    overflow = ((A^value)&(A^intSum)&0x80) != 0
    carry = intSum >= 0
    A = intSum&0xFF
    ZNFlags(A)

cdef void cmp(int value, int reg):
    global carry, zero, negative
    carry = value <= reg
    zero = value == reg
    negative = ((reg-value)&0xFF) > 127

cdef void bit(int value):
    global zero, negative, overflow
    zero = (A&value) == 0
    negative = (value&0x80) != 0
    overflow = (value&0x40) != 0

cdef int Yindexed():
    global Y
    cdef int tempAddr, addr
    addr = readPCByte()
    tempAddr = addr
    addr = read(tempAddr)
    tempAddr += 1
    tempAddr &= 0xFF
    addr = ((read(tempAddr)<<8)|addr)&0xFFFF
    return addr + Y

cdef int Xindexed():
    global X
    cdef int tempAddr, addr
    addr = (readPCByte()+X)&0xFF
    tempAddr = addr
    addr = read(tempAddr)
    tempAddr += 1
    tempAddr &= 0xFF
    return ((read(tempAddr)<<8)|addr)&0xFFFF

cdef void emulateCPU():
    global previousNMILevelDetector, NMILevelDetector, DoNMI, SSTMode
    global A, X, Y, PC, SP, carry, zero, interruptDisable, decimal, overflow
    global cycles, CPUHalted, negative, PPUDot, PPUScanline, frames
    global APUFrameCount, APUFrameMode5, APUFrameIRQEnable
    global APUIRQEnabled
    cdef int opcode
    previousNMILevelDetector = NMILevelDetector
    NMILevelDetector = PPUEnableNMI and PPUVBlank
    if (not previousNMILevelDetector) and NMILevelDetector:
        DoNMI = True
    if DoNMI or ((APUIRQEnabled) and (not interruptDisable)):
        opcode = 0x00
    else:
        opcode = readPCByte()
    cdef int oldcycles = cycles
    cdef int temp, address, tempLow, tempHigh
    cdef int low, high, i
    if opcode == 0x00:
        # BRK
        if not DoNMI:
            PC = PC+1
        push(PC>>8)
        push(PC&0xFF)
        temp = 0
        temp += 1 if carry else 0
        temp += 2 if zero else 0
        temp += 4 if interruptDisable else 0
        temp += 8 if decimal else 0
        temp += 0 if DoNMI else 0x10
        temp += 0x20
        temp += 0x40 if overflow else 0
        temp += 0x80 if negative else 0
        push(temp)
        PC = (read(0xFFFB if DoNMI else 0xFFFF)<<8)|read(0xFFFA if DoNMI else 0xFFFE)
        interruptDisable = True
        DoNMI = False
        cycles += 7
    elif opcode == 0x01:
        # ORA x indexed
        ora(read(Xindexed()))
        cycles += 6
    elif opcode == 0x02:
        # HLT
        CPUHalted = True
        cycles += 2
    elif opcode == 0x05:
        # ORA zero page
        ora(read(readPCByte()))
        cycles += 3
    elif opcode == 0x06:
        # ASL zero page
        address = readPCByte()
        write(address, asl(read(address)))
        cycles += 5
    elif opcode == 0x08:
        # PHP
        temp = 0
        temp += 1 if carry else 0
        temp += 2 if zero else 0
        temp += 4 if interruptDisable else 0
        temp += 8 if decimal else 0
        temp += 0x10
        temp += 0x20
        temp += 0x40 if overflow else 0
        temp += 0x80 if negative else 0
        push(temp)
        cycles += 3
    elif opcode == 0x09:
        # ORA immediate
        ora(readPCByte())
        cycles += 2
    elif opcode == 0x0A:
        # ASL A
        A = asl(A)
        cycles += 2
    elif opcode == 0x0D:
        # ORA absolute
        ora(read(readPCWord()))
        cycles += 4
    elif opcode == 0x0E:
        # ASL absolute
        address = readPCWord()
        write(address, asl(read(address)))
        cycles += 6
    elif opcode == 0x10:
        # BPL
        branch(readPCByte(), not negative)
    elif opcode == 0x11:
        # ORA y indexed
        ora(read(Yindexed()))
        cycles += 5
    elif opcode == 0x15:
        # ORA zero page, x
        ora(read((readPCByte()+X)&0xFF))
        cycles += 4
    elif opcode == 0x16:
        # ASL zero page, x
        address = readPCByte()+X
        write(address&0xFF, asl(read(address&0xFF)))
        cycles += 6
    elif opcode == 0x18:
        # CLC
        carry = False
        cycles += 2
    elif opcode == 0x19:
        # ORA absolute, y
        ora(read((readPCWord()+Y)&0xFFFF))
        cycles += 4
    elif opcode == 0x1D:
        # ORA absolute, x
        ora(read((readPCWord()+X)&0xFFFF))
        cycles += 4
    elif opcode == 0x1E:
        # ASL absolute, x
        address = readPCWord()+X
        write(address&0xFFFF, asl(read(address&0xFFFF)))
        cycles += 7
    elif opcode == 0x20:
        # JSR
        pushWord(PC+1)
        PC = readPCWord()
        cycles += 6
    elif opcode == 0x21:
        # AND x indexed
        andop(read(Xindexed()))
        cycles += 6
    elif opcode == 0x24:
        # BIT zero page
        bit(read(readPCByte()))
        cycles += 3
    elif opcode == 0x25:
        # AND zero page
        andop(read(readPCByte()))
        cycles += 3
    elif opcode == 0x26:
        # ROL zero page
        address = readPCByte()
        write(address, rol(read(address)))
        cycles += 5
    elif opcode == 0x28:
        # PLP
        temp = pull()
        carry = (temp&1)!=0
        zero = (temp&2)!=0
        interruptDisable = (temp&4)!=0
        decimal = (temp&8)!=0
        overflow = (temp&0x40)!=0
        negative = (temp&0x80)!=0
        cycles += 3
    elif opcode == 0x29:
        # AND immediate
        andop(readPCByte())
        cycles += 2
    elif opcode == 0x2A:
        # ROL A
        A = rol(A)
        cycles += 2
    elif opcode == 0x2C:
        # BIT absolute
        bit(read(readPCWord()))
        cycles += 4
    elif opcode == 0x2D:
        # AND absolute
        andop(read(readPCWord()))
        cycles += 4
    elif opcode == 0x2E:
        # ROL absolute
        address = readPCWord()
        write(address, rol(read(address)))
        cycles += 6
    elif opcode == 0x30:
        # BMI
        branch(readPCByte(), negative)
    elif opcode == 0x31:
        # AND Y indexed
        andop(read(Yindexed()))
        cycles += 5
    elif opcode == 0x35:
        # AND zero page, x
        andop(read((readPCByte()+X)&0xFF))
        cycles += 4
    elif opcode == 0x36:
        # ROL zero page, x
        address = readPCByte()+X
        write(address&0xFF, rol(read(address&0xFF)))
        cycles += 6
    elif opcode == 0x38:
        # SEC
        carry = True
        cycles += 2
    elif opcode == 0x39:
        # AND absolute, y
        andop(read((readPCWord()+Y)&0xFFFF))
        cycles += 4
    elif opcode == 0x3D:
        # AND absolute, x
        andop(read((readPCWord()+X)&0xFFFF))
        cycles += 4
    elif opcode == 0x3E:
        # ROL absolute, x
        address = readPCWord()+X
        write(address&0xFFFF, rol(read(address&0xFFFF)))
        cycles += 7
    elif opcode == 0x40:
        # RTI
        temp = pull()
        carry = (temp&1) != 0
        zero = (temp&2) != 0
        interruptDisable = (temp&4) != 0
        decimal = (temp&8) != 0
        overflow = (temp&0x40) != 0
        negative = (temp&0x80) != 0
        tempLow = pull()
        tempHigh = pull()
        PC = (tempHigh<<8)|tempLow
        cycles += 6
    elif opcode == 0x41:
        # EOR x indexed
        eor(read(Xindexed()))
        cycles += 6
    elif opcode == 0x45:
        # EOR zero page
        eor(read(readPCByte()))
        cycles += 3
    elif opcode == 0x46:
        # LSR zero page
        address = readPCByte()
        write(address, lsr(read(address)))
        cycles += 5
    elif opcode == 0x48:
        # PHA
        push(A)
        cycles += 3
    elif opcode == 0x49:
        # EOR immediate
        eor(readPCByte())
        cycles += 2
    elif opcode == 0x4A:
        # LSR A
        A = lsr(A)
        cycles += 2
    elif opcode == 0x4C:
        # JMP absolute
        PC = readPCWord()
        cycles += 3
    elif opcode == 0x4D:
        # EOR absolute
        eor(read(readPCWord()))
        cycles += 4
    elif opcode == 0x4E:
        # LSR absolute
        address = readPCWord()
        write(address, lsr(read(address)))
        cycles += 6
    elif opcode == 0x50:
        # BVC
        branch(readPCByte(), not overflow)
    elif opcode == 0x51:
        # EOR y indexed
        eor(read(Yindexed()))
        cycles += 5
    elif opcode == 0x55:
        # EOR zero page, x
        eor(read((readPCByte()+X)&0xFF))
        cycles += 4
    elif opcode == 0x56:
        # LSR zero page, x
        address = readPCByte()+X
        write(address&0xFF, lsr(read(address&0xFF)))
        cycles += 6
    elif opcode == 0x58:
        # CLI
        interruptDisable = False
        cycles += 2
    elif opcode == 0x59:
        # EOR absolute, y
        eor(read((readPCWord()+Y)&0xFFFF))
        cycles += 4
    elif opcode == 0x5D:
        # EOR absolute
        eor(read((readPCWord()+X)&0xFFFF))
        cycles += 4
    elif opcode == 0x5E:
        # LSR absolute, x
        address = readPCWord()+X
        write(address&0xFFFF, lsr(read(address&0xFFFF)))
        cycles += 7
    elif opcode == 0x60:
        # RTS
        PC = pullWord()+1
        cycles += 6
    elif opcode == 0x61:
        # ADC x indexed
        adc(read(Xindexed()))
        cycles += 6
    elif opcode == 0x65:
        # ADC zero page
        adc(read(readPCByte()))
        cycles += 3
    elif opcode == 0x66:
        # ROR zero page
        address = readPCByte()
        write(address, ror(read(address)))
        cycles += 5
    elif opcode == 0x68:
        # PLA
        A = pull()
        ZNFlags(A)
        cycles += 4
    elif opcode == 0x69:
        # ADC immediate
        adc(readPCByte())
        cycles += 2
    elif opcode == 0x6A:
        # ROR A
        A = ror(A)
        cycles += 2
    elif opcode == 0x6C:
        # JMP indirect
        address = readPCWord()
        low = read(address)
        high = read((address & 0xFF00) | ((address + 1) & 0x00FF))  # page-wrap bug
        PC = (high << 8) | low
        cycles += 5
    elif opcode == 0x6D:
        # ADC absolute
        adc(read(readPCWord()))
        cycles += 4
    elif opcode == 0x6E:
        # ROR absolute
        address = readPCWord()
        write(address, ror(read(address)))
        cycles += 6
    elif opcode == 0x70:
        # BVS
        branch(readPCByte(), overflow)
    elif opcode == 0x71:
        # ADC y indexed
        adc(read(Yindexed()))
        cycles += 5
    elif opcode == 0x75:
        # ADC zero page, x
        adc(read((readPCByte()+X)&0xFF))
        cycles += 4
    elif opcode == 0x76:
        # ROR zero page, x
        address = readPCByte()+X
        write(address&0xFF, ror(read(address&0xFF)))
        cycles += 6
    elif opcode == 0x78:
        # SEI
        interruptDisable = True
        cycles += 2
    elif opcode == 0x79:
        # ADC absolute, y
        adc(read((readPCWord()+Y)&0xFFFF))
        cycles += 4
    elif opcode == 0x7D:
        # ADC absolute, x
        adc(read((readPCWord()+X)&0xFFFF))
        cycles += 4
    elif opcode == 0x7E:
        # ROR absolute, x
        address = readPCWord()+X
        write(address&0xFFFF, ror(read(address&0xFFFF)))
        cycles += 7
    elif opcode == 0x81:
        # STA x indexed
        write(Xindexed(), A)
        cycles += 6
    elif opcode == 0x84:
        # STY zero page
        write(readPCByte(), Y)
        cycles += 3
    elif opcode == 0x85:
        # STA zero page
        write(readPCByte(), A)
        cycles += 3
    elif opcode == 0x86:
        # STX zero page
        write(readPCByte(), X)
        cycles += 3
    elif opcode == 0x88:
        # DEY
        Y = Y-1
        ZNFlags(Y)
        cycles += 2
    elif opcode == 0x8A:
        # TXA
        A = X
        ZNFlags(A)
        cycles += 2
    elif opcode == 0x8C:
        # STY absolute
        write(readPCWord(), Y)
        cycles += 4
    elif opcode == 0x8D:
        # STA absolute
        write(readPCWord(), A)
        cycles += 4
    elif opcode == 0x8E:
        # STX absolute
        write(readPCWord(), X)
        cycles += 4
    elif opcode == 0x90:
        # BCC
        branch(readPCByte(), not carry)
    elif opcode == 0x91:
        # STA y indexed
        write(Yindexed(), A)
        cycles += 6
    elif opcode == 0x94:
        # STY zero page, x
        write((readPCByte()+X)&0xFF, Y)
        cycles += 4
    elif opcode == 0x95:
        # STA zero page, x
        write((readPCByte()+X)&0xFF, A)
        cycles += 4
    elif opcode == 0x96:
        # STX zero page, y
        write((readPCByte()+Y)&0xFF, X)
        cycles += 4
    elif opcode == 0x98:
        # TYA
        A = Y
        ZNFlags(A)
        cycles += 2
    elif opcode == 0x99:
        # STA absolute, y
        write((readPCWord()+Y)&0xFFFF, A)
        cycles += 4
    elif opcode == 0x9A:
        # TXS
        SP = X
        cycles += 2
    elif opcode == 0x9D:
        # STA absolute, x
        write((readPCWord()+X)&0xFFFF, A)
        cycles += 4
    elif opcode == 0xA0:
        # LDY immediate
        Y = readPCByte()
        ZNFlags(Y)
        cycles += 2
    elif opcode == 0xA1:
        # LDA x indexed
        A = read(Xindexed())
        ZNFlags(A)
        cycles += 6
    elif opcode == 0xA2:
        # LDX immediate
        X = readPCByte()
        ZNFlags(X)
        cycles += 2
    elif opcode == 0xA4:
        # LDY zero page
        Y = read(readPCByte())
        ZNFlags(Y)
        cycles += 3
    elif opcode == 0xA5:
        # LDA zero page
        A = read(readPCByte())
        ZNFlags(A)
        cycles += 3
    elif opcode == 0xA6:
        # LDX zero page
        X = read(readPCByte())
        ZNFlags(X)
        cycles += 3
    elif opcode == 0xA8:
        # TAY
        Y = A
        ZNFlags(Y)
        cycles += 2
    elif opcode == 0xA9:
        # LDA immediate
        A = readPCByte()
        ZNFlags(A)
        cycles += 2
    elif opcode == 0xAA:
        # TAX
        X = A
        ZNFlags(X)
        cycles += 2
    elif opcode == 0xAC:
        # LDY absolute
        Y = read(readPCWord())
        ZNFlags(Y)
        cycles += 4
    elif opcode == 0xAE:
        # LDX absolute
        X = read(readPCWord())
        ZNFlags(X)
        cycles += 4
    elif opcode == 0xAD:
        # LDA absolute
        A = read(readPCWord())
        ZNFlags(A)
        cycles += 4
    elif opcode == 0xB0:
        # BCS
        branch(readPCByte(), carry)
    elif opcode == 0xB1:
        # LDA y indexed
        A = read(Yindexed())
        ZNFlags(A)
        cycles += 5
    elif opcode == 0xB4:
        # LDY zero page, x
        Y = read((readPCByte()+X)&0xFF)
        ZNFlags(Y)
        cycles += 4
    elif opcode == 0xB5:
        # LDA zero page, x
        A = read((readPCByte()+X)&0xFF)
        ZNFlags(A)
        cycles += 4
    elif opcode == 0xB6:
        # LDX zero page, y
        X = read((readPCByte()+Y)&0xFF)
        ZNFlags(X)
        cycles += 4
    elif opcode == 0xB8:
        # CLV
        overflow = False
        cycles += 2
    elif opcode == 0xB9:
        # LDA absolute, y
        A = read((readPCWord()+Y)&0xFFFF)
        ZNFlags(A)
        cycles += 4
    elif opcode == 0xBA:
        # TSX
        X = SP
        ZNFlags(X)
        cycles += 2
    elif opcode == 0xBC:
        # LDY absolute, x
        Y = read((readPCWord()+X)&0xFFFF)
        ZNFlags(Y)
        cycles += 4
    elif opcode == 0xBD:
        # LDA absolute, x
        A = read((readPCWord()+X)&0xFFFF)
        ZNFlags(A)
        cycles += 4
    elif opcode == 0xBE:
        # LDX absolute, y
        X = read((readPCWord()+Y)&0xFFFF)
        ZNFlags(X)
        cycles += 4
    elif opcode == 0xC0:
        # CPY immediate
        cmp(readPCByte(), Y)
        cycles += 2
    elif opcode == 0xC1:
        # CMP x indexed
        cmp(read(Xindexed()), A)
        cycles += 6
    elif opcode == 0xC4:
        # CPY zero page
        cmp(read(readPCByte()), Y)
        cycles += 3
    elif opcode == 0xC5:
        # CMP zero page
        cmp(read(readPCByte()), A)
        cycles += 3
    elif opcode == 0xC6:
        # DEC zero page
        address = readPCByte()
        write(address, dec(read(address)))
        cycles += 5
    elif opcode == 0xC8:
        # INY
        Y = Y+1
        ZNFlags(Y)
        cycles += 2
    elif opcode == 0xC9:
        # CMP immediate
        cmp(readPCByte(), A)
        cycles += 2
    elif opcode == 0xCA:
        # DEX
        X = X-1
        ZNFlags(X)
        cycles += 2
    elif opcode == 0xCC:
        # CPY absolute
        cmp(read(readPCWord()), Y)
        cycles += 4
    elif opcode == 0xCD:
        # CMP absolute
        cmp(read(readPCWord()), A)
        cycles += 4
    elif opcode == 0xCE:
        # DEC absolute
        address = readPCWord()
        write(address, dec(read(address)))
        cycles += 6
    elif opcode == 0xD0:
        # BNE
        branch(readPCByte(), not zero)
    elif opcode == 0xD1:
        # CMP y indexed
        cmp(read(Yindexed()), A)
        cycles += 5
    elif opcode == 0xD5:
        # CMP zero page, x
        cmp(read((readPCByte()+X)&0xFF), A)
        cycles += 4
    elif opcode == 0xD6:
        # DEC zero page, x
        address = readPCByte()+X
        write(address&0xFF, dec(read(address&0xFF)))
        cycles += 6
    elif opcode == 0xD8:
        # CLD
        decimal = False
        cycles += 2
    elif opcode == 0xD9:
        # CMP absolute, y
        cmp(read((readPCWord()+Y)&0xFFFF), A)
        cycles += 4
    elif opcode == 0xDD:
        # CMP absolute, x
        cmp(read((readPCWord()+X)&0xFFFF), A)
        cycles += 4
    elif opcode == 0xDE:
        # DEC absolute, x
        address = readPCWord()+X
        write(address&0xFFFF, dec(read(address&0xFFFF)))
        cycles += 7
    elif opcode == 0xE0:
        # CPX immediate
        cmp(readPCByte(), X)
        cycles += 2
    elif opcode == 0xE1:
        # SBC x indexed
        sbc(read(Xindexed()))
        cycles += 6
    elif opcode == 0xE4:
        # CPX zero page
        cmp(read(readPCByte()), X)
        cycles += 3
    elif opcode == 0xE5:
        # SBC zero page
        sbc(read(readPCByte()))
        cycles += 3
    elif opcode == 0xE6:
        # INC zero page
        address = readPCByte()
        write(address, inc(read(address)))
        cycles += 5
    elif opcode == 0xE8:
        # INX
        X = X+1
        ZNFlags(X)
        cycles += 2
    elif opcode == 0xE9:
        # SBC immediate
        sbc(readPCByte())
        cycles += 2
    elif opcode == 0xEA:
        # NOP
        cycles += 2
    elif opcode == 0xEC:
        # CPX absolute
        cmp(read(readPCWord()), X)
        cycles += 4
    elif opcode == 0xED:
        # SBC absolute
        sbc(read(readPCWord()))
        cycles += 4
    elif opcode == 0xEE:
        # INC absolute
        address = readPCWord()
        write(address, inc(read(address)))
        cycles += 6
    elif opcode == 0xF0:
        # BEQ
        branch(readPCByte(), zero)
    elif opcode == 0xF1:
        # SBC y indexed
        sbc(read(Yindexed()))
        cycles += 5
    elif opcode == 0xF5:
        # SBC zero page, x
        sbc(read((readPCByte()+X)&0xFF))
        cycles += 3
    elif opcode == 0xF6:
        # INC zero page, x
        address = readPCByte()+X
        write(address&0xFF, inc(read(address&0xFF)))
        cycles += 6
    elif opcode == 0xF8:
        # SED
        decimal = True
        cycles += 2
    elif opcode == 0xF9:
        # SBC absolute, y
        sbc(read((readPCWord()+Y)&0xFFFF))
        cycles += 4
    elif opcode == 0xFD:
        # SBC absolute, x
        sbc(read((readPCWord()+X)&0xFFFF))
        cycles += 4
    elif opcode == 0xFE:
        # INC absolute, x
        address = readPCWord()+X
        write(address&0xFFFF, inc(read(address&0xFFFF)))
        cycles += 7
    else:
        raise Exception(f"Unknown opcode of 0x{opcode:02x} at PC=0x{PC-1:04x}")
    if not SSTMode:
        for i in range(cycles-oldcycles):
            emulatePPU()
            emulatePPU()
            emulatePPU()
            if ((oldcycles+i)%2) == 0:
                # APU ticks every other CPU cycle
                emulateAPU()
            if ((oldcycles+i)%7445) == 0:
                # Every quarter of a frame
                APUFrameCount += 1
                if (APUFrameMode5 and (APUFrameCount == 5)) or ((not APUFrameMode5) and (APUFrameCount == 4)):
                    APUFrameCount = 0
                    APUIRQEnabled = (not APUFrameMode5) and APUFrameIRQEnable
                    tickAPULength()
                if APUFrameCount == 2:
                    tickAPULength()
    A &= 0xFF
    X &= 0xFF
    Y &= 0xFF
    PC &= 0xFFFF
    SP &= 0xFF

cdef void tickAPULength():
    global APUPulse1ClockEn, APUPulse1Length
    global APUPulse2ClockEn, APUPulse2Length
    if APUPulse1ClockEn and (APUPulse1Length > 0):
        APUPulse1Length -= 1
    if APUPulse2ClockEn and (APUPulse2Length > 0):
        APUPulse2Length -= 1

cdef void emulateAPU():
    global APUPulse1Timer, APUPulse1TimerReset, APUPulse1Waveform
    global APUPulse2Timer, APUPulse2TimerReset, APUPulse2Waveform
    global APUPulse1Enable, APUPulse2Enable
    global APUPulse1Length, APUPulse2Length
    global APUFinalValue, _audioBatch
    cdef float pulse1, pulse2
    pulse1 = 0.0
    pulse2 = 0.0

    if APUPulse1Enable:
        if APUPulse1TimerReset >= 8:
            if APUPulse1Length > 0:
                if APUPulse1Timer == 0:
                    APUPulse1Timer = APUPulse1TimerReset
                    APUPulse1Waveform = ((APUPulse1Waveform << 1) & 0xFF) | (APUPulse1Waveform >> 7)
                else:
                    APUPulse1Timer -= 1
                pulse1 = 1.0 if (APUPulse1Waveform & 0x80) != 0 else 0.0
    
    if APUPulse2Enable:
        if APUPulse2TimerReset >= 8:
            if APUPulse2Length > 0:
                if APUPulse2Timer == 0:
                    APUPulse2Timer = APUPulse2TimerReset
                    APUPulse2Waveform = ((APUPulse2Waveform << 1) & 0xFF) | (APUPulse2Waveform >> 7)
                else:
                    APUPulse2Timer -= 1
                pulse2 = 1.0 if (APUPulse2Waveform & 0x80) != 0 else 0.0

    APUFinalValue = (pulse1+pulse2)/2.0
    audioBatch.append(APUFinalValue)

cdef void emulatePPU():
    global PPUDot, PPUScanline, PPUVBlank, drawNewFrame
    global PPUMaskRenderBG, PPUMaskRenderSprites
    global PPUShiftRegisterPatternL, PPUShiftRegisterPatternH
    global PPUShiftRegisterAttributeL, PPUShiftRegisterAttributeH
    global PPUVRAMAddress, PPUAddressBus
    global PPU8StepTemp, PPU8StepNextCharacter, PPU8StepAttribute
    global PPU8StepPatternLowBitPlane, PPU8StepPatternHighBitPlane
    global PPUMask8pxMaskBG, PPUBGPatternTable, PPUScrollFineX
    global PPUSpriteAttribute, PPUSpriteXPosition, PPUStatusOverflow
    global PPUStatusSprZeroHit, PPUScanlineContainsSpriteZero
    global PPUSpriteShiftRegisterH, PPUSpriteShiftRegisterL
    global PPUMask8pxMaskSprites, PPUSecondaryOAMSize
    global PPUScanlineContainsSpriteZero
    cdef int cycleTick, PalLow, PalHi, col0, col1
    cdef int pal0, pal1, color_idx, fb_idx
    cdef int SpritePalHi, SpritePalLow, SpixelL, SpixelH
    cdef bool SpritePriority
    if (PPUMaskRenderBG or PPUMaskRenderSprites) and (PPUScanline < 240 or PPUScanline == 261):
        spriteEvaluation()

    if PPUDot == 1 and PPUScanline == 241:
        PPUVBlank = True
        drawNewFrame = True
    elif PPUDot == 1 and PPUScanline == 261:
        PPUVBlank = False
        PPUStatusOverflow = False
        PPUStatusSprZeroHit = False
    
    if (PPUScanline < 240) or (PPUScanline == 261):
        if (PPUDot > 0 and PPUDot <= 256) or (PPUDot > 320 and PPUDot <= 336):
            if PPUMaskRenderBG or PPUMaskRenderSprites:
                PPUShiftRegisterPatternL <<= 1
                PPUShiftRegisterPatternL &= 0xFFFF
                PPUShiftRegisterPatternH <<= 1
                PPUShiftRegisterPatternH &= 0xFFFF
                PPUShiftRegisterAttributeL <<= 1
                PPUShiftRegisterAttributeL &= 0xFFFF
                PPUShiftRegisterAttributeH <<= 1
                PPUShiftRegisterAttributeH &= 0xFFFF
                
                if PPUDot <= 256:
                    for i in range(8):
                        if PPUSpriteXPosition[i] > 0:
                            PPUSpriteXPosition[i] -= 1
                        else:
                            PPUSpriteShiftRegisterL[i] = (PPUSpriteShiftRegisterL[i]<<1)&0xFF
                            PPUSpriteShiftRegisterH[i] = (PPUSpriteShiftRegisterH[i]<<1)&0xFF

                cycleTick = (PPUDot-1)&7
                if cycleTick == 0:
                    PPUShiftRegisterPatternL = ((PPUShiftRegisterPatternL&0xFF00)|PPU8StepPatternLowBitPlane)&0xFFFF
                    PPUShiftRegisterPatternH = ((PPUShiftRegisterPatternH&0xFF00)|PPU8StepPatternHighBitPlane)&0xFFFF
                    PPUShiftRegisterAttributeL = ((PPUShiftRegisterAttributeL&0xFF00)|(0xFF if (PPU8StepAttribute&1)==1 else 0))&0xFFFF
                    PPUShiftRegisterAttributeH = ((PPUShiftRegisterAttributeH&0xFF00)|(0xFF if (PPU8StepAttribute&2)==2 else 0))&0xFFFF
                    PPUAddressBus = (0x2000 + (PPUVRAMAddress&0xFFF))
                    PPU8StepTemp = ReadPPU(PPUAddressBus)
                elif cycleTick == 1:
                    PPU8StepNextCharacter = PPU8StepTemp
                elif cycleTick == 2:
                    PPUAddressBus = (0x23C0|(PPUVRAMAddress&0xC00)|((PPUVRAMAddress>>4)&0x38)|((PPUVRAMAddress>>2)&0x7))
                    PPU8StepTemp = ReadPPU(PPUAddressBus)
                elif cycleTick == 3:
                    PPU8StepAttribute = PPU8StepTemp
                    if (PPUVRAMAddress&3) >= 2:
                        PPU8StepAttribute = (PPU8StepAttribute>>2)&0xFF
                    if (((PPUVRAMAddress&0b1111100000)>>5)&3) >= 2:
                        PPU8StepAttribute = (PPU8StepAttribute>>4)&0xFF
                    PPU8StepAttribute = PPU8StepAttribute&3
                elif cycleTick == 4:
                    PPUAddressBus = (((PPUVRAMAddress&0b111000000000000)>>12)|PPU8StepNextCharacter*16|(0x1000 if PPUBGPatternTable else 0))&0xFFFF
                    PPU8StepTemp = ReadPPU(PPUAddressBus)
                elif cycleTick == 5:
                    PPU8StepPatternLowBitPlane = PPU8StepTemp
                    PPUAddressBus += 8
                    PPUAddressBus &= 0xFFFF
                elif cycleTick == 6:
                    PPU8StepTemp = ReadPPU(PPUAddressBus)
                elif cycleTick == 7:
                    PPU8StepPatternHighBitPlane = PPU8StepTemp
                    if (PPUVRAMAddress&0x1F) == 31:
                        PPUVRAMAddress &= 0xFFE0
                        PPUVRAMAddress ^= 0x0400
                    else:
                        PPUVRAMAddress += 1
    
    if PPUMaskRenderBG or PPUMaskRenderSprites:
        if PPUDot == 256 and PPUScanline < 240:
            PPUIncrementScrollY()
        elif PPUDot == 257:
            PPUResetXScroll()
        if PPUDot >= 280 and PPUDot <= 304 and PPUScanline == 261:
            PPUResetYScroll()
    
        if PPUScanline < 240 and PPUDot > 0 and PPUDot <= 256:
            PalHi = 0
            PalLow = 0
            if PPUMaskRenderBG and (PPUDot > 8 or PPUMask8pxMaskBG):
                col0 = (((PPUShiftRegisterPatternL >> (15 - PPUScrollFineX)))&1)&0xFF
                col1 = (((PPUShiftRegisterPatternH >> (15 - PPUScrollFineX)))&1)&0xFF
                PalLow = ((col1<<1)|col0)&0xFF

                pal0 = (((PPUShiftRegisterAttributeL >> (15 - PPUScrollFineX)))&1)&0xFF
                pal1 = (((PPUShiftRegisterAttributeH >> (15 - PPUScrollFineX)))&1)&0xFF
                PalHi = ((pal1<<1)|pal0)&0xFF
                if (PalLow == 0 and PalHi != 0):
                    PalHi = 0
            SpritePalHi = 0
            SpritePalLow = 0
            SpritePriority = False
            if PPUMaskRenderSprites and (PPUDot>8 or PPUMask8pxMaskSprites):
                for i in range(8):
                    if PPUSpriteXPosition[i] == 0 and i < (PPUSecondaryOAMSize//4):
                        SpixelL = ((PPUSpriteShiftRegisterL[i])&0x80) != 0
                        SpixelH = ((PPUSpriteShiftRegisterH[i])&0x80) != 0
                        SpritePalLow = 0
                        if SpixelL:
                            SpritePalLow = 1
                        if SpixelH:
                            SpritePalLow |= 2
                        SpritePalHi = ((PPUSpriteAttribute[i]&0x03)|0x04)&0xFF
                        SpritePriority = ((PPUSpriteAttribute[i]>>5)&1) == 0
                        if SpritePalLow != 0:
                            if i == 0 and PPUScanlineContainsSpriteZero and PalLow != 0 and PPUMaskRenderBG and PPUDot < 255:
                                PPUStatusSprZeroHit = True
                            break
            if (SpritePriority and SpritePalLow != 0) or PalLow == 0:
                PalLow = SpritePalLow
                PalHi = SpritePalHi
                if PalLow == 0:
                    PalHi = 0
            color_idx = PaletteRAM[PalLow + PalHi*4] * 3
            fb_idx = (PPUScanline * 256 + (PPUDot-1)) * 3
            frameBuffer[fb_idx]   = paletteColorsC[color_idx]
            frameBuffer[fb_idx+1] = paletteColorsC[color_idx+1]
            frameBuffer[fb_idx+2] = paletteColorsC[color_idx+2]

    PPUDot += 1
    if PPUDot > 340:
        PPUDot = 0
        PPUScanline += 1
        if PPUScanline > 261:
            PPUScanline = 0

cdef void spriteEvaluation():
    global PPUDot, PPUSpriteEvalTemp, SecondaryOAM, PPUSecondaryOAMSize
    global PPUScanline, PPUSecondaryOAMAddress, PPUSecondaryOAMFull, OAM
    global PPUSpriteEvalTick, PPUOAMAddress, PPUUse8x16Sprites, PPUStatusOverflow
    global PPUSpriteEvaluationOAMOverflowed, PPUSpritePattern, PPUSpritePatternTable
    global PPUSpriteAttribute, PPUSpriteYPosition, PPUSpriteXPosition, PPUAddressBus
    global PPUSpriteShiftRegisterH, PPUSpriteShiftRegisterL, PPUScanlineContainsSpriteZero
    if PPUDot == 0:
        PPUSecondaryOAMAddress = 0
        PPUSecondaryOAMFull = False
        PPUSpriteEvaluationOAMOverflowed = False
        PPUScanlineContainsSpriteZero = False
        PPUSpriteEvalTick = 0
        PPUOAMAddress = 0
    elif PPUDot > 0 and PPUDot <= 64:
        if (PPUDot&1) == 1:
            PPUSpriteEvalTemp = 0xFF
        else:
            SecondaryOAM[(PPUDot>>1)-1] = PPUSpriteEvalTemp
            PPUSecondaryOAMAddress += 1
            PPUSecondaryOAMAddress &= 0x1F
    elif PPUDot > 64 and PPUDot <= 256:
        if (PPUDot&1) == 1:
            PPUSpriteEvalTemp = OAM[PPUOAMAddress]
        else:
            if not PPUSpriteEvaluationOAMOverflowed:
                if not PPUSecondaryOAMFull:
                    SecondaryOAM[PPUSecondaryOAMAddress] = PPUSpriteEvalTemp
                if PPUSpriteEvalTick == 0:
                    if PPUScanline - PPUSpriteEvalTemp >= 0 and PPUScanline - PPUSpriteEvalTemp < (16 if PPUUse8x16Sprites else 8):
                        if PPUSecondaryOAMFull:
                            PPUStatusOverflow = True
                        else:
                            PPUSecondaryOAMAddress += 1
                            PPUOAMAddress += 1
                            PPUOAMAddress &= 0xFF
                            if PPUDot == 66:
                                PPUScanlineContainsSpriteZero = True
                        PPUSpriteEvalTick += 1
                    else:
                        PPUOAMAddress += 4
                        PPUOAMAddress &= 0xFF
                else:
                    PPUSecondaryOAMAddress += 1
                    PPUOAMAddress += 1
                    PPUOAMAddress &= 0xFF
                    if PPUSecondaryOAMAddress == 0x20:
                        PPUSecondaryOAMFull = True
                    PPUSpriteEvalTick += 1
                    PPUSpriteEvalTick &= 3
                if PPUOAMAddress == 0:
                    PPUSpriteEvaluationOAMOverflowed = True
    elif PPUDot > 256 and PPUDot <= 320:
        PPUOAMAddress = 0
        if PPUDot == 257:
            PPUSecondaryOAMSize = PPUSecondaryOAMAddress
            PPUSecondaryOAMAddress = 0
            PPUSpriteEvalTick = 0
        if PPUSpriteEvalTick == 0:
            PPUSpriteYPosition[PPUSecondaryOAMAddress//4] = SecondaryOAM[PPUSecondaryOAMAddress]
            PPUSecondaryOAMAddress += 1
        elif PPUSpriteEvalTick == 1:
            PPUSpritePattern[PPUSecondaryOAMAddress//4] = SecondaryOAM[PPUSecondaryOAMAddress]
            PPUSecondaryOAMAddress += 1
        elif PPUSpriteEvalTick == 2:
            PPUSpriteAttribute[PPUSecondaryOAMAddress//4] = SecondaryOAM[PPUSecondaryOAMAddress]
            PPUSecondaryOAMAddress += 1
        elif PPUSpriteEvalTick == 3:
            PPUSpriteXPosition[PPUSecondaryOAMAddress//4] = SecondaryOAM[PPUSecondaryOAMAddress]
        elif PPUSpriteEvalTick == 4:
            if not PPUUse8x16Sprites:
                if ((PPUSpriteAttribute[PPUSecondaryOAMAddress//4]>>7)&1) == 0:
                    PPUAddressBus = ((0x1000 if PPUSpritePatternTable else 0) + (PPUSpritePattern[PPUSecondaryOAMAddress//4] << 4) + (PPUScanline - PPUSpriteYPosition[PPUSecondaryOAMAddress//4]))&0xFFFF
                else:
                    PPUAddressBus = ((0x1000 if PPUSpritePatternTable else 0) + (PPUSpritePattern[PPUSecondaryOAMAddress//4] << 4) + (7 - (PPUScanline - PPUSpriteYPosition[PPUSecondaryOAMAddress//4])))&0xFFFF
            else:
                if ((PPUSpriteAttribute[PPUSecondaryOAMAddress//4]>>7)&1) == 0:
                    if PPUScanline - PPUSpriteYPosition[PPUSecondaryOAMAddress//4] < 8:
                        PPUAddressBus = (((0x1000 if ((PPUSpritePattern[PPUSecondaryOAMAddress//4]&1) == 1) else 0) | ((PPUSpritePattern[PPUSecondaryOAMAddress//4]&0xFE)<<4)) + (PPUScanline - PPUSpriteYPosition[PPUSecondaryOAMAddress//4]))&0xFFFF
                    else:
                        PPUAddressBus = (((0x1000 if ((PPUSpritePattern[PPUSecondaryOAMAddress//4]&1) == 1) else 0) | (((PPUSpritePattern[PPUSecondaryOAMAddress//4]&0xFE)<<4)+16)) + ((PPUScanline - PPUSpriteYPosition[PPUSecondaryOAMAddress//4]) & 7))&0xFFFF
                else:
                    if PPUScanline - PPUSpriteYPosition[PPUSecondaryOAMAddress//4] < 8:
                        PPUAddressBus = (((0x1000 if ((PPUSpritePattern[PPUSecondaryOAMAddress//4]&1)==1) else 0) | (((PPUSpritePattern[PPUSecondaryOAMAddress//4]&0xFE)<<4)+16)) - ((PPUScanline - PPUSpriteYPosition[PPUSecondaryOAMAddress//4])&7)+7)&0xFFFF
                    else:
                        PPUAddressBus = (((0x1000 if ((PPUSpritePattern[PPUSecondaryOAMAddress//4]&1)==1) else 0) | (((PPUSpritePattern[PPUSecondaryOAMAddress//4]&0xFE)<<4)+7)) - ((PPUScanline - PPUSpriteYPosition[PPUSecondaryOAMAddress//4])&7))&0xFFFF
        elif PPUSpriteEvalTick == 5:
            PPUSpriteEvalTemp = ReadPPU(PPUAddressBus)
            if PPUScanline == 261:
                PPUSpriteEvalTemp = 0
            if ((PPUSpriteAttribute[PPUSecondaryOAMAddress//4]>>6)&1) == 1:
                PPUSpriteEvalTemp = (((PPUSpriteEvalTemp&0xF0)>>4)|((PPUSpriteEvalTemp&0xF)<<4))&0xFF
                PPUSpriteEvalTemp = (((PPUSpriteEvalTemp&0xCC)>>2)|((PPUSpriteEvalTemp&0x33)<<2))&0xFF
                PPUSpriteEvalTemp = (((PPUSpriteEvalTemp&0xAA)>>1)|((PPUSpriteEvalTemp&0x55)<<1))&0xFF
            PPUSpriteShiftRegisterL[PPUSecondaryOAMAddress//4] = PPUSpriteEvalTemp
        elif PPUSpriteEvalTick == 6:
            PPUAddressBus += 8
            PPUAddressBus &= 0xFFFF
        elif PPUSpriteEvalTick == 7:
            PPUSpriteEvalTemp = ReadPPU(PPUAddressBus)
            if PPUScanline == 261:
                PPUSpriteEvalTemp = 0
            if ((PPUSpriteAttribute[PPUSecondaryOAMAddress//4]>>6)&1) == 1:
                PPUSpriteEvalTemp = (((PPUSpriteEvalTemp&0xF0)>>4)|((PPUSpriteEvalTemp&0xF)<<4))&0xFF
                PPUSpriteEvalTemp = (((PPUSpriteEvalTemp&0xCC)>>2)|((PPUSpriteEvalTemp&0x33)<<2))&0xFF
                PPUSpriteEvalTemp = (((PPUSpriteEvalTemp&0xAA)>>1)|((PPUSpriteEvalTemp&0x55)<<1))&0xFF
            PPUSpriteShiftRegisterH[PPUSecondaryOAMAddress//4] = PPUSpriteEvalTemp
            PPUSecondaryOAMAddress += 1
        PPUSpriteEvalTick += 1
        PPUSpriteEvalTick &= 7

cdef void PPUIncrementScrollY():
    global PPUVRAMAddress
    cdef int y
    if (PPUVRAMAddress&0x7000) != 0x7000:
        PPUVRAMAddress += 0x1000
    else:
        PPUVRAMAddress &= 0x8FFF
        y = (PPUVRAMAddress&0x3E0)>>5
        if y == 29:
            y = 0
            PPUVRAMAddress ^= 0x800
        else:
            y += 1
            y &= 0x1F
        PPUVRAMAddress = ((PPUVRAMAddress&0xFC1F)|(y<<5))&0xFFFF

cdef void PPUResetXScroll():
    global PPUVRAMAddress, PPUtempVRAMAddress
    PPUVRAMAddress = ((PPUVRAMAddress & ~0x041F) | (PPUtempVRAMAddress & 0x041F)) & 0xFFFF

cdef void PPUResetYScroll():
    global PPUVRAMAddress, PPUtempVRAMAddress
    PPUVRAMAddress = ((PPUVRAMAddress & 0x041F) | (PPUtempVRAMAddress & ~0x041F)) & 0xFFFF