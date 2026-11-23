#!/usr/bin/env python3
"""Sample data for the 1.0.5 check (1つの明細に複数の施工日).

Runs seed_demo_data_v104.py, then gives the demo-site invoice lines that
cover several days (期間・飛び飛び). All names, places and numbers are made up.
"""
import datetime as dt, json, os, subprocess, sys

docs = sys.argv[1]
here = os.path.dirname(__file__)
subprocess.run([sys.executable, os.path.join(here, "seed_demo_data_v104.py"), docs], check=True)
path = os.path.join(docs, "mitsumori_seikyu", "documents.json")
with open(path, encoding="utf-8") as f:
    data = json.load(f)
first = dt.date.today().replace(day=1)
def days(*ds):
    return [(first + dt.timedelta(days=d - 1)).isoformat() for d in ds]
doc = next(d for d in data["documents"] if d["id"] == "demo-site")
a = days(3, 4, 5, 6, 10, 12)
b = days(17, 18)
doc["lines"] = [
    {"name": "港北区日吉本町2-18 A邸", "quantity": 12, "unit": "人工", "unitPrice": 25000,
     "taxRate": "ten", "workDate": a[0], "workDates": a, "detail": "常用"},
    {"name": "都筑区中川1-4 B倉庫", "quantity": 4, "unit": "人工", "unitPrice": 25000,
     "taxRate": "ten", "workDate": b[0], "workDates": b, "detail": "床CF張替え"},
    {"name": "青葉区美しが丘3-7 C邸", "quantity": 2, "unit": "人工", "unitPrice": 25000,
     "taxRate": "ten", "workDate": days(20)[0], "detail": "クロス張替え"},
]
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
print("seeded v105 sample")
