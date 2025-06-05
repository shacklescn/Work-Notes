import openai
import os

PROXY_API_KEY = "b1b9ad40f6687fa74dbbe07eaa2381b7" #创建的消费者KEY
PROXY_SERVER_URL = "http://10.84.3.100/v1"  #higress gateway的LB地址
PROXYLLM_BACKEND = "Qwen3-235B-A22B" #模型名称

os.environ["OPENAI_API_KEY"] = PROXY_API_KEY
client = openai.OpenAI(base_url=PROXY_SERVER_URL)


def generate_text(prompt, model_name=PROXYLLM_BACKEND, max_tokens=5000):
    payload = {
        'stream': True,
        'model': model_name,
        'temperature': 1,
        'max_tokens': max_tokens,
    }


    messages = [
        {'role': 'system', 'content': '你是一个有用的 AI 助手。'},
        {'role': 'user', 'content': "/no_think"}
    ]

    stream = client.chat.completions.create(
        messages=messages,
        **payload
    )

    text = ""
    for chunk in stream:
        if chunk.choices:
            delta = chunk.choices[0].delta
            if hasattr(delta, 'content') and delta.content:
                text += delta.content
                print(delta.content, end='', flush=True)
    return text



prompt = "3，10，15，26，下一个数字是多少？"
generated_text = generate_text(prompt)
