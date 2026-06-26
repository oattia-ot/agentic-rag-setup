from pathlib import Path

docs = Path("/documents")

for file in docs.glob("*"):
    print(f"Processing {file}")
