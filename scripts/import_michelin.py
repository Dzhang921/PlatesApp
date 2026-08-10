#!/usr/bin/env python3
"""Convert michelin-my-maps CSV into the app's bundled michelin.json.

Keeps starred restaurants (stars 1-3) and Bib Gourmand (stars 0);
drops plain "Selected Restaurants" entries.

Usage: python3 scripts/import_michelin.py [csv_path] [out_path]
"""
import csv
import json
import sys
from datetime import date

AWARDS = {"3 Stars": 3, "2 Stars": 2, "1 Star": 1, "Bib Gourmand": 0}

COUNTRY_CLEANUP = {
    "Hong Kong SAR China": "Hong Kong",
    "Macau SAR China": "Macau",
    "China Mainland": "China",
}


def main() -> None:
    csv_path = sys.argv[1] if len(sys.argv) > 1 else "scripts/michelin_my_maps.csv"
    out_path = sys.argv[2] if len(sys.argv) > 2 else "Plates/Resources/michelin.json"

    records = []
    skipped = 0
    with open(csv_path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            stars = AWARDS.get(row["Award"].strip())
            if stars is None:
                continue  # Selected Restaurants etc.
            try:
                lat = round(float(row["Latitude"]), 5)
                lon = round(float(row["Longitude"]), 5)
            except (ValueError, KeyError):
                skipped += 1
                continue
            location = row.get("Location", "").strip()
            if "," in location:
                city, country = [p.strip() for p in location.rsplit(",", 1)]
            else:
                city = country = location
            country = COUNTRY_CLEANUP.get(country, country)
            rec = {
                "name": row["Name"].strip(),
                "latitude": lat,
                "longitude": lon,
                "city": city,
                "country": country,
                "stars": stars,
            }
            cuisine = row.get("Cuisine", "").strip().lower()
            if cuisine:
                rec["cuisine"] = cuisine
            records.append(rec)

    records.sort(key=lambda r: (-r["stars"], r["country"], r["city"], r["name"]))
    payload = {
        "asOf": f"Michelin Guide via ngshiheng/michelin-my-maps (retrieved {date.today().isoformat()})",
        "records": records,
    }
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, separators=(",", ":"))
    by_stars = {s: sum(1 for r in records if r["stars"] == s) for s in (3, 2, 1, 0)}
    print(f"wrote {len(records)} records to {out_path} (skipped {skipped} without coords)")
    print(f"stars: {by_stars}")


if __name__ == "__main__":
    main()
