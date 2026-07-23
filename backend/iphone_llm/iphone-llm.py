import sys
from openai import OpenAI

# Initialize client pointing to your iPhone's local IP address
client = OpenAI(
    base_url="http://192.168.29.162:8080/v1",  # Replace with iPhone IP
    api_key="not-needed"                  # Any placeholder string works
)

try:
    # Request a streaming response
    stream = client.chat.completions.create(
        model="base",
        messages=[{"role": "user", "content": "Explain quantum computing in one sentence."}],
        stream=True,
    )

    print("iPhone Response: ", end="")
    for chunk in stream:
        if chunk.choices[0].delta.content is not None:
            print(chunk.choices[0].delta.content, end="")
            sys.stdout.flush()
    print()

except Exception as e:
    print(f"\nConnection Error: Ensure the app is open and active on your iPhone.\nDetails: {e}")
