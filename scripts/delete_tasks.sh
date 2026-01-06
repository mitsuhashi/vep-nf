squeue -u "$USER" -h -o "%i" | xargs -r scancel
