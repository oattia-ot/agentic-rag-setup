from fastapi import FastAPI

app = FastAPI()

@app.get("/health")
def health():
    return {"status": "UP"}

@app.post("/chat")
def chat(question: str):
    return {
        "question": question,
        "answer": "Agent implementation goes here"
    }
