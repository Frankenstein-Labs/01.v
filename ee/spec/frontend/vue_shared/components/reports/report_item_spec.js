import { shallowMount } from '@vue/test-utils';
import { componentNames, iconComponentNames } from 'ee/ci/reports/components/issue_body';
import { codequalityParsedIssues } from 'ee_jest/vue_merge_request_widget/mock_data';
import LicenseIssueBody from 'ee/vue_shared/license_compliance/components/license_issue_body.vue';
import LicenseStatusIcon from 'ee/vue_shared/license_compliance/components/license_status_icon.vue';
import CodequalityIssueBody from '~/ci/reports/codequality_report/components/codequality_issue_body.vue';
import ReportLink from '~/ci/reports/components/report_link.vue';
import { licenseComplianceParsedIssues } from 'ee_jest/vue_shared/security_reports/mock_data';
import ReportIssue from '~/ci/reports/components/report_item.vue';
import { STATUS_FAILED, STATUS_SUCCESS, STATUS_NEUTRAL } from '~/ci/reports/constants';

describe('Report issue', () => {
  let wrapper;

  describe('for codequality issue', () => {
    describe('resolved issue', () => {
      beforeEach(() => {
        wrapper = shallowMount(ReportIssue, {
          propsData: {
            issue: codequalityParsedIssues[0],
            component: componentNames.CodequalityIssueBody,
            status: STATUS_SUCCESS,
          },
          stubs: {
            CodequalityIssueBody,
            ReportLink,
          },
        });
      });

      it('should render "Fixed" keyword', () => {
        expect(wrapper.text()).toContain('Fixed');
        expect(wrapper.text()).toMatchInterpolatedText(
          'Fixed: Minor - Insecure Dependency in Gemfile.lock:12',
        );
      });
    });

    describe('unresolved issue', () => {
      beforeEach(() => {
        wrapper = shallowMount(ReportIssue, {
          propsData: {
            issue: codequalityParsedIssues[0],
            component: componentNames.CodequalityIssueBody,
            status: STATUS_FAILED,
          },
        });
      });

      it('should not render "Fixed" keyword', () => {
        expect(wrapper.text()).not.toContain('Fixed');
      });
    });
  });

  describe('for license compliance issue', () => {
    it('renders LicenseIssueBody & LicenseStatusIcon', () => {
      wrapper = shallowMount(ReportIssue, {
        propsData: {
          issue: licenseComplianceParsedIssues[0],
          component: componentNames.LicenseIssueBody,
          iconComponent: iconComponentNames.LicenseStatusIcon,
          status: STATUS_NEUTRAL,
        },
        stubs: {
          LicenseIssueBody,
          LicenseStatusIcon,
        },
      });

      expect(wrapper.findComponent(LicenseIssueBody).exists()).toBe(true);
      expect(wrapper.findComponent(LicenseStatusIcon).exists()).toBe(true);
    });
  });
});
