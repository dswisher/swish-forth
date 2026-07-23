define fregs
    printf "IP  (s0) = 0x%08x\n", $s0
    printf "W   (s1) = 0x%08x\n", $s1
    printf "RSP (s2) = 0x%08x\n", $s2
    printf "DSP (s3) = 0x%08x\n", $s3
    printf "TMP (s4) = 0x%08x\n", $s4
end
document fregs
Display Forth registers: IP, W, RSP, DSP, TMP.
end
