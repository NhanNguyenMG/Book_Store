from fastapi import FastAPI

app = FastAPI(title="Book Store")

@app.get("/")
def home():
    return {"message": "Book Store dang chay"}