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

    def test_release_lint_on_script_and_workflow_changes(self):
        s = self.content("release-workflow-lint.yml")
        self.assertEqual(s.count("      - '.github/workflows/**'"), 2)
        self.assertEqual(s.count("      - 'scripts/**'"), 2)

    def test_main_only_confirmation(self):
        for name, confirmation in WORKFLOWS.items():
            with self.subTest(name=name):
                self.assertIn("inputs.confirm == '" + confirmation + "' && github.ref == 'refs/heads/main'", self.content(name))

    def test_all_manual_production_workflows_pin_factoryos_project(self):
        for name in WORKFLOWS:
            with self.subTest(name=name):
                content = self.content(name)
                self.assertIn('[[ "$SUPABASE_PROJECT_REF" != "zevrmvhnibztbxizswgu" ]]', content)
                self.assertIn('[[ "$CONFIRMED_PROJECT_REF" != "$SUPABASE_PROJECT_REF" ]]', content)

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

    def test_database_only_release_keeps_separate_approval_gate(self):
        s = self.content('supabase-production-release.yml')
        self.assertIn("github.ref == 'refs/heads/main'", s)
        self.assertIn('    environment: factoryos-production\\n'.replace('\\n', '\n'), s)
        self.assertIn('      release_scope:\\n'.replace('\\n', '\n'), s)
        self.assertIn('          - database-only', s)
        self.assertIn('          - full', s)
        self.assertIn("""if [[ "$RELEASE_SCOPE" == 'full' ]]; then""", s)
        self.assertEqual(s.count("if: inputs.release_scope == 'full'"), 2)
        self.assertIn('supabase db push --dry-run', s)
        self.assertIn('supabase db push', s)
        self.assertNotIn('supabase db reset', s)
        self.assertIn('test -f supabase/migrations/0044_customer_pilot_testing.sql', s)
        self.assertIn('test -f supabase/migrations/0048_gas_serial_transaction_links.sql', s)
        self.assertIn('test -f supabase/migrations/0049_gas_serial_attestation_coverage.sql', s)

    def test_smoke_fails_closed_on_ambiguous_membership_and_anon_errors(self):
        s = self.content("production-smoke.yml")
        self.assertIn('type == "array" and length == 1 and all(.[];', s)
        self.assertIn('organization_id&user_id=eq.${user_id}&is_active=eq.true&limit=2', s)
        self.assertIn('type == "array" and length == 1 and (.[0].organization_id | type == "string")', s)
        self.assertIn('Anonymous ${table} access was not explicitly denied (expected 4xx).', s)

    def test_smoke_is_read_only(self):
        s = self.content('production-smoke.yml')
        self.assertIn('Verify authenticated identity and tenant RLS', s)
        self.assertIn('Verify Phase 20 returnable-intake API permissions (read-only)', s)
        self.assertIn('Verify Phase 17 customer-pilot API access (read-only)', s)
        self.assertIn('Verify Phase 21A/21B serial registry and transaction evidence API (read-only)', s)
        self.assertIn('gas_container_assets gas_container_asset_events gas_container_transaction_links', s)
        self.assertIn('Gas registry $table anonymous access not denied', s)
        self.assertIn('Verify Phase 21C serial coverage RPC access (read-only)', s)
        self.assertIn('gas_serial_attestation_coverage', s)
        self.assertIn('Anonymous cylinder serial coverage RPC was not denied', s)
        self.assertIn('for table in pilot_participants pilot_feedback; do', s)
        self.assertIn('Anonymous customer-pilot API access unexpectedly succeeded:', s)
        self.assertIn('type == "array"', s)
        self.assertIn('no data changed', s)
        self.assertIn('dispatch_returnable_intakes dispatch_returnable_intake_lines', s)
        self.assertIn('Anonymous ${table} access was not explicitly denied (expected 4xx).', s)
        self.assertIn('select=id&limit=1', s)
        self.assertNotIn('supabase db push', s)
        self.assertNotIn('supabase db reset', s)
        self.assertNotIn('--request PATCH', s)
        self.assertNotIn('--request DELETE', s)

if __name__ == '__main__':
    unittest.main()
