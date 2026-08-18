import { nextTick, markRaw } from 'vue';
import { GlDashboardLayout } from '@gitlab/ui';
import * as urlUtils from '~/lib/utils/url_utility';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import setWindowLocation from 'helpers/set_window_location_helper';
import { OPERATORS_IS, OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import {
  SEVERITY_LEVELS_KEYS,
  REPORT_TYPES_WITH_MANUALLY_ADDED,
  REPORT_TYPES_CONTAINER_SCANNING_FOR_REGISTRY,
  REPORT_TYPES_WITH_CLUSTER_IMAGE,
} from 'ee/security_dashboard/constants';
import FilteredSearch from 'ee/security_dashboard/components/shared/filtered_search/filtered_search.vue';
import ProjectSecurityDashboardNew from 'ee/security_dashboard/components/shared/project_security_dashboard_new.vue';
import ReportTypeToken from 'ee/security_dashboard/components/shared/filtered_search/tokens/report_type_token.vue';
import TrackedRefToken from 'ee/security_dashboard/components/shared/filtered_search/tokens/tracked_ref_token.vue';
import VulnerabilitiesOverTimePanel from 'ee/security_dashboard/components/shared/vulnerabilities_over_time_panel.vue';
import ProjectRiskScorePanel from 'ee/security_dashboard/components/shared/project_risk_score_panel.vue';
import VulnerabilitiesByAgePanel from 'ee/security_dashboard/components/shared/vulnerabilities_by_age_panel.vue';
import VulnerabilitiesByIdentifierPanel from 'ee/security_dashboard/components/shared/vulnerabilities_by_identifier_panel.vue';
import AgenticAdoptionFunnelPanel from 'ee/security_dashboard/components/shared/agentic_adoption_funnel_panel.vue';
import SecurityDashboardDescription from 'ee/security_dashboard/components/shared/security_dashboard_description.vue';
import PdfExportButton from 'ee/security_dashboard/components/shared/pdf_export_button_new.vue';

jest.mock('~/alert');

describe('Project Security Dashboard (new version) - Component', () => {
  let wrapper;

  const mockProjectFullPath = 'project-1';
  const mockDefaultBranchContext = {
    id: 'gid://gitlab/Security::ProjectTrackedContext/1',
    name: 'main',
    refType: 'branch',
  };

  const createComponent = ({ provide = {} } = {}) => {
    wrapper = shallowMountExtended(ProjectSecurityDashboardNew, {
      provide: {
        projectFullPath: mockProjectFullPath,
        defaultBranchContext: mockDefaultBranchContext,
        glFeatures: {
          vulnerabilitiesAcrossContexts: true,
          securityDashboardAgenticAdoption: true,
        },
        ...provide,
      },
    });
  };

  const findDashboardLayout = () => wrapper.findComponent(GlDashboardLayout);
  const findDashboardDescription = () => wrapper.findComponent(SecurityDashboardDescription);
  const findFilteredSearch = () => wrapper.findComponent(FilteredSearch);
  const findDashboardConfig = () => findDashboardLayout().props('config');
  const findPanelWithId = (panelId) =>
    findDashboardConfig().panels.find(({ id }) => id === panelId);
  const findVulnerabilitiesOverTimePanel = () => findPanelWithId('vulnerabilities-over-time');
  const findRiskScorePanel = () => findPanelWithId('total-risk-score');
  const findVulnerabilitiesByAgePanel = () => findPanelWithId('vulnerabilities-by-age');
  const findVulnerabilitiesByIdentifierPanel = () =>
    findPanelWithId('vulnerabilities-by-identifier');
  const findAgenticAdoptionFunnelPanel = () => findPanelWithId('agentic-adoption-funnel');
  const findTitle = () => wrapper.find('h1');
  const findPdfExportButton = () => wrapper.findComponent(PdfExportButton);

  beforeEach(() => {
    createComponent();
  });

  describe('component rendering', () => {
    it('renders the dashboard layout component', () => {
      expect(findDashboardLayout().exists()).toBe(true);
    });

    it('renders the correct title', () => {
      expect(findTitle().text()).toBe('Security dashboard');
    });

    it('renders the description', () => {
      expect(findDashboardDescription().exists()).toBe(true);
    });

    it('renders the vulnerabilities over time panel with the correct configuration', () => {
      const vulnerabilitiesOverTimePanel = findVulnerabilitiesOverTimePanel();

      expect(vulnerabilitiesOverTimePanel.component).toBe(VulnerabilitiesOverTimePanel);
      expect(vulnerabilitiesOverTimePanel.componentProps.namespace).toBe('project');
      expect(vulnerabilitiesOverTimePanel.componentProps.filters).toEqual({});
      expect(vulnerabilitiesOverTimePanel.gridAttributes).toEqual({
        width: 7,
        height: 4,
        yPos: 3,
        xPos: 5,
      });
    });

    it('renders the severity panels with the correct configuration', () => {
      SEVERITY_LEVELS_KEYS.forEach((severity, index) => {
        const severityPanel = findPanelWithId(severity);

        expect(severityPanel.componentProps).toMatchObject({
          namespace: 'project',
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

    it('includes the risk score panel', () => {
      expect(findRiskScorePanel()).not.toBeUndefined();
    });

    it('renders the risk score panel with the correct configuration', () => {
      const riskScorePanel = findRiskScorePanel();

      expect(riskScorePanel.component).toBe(ProjectRiskScorePanel);
      expect(riskScorePanel.componentProps.filters).toEqual({});
      expect(riskScorePanel.gridAttributes).toEqual({
        width: 5,
        height: 4,
        yPos: 3,
        xPos: 0,
      });
    });

    it('renders the vulnerabilities by age panel with the correct configuration', () => {
      const panel = findVulnerabilitiesByAgePanel();

      expect(panel.component).toBe(VulnerabilitiesByAgePanel);
      expect(panel.componentProps.namespace).toBe('project');
      expect(panel.componentProps.filters).toEqual({});
      expect(panel.gridAttributes).toEqual({
        width: 6,
        height: 4,
        yPos: 7,
        xPos: 0,
      });
    });

    it('includes the vulnerabilities by identifier panel with the correct configuration', () => {
      const panel = findVulnerabilitiesByIdentifierPanel();

      expect(panel.component).toBe(VulnerabilitiesByIdentifierPanel);
      expect(panel.componentProps.namespace).toBe('project');
      expect(panel.componentProps.filters).toEqual({});
      expect(panel.gridAttributes).toEqual({
        width: 6,
        height: 4,
        yPos: 7,
        xPos: 6,
      });
    });

    it('renders the panel with the correct configuration', () => {
      const panel = findAgenticAdoptionFunnelPanel();

      expect(panel.component).toBe(AgenticAdoptionFunnelPanel);
      expect(panel.componentProps.namespace).toBe('project');
      expect(panel.componentProps.filters).toEqual({});
      expect(panel.gridAttributes).toEqual({
        width: 12,
        height: 2,
        yPos: 1,
        xPos: 0,
      });
    });

    it('renders the PDF export button', () => {
      createComponent();
      expect(findPdfExportButton().exists()).toBe(true);
    });
  });

  describe('when the `securityDashboardAgenticAdoption` feature flag is disabled', () => {
    beforeEach(() => {
      createComponent({ provide: { glFeatures: { securityDashboardAgenticAdoption: false } } });
    });

    it('does not render the panel', () => {
      expect(findAgenticAdoptionFunnelPanel()).toBeUndefined();
    });

    it('shifts the panels below up to close the gap left by the hidden funnel', () => {
      expect(findRiskScorePanel().gridAttributes.yPos).toBe(1);
      expect(findVulnerabilitiesOverTimePanel().gridAttributes.yPos).toBe(1);
      expect(findVulnerabilitiesByAgePanel().gridAttributes.yPos).toBe(5);
      expect(findVulnerabilitiesByIdentifierPanel().gridAttributes.yPos).toBe(5);
    });
  });

  describe('filtered search', () => {
    it('gets passed the correct tokens including tracked ref token', () => {
      expect(findFilteredSearch().props('tokens')).toMatchObject([
        {
          type: 'reportType',
          title: 'Report type',
          multiSelect: true,
          unique: true,
          token: markRaw(ReportTypeToken),
          operators: OPERATORS_OR,
        },
        {
          type: 'trackedRefIds',
          title: 'Tracked ref',
          multiSelect: false,
          unique: true,
          token: markRaw(TrackedRefToken),
          operators: OPERATORS_IS,
        },
      ]);
    });

    it('passes the correct reportTypes configuration to the ReportTypeToken', () => {
      const reportTypeToken = findFilteredSearch()
        .props('tokens')
        .find((token) => token.type === 'reportType');

      const expectedReportTypes = {
        ...REPORT_TYPES_WITH_MANUALLY_ADDED,
        ...REPORT_TYPES_WITH_CLUSTER_IMAGE,
        ...REPORT_TYPES_CONTAINER_SCANNING_FOR_REGISTRY,
      };

      expect(reportTypeToken.reportTypes).toEqual(expectedReportTypes);
    });

    describe('when `defaultBranchContext` is null', () => {
      beforeEach(() => {
        createComponent({ provide: { defaultBranchContext: null } });
      });

      it('does not include tracked ref token', () => {
        const tokens = findFilteredSearch().props('tokens');

        expect(tokens).toHaveLength(1);
        expect(tokens[0].type).toBe('reportType');
      });
    });

    describe('when the `vulnerabilitiesAcrossContexts` feature flag is disabled', () => {
      beforeEach(() => {
        createComponent({ provide: { glFeatures: { vulnerabilitiesAcrossContexts: false } } });
      });

      it('does not include tracked ref token', () => {
        const tokens = findFilteredSearch().props('tokens');

        expect(tokens).toHaveLength(1);
        expect(tokens[0].type).toBe('reportType');
      });
    });

    it('updates filters when filters-changed event is emitted', async () => {
      const newFilters = { reportType: 'API_FUZZING' };
      findFilteredSearch().vm.$emit('filters-changed', newFilters);
      await nextTick();

      expect(findVulnerabilitiesOverTimePanel().componentProps.filters).toEqual(newFilters);

      SEVERITY_LEVELS_KEYS.forEach((severity) => {
        expect(findPanelWithId(severity).componentProps.filters).toEqual(newFilters);
      });
      expect(findRiskScorePanel().componentProps.filters).toEqual(newFilters);
    });

    it('clears filters when empty filters object is emitted', async () => {
      const initialFilters = { reportType: 'API_FUZZING' };
      findFilteredSearch().vm.$emit('filters-changed', initialFilters);
      await nextTick();

      expect(findVulnerabilitiesOverTimePanel().componentProps.filters).toEqual(initialFilters);

      SEVERITY_LEVELS_KEYS.forEach((severity) => {
        expect(findPanelWithId(severity).componentProps.filters).toEqual(initialFilters);
      });
      expect(findRiskScorePanel().componentProps.filters).toEqual(initialFilters);

      // Clear filters
      findFilteredSearch().vm.$emit('filters-changed', {});
      await nextTick();

      expect(findVulnerabilitiesOverTimePanel().componentProps.filters).toEqual({});

      SEVERITY_LEVELS_KEYS.forEach((severity) => {
        expect(findPanelWithId(severity).componentProps.filters).toEqual({});
      });
      expect(findRiskScorePanel().componentProps.filters).toEqual({});
    });

    it('passes filters to the vulnerabilities over time panel', async () => {
      const reportType = 'API_FUZZING';
      findFilteredSearch().vm.$emit('filters-changed', { reportType });
      await nextTick();

      expect(findVulnerabilitiesOverTimePanel().componentProps.filters).toEqual({ reportType });
    });

    it('passes filters to all severity panels', async () => {
      const reportType = 'API_FUZZING';
      findFilteredSearch().vm.$emit('filters-changed', { reportType });
      await nextTick();

      SEVERITY_LEVELS_KEYS.forEach((severity) => {
        expect(findPanelWithId(severity).componentProps.filters).toEqual({ reportType });
      });
    });

    it('passes filters to the risk score panel', async () => {
      const reportType = 'API_FUZZING';
      findFilteredSearch().vm.$emit('filters-changed', { reportType });
      await nextTick();

      expect(findRiskScorePanel().componentProps.filters).toEqual({ reportType });
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
});
