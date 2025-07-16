# SubHunter
This script performs  subdomain enumeration for a specified domain using multiple tools such as Amass, Subfinder, Assetfinder, Findomain, gau, and others. By combining these sources, it maximizes subdomain coverage from publicly available information (OSINT). The script collects the outputs, removes duplicates, and generates a unified list for further analysis.


<p align="center">
 <img src="https://github.com/user-attachments/assets/6bc40724-ad16-4d8a-a1dc-848383d29ca2" alt="image">
</p>

## Installation:
```
git clone https://github.com/lulusec/Subhunter/
cd Subhunter
bash install.sh
```

## Usage:
```
chmod +x SubHunter.sh
./SubHunter.sh -d example.com -g -j
```
## Help:
```
└─$ ./SubHunter.sh -h
```
| Flag | Description                                         | Example                          |
|------|-----------------------------------------------------|----------------------------------|
| -d   | Target domain to enumerate subdomains               | `./SubHunter.sh -d example.com`  |
| -g   | Use Google Dorking with auto-generated cookies      | `./SubHunter.sh -d example.com -g`              |
| -j   | Subdomain discovery from JavaScript files on live hosts (active enumeration)    | `./SubHunter.sh -d example.com -j`              |
| -h   | Show this help message                              | `./SubHunter.sh -h`              |

## API keys
```
python key_manager.py
```
<p align="center">
 <img src="https://github.com/user-attachments/assets/bc99a933-b02d-4209-8786-55cdb603c30e" alt="image">
</p>


