from __future__ import annotations

import hashlib
import importlib.util
import tempfile
import unittest
from pathlib import Path

MODULE_PATH = (
    Path(__file__).resolve().parents[2]
    / "docs"
    / "tooling"
    / "version_assets.py"
)
MODULE_SPEC = importlib.util.spec_from_file_location(
    "version_docs_assets", MODULE_PATH
)
if MODULE_SPEC is None or MODULE_SPEC.loader is None:
    raise RuntimeError(
        f"Could not load documentation tooling from {MODULE_PATH}"
    )
VERSION_DOCS_ASSETS = importlib.util.module_from_spec(MODULE_SPEC)
MODULE_SPEC.loader.exec_module(VERSION_DOCS_ASSETS)
version_assets = VERSION_DOCS_ASSETS.version_assets


class VersionDocsAssetsTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.site_dir = Path(self.temporary_directory.name).resolve()

    def write(self, relative_path: str, content: str) -> Path:
        path = self.site_dir / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        return path

    def digest(self, content: str) -> str:
        return hashlib.sha256(content.encode()).hexdigest()[:12]

    def test_versions_all_local_stylesheets_and_scripts(self) -> None:
        base_css = self.write("assets/base.css", "base")
        custom_css = self.write("assets/custom.css", "custom")
        app_js = self.write("assets/app.js", "app")
        index = self.write(
            "guide/index.html",
            """<!doctype html>
<link rel="stylesheet" href="/assets/base.css">
<link href='../assets/custom.css?v=old&amp;theme=dark#colors' rel='stylesheet'>
<link rel="stylesheet" href="https://example.com/external.css">
<link rel="icon" href="/assets/favicon.svg">
<script defer src="../assets/app.js"></script>
<script src="//cdn.example.com/external.js"></script>
<script>console.log("inline")</script>
""",
        )

        versions = version_assets(self.site_dir)

        self.assertEqual(
            versions,
            {
                base_css: self.digest("base"),
                custom_css: self.digest("custom"),
                app_js: self.digest("app"),
            },
        )
        rendered = index.read_text(encoding="utf-8")
        self.assertIn(f"/assets/base.css?v={self.digest('base')}", rendered)
        self.assertIn(
            f"../assets/custom.css?theme=dark&amp;v={self.digest('custom')}#colors",
            rendered,
        )
        self.assertIn(f"../assets/app.js?v={self.digest('app')}", rendered)
        self.assertIn("https://example.com/external.css", rendered)
        self.assertIn("//cdn.example.com/external.js", rendered)
        self.assertIn('rel="icon" href="/assets/favicon.svg"', rendered)

    def test_second_run_is_idempotent(self) -> None:
        self.write("assets/site.css", "style")
        index = self.write(
            "index.html",
            '<link rel="stylesheet" href="assets/site.css">',
        )

        version_assets(self.site_dir)
        first_run = index.read_text(encoding="utf-8")
        version_assets(self.site_dir)

        self.assertEqual(index.read_text(encoding="utf-8"), first_run)

    def test_missing_local_asset_fails(self) -> None:
        self.write(
            "index.html",
            '<script src="assets/missing.js"></script>',
        )

        with self.assertRaisesRegex(
            FileNotFoundError,
            "Referenced asset does not exist",
        ):
            version_assets(self.site_dir)

    def test_asset_cannot_escape_site_directory(self) -> None:
        outside = self.site_dir.parent / f"{self.site_dir.name}-outside.css"
        outside.write_text("outside", encoding="utf-8")
        self.addCleanup(outside.unlink)
        self.write(
            "index.html",
            f'<link rel="stylesheet" href="../{outside.name}">',
        )

        with self.assertRaisesRegex(
            RuntimeError,
            "Asset URL escapes the site directory",
        ):
            version_assets(self.site_dir)


if __name__ == "__main__":
    unittest.main()
