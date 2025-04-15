"""
student.py
-----------
Represents a single student.
Currently, it only stores the student’s username.
"""

class Student:
    def __init__(self, username: str):
        self.username = username

    def __str__(self):
        return self.username