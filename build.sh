#!/usr/bin/env zsh
# This script builds the software package from source.

mcc -a ~/Code/Psychtoolbox/PsychBasic/PsychPlugins/ \
-a ~/Code/Psychtoolbox/PsychOpenGL/MOGL/core \
-a ~/Code/Psychtoolbox/PsychOpenGL/PsychGLSLShaders \
-a ~/Code/opticka/communication \
-a ~/Code/opticka/tools \
-a ~/Code/opticka/stimuli \
-a ~/Code/opticka/stimuli/lib \
-a ~/Code/opticka/ui/images \
-a ~/Code/opticka/help \
-a ~/Code/matlab-jzmq/ \
-a ~/Code/PTBSimia/ \
-a ~/Code/CageLab-Code \
-a ~/Code/CageLab-Code/+clutil \
-a ~/Code/CageLab-Code/+cltasks \
-a ~/Code/CageLab-Code/ui \
-R -startmsg,'Runtime Init START' \
-R -completemsg,'Runime Init FINISH' \
-d ~/build \
-m ~/Code/CageLab-Code/runCageLab.m
