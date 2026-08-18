import { GlLink, GlSprintf } from '@gitlab/ui';
import { mapValues, pick } from 'lodash-es';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import pipelineSecurityReportSummaryQuery from 'ee/security_dashboard/graphql/queries/pipeline_security_report_summary.query.graphql';
import PipelineSecurityDashboard from 'ee/security_dashboard/components/pipeline/pipeline_security_dashboard.vue';
import ReportStatusAlert from 'ee/security_dashboard/components/pipeline/report_status_alert.vue';
import ScanAlerts, {
  TYPE_ERRORS,
  TYPE_WARNINGS,
} from 'ee/security_dashboard/components/pipeline/scan_alerts.vue';
import SecurityReportsSummary from 'ee/security_dashboard/components/pipeline/security_reports_summary.vue';
import { dismissalDescriptions } from 'ee_jest/vulnerabilities/mock_data';
import SbomReportsErrorsAlert from 'ee/dependencies/components/sbom_reports_errors_alert.vue';
import {
  pipelineSecurityReportSummary,
  pipelineSecurityReportSummaryWithErrors,
  pipelineSecurityReportSummaryWithWarnings,
  purgedPipelineSecurityReportSummaryWithErrors,
  purgedPipelineSecurityReportSummaryWithWarnings,
  scansWithErrors,
  scansWithWarnings,
  pipelineSecurityReportSummaryEmpty,
} from './mock_data';

const pipelineIid = 4321;

describe('Pipeline Security Dashboard component', () => {
  let store;
  let wrapper;

  const findVulnerabilityReport = () => wrapper.findByTestId('pipeline-vulnerability-report');
  const findScanAlerts = () => wrapper.findComponent(ScanAlerts);
  const findReportStatusAlert = () => wrapper.findComponent(ReportStatusAlert);

  const factory = ({ stubs, propsData, apolloProvider } = {}) => {
    wrapper = shallowMountExtended(PipelineSecurityDashboard, {
      apolloProvider,
      store,
      provide: {
        projectFullPath: 'my-path',
        pipeline: {
          iid: pipelineIid,
        },
      },
      propsData: {
        dismissalDescriptions,
        sbomReportsErrors: [],
        ...propsData,
      },
      stubs: { PipelineVulnerabilityReport: true, ...stubs },
    });
  };

  const factoryWithApollo = ({ requestHandlers }) => {
    Vue.use(VueApollo);

    factory({ apolloProvider: createMockApollo(requestHandlers) });
  };

  it('renders pipeline vulnerability report', () => {
    factory();

    expect(findVulnerabilityReport().exists()).toBe(true);
  });

  describe('report status alert', () => {
    describe('with purged scans', () => {
      beforeEach(async () => {
        factoryWithApollo({
          requestHandlers: [
            [
              pipelineSecurityReportSummaryQuery,
              jest.fn().mockResolvedValueOnce(purgedPipelineSecurityReportSummaryWithErrors),
            ],
          ],
        });
        await waitForPromises();
      });

      it('shows the alert', () => {
        expect(findReportStatusAlert().exists()).toBe(true);
      });
    });

    describe('without purged scans', () => {
      beforeEach(async () => {
        factoryWithApollo({
          requestHandlers: [
            [
              pipelineSecurityReportSummaryQuery,
              jest.fn().mockResolvedValueOnce(pipelineSecurityReportSummary),
            ],
          ],
        });
        await waitForPromises();
      });

      it('does not show the alert', () => {
        expect(findReportStatusAlert().exists()).toBe(false);
      });
    });
  });

  describe('scans error alert', () => {
    describe('with errors', () => {
      describe('with purged scans', () => {
        beforeEach(async () => {
          factoryWithApollo({
            requestHandlers: [
              [
                pipelineSecurityReportSummaryQuery,
                jest.fn().mockResolvedValueOnce(purgedPipelineSecurityReportSummaryWithErrors),
              ],
            ],
          });
          await waitForPromises();
        });

        it('does not show the alert', () => {
          expect(findScanAlerts().exists()).toBe(false);
        });
      });

      describe('without purged scans', () => {
        beforeEach(async () => {
          factoryWithApollo({
            requestHandlers: [
              [
                pipelineSecurityReportSummaryQuery,
                jest.fn().mockResolvedValueOnce(pipelineSecurityReportSummaryWithErrors),
              ],
            ],
          });
          await waitForPromises();
        });

        it('shows an alert with information about each scan with errors', () => {
          expect(findScanAlerts().props()).toMatchObject({
            scans: scansWithErrors,
            type: TYPE_ERRORS,
          });
        });
      });
    });

    describe('without errors', () => {
      beforeEach(() => {
        factoryWithApollo({
          requestHandlers: [
            [
              pipelineSecurityReportSummaryQuery,
              jest.fn().mockResolvedValueOnce(pipelineSecurityReportSummary),
            ],
          ],
        });
      });

      it('does not show the alert', () => {
        expect(findScanAlerts().exists()).toBe(false);
      });
    });
  });

  describe('page description', () => {
    it('shows page description and help link', () => {
      factory({ stubs: { GlSprintf } });

      expect(wrapper.findByTestId('page-description').text()).toBe(
        'Results show vulnerability findings from the latest successful pipeline.',
      );
      expect(wrapper.findComponent(GlLink).attributes('href')).toBe(
        '/help/user/application_security/detect/security_scanning_results',
      );
    });
  });

  describe('scan warnings', () => {
    describe('with warnings', () => {
      describe('with purged scans', () => {
        beforeEach(async () => {
          factoryWithApollo({
            requestHandlers: [
              [
                pipelineSecurityReportSummaryQuery,
                jest.fn().mockResolvedValueOnce(purgedPipelineSecurityReportSummaryWithWarnings),
              ],
            ],
          });
          await waitForPromises();
        });

        it('does not show the alert', () => {
          expect(findScanAlerts().exists()).toBe(false);
        });
      });

      describe('without purged scans', () => {
        beforeEach(async () => {
          factoryWithApollo({
            requestHandlers: [
              [
                pipelineSecurityReportSummaryQuery,
                jest.fn().mockResolvedValueOnce(pipelineSecurityReportSummaryWithWarnings),
              ],
            ],
          });
          await waitForPromises();
        });

        it('shows an alert with information about each scan with warnings', () => {
          expect(findScanAlerts().props()).toMatchObject({
            scans: scansWithWarnings,
            type: TYPE_WARNINGS,
          });
        });
      });
    });

    describe('without warnings', () => {
      beforeEach(() => {
        factoryWithApollo({
          requestHandlers: [
            [
              pipelineSecurityReportSummaryQuery,
              jest.fn().mockResolvedValueOnce(pipelineSecurityReportSummary),
            ],
          ],
        });
      });

      it('does not show the alert', () => {
        expect(findScanAlerts().exists()).toBe(false);
      });
    });
  });

  describe('security reports summary', () => {
    it('when response is empty, does not show report summary', async () => {
      factoryWithApollo({
        requestHandlers: [
          [
            pipelineSecurityReportSummaryQuery,
            jest.fn().mockResolvedValueOnce(pipelineSecurityReportSummaryEmpty),
          ],
        ],
      });

      await waitForPromises();

      expect(wrapper.findComponent(SecurityReportsSummary).exists()).toBe(false);
    });

    it('with non-empty response, shows report summary', async () => {
      factoryWithApollo({
        requestHandlers: [
          [
            pipelineSecurityReportSummaryQuery,
            jest.fn().mockResolvedValueOnce(pipelineSecurityReportSummary),
          ],
        ],
      });

      await waitForPromises();

      expect(wrapper.findComponent(SecurityReportsSummary).props()).toEqual({
        jobs: [],
        summary: mapValues(
          pipelineSecurityReportSummary.data.project.pipeline.securityReportSummary,
          (obj) =>
            pick(obj, 'vulnerabilitiesCount', 'scannedResourcesCsvPath', 'scans', '__typename'),
        ),
      });
    });
  });

  describe('given SBOM report errors are present', () => {
    const sbomErrors = [['Invalid SBOM report']];

    beforeEach(() => {
      factory({
        propsData: {
          sbomReportsErrors: sbomErrors,
        },
      });
    });

    it('passes the correct props to the sbom-report-errort alert', () => {
      const componentWrapper = wrapper.findComponent(SbomReportsErrorsAlert);
      expect(componentWrapper.exists()).toBe(true);
      expect(componentWrapper.props('errors')).toEqual(sbomErrors);
    });
  });

  describe('validity check', () => {
    it('accepts validityChecksEnabled prop', () => {
      factory({
        propsData: {
          validityChecksEnabled: true,
        },
      });

      expect(wrapper.props('validityChecksEnabled')).toBe(true);
    });
  });
});
