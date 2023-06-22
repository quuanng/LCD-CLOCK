.text                           # IMPORTANT: subsequent stuff is executable
.global  set_tod_from_ports
        
## ENTRY POINT FOR REQUIRED FUNCTION
set_tod_from_ports:
        ## assembly instructions here
        ## %rdi is the pointer to the tod_t argument

        ## this block checks if the TIME_OF_DAY_PORT is valid
        movl    TIME_OF_DAY_PORT(%rip), %ecx
        cmpl    $0, %ecx
        jl      .FAIL
        cmpl    $1382400, %ecx
        jg      .FAIL
        ## this block rounds for day_secs and puts it into tod->day_secs
        sarl    $3, %ecx
        testl   $1, %ecx
        jz      .NOROUND

        sarl    $1, %ecx
        addl    $1, %ecx
        movl    %ecx, 0(%rdi)
        jmp     .AFTER
.NOROUND:
        sarl    $1, %ecx
        movl    %ecx, 0(%rdi)
.AFTER:
        ## setting hours, minutes, and ampm
        cmpl    $3600, 0(%rdi)
        jl      .HOURS

        movl    0(%rdi), %eax
        cqto
        movl    $3600, %esi
        idivl   %esi
        movw    %ax, 8(%rdi)
        jmp     .AFTER2
.HOURS:
        movw    $12, 8(%rdi)    ## for 12:00-12:59am time set
.AFTER2:
        cmpw    $12, 8(%rdi)
        je      .SETPM
        jl      .SETAM
        subw    $12, 8(%rdi)
        movb    $2, 10(%rdi)
        jmp     .AFTER3
.SETPM:
        cmpl    $3600, 0(%rdi)          ## test for my else condition if hours is 12 but am
        jle     .SETAM
        movb    $2, 10(%rdi)
        jmp     .AFTER3
.SETAM:
        movb    $1, 10(%rdi)
.AFTER3:
        ## this block uses division to get tod->time_mins and tod->time_secs
        movl    0(%rdi), %eax
        cqto
        movl    $3600, %esi
        idivl   %esi
        
        movl    %edx, %eax
        cqto
        movl    $60, %esi
        idivl   %esi

        movw    %ax, 6(%rdi)
        movw    %dx, 4(%rdi)

        movl $0, %eax
        ret

.FAIL:
        movl $1, %eax
        ret


### Data area associated with the next function
.data # IMPORTANT: use .data directive for data section

my_array:
        ## array for masking the display               
        .int 119              
        .int 36 
        .int 93
        .int 109
        .int 46
        .int 107
        .int 123
        .int 37
        .int 127
        .int 111


.text # IMPORTANT: switch back to executable code after .data section
.global  set_display_from_tod

## ENTRY POINT FOR REQUIRED FUNCTION
set_display_from_tod:
        ## assembly instructions here
        movq    %rdx, %r11                      ## %r11 holds the memory address of *diplay

        movq    $0b1111111111111111, %rax       # 16 1s for masking
        movq    %rdi, %rcx

        sarq    $32, %rcx
        andq    %rcx, %rax
        movq    %rax, %r8                       ## %r8 holds tod.time_secs
        
        cmpq    $0, %r8
        jl      .FAIL2
        cmpq    $59, %r8
        jg      .FAIL2

        movq    $0b1111111111111111, %rax
        sarq    $16, %rcx
        andq    %rcx, %rax
        movq    %rax, %r9                       ## %r9 holds tod.time_mins
        cmpq    $0, %r9
        jl      .FAIL2
        cmpq    $59, %r9
        jg      .FAIL2

        movq    %rsi, %rcx
        movl    $0b1111111111111111, %eax
        andl    %ecx, %eax
        movq    %rax, %r10                      ## %r10 holds tod.time_hours

        cmpq    $0, %r10
        jl      .FAIL2
        cmpq    $12, %r10
        jg      .FAIL2

        sarq    $16, %rsi                       ## %rsi holds tod.ampm
        movb    %sil, %cl
        cmpb    $2, %cl
        jg      .FAIL2
        cmpb    $1, %cl
        jl      .FAIL2

        ## initialize display with ampm
        movq    %rsi, %rcx                      ## %rdx used as temp var
        addq    $27, %rcx
        movq    $1, %rax                        ## %rax used as temp var
        salq    %cl, %rax                       ## done with %rdx
        movq    %rax, %rsi                      ## done with %rax and %rcx holds *display

        movq    %r11, %rcx                      ## %rcx now holds memory address of *display
        leaq    my_array(%rip), %r11            ## %r11 holds address of my_array

        movq    %r9, %rax
        cqto
        movq    $10, %rdi                       ## %rdi used as temp var
        idivq   %rdi                            ## done with %rdi
        orq     (%r11, %rdx, 4), %rsi           ## *display = *display | (mask[tod.time_mins % 10]);

        movq    (%r11, %rax, 4), %rdi           ## %rdi used as temp var
        salq    $7, %rdi
        orq     %rdi, %rsi                      ## *display = *display | (mask[tod.time_mins / 10] << 7);
                                        
        movq    %r10, %rax
        cqto
        movq    $10, %rdi                       ## %rdi used as temp var
        idivq   %rdi                            ## done with %rdi

        movq    (%r11, %rdx, 4), %rdi           ## %rdi used as temp var
        salq    $14, %rdi
        orq     %rdi, %rsi                      ## done with %rdi

        movq    %rcx, %rdx

        cmpq    $10, %r10
        jge     .SETSECONDHOURDIGIT
        movl    %esi, (%rdx)
        movl    $0, %eax
        ret
.SETSECONDHOURDIGIT:
        movq    (%r11, %rax, 4), %rdi           ## %rdi used as temp var
        salq    $21, %rdi
        orq     %rdi, %rsi                      ## done with %rdi
        movl    %esi, (%rdx)

        movl    $0, %eax
        ret

.FAIL2:
        movl    $1, %eax
        ret


.text
.global clock_update
        
## ENTRY POINT FOR REQUIRED FUNCTION
clock_update:
	## assembly instructions here
        movl    TIME_OF_DAY_PORT(%rip), %ecx
        cmpl    $0, %ecx
        jl      .FAIL3
        cmpl    $1382400, %ecx
        jg      .FAIL3

        subq    $24, %rsp 
        movl    $0, 0(%rsp) 
        movw    $0, 4(%rsp) 
        movw    $0, 6(%rsp) 
        movw    $0, 8(%rsp) 
        movb    $0, 10(%rsp) 
        leaq    (%rsp), %rdi 
        call    set_tod_from_ports 
        cmpl    $0, %eax                        ## checking for fail
        jne     .FAIL4

        leaq    CLOCK_DISPLAY_PORT(%rip), %rdx 
        movq    %rdi, %rax
        movq    (%rax), %rdi                    ## unpacking the tod
        movl    8(%rax), %esi                   ## last part into %esi
        call    set_display_from_tod 
        cmpl    $0, %eax                        ## checking for fail
        jne     .FAIL4
        addq    $24, %rsp

        movb    $0, %al
        ret
.FAIL3:
        movb    $1, %al
        ret
.FAIL4:
        addq    $24, %rsp
        ret