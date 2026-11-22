#!/usr/bin/env python3
"""Sample data for the 1.0.4 screenshots (明細の見出し・施工日・代表者名).

Runs tool/seed_demo_data.py first, then switches the line heading to 現場名,
adds a 2-line issuer and an invoice whose lines carry 施工日 / 施工内容.
Only for screenshots. All names, places and numbers are made up.
"""
import datetime as dt
import json
import os
import subprocess
import sys

docs = sys.argv[1]
here = os.path.dirname(__file__)
subprocess.run([sys.executable, os.path.join(here, "seed_demo_data.py"), docs], check=True)
root = os.path.join(docs, "mitsumori_seikyu")
today = dt.date.today()


def day(offset):
    return (today + dt.timedelta(days=offset)).isoformat()


def load(name):
    with open(os.path.join(root, name), encoding="utf-8") as f:
        return json.load(f)


def write(name, obj):
    with open(os.path.join(root, name), "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)


settings = load("settings.json")
settings["lineLabel"] = "site"
settings["profile"]["name"] = "合同会社 山田内装"
settings["profile"]["representative"] = "代表社員 山田 太郎"
write("settings.json", settings)


def site(name, date, detail, qty, price=25000):
    return {"name": name, "quantity": qty, "unit": "人工", "unitPrice": price,
            "taxRate": "ten", "workDate": date, "detail": detail}


documents = load("documents.json")
d0 = dt.date.fromisoformat(day(0))
documents["documents"].insert(0, {
    "id": "demo-site", "kind": "invoice", "number": "INV-2026-019",
    "customerId": "c1", "customerName": "山田工務店", "honorific": "御中",
    "customerAddress": "横浜市都筑区中川1-4-2", "title": "",
    "issueDate": day(0), "dueDate": None,
    "lines": [
        site("港北区日吉本町2-18 A邸", day(-5), "内装下地", 3),
        site("港北区日吉本町2-18 A邸", day(-4), "クロス張替え", 2),
        site("都筑区中川1-4 B倉庫", day(-2), "床CF張替え", 5),
    ],
    "note": "", "status": "unsent",
    "createdAt": int(dt.datetime(d0.year, d0.month, d0.day, 10).timestamp() * 1000),
})
documents["documents"][0].pop("dueDate")
write("documents.json", documents)
print("seeded v104 sample")
