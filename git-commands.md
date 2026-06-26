#create a new repository on the command line
git init
git add .
git commit -m "ver-0.1r1m0"
git branch -M main
git remote add origin https://github.com/oattia-ot/agentic-rag-setup.git
git push -u origin main

#push an existing repository from the command line
git remote add origin https://github.com/oattia-ot/agentic-rag-setup.git
git branch -M main
git push -u origin main