import json
import math
from web3 import Web3
from web3.middleware import geth_poa_middleware
import subprocess
import time

NODE_URL = "http://127.0.0.1:8545" #Ethereum node URL

PRIVATE_KEY = "Just for tests"

PRIVATE_KEY = "Just for test in the theme of the ORACLE"

SMART_CONTRACT_ADDRESS = "Contract of the city"





QRNG_API_URL = "https://qrng.idqloud.com/api/1.0/short?max=32767&min=-32768&quantity=10"
QRNG_API_KEY = "aTo4BKRvnc49uRWDk034zaua87vGRXKk9TMLdfkI"

def get_qrng_number_from_api():
    """Random number (QNRGs)"""
    command = [
        "curl",
        QRNG_API_URL,
        "-X", "GET",
        "-H", f"X-API-KEY: {QRNG_API_KEY}"
    ]
    print(f"Trying comand: {' '.join(command)}")

    try:
        # Ejecuta el comando curl
        result = subprocess.run(command, capture_output=True, text=True, check=True)
        response_data = json.loads(result.stdout)
        if response_data and "data" in response_data and len(response_data["data"]) > 0:
            raw_number = response_data["data"][0]
            positive_number = abs(raw_number)
            print(f"Crude QRNG number obtained: {raw_number}, positive: {positive_number}")
            return positive_number
        else:
            print("Error: No random data was found in the response.")
            print("Complete answer", response_data)
            return None 
        
    except subprocess.CalledProcessError as e:
        print(f"Error to ejecute: {e}")
        print(f"Stderr: {e.stderr}")
        return None 
    except json.JSONDecodeError:
        print(f"Error JSON: {result.stdout}")
        return None 
    except Exception as e:
        print(f"Error: {e}")
        return None 
    
def fulfill_request(w3, contract, account, request_id, random_word):
    print(f"Sending transaction for fulfillment request {request_id} con random word {random_word}")
    try:
        transaction = contract.functions.fulfillRandomness(request_id, random_word).build_transaction({
            'chainId': w3.eth.chain_id,
            'from': account.address,
            'nonce': w3.eth.get_transaction_count(account.address),
            'gas': 2000000, 
            'gasPrice': w3.eth.gas_price 
        })

        signed_transaction = account.sign_transaction(transaction)

        tx_hash = w3.eth.send_raw_transaction(signed_transaction.rawTransaction)

        print(f"Transaction sent: {tx_hash.hex()}")
        receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=120)
        print(f"Transaction accept from the block {receipt.blockNumber}")

        if receipt.status == 1:
            print("Transaction well.")
        else:
            print("Failed Transaction")


    except Exception as e:
        print(f"Error sending transaction: {e}")

def listen_for_requests(w3, contract, account):
    """Listen to the RandomnessRequested event and process the requests."""

    event_filter = contract.events.RandomnessRequested.create_filter(fromBlock='latest')

    # Principle loop from oracle
    while True:
        try:
            new_entries = event_filter.get_new_entries()

            for event in new_entries:
                request_id = event['args']['requestId']
                callback_contract_address = SMART_CONTRACT_ADDRESS 

                print(f"\n¡Random request detected! Request ID: {request_id}")

                # --- Getting the QNRGs (simulating the curl) ---
                random_word = get_qrng_number_from_api()

                if random_word is not None:
                    your_contract_instance = w3.eth.contract(address=callback_contract_address, abi= SMART_CONTRACT_ABI)
                    fulfill_request(w3, your_contract_instance, account, request_id, random_word)
                else:
                    print(f"Could not get a QRNG number for request {request_id}.")

            time.sleep(5) 

        except Exception as e:
            print(f"Oracle main loop error: {e}")
            time.sleep(10)

if __name__ == "__main__":
    print("Starting Oracle Mock script....")
    try:
        w3 = Web3(Web3.HTTPProvider(NODE_URL))

        if not w3.is_connected():
            print("Error to connecting a node in ETH")
        else:
            print(f"Connecting to ETH. Chain ID: {w3.eth.chain_id}")

            account = w3.eth.account.from_key(PRIVATE_KEY)
            print(f"Using oracle account: {account.address}")

            # Cargar el contrato de tu protocolo evolutivo
            your_contract = w3.eth.contract(address=SMART_CONTRACT_ADDRESS, abi=SMART_CONTRACT_ABI)

            # Iniciar la escucha de eventos
            listen_for_requests(w3, your_contract, account)

    except Exception as e:
        print(f"Error trying to initializa the oracle: {e}")



