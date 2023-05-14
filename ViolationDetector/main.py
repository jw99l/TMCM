import requests
import json
import urllib3
import time
import aiohttp, asyncio
import sys

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
            print("ERROR", base_url.split("https://")[1])
            return (url, [])


WEB3_API_URL = "https://eth.rpc.blxrbdn.com"
WEB3_API_URL_2 = "https://eth.llamarpc.com"


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
            response = requests.post(WEB3_API_URL_2, headers=headers, json=payload)
            return response.json()["result"]["hash"]
        except:
            return ""
        return ""


def fetch_finalized_block():
    headers = {
        "Content-Type": "application/json",
    }
    payload = {
        "jsonrpc": "2.0",
        "method": "eth_getBlockByNumber",
        "params": ["finalized", False],
        "id": 1,
    }

    response = requests.post(WEB3_API_URL, headers=headers, json=payload)
    try:
        return int(response.json()["result"]["number"], 16)
    except:
        time.sleep(0.5)
        try:
            response = requests.post(WEB3_API_URL_2, headers=headers, json=payload)
            return int(response.json()["result"]["number"], 16)
        except:
            return ""
        return ""


async def main():
    old_block = fetch_finalized_block()

    while True:
        now_block = fetch_finalized_block()
        if old_block < now_block:
            for block_number in range(old_block, now_block):
                sys.stdout.flush()
                block_hash = fetch_block_hash(block_number).lower().strip()
                tasks = [
                    asyncio.create_task(fetch_url(relay, block_number))
                    for relay in RELAYS_URL
                ]
                results = await asyncio.gather(*tasks)
                print(block_number, end=' ')

                for result in results:
                    url, res = result
                    if len(res) == 0:
                        continue
                    if res[0]["block_hash"].lower().strip() != block_hash:
                        print("\n[found]")
                        print(url, block_hash, res[0]["block_hash"])
                        print(res[0])
            old_block = now_block
        else:
            time.sleep(10)
            continue


if __name__ == "__main__":
    asyncio.run(main())
