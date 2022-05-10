set_proofgrid_mode shell; 
set_proofgrid_shell {/grid/sfi/farm/bin/bsub -W 2:0 -I -q interactive -R "OSNAME==Linux && OSREL==EE60" -R "rusage[mem=8000]"}; 
set_proofgrid_per_engine_max_jobs 30; 
set_proofgrid_per_engine_privileged_jobs 5
set_proofgrid_socket_communication off
