import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlSkeletonLoader, GlTable, GlLink } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import { createAlert } from '~/alert';
import GroupScannersOverview from 'ee/security_configuration/components/scan_profiles/group_scanners_overview.vue';
import StatisticsCardRow from 'ee/security_configuration/components/scan_profiles/statistics_card_row.vue';
import ProjectsListModal from 'ee/security_configuration/components/scan_profiles/projects_list_modal.vue';
import SegmentedBar from 'ee/security_inventory/components/segmented_bar.vue';
import ScanTypeCell from '~/security_configuration/components/scan_profiles/scan_type_cell.vue';
import groupAvailableSecurityScanProfilesQuery from 'ee/security_configuration/graphql/scan_profiles/group_available_security_scan_profiles.query.graphql';
import groupAnalyzerStatusesQuery from 'ee/security_configuration/graphql/scan_profiles/group_analyzer_statuses.query.graphql';
import groupSecurityPostureCountersQuery from 'ee/security_configuration/graphql/scan_profiles/group_security_posture_counters.query.graphql';
import { ROUTE_ENABLE_SCANNERS } from 'ee/security_configuration/components/enable_scanners_wizard/constants';
import {
  mockScanner,
  mockScanner2,
  mockAnalyzerStatus,
  mockSecurityPostureCounters,
} from './mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');

const GROUP_FULL_PATH = 'my-group';
const SECURITY_INVENTORY_PATH = '/groups/my-group/-/security/inventory';

describe('GroupScannersOverview', () => {
  let wrapper;

  const createAvailableScannersResolver = (scanners = [mockScanner]) =>
    jest.fn().mockResolvedValue({
      data: {
        group: {
          id: 'gid://gitlab/Group/1',
          name: GROUP_FULL_PATH,
          availableSecurityScanProfiles: scanners,
          __typename: 'Group',
        },
      },
    });

  const createAnalyzerStatusesResolver = (statuses = [mockAnalyzerStatus]) =>
    jest.fn().mockResolvedValue({
      data: {
        group: {
          id: 'gid://gitlab/Group/1',
          analyzerStatuses: statuses,
          __typename: 'Group',
        },
      },
    });

  const createPostureCountersResolver = (counters = mockSecurityPostureCounters) =>
    jest.fn().mockResolvedValue({
      data: {
        group: {
          id: 'gid://gitlab/Group/1',
          securityPostureCounters: counters,
          __typename: 'Group',
        },
      },
    });

  const createComponent = ({
    availableScannersResolver = createAvailableScannersResolver(),
    analyzerStatusesResolver = createAnalyzerStatusesResolver(),
    postureCountersResolver = createPostureCountersResolver(),
    stubs = {},
  } = {}) => {
    wrapper = mountExtended(GroupScannersOverview, {
      apolloProvider: createMockApollo([
        [groupAvailableSecurityScanProfilesQuery, availableScannersResolver],
        [groupAnalyzerStatusesQuery, analyzerStatusesResolver],
        [groupSecurityPostureCountersQuery, postureCountersResolver],
      ]),
      provide: {
        groupFullPath: GROUP_FULL_PATH,
        groupId: '1',
        securityInventoryPath: SECURITY_INVENTORY_PATH,
      },
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      stubs: { ScanTypeCell: true, ...stubs },
    });
  };

  const findTable = () => wrapper.findComponent(GlTable);
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findSegmentedBars = () => wrapper.findAllComponents(SegmentedBar);
  const findScanTypeCells = () => wrapper.findAllComponents(ScanTypeCell);
  const findSecurityInventoryLink = () => wrapper.findComponent(GlLink);
  const findEnableScannersButton = () => wrapper.findComponentByTestId('enable-scanners-button');
  const findEnableScannersButtonWrapper = () =>
    wrapper.findByTestId('enable-scanners-button-wrapper');
  const findViewDetailsButton = () => wrapper.findComponentByTestId('view-details-button');
  const findStatisticsCardRow = () => wrapper.findComponent(StatisticsCardRow);
  const findProjectsModal = () => wrapper.findComponent(ProjectsListModal);
  const findCoverageHeaderInfoIcon = () =>
    wrapper.findComponentByTestId('coverage-header-info-icon');

  const openModalForCard = async (index) => {
    const card = findStatisticsCardRow().props('cards')[index];
    findStatisticsCardRow().vm.$emit('view-projects', card);
    await nextTick();
    return card;
  };

  describe('description', () => {
    beforeEach(async () => {
      createComponent();

      await waitForPromises();
    });

    it('renders a link to the Security Inventory', () => {
      expect(findSecurityInventoryLink().attributes('href')).toBe(SECURITY_INVENTORY_PATH);
    });

    it('renders an "Enable scanners" button that links to the enable scanners wizard route', () => {
      expect(findEnableScannersButton().props('to')).toStrictEqual({ name: ROUTE_ENABLE_SCANNERS });
    });
  });

  describe('enable scanners button', () => {
    describe('when at least one scanner has not-enabled projects', () => {
      beforeEach(async () => {
        createComponent();
        await waitForPromises();
      });

      it('renders an enabled button linking to the enable scanners wizard route', () => {
        expect(findEnableScannersButton().props('disabled')).toBe(false);
        expect(findEnableScannersButton().props('to')).toStrictEqual({
          name: ROUTE_ENABLE_SCANNERS,
        });
      });

      it('shows no tooltip', () => {
        expect(getBinding(findEnableScannersButtonWrapper().element, 'gl-tooltip').value).toBe('');
      });
    });

    describe('when no scanner has not-enabled projects', () => {
      beforeEach(async () => {
        createComponent({
          analyzerStatusesResolver: createAnalyzerStatusesResolver([
            { ...mockAnalyzerStatus, notConfigured: 0 },
          ]),
        });
        await waitForPromises();
      });

      it('renders the button in a disabled state with no route', () => {
        expect(findEnableScannersButton().props('disabled')).toBe(true);
        expect(findEnableScannersButton().props('to')).toBeNull();
      });

      it('shows a tooltip on the wrapper explaining why the button is disabled', () => {
        expect(getBinding(findEnableScannersButtonWrapper().element, 'gl-tooltip').value).toBe(
          'All scanners are already enabled on all projects.',
        );
      });
    });

    describe('when the available scanners query is still loading', () => {
      beforeEach(async () => {
        createComponent({
          availableScannersResolver: jest.fn().mockReturnValue(new Promise(() => {})),
          analyzerStatusesResolver: createAnalyzerStatusesResolver([
            { ...mockAnalyzerStatus, notConfigured: 0 },
          ]),
        });
        await waitForPromises();
      });

      it('renders the button in a disabled state with no route', () => {
        expect(findEnableScannersButton().props('disabled')).toBe(true);
        expect(findEnableScannersButton().props('to')).toBeNull();
      });

      it('shows no tooltip while loading', () => {
        expect(getBinding(findEnableScannersButtonWrapper().element, 'gl-tooltip').value).toBe('');
      });
    });
  });

  describe('scanner list', () => {
    it('sets the table to busy while the scanner list is loading', () => {
      createComponent({
        availableScannersResolver: jest.fn().mockReturnValue(new Promise(() => {})),
        stubs: { GlTable: stubComponent(GlTable, { props: ['busy'] }) },
      });

      expect(findTable().props('busy')).toBe(true);
    });

    it('renders a row for each available scanner', async () => {
      createComponent({
        availableScannersResolver: createAvailableScannersResolver([mockScanner, mockScanner2]),
      });

      await waitForPromises();

      expect(findScanTypeCells()).toHaveLength(2);
    });

    it('excludes scanners with an unsupported scan type', async () => {
      createComponent({
        availableScannersResolver: createAvailableScannersResolver([
          mockScanner,
          {
            ...mockScanner,
            id: 'gid://gitlab/Security::ScanProfile/2',
            scanType: 'UNSUPPORTED_SCAN_TYPE',
          },
        ]),
      });

      await waitForPromises();

      expect(findScanTypeCells()).toHaveLength(1);
    });

    it('renders one row per scan type when multiple profiles share a scan type', async () => {
      createComponent({
        availableScannersResolver: createAvailableScannersResolver([
          mockScanner,
          {
            ...mockScanner,
            id: 'gid://gitlab/Security::ScanProfile/3',
            name: 'Secret Detection Custom',
            gitlabRecommended: false,
          },
          mockScanner2,
        ]),
      });

      await waitForPromises();

      expect(findScanTypeCells()).toHaveLength(2);
    });

    it('keeps the recommended profile per scan type regardless of API response order', async () => {
      const recommended = { ...mockScanner, gitlabRecommended: true };
      const custom = {
        ...mockScanner,
        id: 'gid://gitlab/Security::ScanProfile/3',
        name: 'Secret Detection Custom',
        gitlabRecommended: false,
      };

      createComponent({
        availableScannersResolver: createAvailableScannersResolver([recommended, custom]),
      });
      await waitForPromises();

      expect(wrapper.vm.availableScanners).toEqual([recommended]);
    });
  });

  describe('coverage column', () => {
    describe('header info tooltip', () => {
      beforeEach(async () => {
        createComponent();
        await waitForPromises();
      });

      it('renders an information-o icon next to the column header', () => {
        expect(findCoverageHeaderInfoIcon().exists()).toBe(true);
        expect(findCoverageHeaderInfoIcon().props('name')).toBe('information-o');
      });

      it('binds the tooltip directive with the explanatory content as the title', () => {
        expect(getBinding(findCoverageHeaderInfoIcon().element, 'gl-tooltip')).toBeDefined();
        expect(findCoverageHeaderInfoIcon().attributes('title')).toBe(
          'Show scanner coverage across all configuration methods, including security policies, CI configuration, and configuration profiles.',
        );
      });
    });

    it('shows a skeleton loader while analyzer statuses are loading', async () => {
      createComponent({
        analyzerStatusesResolver: jest.fn().mockReturnValue(new Promise(() => {})),
      });

      await waitForPromises();

      expect(findSkeletonLoader().exists()).toBe(true);
    });

    describe('when statuses have loaded', () => {
      beforeEach(async () => {
        createComponent();

        await waitForPromises();
      });

      it('renders a segmented bar showing active, failed, stale, and not-configured counts', () => {
        expect(findSegmentedBars()).toHaveLength(1);
        expect(findSegmentedBars().at(0).props('segments')).toEqual([
          { class: 'gl-bg-green-500', count: 3, template: '%{count} active' },
          { class: 'gl-bg-red-500', count: 1, template: '%{count} failed' },
          { class: 'gl-bg-neutral-600', count: 2, template: '%{count} stale' },
          { class: 'gl-bg-status-neutral', count: 6 },
        ]);
      });

      it('renders the active project coverage percentage', () => {
        expect(wrapper.text()).toContain('25%');
      });

      it('renders the active, failed, and stale project counts as text', () => {
        expect(wrapper.text()).toContain('3 active, 1 failed, 2 stale');
      });
    });

    describe('when total project count is zero', () => {
      it('shows 0%', async () => {
        createComponent({
          analyzerStatusesResolver: createAnalyzerStatusesResolver([
            { ...mockAnalyzerStatus, success: 0, failure: 0, stale: 0, notConfigured: 0 },
          ]),
        });

        await waitForPromises();

        expect(wrapper.text()).toContain('0%');
      });
    });
  });

  describe('actions column', () => {
    it('renders a "View details" button that links to the scanner details route for the scan type', async () => {
      createComponent();

      await waitForPromises();

      expect(findViewDetailsButton().props('to')).toStrictEqual({
        name: 'scanner_details',
        params: { scanner_key: 'SECRET_DETECTION' },
      });
    });
  });

  describe('statistics cards', () => {
    describe('when loading', () => {
      it.each(['analyzerStatuses', 'postureCounters'])(
        'shows a loading state while the %s query is loading',
        async (query) => {
          createComponent({
            [`${query}Resolver`]: jest.fn().mockReturnValue(new Promise(() => {})),
          });

          await waitForPromises();

          expect(findStatisticsCardRow().props('loading')).toBe(true);
        },
      );
    });

    describe('with data', () => {
      beforeEach(async () => {
        createComponent();

        await waitForPromises();
      });

      it('passes the computed statistics to the cards', () => {
        expect(findStatisticsCardRow().props('cards')).toEqual([
          {
            title: 'Unprotected projects',
            value: 3,
            description: '7 of 10 projects have scanners enabled',
            filters: { hasScanners: false },
          },
          {
            title: 'Scanners enabled',
            value: '1 of 1',
            description: '0 scanners not enabled',
            linkText: 'Enable scanners',
            to: { name: ROUTE_ENABLE_SCANNERS },
          },
          {
            title: 'Needs attention',
            value: 2,
            description: 'Projects with scan failures',
            filters: { hasFailedOrWarning: true },
          },
          {
            title: 'Stale scans',
            value: 4,
            description: 'Projects not scanned in 90+ days',
            filters: { hasStale: true },
          },
        ]);
      });
    });

    describe('on error', () => {
      it.each(['analyzerStatuses', 'postureCounters'])(
        'shows the error state and creates an alert when the %s query fails',
        async (query) => {
          createComponent({ [`${query}Resolver`]: jest.fn().mockRejectedValue(new Error()) });

          await waitForPromises();

          expect(findStatisticsCardRow().props('error')).toBe(true);
          expect(createAlert).toHaveBeenCalledWith({
            message: 'Failed to load scanner statistics',
          });
        },
      );
    });
  });

  describe('projects modal', () => {
    const showProjectsModal = jest.fn();

    beforeEach(async () => {
      createComponent({
        stubs: {
          ProjectsListModal: stubComponent(ProjectsListModal, {
            methods: { show: showProjectsModal },
          }),
        },
      });
      await waitForPromises();
      await openModalForCard(2);
    });

    it('opens the projects modal with the card filters and title when a card emits view-projects', () => {
      expect(showProjectsModal).toHaveBeenCalled();
      expect(findProjectsModal().props('title')).toBe('Needs attention');
      expect(findProjectsModal().props('filters')).toEqual({ hasFailedOrWarning: true });
    });

    it('clears the selected filters and title when the modal is hidden', async () => {
      findProjectsModal().vm.$emit('hidden');
      await nextTick();

      expect(findProjectsModal().props('title')).toBe('');
      expect(findProjectsModal().props('filters')).toEqual({});
    });
  });

  describe('empty state', () => {
    it('renders empty state text when there are no scanners', async () => {
      createComponent({ availableScannersResolver: createAvailableScannersResolver([]) });

      await waitForPromises();

      expect(wrapper.text()).toContain('No scanners enabled yet');
      expect(wrapper.text()).toContain(
        'Enable security scanning to automatically detect vulnerabilities in your projects.',
      );
    });
  });
});
