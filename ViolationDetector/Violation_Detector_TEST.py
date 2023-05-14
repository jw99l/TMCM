import requests
import json
import urllib3
import time
import aiohttp, asyncio


urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

RELAYS_URL = [
    "https://boost-relay.flashbots.net",
    "https://relay.ultrasound.money",
    "https://agnostic-relay.net",
    "https://bloxroute.max-profit.blxrbdn.com",
    "https://bloxroute.ethical.blxrbdn.com",
    "https://bloxroute.regulated.blxrbdn.com",
    "https://aestus.live",
    "https://relay.edennetwork.io",
    "https://mainnet-relay.securerpc.com/",
]
RELAY_API = "/relay/v1/data/bidtraces/proposer_payload_delivered?block_number="


async def fetch_url(base_url, idx):
    try:
        url = base_url + RELAY_API + str(idx)
        async with aiohttp.ClientSession() as session:
            async with session.get(url, ssl=False, timeout=10) as response:
                response_text = await response.text()
                response = json.loads(response_text)
                # print(url, response_text)
                return (url, response)
    except Exception as e:
        time.sleep(0.5)
        try:
            url = base_url + RELAY_API + str(idx)
            async with aiohttp.ClientSession() as session:
                async with session.get(url, ssl=False, timeout=10) as response:
                    response_text = await response.text()
                    response = json.loads(response_text)
                    # print(url, response_text)
                    return (url, response)
        except Exception as e:
            # print(e)
            return (url, [])
        return (url, [])


WEB3_API_URL = "https://eth.llamarpc.com"


def fetch_block_hash(num):
    headers = {
        "Content-Type": "application/json",
    }
    payload = {
        "jsonrpc": "2.0",
        "method": "eth_getBlockByNumber",
        "params": [hex(num), False],
        "id": 1,
    }

    response = requests.post(WEB3_API_URL, headers=headers, json=payload)
    try:
        return response.json()["result"]["hash"]
    except:
        time.sleep(0.5)
        try:
            return response.json()["result"]["hash"]
        except:
            return ""
        return ""

hackedBlock = 16964664
blockHash = fetch_block_hash(hackedBlock).lower().strip()

async def main():
    tasks = [
        asyncio.create_task(fetch_url(relay, hackedBlock)) for relay in RELAYS_URL
    ]
    results = await asyncio.gather(*tasks)

    for result in results:
        # print(result)
        url, res = result
        if len(res) == 0:
            continue
        if res[0]["block_hash"].lower().strip() != blockHash:
            print(url)
            print('[ethereum]', blockHash)
            print('[mevboost]', res[0]["block_hash"])


if __name__ == "__main__":
    asyncio.run(main())
