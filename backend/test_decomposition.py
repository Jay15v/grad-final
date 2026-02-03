from services.decomposition_service import decompose_prompt

if __name__ == "__main__":
    out = decompose_prompt("Compare CNN and RNN and give examples")
    print(out)
