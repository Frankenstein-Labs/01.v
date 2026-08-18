import { statusesInfo } from 'ee/compliance_dashboard/components/standards_adherence_report/components/details_drawer/statuses_info';

describe('statusesInfo', () => {
  describe('projectSettingsPath configuration', () => {
    it('includes projectSettingsPath for approval-related controls', () => {
      const approvalControls = [
        'minimum_approvals_required_1',
        'minimum_approvals_required_2',
        'merge_request_prevent_author_approval',
        'merge_request_prevent_committers_approval',
        'reset_approvals_on_push',
      ];

      approvalControls.forEach((controlName) => {
        expect(statusesInfo[controlName]).toHaveProperty('projectSettingsPath');
        expect(statusesInfo[controlName].projectSettingsPath).toBe('/-/settings/merge_requests');
      });
    });

    it('includes projectSettingsPath for repository-related controls', () => {
      const repositoryControls = [
        'default_branch_protected',
        'code_changes_requires_code_owners',
        'restrict_push_merge_access',
        'force_push_disabled',
        'push_protection_enabled',
      ];

      repositoryControls.forEach((controlName) => {
        expect(statusesInfo[controlName]).toHaveProperty('projectSettingsPath');
        expect(statusesInfo[controlName].projectSettingsPath).toBe('/-/settings/repository');
      });
    });

    it('includes projectSettingsPath for CI/CD-related controls', () => {
      const cicdControls = [
        'project_user_defined_variables_restricted_to_maintainers',
        'cicd_job_token_scope_enabled',
      ];

      cicdControls.forEach((controlName) => {
        expect(statusesInfo[controlName]).toHaveProperty('projectSettingsPath');
        expect(statusesInfo[controlName].projectSettingsPath).toBe('/-/settings/ci_cd');
      });
    });

    it('includes projectSettingsPath for general project settings controls', () => {
      const generalControls = ['project_visibility_not_internal', 'issue_tracking_enabled'];

      generalControls.forEach((controlName) => {
        expect(statusesInfo[controlName]).toHaveProperty('projectSettingsPath');
        expect(statusesInfo[controlName].projectSettingsPath).toBe('/-/edit');
      });
    });

    it('does not include projectSettingsPath for scanner-related controls', () => {
      const scannerControls = [
        'scanner_sast_running',
        'scanner_secret_detection_running',
        'scanner_dep_scanning_running',
        'scanner_container_scanning_running',
        'scanner_license_compliance_running',
        'scanner_dast_running',
        'scanner_api_security_running',
        'scanner_code_quality_running',
        'scanner_iac_running',
      ];

      scannerControls.forEach((controlName) => {
        expect(statusesInfo[controlName]).not.toHaveProperty('projectSettingsPath');
      });
    });

    it('does not include projectSettingsPath for controls without actionable settings', () => {
      const nonActionableControls = [
        'auth_sso_enabled',
        'terraform_enabled',
        'project_repo_exists',
        'gitlab_license_level_ultimate',
      ];

      nonActionableControls.forEach((controlName) => {
        if (statusesInfo[controlName]) {
          expect(statusesInfo[controlName]).not.toHaveProperty('projectSettingsPath');
        }
      });
    });
  });

  describe('existing functionality', () => {
    it('maintains all required properties for each status', () => {
      Object.entries(statusesInfo).forEach(([, statusInfo]) => {
        expect(statusInfo).toHaveProperty('title');
        expect(statusInfo).toHaveProperty('description');
        expect(statusInfo).toHaveProperty('fixes');
        expect(Array.isArray(statusInfo.fixes)).toBe(true);

        statusInfo.fixes.forEach((fix) => {
          expect(fix).toHaveProperty('title');
          expect(fix).toHaveProperty('description');
          expect(fix).toHaveProperty('linkTitle');
          expect(fix).toHaveProperty('ultimate');
          expect(fix).toHaveProperty('link');
        });
      });
    });

    it('has consistent structure for controls with projectSettingsPath', () => {
      const controlsWithSettings = Object.entries(statusesInfo).filter(
        ([, statusInfo]) => statusInfo.projectSettingsPath,
      );

      expect(controlsWithSettings.length).toBeGreaterThan(0);

      controlsWithSettings.forEach(([, statusInfo]) => {
        expect(typeof statusInfo.projectSettingsPath).toBe('string');
        expect(statusInfo.projectSettingsPath).toMatch(/^\/.*$/); // Should start with /
        expect(statusInfo.fixes.length).toBeGreaterThan(0); // Should have fixes
      });
    });
  });
});
