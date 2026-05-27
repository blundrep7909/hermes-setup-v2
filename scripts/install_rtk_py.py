import urllib.request, tarfile, os, subprocess, sys

# Step 1: Install pip
url = "https://bootstrap.pypa.io/get-pip.py"
urllib.request.urlretrieve(url, "/tmp/get-pip.py")
subprocess.run([sys.executable, "/tmp/get-pip.py"], check=True)
print("pip installed")

# Step 2: Install rtk-hermes
subprocess.run([sys.executable, "-m", "pip", "install", "rtk-hermes"], check=True)
print("rtk-hermes installed")

# Step 3: Verify
import importlib.metadata as md
for ep in md.entry_points().select(group='hermes_agent.plugins'):
    if ep.name == 'rtk-rewrite':
        module = ep.load()
        print(f"Plugin OK: {ep.name} {ep.dist.metadata['Version']}")
