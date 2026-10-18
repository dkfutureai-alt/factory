"""Offline release-engineering regressions; use only fabricated config values."""

import sys
import tempfile
import unittest
from pathlib import Path
from xml.etree import ElementTree as ET

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from release_preflight import validate_configuration
from android_permissions import apply_manifest, NAME, REQUIRED


class ReleaseConfigurationTests(unittest.TestCase):
    def setUp(self):
        self.env = {
            "FACTORYOS_RELEASE_ENV": "staging",
            "FACTORYOS_SUPABASE_URL": "https://factory-staging.supabase.co",
            "FACTORYOS_SUPABASE_PUBLISHABLE_KEY": "sb_publishable_0123456789abcdef",
            "FACTORYOS_ADMIN_BASE_HREF": "/factoryos/",
        }

    def bad(self, **updates):
        self.assertTrue(validate_configuration({**self.env, **updates}, "web"))

    def test_web_and_android_valid(self):
        self.assertEqual(validate_configuration(self.env, "web"), [])
        self.assertEqual(validate_configuration(self.env, "android-qa"), [])

    def test_missing_release_env(self):
        self.bad(FACTORYOS_RELEASE_ENV="")

    def test_insecure_url(self):
        self.bad(FACTORYOS_SUPABASE_URL="http://factory.supabase.co")

    def test_localhost_url(self):
        self.bad(FACTORYOS_SUPABASE_URL="https://localhost")

    def test_placeholder_url(self):
        self.bad(FACTORYOS_SUPABASE_URL="https://example.supabase.co")

    def test_url_credentials(self):
        self.bad(FACTORYOS_SUPABASE_URL="https://u:p@factory.supabase.co")

    def test_url_query(self):
        self.bad(FACTORYOS_SUPABASE_URL="https://factory.supabase.co/?key=x")

    def test_url_path(self):
        self.bad(FACTORYOS_SUPABASE_URL="https://factory.supabase.co/rest/v1")

    def test_service_secret_rejected(self):
        self.bad(FACTORYOS_SUPABASE_PUBLISHABLE_KEY="sb_secret_0123456789abcdef")

    def test_service_role_jwt_rejected(self):
        self.bad(FACTORYOS_SUPABASE_PUBLISHABLE_KEY="eyJ.fake.service_role")

    def test_empty_key_rejected(self):
        self.bad(FACTORYOS_SUPABASE_PUBLISHABLE_KEY="")

    def test_invalid_web_subpath(self):
        self.bad(FACTORYOS_ADMIN_BASE_HREF="/factoryos")

    def test_external_web_subpath(self):
        self.bad(FACTORYOS_ADMIN_BASE_HREF="https://host.example/")

    def test_root_web_subpath(self):
        self.env["FACTORYOS_ADMIN_BASE_HREF"] = "/"
        self.assertEqual(validate_configuration(self.env, "web"), [])

    def test_unknown_target(self):
        self.assertTrue(validate_configuration(self.env, "ios"))

    def test_android_qa_requires_no_runtime_brand_override(self):
        # Package identity is fixed in the committed Gradle project.
        self.assertNotIn("FACTORYOS_ANDROID_ORG", self.env)
        self.assertEqual(validate_configuration(self.env, "android-qa"), [])



class NativeIdentityTests(unittest.TestCase):
    def test_qa_workflow_reuses_committed_native_package(self):
        root = Path(__file__).resolve().parents[2]
        workflow = (root / ".github/workflows/release-candidate.yml").read_text()
        gradle = (root / "apps/mobile/android/app/build.gradle.kts").read_text()
        app_id = 'applicationId = "com.dkappsstudio.factoryos"'
        namespace = 'namespace = "com.dkappsstudio.factoryos"'
        self.assertNotIn("flutter create", workflow)
        self.assertNotIn("FACTORYOS_ANDROID_ORG", workflow)
        self.assertIn(app_id, workflow)
        self.assertIn(namespace, workflow)
        self.assertIn(app_id, gradle)
        self.assertIn(namespace, gradle)



class AndroidPermissionsTests(unittest.TestCase):
    def test_permissions_and_idempotency(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "AndroidManifest.xml"
            path.write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application android:label="FactoryOS" /></manifest>')
            self.assertTrue(apply_manifest(path))
            self.assertFalse(apply_manifest(path))
            root = ET.parse(path).getroot()
            permissions = {e.attrib[NAME] for e in root.findall("uses-permission")}
            self.assertEqual(permissions, {"android.permission.INTERNET", "android.permission.CAMERA"})
            self.assertEqual(root.find("uses-feature").attrib[REQUIRED], "false")
            self.assertEqual(root.find("application").attrib[f"{{http://schemas.android.com/apk/res/android}}label"], "FactoryOS")

    def test_invalid_manifest(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "AndroidManifest.xml"
            path.write_text("<application />")
            with self.assertRaises(ValueError):
                apply_manifest(path)


if __name__ == "__main__":
    unittest.main()
