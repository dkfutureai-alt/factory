"""Protect manual production workflows from unreviewed release changes."""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
WORKFLOWS = {
    'production-smoke.yml': 'VERIFY',
    'admin-production-release.yml': 'PUBLISH',
    'android-production-bundle.yml': 'BUILD',
    'supabase-production-release.yml': 'DEPLOY',
}

class ProductionWorkflowGuardTests(unittest.TestCase):
    def content(self, name):
        return (ROOT / '.github' / 'workflows' / name).read_text(encoding='utf-8')

    def test_main_only_confirmation(self):
        for name, confirmation in WORKFLOWS.items():
            with self.subTest(name=name):
                self.assertIn("inputs.confirm == '" + confirmation + "' && github.ref == 'refs/heads/main'", self.content(name))

    def test_production_environment(self):
        for name in WORKFLOWS:
            with self.subTest(name=name):
                self.assertIn('    environment: factoryos-production\n', self.content(name))

    def test_admin_human_project_confirmation(self):
        s = self.content('admin-production-release.yml')
        self.assertIn('      confirm_project_ref:\n', s)
        self.assertIn('      CONFIRMED_PROJECT_REF: ${{ inputs.confirm_project_ref }}', s)
        self.assertIn('[[ "$CONFIRMED_PROJECT_REF" != "$SUPABASE_PROJECT_REF" ]]', s)
        self.assertIn('[[ "${SUPABASE_URL%/}" != "https://${SUPABASE_PROJECT_REF}.supabase.co" ]]', s)
        self.assertIn('^[a-z0-9]{20}$', s)

    def test_admin_both_jobs_main_only(self):
        s = self.content('admin-production-release.yml')
        self.assertEqual(s.count("if: ${{ inputs.confirm == 'PUBLISH' && github.ref == 'refs/heads/main' }}"), 2)

    def test_smoke_is_read_only(self):
        s = self.content('production-smoke.yml')
        self.assertIn('Verify authenticated identity and tenant RLS', s)
        self.assertNotIn('supabase db push', s)

if __name__ == '__main__':
    unittest.main()
