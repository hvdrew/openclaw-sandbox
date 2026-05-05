# DEFINITELY NOT READY - this script is a work in progress
# If you run into issues, try running through the README
# or manually entering the commands below one-by-one.

# Set up network policies to allow Ollama and nodesource for setup
sbx policy allow network localhost:11434
sbx policy allow network deb.nodesource.com

# Creates the shell environment for our sandbox
sbx create shell . --name openclaw
sbx run openclaw
# TODO: CREATE AN IMAGE THAT COMES READY TO GO WITH A SETUP SCRIPT
# CURRENTLY CAN'T RUN SETUP COMMANDS FROM HOST AS sbx run openclaw STARTS
# AN INTERACTIVE PROMPT.