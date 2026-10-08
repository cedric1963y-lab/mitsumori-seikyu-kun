#!/usr/bin/env python3
"""Write realistic sample data into the app's Documents folder.

Usage: tool/seed_demo_data.py <Documents dir>
For the simulator:
  tool/seed_demo_data.py "$(xcrun simctl get_app_container booted jp.mitsumori.app data)/Documents"
Only for store screenshots. The app never ships with this data.
"""
import calendar
import datetime as dt
import json
import os
import shutil
import sys

docs = sys.argv[1]
root = os.path.join(docs, "mitsumori_seikyu")
os.makedirs(os.path.join(root, "exports"), exist_ok=True)
today = dt.date.today()


def day(offset):
    return (today + dt.timedelta(days=offset)).isoformat()


def end_of_month(date):
    return dt.date(date.year, date.month, calendar.monthrange(date.year, date.month)[1]).isoformat()


def ms(date_str, hour=9):
    d = dt.date.fromisoformat(date_str)
    return int(dt.datetime(d.year, d.month, d.day, hour).timestamp() * 1000)


created = ms(day(-60))

customers = [
    ("c1", "山田工務店", "御中", "横浜市都筑区中川1-4-2"),
    ("c2", "株式会社アオバ建設", "御中", "横浜市青葉区美しが丘3-7-1"),
    ("c3", "佐藤 一郎", "様", "横浜市港北区日吉本町2-18-6"),
    ("c4", "港北リフォーム株式会社", "御中", "横浜市港北区大倉山4-1-9"),
]
items = [
    ("i1", "内装工事 職人", "人工", 22000, "ten"),
    ("i2", "クロス張替え（量産品）", "m²", 1200, "ten"),
    ("i3", "床CF張替え", "m²", 3800, "ten"),
    ("i4", "石膏ボード張り", "m²", 2600, "ten"),
    ("i5", "下地補修", "式", 15000, "ten"),
    ("i6", "養生・清掃", "式", 8000, "ten"),
    ("i7", "廃材処分費", "式", 12000, "ten"),
    ("i8", "収入印紙代（立替）", "式", 200, "exempt"),
]
item = {i[0]: i for i in items}


def line(item_id, qty):
    _, name, unit, price, rate = item[item_id]
    return {"name": name, "quantity": qty, "unit": unit, "unitPrice": price, "taxRate": rate}


def free(name, qty, unit, price, rate="ten"):
    return {"name": name, "quantity": qty, "unit": unit, "unitPrice": price, "taxRate": rate}


cust = {c[0]: c for c in customers}


def doc(id_, kind, number, cid, title, issue, due, lines, status, note="", paid=None, source=None, converted=None):
    _, name, hon, addr = cust[cid]
    d = {
        "id": id_, "kind": kind, "number": number, "customerId": cid,
        "customerName": name, "honorific": hon, "customerAddress": addr,
        "title": title, "issueDate": issue, "dueDate": due, "lines": lines,
        "note": note, "status": status, "createdAt": ms(issue, 10),
    }
    if paid: d["paidDate"] = paid
    if source: d["sourceId"] = source
    if converted: d["convertedId"] = converted
    return d


office_lines = [
    line("i4", 48), line("i2", 96), line("i3", 32), line("i1", 3),
    line("i5", 1), line("i7", 1), line("i8", 1),
]
note_invoice = "お振込手数料は貴社にてご負担くださいますようお願いいたします。"
documents = [
    doc("demo-estimate", "estimate", "Q-2026-024", "c2", "倉庫事務所 床改修工事", day(0), day(30), [
        free("既存床材撤去", 30, "m²", 1500), line("i3", 30), line("i5", 1),
        line("i1", 2), line("i6", 1), line("i7", 1),
    ], "unsent", note="工期: 2日（土日施工可）"),
    doc("demo-invoice", "invoice", "INV-2026-018", "c1", "事務所 内装改修工事", day(-1), end_of_month(today),
        office_lines, "sent", note=note_invoice, source="q22"),
    doc("q23", "estimate", "Q-2026-023", "c3", "戸建て 和室→洋室 改装", day(-3), day(27), [
        line("i3", 13), line("i2", 38), line("i1", 2), line("i7", 1),
    ], "sent"),
    doc("q22", "estimate", "Q-2026-022", "c1", "事務所 内装改修工事", day(-8), day(22),
        office_lines, "sent", converted="demo-invoice"),
    doc("inv17", "invoice", "INV-2026-017", "c4", "マンション302号室 クロス張替え", day(-22), day(-8), [
        line("i2", 58), line("i5", 1), line("i6", 1),
    ], "sent", note=note_invoice),
    doc("inv16", "invoice", "INV-2026-016", "c2", "倉庫 間仕切り工事", day(-26), day(-5), [
        line("i4", 64), line("i1", 4),
    ], "paid", paid=day(-5)),
]


def write(name, obj):
    with open(os.path.join(root, name), "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)


write("customers.json", {"version": 1, "customers": [
    {"id": i, "name": n, "honorific": h, "address": a, "createdAt": created} for i, n, h, a in customers]})
write("items.json", {"version": 1, "items": [
    {"id": i, "name": n, "unit": u, "unitPrice": p, "taxRate": r, "createdAt": created} for i, n, u, p, r in items]})
write("documents.json", {"version": 1, "documents": documents})
month = today.strftime("%Y-%m")
write("settings.json", {
    "version": 1,
    "profile": {
        "name": "鈴木内装",
        "postalCode": "222-0033",
        "address": "神奈川県横浜市港北区新横浜2-5-10",
        "phone": "090-1234-5678",
        "email": "",
        "bank": "港北信用金庫 新横浜支店\n普通 1234567 スズキ ハヤト",
        "registrationNumber": "T1234567890123",
    },
    "counters": {f"Q-{today.year}": 24, f"INV-{today.year}": 18},
    "created": {month: 3},
})
write("entitlement.json", {"version": 1})
shutil.copy(os.path.join(os.path.dirname(__file__), "demo_seal.png"), os.path.join(root, "seal.png"))
print(f"wrote {len(documents)} documents to {root}")
