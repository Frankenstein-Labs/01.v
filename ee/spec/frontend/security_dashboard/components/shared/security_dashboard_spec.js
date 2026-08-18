import SecurityDashboard from 'ee/security_dashboard/components/shared/security_dashboard.vue';
import gradesQuery from 'ee/security_dashboard/graphql/queries/instance_vulnerability_grades.query.graphql';
import historyQuery from 'ee/security_dashboard/graphql/queries/instance_vulnerability_history.query.graphql';
import VulnerabilitiesOverTimeChart from 'ee/security_dashboard/components/shared/vulnerabilities_over_time_chart.vue';
import VulnerabilitySeverities from 'ee/security_dashboard/components/shared/project_security_status_chart.vue';
import NoLongerDetectedVulnerabilitiesAlert from 'ee/security_dashboard/components/shared/no_longer_detected_vulnerabilities_alert.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import IndexLayout from '~/vue_shared/components/index_layout.vue';
import BaseLayout from '~/vue_shared/components/base_layout.vue';
import PdfExportButton from 'ee/security_dashboard/components/shared/pdf_export_button.vue';

describe('Security Dashboard Layout component', () => {
  let wrapper;

  const groupFullPath = 'group/path';

  const findVulnerabilitiesOverTimeChart = () =>
    wrapper.findComponent(VulnerabilitiesOverTimeChart);
  const findVulnerabilitySeverities = () => wrapper.findComponent(VulnerabilitySeverities);
  const findNoLongerDetectedVulnerabilitiesAlert = () =>
    wrapper.findComponent(NoLongerDetectedVulnerabilitiesAlert);
  const findExportButton = () => wrapper.findComponent(PdfExportButton);

  const createWrapper = ({ showExport = false, stubs = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(SecurityDashboard, {
      propsData: { historyQuery, gradesQuery, showExport },
      stubs: {
        PageHeading,
        IndexLayout,
        BaseLayout,
        ...stubs,
      },
      provide: {
        groupFullPath,
        ...provide,
      },
    });
  };

  it('displays page header', () => {
    createWrapper();

    expect(wrapper.findByTestId('page-heading').text()).toBe('Security dashboard');
  });

  it('displays charts', () => {
    createWrapper();

    expect(findVulnerabilitiesOverTimeChart().props('query')).toBe(historyQuery);
    expect(findVulnerabilitySeverities().props('query')).toBe(gradesQuery);
  });

  it('displays the no longer detected vulnerabilities alert', () => {
    createWrapper();

    expect(findNoLongerDetectedVulnerabilitiesAlert().exists()).toBe(true);
  });

  describe('export button', () => {
    it.each`
      showExport | expected
      ${false}   | ${false}
      ${true}    | ${true}
    `(
      'renders export button $expected when showExport is $showExport',
      ({ showExport, expected }) => {
        createWrapper({ showExport });
        expect(findExportButton().exists()).toBe(expected);
      },
    );

    it('includes the group full path in the report data', () => {
      createWrapper({
        showExport: true,
      });

      const getReportDataFn = findExportButton().props('getReportData');
      const result = getReportDataFn();

      expect(result.full_path).toBe(groupFullPath);
    });
  });
});
