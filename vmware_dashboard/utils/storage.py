"""
storage.py
----------
Loads/saves ClassGroup objects to JSON, or uses mock_data if USE_MOCK.
"""

import json
import os
from vmware_dashboard.utils.config import USE_MOCK
from vmware_dashboard.models.classgroup import ClassGroup
from vmware_dashboard.models.student import Student

DATA_FILE = os.path.join(os.path.dirname(__file__), "data.json")

if USE_MOCK:
    from vmware_dashboard.utils.mock_data import get_mock_classes

    def load_classes() -> list[ClassGroup]:
        raw = get_mock_classes()
        classes = []
        for item in raw:
            students = [Student(u) for u in item["students"]]
            cls = ClassGroup(
                name=item["name"],
                quarter=item["quarter"],
                course=item["course"],
                students=students,
                template=item["template"],
                datastore=item["datastore"],
                network_adapters=item["network_adapters"]
            )
            classes.append(cls)
        return classes

    def save_classes(class_list: list[ClassGroup]) -> None:
        print("[MOCK] Saved classes:", [c.name for c in class_list])

else:
    def load_classes() -> list[ClassGroup]:
        if not os.path.exists(DATA_FILE):
            return []
        with open(DATA_FILE, "r") as f:
            data = json.load(f)
        classes = []
        for item in data:
            students = [Student(u) for u in item.get("students", [])]
            cls = ClassGroup(
                name=item.get("name", ""),
                quarter=item.get("quarter", ""),
                course=item.get("course", ""),
                students=students,
                template=item.get("template", ""),
                datastore=item.get("datastore", ""),
                network_adapters=item.get("network_adapters", [])
            )
            classes.append(cls)
        return classes

    def save_classes(class_list: list[ClassGroup]) -> None:
        os.makedirs(os.path.dirname(DATA_FILE), exist_ok=True)
        data = []
        for cls in class_list:
            data.append({
                "name": cls.name,
                "quarter": cls.quarter,
                "course": cls.course,
                "template": cls.template,
                "datastore": cls.datastore,
                "network_adapters": cls.network_adapters,
                "students": [s.username for s in cls.students]
            })
        with open(DATA_FILE, "w") as f:
            json.dump(data, f, indent=4)