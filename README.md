# SubHunter
This script performs  subdomain enumeration for a specified domain using multiple tools such as Amass, Subfinder, Assetfinder, Findomain, gau, and others. By combining these sources, it maximizes subdomain coverage from publicly available information (OSINT). The script collects the outputs, removes duplicates, and generates a unified list for further analysis.

![SubHunter](https://github.com/user-attachments/assets/e9dfae2b-1816-4eed-982f-765ab5fbef45)

## Inštalácia:
```
git clone https://github.com/lulusec/Subhunter-v1/
cd Subhunter-v1
bash install.sh
```

## Použitie:
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

## API klúče
```
python key_manager.py
```
<p align="center">
 <img src="https://github.com/user-attachments/assets/bc99a933-b02d-4209-8786-55cdb603c30e" alt="image">
</p>


