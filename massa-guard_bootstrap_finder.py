#!/usr/bin/python3
##############################################################################################################################################
# WARNING: This script will delete comment inside the config file it writes.
# SOURCE --> https://gitlab.com/0x6578656376652829/massa_admin/-/blob/main/massa/services/bootstrap_finder/massa_bootstrap_finder.py
##############################################################################################################################################
import datetime
import configparser
import subprocess
import pathlib

ERROR="[ \033[0;31m\033[1m ERROR \033[0m]"
WARN="[ \033[0;33m\033[1m WARN \033[0m ]"
INFO="[ \033[0;32m\033[1m INFO \033[0m ]"

BASE_CONFIG_FILE_PATH = "/massa/massa-node/base_config/config.toml"
CONFIG_FILE_PATH = "/massa/massa-node/config/config.toml"
BOOTSTRAPPERS_FILE_PATH = "/massa/massa-node/config/bootstrappers.toml"
CLIENT = "/massa/target/release/massa-client"
PATH_TO_LOG_FILE = "/massa/massa-node/logs.txt"

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

class BootstrapFinder():

    def __init__(self, client, base_config_file, config_file, bootstrappers_file):
        self.__client = client
        self.__base_config_file = base_config_file
        self.__config_file = config_file
        self.__bootstrappers_file = bootstrappers_file

    def get_trace(self, level, message):
        utcnow = datetime.datetime.utcnow()
        return f"{utcnow} {level}: {message}"

    def get_out_nodes(self):
        client_get_status = subprocess.Popen([self.__client, "get_status"], stdout=subprocess.PIPE)
        grep = subprocess.Popen(["grep", "IP address: [0-9]"], stdin=client_get_status.stdout, stdout=subprocess.PIPE)
        awk = subprocess.Popen(["awk", "{print \"[\\\"\"$7\":31245\\\", \\\"\"$3\"\\\"],\"}"], stdin=grep.stdout, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        output, error = awk.communicate()
        if (not error) and output:
            output = output[:-2].decode("UTF-8")
        else:
            output = ""
            print (self.get_trace(ERROR, f"Failed to obtain connected nodes: {error}"))
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
        journalctl = subprocess.Popen(["cat", "/massa/massa-node/logs.txt"], stdout=subprocess.PIPE)
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
        return cleared_bootstrappers

    def update_bootstrappers_file(self):
        print (self.get_trace(INFO, f"Updating bootstrappers file {self.__bootstrappers_file}"))
        parser = configparser.ConfigParser()
        parser.read(self.__bootstrappers_file)
        out_nodes = self.get_out_nodes()[1:-1] # remove the first and the last "]"
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
        bootstrappers = [bootstrapper.strip(" ") for bootstrapper in out_nodes.split(",\n") if bootstrapper]
        for bootstrapper in bootstrappers:
            if (not bootstrapper in official_bootstrappers) and (not bootstrapper in friend_bootstrappers) and \
                (not bootstrapper in banned_bootstrappers) and (not bootstrapper in other_bootstrappers):
                print (self.get_trace(INFO, f"Adding new bootstrapper {bootstrapper} to [others] bootstrap list"))
                other_bootstrappers.append(bootstrapper)
        other_bootstrappers = ",\n".join(other_bootstrappers)
        parser["others"]["bootstrap_list"] = f"[{other_bootstrappers}]"
        with open(self.__bootstrappers_file, "w") as bfile:
            parser.write(bfile)
        print (self.get_trace(INFO, f"Bootstrappers file update done."))

    def update_config_file(self):
        print (self.get_trace(INFO, f"Updating massa config file {self.__config_file}"))
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
        print (self.get_trace(INFO, "Massa config file update done."))

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