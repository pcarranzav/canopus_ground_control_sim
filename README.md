Canopus Ground Control Simulator
================================

Ground Control Simulator for Satellogic's cubesat platform. See http://github.com/satellogic/canopus

#Requirements
Ruby (developed and tested with Ruby 1.9.3)

#Usage
Download the cubesat code from Satellogic's repo.
Modify the telecommand key in src/lib/canopus/subsystem/nvram.c and build the software as described in Satellogic's README.
Modify it accordingly in cdh_server.rb.

Run the ground control console with:
    ruby cdh_server.rb
    
Then run the cubebug program.

To send a command, write it in hexadecimal, with each byte separated by a space.
For example:
    0 21
Will reset the satellite (0x00 is the PLATFORM subsystem, and 0x21 is the soft reset command).

Another example:
    2 36 1
Inhibits antenna deployment (0x02: CDH subsystem. 0x36: `SS_CMD_CDH_ANTENNA_DEPLOY_INHIBIT` command. 0x01: Set enabled to false.

See [the list of commands](http://github.com/satellogic/canopus/blob/master/src/include/canopus/subsystem/command.h) for more things to do...

#Contributing
I've just started with this. It took a while to understand the frame format. If you want to contribute, just fork, code and make a pull request.
It would be nice to beautify the code and develop a more friendly interface (maybe make a small web app with Sinatra or Cuba?).
