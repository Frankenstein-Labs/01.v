import { nextTick, markRaw } from 'vue';
import { GlDashboardLayout } from '@gitlab/ui';
import * as urlUtils from '~/lib/utils/url_utility';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import setWindowLocation from 'helpers/set_window_location_helper';
import { OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import {
  SEVERITY_LEVELS_KEYS,
  REPORT_TYPES_WITH_MANUALLY_ADDED,
  REPORT_TYPES_CONTAINER_SCANNING_FOR_REGISTRY,
  REPORT_TYPES_WITH_CLUSTER_IMAGE,
} from 'ee/security_dashboard/constants';
import FilteredSearch from 'ee/security_dashboard/components/shared/filtered_search/filtered_search.vue';
import OrganizationSecurityDashboardNew from 'ee/security_dashboard/components/shared/organization_security_dashboard_new.vue';
import ProjectToken from 'ee/security_dashboard/components/shared/filtered_search/tokens/project_token.vue';
import ReportTypeToken from 'ee/security_dashboard/components/shared/filtered_search/tokens/report_type_token.vue';
import VulnerabilitiesOverTimePanel from 'ee/security_dashboard/components/shared/vulnerabilities_over_time_panel.vue';
import VulnerabilitiesByAgePanel from 'ee/security_dashboard/components/shared/vulnerabilities_by_age_panel.vue';
import VulnerabilitiesByIdentifierPanel from 'ee/security_dashboard/components/shared/vulnerabilities_by_identifier_panel.vue';
import RiskScorePanel from 'ee/security_dashboard/components/shared/risk_score_panel.vue';
import SecurityDashboardDescription from 'ee/security_dashboard/components/shared/security_dashboard_description.vue';
import PdfExportButton from 'ee/security_dashboard/components/shared/pdf_export_button_new.vue';

describe('OrganizationSecurityDashboardNew', () => {
  let wrapper;

  const createComponent = ({ provide = {} } = {}) => {
    wrapper = shallowMountExtended(OrganizationSecurityDashboardNew, {
      provide,
    });
  };

  const findDashboardLayout = () => wrapper.findComponent(GlDashboardLayout);
  const findDashboardDescription = () => wrapper.findComponent(SecurityDashboardDescription);
  const findFilteredSearch = () => wrapper.findComponent(FilteredSearch);
  const findPdfExportButton = () => wrapper.findComponent(PdfExportButton);
  const getDashboardConfig = () => findDashboardLayout().props('config');
  const findPanelWithId = (panelId) => getDashboardConfig().panels.find(({ id }) => id === panelId);
  const getVulnerabilitiesOverTimePanel = () => findPanelWithId('vulnerabilities-over-time');
  const getVulnerabilitiesByAgePanel = () => findPanelWithId('vulnerabilities-by-age');
  const getVulnerabilitiesByIdentifierPanel = () =>
    findPanelWithId('vulnerabilities-by-identifier');
  const getRiskScorePanel = () => findPanelWithId('risk-score');

  beforeEach(() => {
    createComponent();
  });

  describe('component rendering', () => {
    it('renders the dashboard layout component', () => {
      expect(findDashboardLayout().exists()).toBe(true);
      expect(wrapper.findByTestId('organization-security-dashboard-new').exists()).toBe(true);
    });

    it('renders the correct title', () => {
      expect(wrapper.find('h1').text()).toBe('Security dashboard');
    });

    it('renders the description', () => {
      expect(findDashboardDescription().exists()).toBe(true);
    });

    // The PDF export endpoint does not exist for organizations, so the button must not render.
    it('does not render the PDF export button', () => {
      expect(findPdfExportButton().exists()).toBe(false);
    });
  });

  describe('panels', () => {
    it('renders the severity panels with the organization namespace', () => {
      SEVERITY_LEVELS_KEYS.forEach((severity, index) => {
        const severityPanel = findPanelWithId(severity);

        expect(severityPanel.componentProps).toMatchObject({
          namespace: 'organization',
          severity,
          filters: {},
        });
        expect(severityPanel.gridAttributes).toEqual({
          width: 2,
          height: 1,
          yPos: 0,
          xPos: 2 * index,
        });
      });
    });

    it('renders the risk score panel with the organization namespace', () => {
      const riskScorePanel = getRiskScorePanel();

      expect(riskScorePanel.component).toBe(RiskScorePanel);
      expect(riskScorePanel.componentProps.namespace).toBe('organization');
      expect(riskScorePanel.componentProps.filters).toEqual({});
      expect(riskScorePanel.gridAttributes).toEqual({ width: 5, height: 4, yPos: 1, xPos: 0 });
    });

    it('renders the vulnerabilities over time panel with the organization namespace', () => {
      const panel = getVulnerabilitiesOverTimePanel();

      expect(panel.component).toBe(VulnerabilitiesOverTimePanel);
      expect(panel.componentProps.namespace).toBe('organization');
      expect(panel.gridAttributes).toEqual({ width: 7, height: 4, xPos: 5, yPos: 1 });
    });

    it('renders the vulnerabilities by age panel with the organization namespace', () => {
      const panel = getVulnerabilitiesByAgePanel();

      expect(panel.component).toBe(VulnerabilitiesByAgePanel);
      expect(panel.componentProps.namespace).toBe('organization');
      expect(panel.gridAttributes).toEqual({ width: 6, height: 4, xPos: 0, yPos: 5 });
    });

    it('renders the vulnerabilities by identifier panel with the organization namespace', () => {
      const panel = getVulnerabilitiesByIdentifierPanel();

      expect(panel.component).toBe(VulnerabilitiesByIdentifierPanel);
      expect(panel.componentProps.namespace).toBe('organization');
      expect(panel.componentProps.filters).toEqual({});
      expect(panel.gridAttributes).toEqual({ width: 6, height: 4, yPos: 5, xPos: 6 });
    });

    it('does not render the agentic adoption funnel panel', () => {
      expect(findPanelWithId('agentic-adoption-funnel')).toBeUndefined();
    });
  });

  describe('filtered search', () => {
    it('renders filtered search without waiting on a categories query', () => {
      expect(findFilteredSearch().exists()).toBe(true);
    });

    it('offers only the project and report-type tokens', () => {
      const tokens = findFilteredSearch().props('tokens');

      expect(tokens).toEqual([
        expect.objectContaining({
          type: 'projectId',
          title: 'Project',
          multiSelect: true,
          unique: true,
          token: markRaw(ProjectToken),
          operators: OPERATORS_OR,
        }),
        expect.objectContaining({
          type: 'reportType',
          title: 'Report type',
          multiSelect: true,
          unique: true,
          token: markRaw(ReportTypeToken),
          operators: OPERATORS_OR,
        }),
      ]);
    });

    // securityCategories is not available on OrganizationType, so no attribute tokens are built.
    it('does not include any attribute/category tokens', () => {
      const tokens = findFilteredSearch().props('tokens');

      expect(tokens.some((token) => token.type.startsWith('attribute~'))).toBe(false);
    });

    it('passes the correct reportTypes configuration to the ReportTypeToken', () => {
      const reportTypeToken = findFilteredSearch()
        .props('tokens')
        .find((token) => token.type === 'reportType');

      expect(reportTypeToken.reportTypes).toEqual({
        ...REPORT_TYPES_WITH_MANUALLY_ADDED,
        ...REPORT_TYPES_WITH_CLUSTER_IMAGE,
        ...REPORT_TYPES_CONTAINER_SCANNING_FOR_REGISTRY,
      });
    });

    it('updates panel filters when filters-changed event is emitted', async () => {
      const newFilters = { projectId: ['gid://gitlab/Project/123'] };
      findFilteredSearch().vm.$emit('filters-changed', newFilters);
      await nextTick();

      expect(getVulnerabilitiesOverTimePanel().componentProps.filters).toEqual(newFilters);
    });
  });

  describe('url-params-changed', () => {
    beforeEach(() => {
      jest.spyOn(urlUtils, 'updateHistory');
    });

    afterEach(() => {
      setWindowLocation('');
    });

    it('updates browser URL when url-params-changed is emitted', () => {
      findFilteredSearch().vm.$emit('url-params-changed', {
        projectId: '5',
        reportType: 'DAST,SAST',
      });

      expect(urlUtils.updateHistory).toHaveBeenCalledWith({
        url: expect.stringContaining('projectId=5&reportType=DAST,SAST'),
        replace: true,
      });
    });

    it('does not update browser URL when it has not changed', () => {
      findFilteredSearch().vm.$emit('url-params-changed', {});

      expect(urlUtils.updateHistory).not.toHaveBeenCalled();
    });
  });
});
