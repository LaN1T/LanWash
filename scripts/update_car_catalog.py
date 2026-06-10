#!/usr/bin/env python3
"""Update car_catalog.json with missing brands and models."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG_PATH = ROOT / "assets" / "data" / "car_catalog.json"

with open(CATALOG_PATH, "r", encoding="utf-8") as f:
    data = json.load(f)

existing_brands = {entry["brand"].lower(): entry for entry in data}

# New brands to add
NEW_BRANDS = {
    "Xiaomi": ["SU7", "SU7 Ultra", "YU7"],
    "Onvo": ["L60", "L80", "L90"],
    "Skywell": ["ET5", "EVA 5", "HT-i"],
    "Livan": ["7", "8", "9"],
    "Radar": ["RD6", "Horizon"],
    "SWM": ["G01", "G05", "Tiger"],
    "Foton": ["Sauvana", "Tunland", "View"],
    "Haima": ["8S", "7X", "Freema"],
    "Forthing": ["T5 EVO", "Yacht", "U-Tour"],
    "Polestar": ["2", "3", "4", "5", "6"],
    "Cupra": ["Formentor", "Leon", "Ateca", "Born", "Tavascan", "Terramar"],
    "Maserati": ["Ghibli", "Levante", "Quattroporte", "MC20", "Grecale", "GranTurismo"],
    "Ferrari": ["296", "488", "F8", "SF90", "Roma", "Portofino", "812", "Purosangue"],
    "Lamborghini": ["Huracan", "Urus", "Revuelto", "Temerario"],
    "Bentley": ["Continental GT", "Flying Spur", "Bentayga"],
    "Rolls-Royce": ["Cullinan", "Ghost", "Phantom", "Spectre", "Wraith", "Dawn"],
    "Aston Martin": ["DB11", "DB12", "DBS", "Vantage", "Valkyrie", "DBX"],
    "McLaren": ["720S", "750S", "Artura", "GT"],
    "Lotus": ["Emira", "Eletre", "Emeya", "Evora"],
    "Daihatsu": ["Terios", "Sirion", "Ayla", "Rocky", "Xenia"],
    "Isuzu": ["D-Max", "MU-X"],
    "SsangYong": ["Rexton", "Korando", "Tivoli", "Musso"],
    "Moskvich": ["3", "3e", "6"],
    "ZAZ": ["Vida", "Sens", "Chance", "Forza"],
}

# Additional models for existing brands
ADDITIONAL_MODELS = {
    "BYD": ["Sealion 7", "Sealion 5", "Shark", "Song L DM-i", "Seal 06 GT", "e2", "Destroyer 05"],
    "Geely": ["Galaxy E5", "Galaxy E8", "Galaxy L6", "Galaxy L7", "Galaxy Starship 7", "Monjaro", "Tugella", "Cityray"],
    "Haval": ["Jolion", "Dargo", "F7", "F7x", "H6 GT", "H5", "H7", "H9"],
    "Changan": ["CS55 Plus", "UNI-T", "UNI-K", "UNI-V", "Deepal SL03", "Deepal S07", "Nevo"],
    "Chery": ["Tiggo 4 Pro", "Tiggo 7 Pro Max", "Tiggo 8 Pro Max", "Omoda 5", "Omoda E5", "Arrizo 8"],
    "Jetour": ["Dashing", "X70 Plus", "X90 Plus", "T1", "T5", "Traveller"],
    "Tank": ["Tank 400", "Tank 700", "Tank 500"],
    "GAC": ["GS8", "M8", "Aion S", "Aion Y", "Aion V", "Trumpchi E8", "Empow"],
    "MG": ["MG4", "MG5", "MG7", "Cyberster", "HS", "ZS", "Marvel R"],
    "NIO": ["ET5T", "EC6", "EC7", "ES7"],
    "Xpeng": ["Mona M03", "P7+", "G9", "X9"],
    "Li Auto": ["L6", "L9"],
    "AITO": ["M5", "M7", "M8", "M9"],
    "Zeekr": ["001 FR", "007", "7X", "9X", "MIX"],
    "Leapmotor": ["C10", "C11", "C16", "C01", "T03", "B10"],
    "Neta": ["S", "GT", "X", "Aya"],
    "IM Motors": ["LS6", "LS7", "L6", "L7"],
    "Hongqi": ["H5", "H9", "HS5", "HS7", "E-HS9", "EH7"],
    "Bestune": ["B70", "B70S", "T55", "T77", "T90", "T99", "M9"],
    "Baojun": ["KiWi EV", "Yunduo", "Yep", "Yunhai", "KiWi EV Plus", "Cloud", "Yixin"],
    "Wuling": ["Hongguang Mini", "Bingo", "Yangguang", "Xingchi", "Asta", "Nebula"],
    "Dongfeng": ["Aeolus Huge", "Aeolus Shine", "Fengshen AX7", "Mengshi", "M-Hero 917"],
    "JAC": ["JS4", "JS6", "JS8", "E-JS4", "Yiwei 3"],
    "Great Wall": ["Poer", "Wingle 7", "Cannon"],
    "Hycan": ["A06", "V09", "Z03"],
    "Rising Auto": ["F7", "R7"],
    "Roewe": ["D7", "D5X", "i5", "RX5", "RX9"],
    "Maxus": ["Mifa 7", "Mifa 9", "T90", "D90"],
    "Voyah": ["Free", "Dream", "Passion"],
    "Fangchengbao": ["Bao 5", "Bao 8", "Tai 7"],
    "Denza": ["D9", "N7", "N8", "Z9"],
    "Yangwang": ["U7", "U8", "U9"],
    "Skyworth": ["EV6", "HT-i"],
    "Omoda": ["C5", "S5", "E5"],
    "Jaecoo": ["J7", "J8"],
    "Exeed": ["TXL", "VX", "RX", "Yaoguang", "Lanyue"],
    "iCar": ["03", "V23", "03T"],
    "Weltmeister": ["W5", "W6", "E.5"],
    "WEY": ["Coffee 01", "Coffee 02", "Lan Shan", "Mocha"],
    "Brilliance": ["V3", "V5", "V7", "H530", "H3", "H230"],
    "Soueast": ["DX3", "DX5", "DX7", "S06"],
    "Venucia": ["D60", "T60", "VX6", "V-Online"],
    "Arcfox": ["Alpha S", "Alpha T", "Alpha S5", "Alpha T5", "Kaola"],
    "Aiways": ["U5", "U6"],
    "BAIC": ["X3", "X5", "X7", "U5", "U5 Plus", "EU5", "EU7", "BJ30", "BJ40", "BJ60", "BJ80", "BJ90"],
}

# Apply additions to existing brands
for entry in data:
    brand = entry["brand"]
    if brand in ADDITIONAL_MODELS:
        existing = set(entry["models"])
        for model in ADDITIONAL_MODELS[brand]:
            if model not in existing:
                entry["models"].append(model)
                existing.add(model)

# Add new brands
for brand, models in NEW_BRANDS.items():
    if brand.lower() not in existing_brands:
        data.append({"brand": brand, "models": models})
        existing_brands[brand.lower()] = True

# Sort by brand name
data.sort(key=lambda x: x["brand"].lower())

# Write back with consistent formatting
with open(CATALOG_PATH, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print(f"Updated {CATALOG_PATH}")
print(f"Total brands: {len(data)}")

# Stats
total_models = sum(len(b["models"]) for b in data)
print(f"Total models: {total_models}")
