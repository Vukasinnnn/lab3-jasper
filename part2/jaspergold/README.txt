The scripts with name *_proofgrid* use proofgrid to run the proofs on multiple machines.
You are likely to have to change the name of the path and command used to send jobs to the farm in file
example_proofgrid_setup.tcl to whatever you use in your company 
Edit the file and change the command:
set_proofgrid_shell {<whatever your job dispatch command is>}
If you get it working then you can use that in all future labs.
