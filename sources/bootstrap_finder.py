#!/usr/bin/python3
##############################################################################################################################################
# WARNING: This script will delete comment inside the config file it writes.
# SOURCE --> https://gitlab.com/0x6578656376652829/massa_admin/-/blob/main/massa/services/bootstrap_finder/massa_bootstrap_finder.py
##############################################################################################################################################

from ipaddress import ip_address, IPv4Address

import datetime
import configparser
import subprocess
import pathlib

ERROR="[ERROR]"
WARN="[WARN]"
INFO="[INFO]"

BASE_CONFIG_FILE_PATH = "/massa/massa-node/base_config/config.toml"
CONFIG_FILE_PATH = "/massa_mount/config.toml"
BOOTSTRAPPERS_FILE_PATH = "/massa_mount/config/bootstrappers.toml"
CLIENT = "/massa/target/release/massa-client"
PATH_TO_LOG_FILE = "/massa/massa-node/logs.txt"
PATH_TO_UNREACHABLE_BOOTSTRAPPERS = "/massa_mount/config/bootstrappers_unreachable.txt"

TEMPLATE = """
[official]
bootstrap_list=[]
[friends]
bootstrap_list=[]
[banned]
bootstrap_list=[]
[others]
bootstrap_list=[]
"""

def validIPAddress(IP: str) -> str:
    try:
        return "IPv4" if type(ip_address(IP)) is IPv4Address else "IPv6"
    except ValueError:
        return "Invalid"

class BootstrapFinder():
    def __init__(self, client, base_config_file, config_file, bootstrappers_file):
        self.__client = client
        self.__base_config_file = base_config_file
        self.__config_file = config_file
        self.__bootstrappers_file = bootstrappers_file

    def get_trace(self, level, message):
        date = datetime.datetime.today()
        dateLog = date.strftime('%Y%m%d-%HH%M')
        return f"[{dateLog}]{level}[BOOTSTRAP]{message}"

    def get_out_nodes(self):
        client_get_status = subprocess.Popen([self.__client, "get_status"], stdout=subprocess.PIPE)
        grep = subprocess.Popen(["grep", "-E", "Node\'s ID: [0-z]{49,50} / IP address: [[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}"], stdin=client_get_status.stdout, stdout=subprocess.PIPE)
        awk = subprocess.Popen(["awk", "{print \"[\\\"\"$7\":31245\\\", \\\"\"$3\"\\\"],\"}"], stdin=grep.stdout, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        output, error = awk.communicate()
        if (not error) and output:
            output = output[:-2].decode("UTF-8")
        else:
            output = ""
        return f"[{output}]"

    def get_ipv6_out_nodes(self):
        client_get_status = subprocess.Popen([self.__client, "get_status"], stdout=subprocess.PIPE)
        grep = subprocess.Popen(["grep", "-E", "Node\'s ID: [0-z]{49,50} / IP address: ([0-9a-z]{1,4})(:[0-9a-z]{0,4}){1,7}"], stdin=client_get_status.stdout, stdout=subprocess.PIPE)
        awk = subprocess.Popen(["awk", "{print \"[\\\"[\"$7\"]:31245\\\", \\\"\"$3\"\\\"],\"}"], stdin=grep.stdout, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        output, error = awk.communicate()
        if (not error) and output:
            output = output[:-2].decode("UTF-8")
        else:
            output = ""
        return f"[{output}]"

    def get_official_bootstrappers(self):
        parser = ""
        parser = configparser.ConfigParser(allow_no_value=True) # the team's base_config file isn't formatted correctly
        parser.read(self.__base_config_file)
        output = ""
        if "bootstrap" in parser and "bootstrap_list" in parser["bootstrap"]:
            output = parser["bootstrap"]["bootstrap_list"][2:] # [2:] to remove the first "[\n"
        else:
            print (self.get_trace(ERROR, f"Unable to find official bootstrappers in base config file {self.__base_config_file}"))
        return f"[{output}]"

    def create_bootstrappers_file(self):
        parser = configparser.ConfigParser()
        parser.read_string(TEMPLATE)
        official_bootstrappers = self.get_official_bootstrappers()
        parser["official"]["bootstrap_list"] = f"{official_bootstrappers}"
        with open(self.__bootstrappers_file, "w") as bfile:
            parser.write(bfile)

    def check_and_repair_bootstrappers_file(self):
        parser = configparser.ConfigParser()
        parser.read(self.__bootstrappers_file)
        if not "official" in parser:
            parser["official"] = {}
        if not "friends" in parser:
            parser["friends"] = {}
        if not "banned" in parser:
            parser["banned"] ={}
        if not "others" in parser:
            parser["others"] = {}
        if not "bootstrap_list" in parser["official"]:
            official_bootstrappers = self.get_official_bootstrappers()
            parser["official"]["bootstrap_list"] = f"{official_bootstrappers}"
        if not "bootstrap_list" in parser["friends"]:
            parser["friends"]["bootstrap_list"] = "[]"
        if not "bootstrap_list" in parser["banned"]:
            parser["banned"]["bootstrap_list"] = "[]"
        if not "bootstrap_list" in parser["others"]:
            parser["others"]["bootstrap_list"] = "[]"
        with open(self.__bootstrappers_file, "w") as bfile:
            parser.write(bfile)

    def remove_faulty_bootstrappers(self, bootstrappers):
        cleared_bootstrappers = bootstrappers
        # edit the following line to change service name or if you don't use systemd
        # for example if you don't use systemd: journalctl = subprocess.Popen(["cat", "path_to_log_file"], stdout=subprocess.PIPE)
        journalctl = subprocess.Popen(["cat", PATH_TO_LOG_FILE], stdout=subprocess.PIPE)
        grep = subprocess.Popen(["grep", "-B", "1", "error while bootstrapping"], stdin=journalctl.stdout, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        output, error = grep.communicate()
        if not error:
            logs = output.decode("UTF-8").split("\n")
            for line in logs:
                if "Start bootstrapping from" in line:
                    node_ip = line.split(" ")[-1]
                    for bootstrapper in bootstrappers:
                        if node_ip in bootstrapper:
                            print (self.get_trace(WARN, f"Removing boostrapper {bootstrapper} for bootstrap failure"))
                            cleared_bootstrappers.remove(bootstrapper)
                            break
        else:
            error = error.decode("UTF-8")
            print (self.get_trace(ERROR, f"Failed to proceed logs: unable to remove faulty bootstrappers: {error}"))
        # Get list of unreachable nodes on port 31245
        with open(PATH_TO_UNREACHABLE_BOOTSTRAPPERS) as unreachablebootstrappers:
            unreachablebootstrapperslist = unreachablebootstrappers.read().splitlines()
        for bootstrapper in bootstrappers:
            if any(unreachablebootstrapper in bootstrapper for unreachablebootstrapper in unreachablebootstrapperslist):
                print (self.get_trace(WARN, f"Removing boostrapper {bootstrapper} because this node is unreachable on port TCP 31245"))
                cleared_bootstrappers.remove(bootstrapper)
        return cleared_bootstrappers

    def update_bootstrappers_file(self):
        parser = configparser.ConfigParser()
        parser.read(self.__bootstrappers_file)
	# Get list of unreachable nodes on port 31245
        with open(PATH_TO_UNREACHABLE_BOOTSTRAPPERS) as unreachablebootstrappers:
            unreachablebootstrapperslist = unreachablebootstrappers.read().splitlines()
        out_nodes = self.get_out_nodes()[1:-1] # remove the first and the last "]"
        out_ipv6_nodes = self.get_ipv6_out_nodes()[1:-1]
        # get official nodes
        official_bootstrappers = self.get_official_bootstrappers()
        official_bootstrappers = [bootstrapper.strip(" ") for bootstrapper in official_bootstrappers.split(",\n") if bootstrapper]
        # get friend nodes
        friend_bootstrappers = parser["friends"]["bootstrap_list"][1:-1] # remove the first and the last "]"
        friend_bootstrappers = [bootstrapper.strip(" ") for bootstrapper in friend_bootstrappers.split(",\n") if bootstrapper]
        # get banned nodes
        banned_bootstrappers = parser["banned"]["bootstrap_list"][1:-1] # remove the first and the last "]"
        banned_bootstrappers = [bootstrapper.strip(" ") for bootstrapper in banned_bootstrappers.split(",\n") if bootstrapper]
        # get other nodes
        other_bootstrappers = parser["others"]["bootstrap_list"][1:-1] # remove the first "[" and the last "]"
        other_bootstrappers = self.remove_faulty_bootstrappers([bootstrapper.strip(" ") for bootstrapper in other_bootstrappers.split(",\n") if bootstrapper])
        other_bootstrappers = [bootstrapper for bootstrapper in other_bootstrappers if bootstrapper not in banned_bootstrappers]
	# Add IPV4 nodes
        bootstrappers = [bootstrapper.strip(" ") for bootstrapper in out_nodes.split(",\n") if bootstrapper]
        for bootstrapper in bootstrappers:
            if (not bootstrapper in official_bootstrappers) and (not bootstrapper in friend_bootstrappers) and \
                (not bootstrapper in banned_bootstrappers) and (not bootstrapper in other_bootstrappers) and \
		(not any(unreachablebootstrapper in bootstrapper for unreachablebootstrapper in unreachablebootstrapperslist)):
                print (self.get_trace(INFO, f"Adding new bootstrapper {bootstrapper} to [others] bootstrap list"))
                other_bootstrappers.append(bootstrapper)
        # Add IPV6 nodes
        bootstrappers_ipv6 = [bootstrapper_ipv6.strip(" ") for bootstrapper_ipv6 in out_ipv6_nodes.split(",\n") if bootstrapper_ipv6]
        for bootstrapper_ipv6 in bootstrappers_ipv6:
            if (not bootstrapper_ipv6 in official_bootstrappers) and (not bootstrapper_ipv6 in friend_bootstrappers) and \
                (not bootstrapper_ipv6 in banned_bootstrappers) and (not bootstrapper_ipv6 in other_bootstrappers) and \
                (not any(unreachablebootstrapper in bootstrapper for unreachablebootstrapper in unreachablebootstrapperslist)):
                print (self.get_trace(INFO, f"Adding new bootstrapper {bootstrapper_ipv6} to [others] bootstrap list"))
                other_bootstrappers.append(bootstrapper_ipv6)
        other_bootstrappers = ",\n".join(other_bootstrappers)
        parser["others"]["bootstrap_list"] = f"[{other_bootstrappers}]"
        with open(self.__bootstrappers_file, "w") as bfile:
            parser.write(bfile)

    def update_config_file(self):
        parser = configparser.ConfigParser()
        parser.read(self.__bootstrappers_file)
        official_bootstrappers = parser["official"]["bootstrap_list"][1:-1] # remove the first "[" and the last "]"
        official_bootstrappers = [bootstrapper.strip(" ") for bootstrapper in official_bootstrappers.split(",\n") if bootstrapper]
        friend_bootstrappers = parser["friends"]["bootstrap_list"][1:-1]
        friend_bootstrappers = [bootstrapper.strip(" ") for bootstrapper in friend_bootstrappers.split(",\n") if bootstrapper]
        other_bootstrappers = parser["others"]["bootstrap_list"][1:-1] # remove the first "[" and the last "]"
        other_bootstrappers = [bootstrapper.strip(" ") for bootstrapper in other_bootstrappers.split(",\n") if bootstrapper]
        bootstrap_set = set(official_bootstrappers + friend_bootstrappers + other_bootstrappers)
        bootstrappers = ",\n".join(bootstrap_set)
        # create config file if it doesn't exist
        open(self.__config_file, "a").close()
        parser = configparser.ConfigParser()
        parser.read(self.__config_file)
        if not "bootstrap" in parser:
            parser["bootstrap"] = {}
        parser["bootstrap"]["bootstrap_list"] = f"[{bootstrappers}]"
        with open(self.__config_file, "w") as cfile:
            parser.write(cfile)

    def run(self):
        if not (pathlib.Path(self.__bootstrappers_file).is_file() and pathlib.Path(self.__bootstrappers_file).stat().st_size):
            self.create_bootstrappers_file()
        else:
            self.check_and_repair_bootstrappers_file()
        self.update_bootstrappers_file()
        self.update_config_file()


if __name__ == "__main__":
    finder = BootstrapFinder(CLIENT, BASE_CONFIG_FILE_PATH, CONFIG_FILE_PATH, BOOTSTRAPPERS_FILE_PATH)
    finder.run()
