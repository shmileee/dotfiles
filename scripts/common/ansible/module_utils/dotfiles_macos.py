"""Pure helpers shared by the dotfiles macOS Ansible modules.

This file deliberately has no Ansible imports. Keeping normalization and
comparison code independent makes it usable from module code and inexpensive
to test with the Python standard library.
"""

from __future__ import annotations

import base64
import datetime
import plistlib
import posixpath
import xml.etree.ElementTree as element_tree
from pathlib import Path
from typing import Any, Dict, Iterable, List, Mapping
from urllib.parse import unquote, urlsplit, urlunsplit


def normalize_plist_value(value: Any, value_type: str) -> Any:
    """Coerce a module value and verify that plistlib can serialize it."""
    if value_type == "string":
        normalized = str(value)
    elif value_type == "bool":
        if not isinstance(value, bool):
            raise ValueError("a bool value must be true or false")
        normalized = value
    elif value_type == "int":
        if isinstance(value, bool):
            raise ValueError("an int value cannot be a boolean")
        try:
            normalized = int(value)
        except (TypeError, ValueError) as error:
            raise ValueError("an int value must be an integer") from error
    elif value_type == "float":
        if isinstance(value, bool):
            raise ValueError("a float value cannot be a boolean")
        try:
            normalized = float(value)
        except (TypeError, ValueError) as error:
            raise ValueError("a float value must be numeric") from error
    elif value_type == "array":
        if not isinstance(value, list):
            raise ValueError("an array value must be a list")
        normalized = value
    elif value_type == "dict":
        if not isinstance(value, dict):
            raise ValueError("a dict value must be a mapping")
        normalized = value
    else:
        raise ValueError("unsupported plist value type: {0}".format(value_type))

    try:
        plistlib.dumps([normalized], fmt=plistlib.FMT_XML, sort_keys=False)
    except (TypeError, ValueError) as error:
        raise ValueError(
            "value is not plist-serializable: {0}".format(error)
        ) from error
    return normalized


def plist_fragment(value: Any) -> str:
    """Serialize one value in the XML form accepted by ``defaults``."""
    document = plistlib.dumps([value], fmt=plistlib.FMT_XML, sort_keys=False)
    root = element_tree.fromstring(document)
    array = root.find("array")
    if array is None or len(array) != 1:
        raise ValueError("could not serialize plist value")
    return element_tree.tostring(array[0], encoding="unicode")


def merged_mapping(current: Any, desired: Mapping[str, Any]) -> Dict[str, Any]:
    """Return a shallow plist dictionary merge without mutating either input."""
    merged = dict(current) if isinstance(current, dict) else {}
    merged.update(desired)
    return merged


def json_safe_plist(value: Any) -> Any:
    """Convert native plist-only values into explicit JSON-safe representations."""
    if isinstance(value, bytes):
        return {"__plist_data__": base64.b64encode(value).decode("ascii")}
    if isinstance(value, datetime.datetime):
        return {"__plist_date__": value.isoformat()}
    if isinstance(value, str):
        return value.encode("utf-8", "replace").decode("utf-8")
    if isinstance(value, dict):
        return {
            json_safe_plist(key): json_safe_plist(item) for key, item in value.items()
        }
    if isinstance(value, list):
        return [json_safe_plist(item) for item in value]
    return value


def normalize_location(value: str) -> str:
    """Normalize file paths and URLs without losing URL scheme or authority."""
    parsed = urlsplit(value)
    if parsed.scheme and parsed.scheme != "file":
        path = posixpath.normpath(unquote(parsed.path or "/"))
        if parsed.path.endswith("/") and path != "/":
            path += "/"
        return urlunsplit(
            (parsed.scheme.lower(), parsed.netloc, path, parsed.query, parsed.fragment)
        )

    path = unquote(parsed.path) if parsed.scheme == "file" else value
    expanded = str(Path(path).expanduser())
    return expanded if expanded == "/" else expanded.rstrip("/")


def parse_dockutil_output(output: str) -> List[Dict[str, str]]:
    """Parse dockutil's documented tab-delimited list format."""
    sections = {"persistentApps": "apps", "persistentOthers": "others"}
    items = []
    for line_number, line in enumerate(output.splitlines(), start=1):
        if not line.strip():
            continue
        fields = line.split("\t")
        if len(fields) < 4:
            raise ValueError(
                "unexpected dockutil output on line {0}: {1!r}".format(
                    line_number, line
                )
            )
        section = sections.get(fields[2])
        if section is None:
            raise ValueError(
                "unexpected Dock section on line {0}: {1!r}".format(
                    line_number, fields[2]
                )
            )
        items.append(
            {
                "name": fields[0],
                "path": normalize_location(fields[1]),
                "section": section,
                "plist": fields[3],
            }
        )
    return items


def dock_states_match(
    current: Iterable[Mapping[str, Any]], desired: Iterable[Mapping[str, Any]]
) -> bool:
    """Compare ordered Dock state, ignoring unspecified folder presentation."""
    current_list = list(current)
    desired_list = list(desired)
    if len(current_list) != len(desired_list):
        return False

    for actual, expected in zip(current_list, desired_list):
        if (
            actual["path"] != expected["path"]
            or actual["section"] != expected["section"]
        ):
            return False
        expected_options = expected.get("options", {})
        actual_options = actual.get("options", {})
        if any(
            actual_options.get(key) != value for key, value in expected_options.items()
        ):
            return False
    return True


def dock_option_arguments(options: Mapping[str, str]) -> List[str]:
    """Convert typed folder presentation options to stable dockutil arguments."""
    arguments = []
    for name in ("view", "display", "sort"):
        value = options.get(name)
        if value is not None:
            arguments.extend(["--{0}".format(name), value])
    return arguments
