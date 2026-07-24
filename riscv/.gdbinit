
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

define fdstack
    set $dsp = $s3
    set $dsp_top = &dsp_top
    if $dsp == $dsp_top
        printf "Data stack: empty\n"
    else
        printf "Data stack (top first):\n"
        set $i = 0
        while $dsp < $dsp_top
            printf "  [%d] 0x%08x (%d)\n", $i, *(int*)$dsp, *(int*)$dsp
            set $dsp = $dsp + 4
            set $i = $i + 1
        end
    end
end
document fdstack
Display Forth data stack contents, top first.
end

define frstack
    set $rsp = $s2
    set $rsp_top = &rsp_top
    if $rsp == $rsp_top
        printf "Return stack: empty\n"
    else
        printf "Return stack (top first):\n"
        set $i = 0
        while $rsp < $rsp_top
            printf "  [%d] 0x%08x\n", $i, *(int*)$rsp
            set $rsp = $rsp + 4
            set $i = $i + 1
        end
    end
end
document frstack
Display Forth return stack contents, top first.
end
