# Atari-DeepReinforcementLearning

Code from the paper 'Human-level control through deep reinforcement learning': https://sites.google.com/a/deepmind.com/dqn/




##DQN 3.0

This project contains the source code of DQN 3.0, a Lua-based deep reinforcement
learning architecture, necessary to reproduce the experiments
described in the paper "Human-level control through deep reinforcement
learning", Nature 518, 529–533 (26 February 2015) doi:10.1038/nature14236.

To replicate the experiment results, a number of dependencies need to be
installed, namely:<br />
  * LuaJIT and Torch 7.0<br />
  * nngraph<br />
  * Xitari (fork of the Arcade Learning Environment (Bellemare et al., 2013))<br />
  * AleWrap (a lua interface to Xitari)<br />
An install script for these dependencies is provided.

When all dependencies have been installed, you have to replace the code from 
'torch/share/lua/5.1/alewrap' with the code given in this project.

Two run scripts are provided:<br />
  - run_gpu: trains the DQN network using GPUs according to the given parameters<br />
  - test_tr: executes a performance test and show the game in the screen <br />



##Installation instructions

The installation requires Linux with apt-get.

Note: In order to run the GPU version of DQN, you should additionally have the
NVIDIA® CUDA® (version 5.5 or later) toolkit installed prior to the Torch
installation below.
This can be downloaded from https://developer.nvidia.com/cuda-toolkit
and installation instructions can be found in
http://docs.nvidia.com/cuda/cuda-getting-started-guide-for-linux


To train DQN on Atari games, the following components must be installed:<br />
  * LuaJIT and Torch 7.0<br />
  * nngraph<br />
  * Xitari<br />
  * AleWrap<br />

To install all of the above in a subdirectory called 'torch', it should be enough to run

    ./install_dependencies.sh

from the base directory of the package.


Note: The above install script will install the following packages via apt-get:
build-essential, gcc, g++, cmake, curl, libreadline-dev, git-core, libjpeg-dev,
libpng-dev, ncurses-dev, imagemagick, unzip



##Training DQN on Atari games

Prior to running DQN on a game, you should copy its ROM in the 'roms' subdirectory.
It should then be sufficient to run the script

    ./run_gpu <game name>


Note: On a system with more than one GPU, DQN training can be launched on a
specified GPU by setting the environment variable GPU_ID, e.g. by

    GPU_ID=2 ./run_gpu <game name>

If GPU_ID is not specified, the first available GPU (ID 0) will be used by default.



##Options

Options to DQN are set within run_cpu (respectively, run_gpu). You may,
for example, want to change the frequency at which information is output 
to stdout by setting 'prog_freq' to a different value.

