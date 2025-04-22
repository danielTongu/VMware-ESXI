"""
mock_data.py
------------
Provides mock data for rapid GUI prototyping without a real backend.
Includes lists of classes, VM templates, datastores, and network adapters.
"""


def get_mock_classes():
    """
    Returns a list of mock class dictionaries.

    Each dictionary contains:
      - name:       The class name/ID
      - quarter:    The academic quarter
      - course:     The course code
      - template:   The VM template name
      - datastore:  The datastore name
      - network_adapters: A list of adapter types
      - students:   A list of student usernames
    """
    return [
        {
            "name": "CS470",
            "quarter": "Spring 2025",
            "course": "CS470",
            "template": "UbuntuTemplate",
            "datastore": "Datastore1",
            "network_adapters": ["NAT", "Instructor"],
            "students": ["alice", "bob", "carol"]
        },
        {
            "name": "CS480",
            "quarter": "Winter 2025",
            "course": "CS480",
            "template": "WinTemplate",
            "datastore": "Datastore2",
            "network_adapters": ["Inside"],
            "students": ["dave", "emma"]
        }
    ]


def get_mock_templates():
    """
    Returns a list of available VM template names for mocking.
    """
    return ["UbuntuTemplate", "WinTemplate"]


def get_mock_datastores():
    """
    Returns a list of datastore names for mocking.
    """
    return ["Datastore1", "Datastore2"]


def get_mock_adapters():
    """
    Returns a list of network adapter types for mocking.
    """
    return ["NAT", "Instructor", "Inside"]