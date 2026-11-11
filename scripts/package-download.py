"""Package the Android demo built by CI with the Render endpoints."""
import hashlib
import json
import os
from pathlib import Path
import shutil

apk = Path("build/app/outputs/flutter-apk/app-debug.apk")
assert apk.is_file(), "APK de demonstração não encontrado."
downloads = Path("downloads")
downloads.mkdir(exist_ok=True)
target = downloads / "MediShop-Aluno-Android.apk"
shutil.copy2(apk, target)
info = {
    "commit": os.environ.get("GITHUB_SHA"),
    "api": os.environ["API_BASE_URL"],
    "site": os.environ["WEB_BASE_URL"],
    "mode": "debug",
    "signing": "Android debug key; demonstração acadêmica",
}
assert info["api"] == "https://pim4-api-demo.onrender.com/"
assert info["site"] == "https://pim4front.onrender.com/"
(downloads / "build-info.json").write_text(json.dumps(info, indent=2) + "\n")
checksum = hashlib.sha256(target.read_bytes()).hexdigest()
(downloads / "SHA256SUMS.txt").write_text(f"{checksum}  {target.name}\n")
print("APK de demonstração preparado com URLs do Render e checksum.")
