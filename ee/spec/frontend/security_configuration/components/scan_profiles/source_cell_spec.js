import { GlPopover } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SourceCell from 'ee/security_configuration/components/scan_profiles/source_cell.vue';
import { mockScanner, mockScanner2, mockProject, mockProjectAnalyzerStatus } from './mock_data';

describe('SourceCell', () => {
  let wrapper;

  const createWrapper = ({ item = mockProject, scannerKey = 'SECRET_DETECTION' } = {}) => {
    wrapper = shallowMountExtended(SourceCell, {
      propsData: { item, scannerKey },
    });
  };

  const findSourcesCount = () => wrapper.findByTestId('sources-count');
  const findAnalyzerSource = () => wrapper.findByTestId('analyzer-source');
  const findPopover = () => wrapper.findComponent(GlPopover);
  const rowText = () => wrapper.text();

  const projectWithProfileOnly = {
    ...mockProject,
    analyzerStatuses: [],
  };

  const projectWithSource = (source) => ({
    ...mockProject,
    securityScanProfiles: [],
    analyzerStatuses: [{ ...mockProjectAnalyzerStatus, source }],
  });

  const projectWithProfileAndSource = (source) => ({
    ...mockProject,
    analyzerStatuses: [{ ...mockProjectAnalyzerStatus, source }],
  });

  describe('when the project has no profile and no analyzer source', () => {
    beforeEach(() => {
      createWrapper({
        item: { ...mockProject, securityScanProfiles: [], analyzerStatuses: [] },
      });
    });

    it('shows "No profile applied"', () => {
      expect(rowText()).toContain('No profile applied');
    });

    it('does not render the sources popover', () => {
      expect(findPopover().exists()).toBe(false);
    });
  });

  describe('when the project has only a profile (single source)', () => {
    beforeEach(() => {
      createWrapper({ item: projectWithProfileOnly });
    });

    it('shows the profile name as the primary label', () => {
      expect(rowText()).toContain(mockScanner.name);
    });

    it('shows "Configuration profile" as the sub-label', () => {
      expect(findAnalyzerSource().text()).toBe('Configuration profile');
    });

    it('does not render the sources count or popover', () => {
      expect(findSourcesCount().exists()).toBe(false);
      expect(findPopover().exists()).toBe(false);
    });
  });

  describe('when the project has only an analyzer source (single source)', () => {
    it.each([
      ['YML', 'YAML configuration'],
      ['SCAN_EXECUTION_POLICY', 'Scan execution policy'],
      ['PIPELINE_EXECUTION_POLICY', 'Pipeline execution policy'],
      ['PIPELINE_EXECUTION_POLICY_SCHEDULE', 'Scheduled pipeline execution policy'],
      ['SECURITY_ORCHESTRATION_POLICY', 'Security orchestration policy'],
      ['ON_DEMAND_DAST_SCAN', 'On-demand DAST scan'],
      ['ON_DEMAND_DAST_VALIDATION', 'On-demand DAST validation'],
    ])('renders "%s" as the single-line label for %s', (source, expected) => {
      createWrapper({ item: projectWithSource(source) });

      expect(rowText()).toContain(expected);
      expect(findAnalyzerSource().exists()).toBe(false);
      expect(findSourcesCount().exists()).toBe(false);
      expect(findPopover().exists()).toBe(false);
    });

    it('shows "No profile applied" when the analyzer status has no source', () => {
      createWrapper({ item: projectWithSource(null) });

      expect(rowText()).toContain('No profile applied');
      expect(findPopover().exists()).toBe(false);
    });

    it('treats an analyzer source of SECURITY_SCAN_PROFILES as no source when no profile is attached', () => {
      createWrapper({ item: projectWithSource('SECURITY_SCAN_PROFILES') });

      expect(rowText()).toContain('No profile applied');
    });
  });

  describe('when the project has a profile and a non-profile analyzer source (multiple sources)', () => {
    it.each([
      ['YML', 'Profile, YAML'],
      ['SCAN_EXECUTION_POLICY', 'Profile, Policy'],
      ['PIPELINE_EXECUTION_POLICY', 'Profile, Policy'],
      ['PIPELINE_EXECUTION_POLICY_SCHEDULE', 'Profile, Policy'],
      ['SECURITY_ORCHESTRATION_POLICY', 'Profile, Policy'],
      ['ON_DEMAND_DAST_SCAN', 'Profile, On-demand'],
      ['ON_DEMAND_DAST_VALIDATION', 'Profile, On-demand'],
    ])('shows "2 sources" with joined category labels for a profile + %s', (source, categories) => {
      createWrapper({ item: projectWithProfileAndSource(source) });

      expect(findSourcesCount().text()).toBe('2 sources');
      expect(findAnalyzerSource().text()).toBe(categories);
    });

    describe('popover', () => {
      beforeEach(() => {
        createWrapper({ item: projectWithProfileAndSource('SCAN_EXECUTION_POLICY') });
      });

      it('renders a popover targeting the sources count element', () => {
        const popover = findPopover();
        expect(popover.exists()).toBe(true);
        expect(popover.attributes('target')).toBe(findSourcesCount().attributes('id'));
      });

      it('lists each source with its full label inside the popover', () => {
        const items = findPopover().findAll('li');
        expect(items).toHaveLength(2);
        expect(items.at(0).text()).toBe(`${mockScanner.name} configuration profile`);
        expect(items.at(1).text()).toBe('Scan execution policy');
      });
    });

    it('treats a matching-profile analyzer source as one source (not two)', () => {
      createWrapper({ item: projectWithProfileAndSource('SECURITY_SCAN_PROFILES') });

      expect(findSourcesCount().exists()).toBe(false);
      expect(rowText()).toContain(mockScanner.name);
      expect(findAnalyzerSource().text()).toBe('Configuration profile');
    });
  });

  describe('when a different scanner is looked up on the same item', () => {
    it('finds the profile matching the current scannerKey', () => {
      createWrapper({
        item: {
          ...mockProject,
          securityScanProfiles: [mockScanner, mockScanner2],
          analyzerStatuses: [],
        },
        scannerKey: 'SAST',
      });

      expect(rowText()).toContain(mockScanner2.name);
    });
  });
});
