"""
storage.py
-----------
Provides functions to save and load class data to/from a JSON file.
This is a simple persistent storage solution.
"""

import json
import os
from models.classgroup import ClassGroup
from models.student import Student

# Define the file path for storage.
STORAGE_FILE = os.path.join(os.path.dirname(__file__), "data.json")


def save_classes(class_list: list[ClassGroup]) -> None:
    """
    Saves the given list of ClassGroup objects to a JSON file.

    Args:
        class_list (list[ClassGroup]): List of class objects to save.
    """
    data = []
    for cls in class_list:
        data.append({
            "name": cls.name,
            "quarter": cls.quarter,
            "course": cls.course,
            "template": cls.template,
            "datastore": cls.datastore,
            "network_adapters": cls.network_adapters,
            "students": [stu.username if hasattr(stu, "username") else str(stu) for stu in cls.students],
        })
    with open(STORAGE_FILE, "w") as f:
        json.dump(data, f, indent=4)


def load_classes() -> list[ClassGroup]:
    """
    Loads class objects from the JSON file.

    Returns:
        list[ClassGroup]: The list of classes, or an empty list if the file does not exist.
    """
    if not os.path.exists(STORAGE_FILE):
        return []
    with open(STORAGE_FILE, "r") as f:
        data = json.load(f)
    classes = []
    for item in data:
        student_objs = [Student(s) for s in item.get("students", [])]
        cls = ClassGroup(
            name=item["name"],
            quarter=item["quarter"],
            course=item["course"],
            students=student_objs,
            template=item["template"],
            datastore=item["datastore"],
            network_adapters=item.get("network_adapters", [])
        )
        classes.append(cls)
    return classes