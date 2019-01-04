import json
from web3 import Web3


class GeoServiceRegistry:

    def __init__(self, connection, address):
        interface_file = open("./build/contracts/GeoServiceRegistry.json", "r")
        contract_interface = json.load(interface_file)
        interface_file.close()

        w3 = connection.get_web3()

        self.contract = w3.eth.contract(
            address=address,
            abi=contract_interface['abi'],
        )

    def is_registry_exist(self, registry_name):
        return self.contract.functions.isRegistryExist(registry_name).call()

    def test(self):
        reg_name = "provider"
        print("isRegistryExist {} - {}".format(reg_name, self.is_registry_exist(reg_name)))
        reg_name = "not_exist_registry"
        print("isRegistryExist {} - {}".format(reg_name, self.is_registry_exist(reg_name)))
