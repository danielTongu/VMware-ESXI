"""
classgroup.py
--------------
Defines the ClassGroup model representing a course or class.
Holds:
  - name: Class name (unique)
  - quarter: Quarter/Semester
  - course: Course code/title
  - students: List of student usernames
  - template: Selected VM template
  - datastore: Selected datastore
  - network_adapters: List of selected network adapter types
"""

class ClassGroup:
    def __init__(self, name: str, quarter: str = "", course: str = "", students: list = None,
                 template: str = "", datastore: str = "", network_adapters: list = None):

        self.name = name
        self.quarter = quarter
        self.course = course
        self.students = students if students is not None else []
        self.template = template
        self.datastore = datastore
        self.network_adapters = network_adapters if network_adapters is not None else []

    def add_students(self, student_names: list[str]):
        """Adds student usernames to the class."""
        self.students.extend(student_names)

    def __str__(self):
        """Returns a string representation for display (e.g., 'CS101 (25 students)')."""
        return f"{self.name} ({len(self.students)} students)"