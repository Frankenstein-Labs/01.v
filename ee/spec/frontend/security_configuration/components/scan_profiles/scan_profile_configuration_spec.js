import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import {
  GlCollapsibleListbox,
  GlTable,
  GlAlert,
  GlLink,
  GlDisclosureDropdownItem,
  GlLoadingIcon,
} from '@gitlab/ui';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { stubComponent } from 'helpers/stub_component';
import ScanProfileConfiguration from 'ee/security_configuration/components/scan_profiles/scan_profile_configuration.vue';
import ScanProfileTable from '~/security_configuration/components/scan_profiles/scan_profile_table.vue';
import DisableScanProfileConfirmationModal from 'ee/security_configuration/components/scan_profiles/disable_scan_profile_confirmation_modal.vue';
import ScanProfileDetailsModal from 'ee/security_configuration/components/scan_profiles/scan_profile_details_modal.vue';
import InsufficientPermissionsPopover from 'ee/security_configuration/components/scan_profiles/insufficient_permissions_popover.vue';
import ScanProfileLaunchModal from 'ee/security_configuration/components/scan_profiles/scan_profile_launch_modal.vue';
import JobDetailsPopover from 'ee/security_configuration/components/scan_profiles/job_details_popover.vue';
import LastScanCell from 'ee/security_configuration/components/scan_profiles/last_scan_cell.vue';
import TroubleshootJobDrawer from 'ee/security_configuration/components/scan_profiles/troubleshoot_job_drawer.vue';
import ScannerStatusIcon from 'ee/security_configuration/components/scan_profiles/scanner_status_icon.vue';
import availableProfilesQuery from 'ee/security_configuration/graphql/scan_profiles/group_available_security_scan_profiles.query.graphql';
import projectProfilesQuery from 'ee/security_configuration/graphql/scan_profiles/project_security_scan_profiles.query.graphql';
import attachMutation from 'ee/security_configuration/graphql/scan_profiles/security_scan_profile_attach.mutation.graphql';
import detachMutation from 'ee/security_configuration/graphql/scan_profiles/security_scan_profile_detach.mutation.graphql';
import profileDetailsQuery from 'ee/security_configuration/graphql/scan_profiles/security_scan_profile.query.graphql';
import scanProfileStatusesQuery from 'ee/security_configuration/graphql/scan_profiles/scan_profile_statuses.query.graphql';
import { SCAN_PROFILE_I18N } from '~/security_configuration/constants';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { mockScanner, mockStatus } from './mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('ScanProfileConfiguration', () => {
  let wrapper;
  let mockToastShow;

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const mockStatusWithStatus = (status) => ({ ...mockStatus, status });

  const mockDsProfile = {
    id: 'gid://gitlab/Security::ScanProfile/dependency_scanning',
    name: 'Dependency Scanning - Standard',
    description:
      "Identify known vulnerabilities in your project's open source dependencies before they reach production.",
    gitlabRecommended: true,
    scanType: 'DEPENDENCY_SCANNING',
    triggers: ['MERGE_REQUEST_PIPELINE', 'DEFAULT_BRANCH_PIPELINE'],
    __typename: 'ScanProfileType',
  };

  const mockProjectId = 'gid://gitlab/Project/1';

  const createAvailableProfilesResolver = (profiles = [mockScanner]) =>
    jest.fn().mockResolvedValue({
      data: {
        group: {
          id: 'gid://gitlab/Group/1',
          name: 'group',
          availableSecurityScanProfiles: profiles,
          __typename: 'Group',
        },
      },
    });

  const createProjectProfilesResolver = (profiles = []) =>
    jest.fn().mockResolvedValue({
      data: {
        project: {
          id: mockProjectId,
          name: 'project',
          securityScanProfiles: profiles,
          __typename: 'Project',
        },
      },
    });

  const createAttachMutationResolver = (errors = []) =>
    jest.fn().mockResolvedValue({
      data: { securityScanProfileAttach: { clientMutationId: null, errors } },
    });

  const createDetachMutationResolver = (errors = []) =>
    jest.fn().mockResolvedValue({
      data: { securityScanProfileDetach: { clientMutationId: null, errors } },
    });

  const createProfileDetailsResolver = (profile = mockScanner) =>
    jest.fn().mockResolvedValue({ data: { securityScanProfile: profile } });

  const createScanProfileStatusesResolver = (statuses = []) =>
    jest.fn().mockResolvedValue({
      data: {
        project: {
          scanProfileStatuses: statuses,
        },
      },
    });

  const createComponent = ({
    availableProfilesResolver = createAvailableProfilesResolver(),
    projectProfilesResolver = createProjectProfilesResolver(),
    attachResolver = createAttachMutationResolver(),
    detachResolver = createDetachMutationResolver(),
    profileDetailsResolver = createProfileDetailsResolver(),
    scanProfileStatusesResolver = null,
    canApplyProfiles = true,
    securityScanProfilesLicensed = true,
    glFeatures = {},
    statuses = [],
  } = {}) => {
    mockToastShow = jest.fn();

    const apolloProvider = createMockApollo([
      [availableProfilesQuery, availableProfilesResolver],
      [projectProfilesQuery, projectProfilesResolver],
      [attachMutation, attachResolver],
      [detachMutation, detachResolver],
      [profileDetailsQuery, profileDetailsResolver],
      [
        scanProfileStatusesQuery,
        scanProfileStatusesResolver || createScanProfileStatusesResolver(statuses),
      ],
    ]);

    wrapper = mountExtended(ScanProfileConfiguration, {
      apolloProvider,
      provide: {
        projectFullPath: 'group/project',
        groupFullPath: 'group',
        canApplyProfiles,
        securityScanProfilesLicensed,
        glFeatures,
      },
      mocks: {
        $toast: { show: mockToastShow },
      },
      stubs: {
        ScanProfileLaunchModal: stubComponent(ScanProfileLaunchModal),
        JobDetailsPopover: stubComponent(JobDetailsPopover),
        TroubleshootJobDrawer: stubComponent(TroubleshootJobDrawer),
      },
      data() {
        return { statuses };
      },
    });

    return wrapper;
  };

  const findTable = () => wrapper.findComponent(ScanProfileTable);
  const findGlTable = () => wrapper.findComponent(GlTable);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findDisableModal = () => wrapper.findComponent(DisableScanProfileConfirmationModal);
  const findDetailsModal = () => wrapper.findComponent(ScanProfileDetailsModal);
  const findPopover = () => wrapper.findComponent(InsufficientPermissionsPopover);
  const findDropdownItems = () => wrapper.findAllComponents(GlDisclosureDropdownItem);
  const findLastScanCell = () => wrapper.findComponent(LastScanCell);
  const findJobDetailsPopover = () => findLastScanCell().findComponent(JobDetailsPopover);
  const findTroubleshootDrawer = () => wrapper.findComponent(TroubleshootJobDrawer);
  const findStatusIcon = () => wrapper.findComponent(ScannerStatusIcon);
  const findLastScanLink = () => wrapper.findByTestId(`scanner-details-${mockStatus.id}`);
  const findLastScan = () => wrapper.findByTestId('last-scan');
  const findApplyProfileBtn = () => wrapper.findComponentByTestId('apply-profile-button');
  const findDisableBtn = () => wrapper.findByTestId('disable-button');
  const findPreviewBtn = () => wrapper.findComponentByTestId('preview-button');
  const findAllLinks = () => wrapper.findAllComponents(GlLink);
  const findDisableDropdownItem = () =>
    findDropdownItems().wrappers.find((item) => item.text().includes('Disable'));

  describe('loading state', () => {
    it('shows table in busy state while queries are loading', () => {
      const loadingResolver = jest.fn(() => new Promise(() => {}));
      createComponent({
        availableProfilesResolver: loadingResolver,
        projectProfilesResolver: loadingResolver,
      });

      expect(findTable().attributes('aria-busy')).toBe('true');
    });
  });

  describe('error handling', () => {
    it('displays error message when available profiles query fails', async () => {
      const errorResolver = jest.fn().mockRejectedValue(new Error('Query failed'));
      createComponent({ availableProfilesResolver: errorResolver });
      await waitForPromises();

      expect(findAlert().exists()).toBe(true);
      expect(findAlert().text()).toContain('Error loading profiles');
    });

    it('displays error message when project profiles query fails', async () => {
      const errorResolver = jest.fn().mockRejectedValue(new Error('Query failed'));
      createComponent({ projectProfilesResolver: errorResolver });
      await waitForPromises();

      expect(findAlert().exists()).toBe(true);
      expect(findAlert().text()).toContain('Error loading profiles');
    });

    it('captures exception in Sentry when available profiles query fails', async () => {
      const errorResolver = jest.fn().mockRejectedValue(new Error('Query failed'));
      createComponent({ availableProfilesResolver: errorResolver });
      await waitForPromises();

      expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
    });

    it('captures exception in Sentry when project profiles query fails', async () => {
      const errorResolver = jest.fn().mockRejectedValue(new Error('Query failed'));
      createComponent({ projectProfilesResolver: errorResolver });
      await waitForPromises();

      expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
    });

    it('captures exception in Sentry when statuses query fails', async () => {
      const errorResolver = jest.fn().mockRejectedValue(new Error('Query failed'));
      createComponent({
        scanProfileStatusesResolver: errorResolver,
        glFeatures: { securityScanProfilesStatusIndicators: true },
      });
      await waitForPromises();

      expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
    });

    it('clears error alert when dismissed', async () => {
      const errorResolver = jest.fn().mockRejectedValue(new Error('Query failed'));
      createComponent({ availableProfilesResolver: errorResolver });
      await waitForPromises();

      expect(findAlert().exists()).toBe(true);
      await findAlert().vm.$emit('dismiss');
      await nextTick();

      expect(findAlert().exists()).toBe(false);
    });
  });

  describe('table rendering', () => {
    it('renders table with correct fields', async () => {
      createComponent();
      await waitForPromises();

      const table = findGlTable();
      expect(table.exists()).toBe(true);
      expect(table.props('fields')).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ key: 'scanType', label: 'Scanner' }),
          expect.objectContaining({ key: 'name', label: 'Profile' }),
          expect.objectContaining({ key: 'status', label: 'Scanner health' }),
          expect.objectContaining({ key: 'actions', label: '' }),
        ]),
      );
    });

    it('renders "No profile applied" when profile is not configured', async () => {
      createComponent();
      await waitForPromises();

      expect(findAlert().exists()).toBe(false);
      expect(findTable().exists()).toBe(true);
      expect(wrapper.text()).toContain('No profile applied');
    });

    it('renders profile name as link when profile is configured', async () => {
      createComponent({
        projectProfilesResolver: createProjectProfilesResolver([mockScanner]),
      });
      await waitForPromises();
      const profileLinks = findAllLinks().filter((link) => link.text() === mockScanner.name);
      expect(profileLinks.length).toBeGreaterThan(0);
    });

    it('shows not configured status when profile is not attached', async () => {
      createComponent();
      await waitForPromises();

      expect(wrapper.text()).toContain('Unconfigured');
      expect(wrapper.text()).toContain('Apply profile to enable');
    });

    it('shows active status when profile is attached', async () => {
      createComponent({
        projectProfilesResolver: createProjectProfilesResolver([mockScanner]),
      });
      await waitForPromises();

      expect(wrapper.text()).toContain('Active');
    });

    it('renders Dependency Scanning profile when returned from API', async () => {
      createComponent({
        availableProfilesResolver: createAvailableProfilesResolver([mockDsProfile]),
      });
      await waitForPromises();

      expect(wrapper.text()).toContain('DS');
      expect(wrapper.text()).toContain('Dependency scanning');
    });

    it('filters out profiles with unknown scan types', async () => {
      const unknownProfile = {
        ...mockScanner,
        id: 'gid://gitlab/Security::ScanProfile/99',
        name: 'Unknown Scanner Profile',
        scanType: 'UNKNOWN_SCANNER_TYPE',
      };
      createComponent({
        availableProfilesResolver: createAvailableProfilesResolver([unknownProfile]),
      });
      await waitForPromises();

      expect(wrapper.text()).not.toContain('Unknown Scanner Profile');
    });
  });

  describe('when unlicensed', () => {
    beforeEach(() => {
      createComponent({ securityScanProfilesLicensed: false });
    });

    it('renders table with correct fields', () => {
      const table = findGlTable();
      expect(table.exists()).toBe(true);
      expect(table.props('fields')).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ key: 'scanType', label: 'Scanner' }),
          expect.objectContaining({ key: 'name', label: 'Profile' }),
          expect.objectContaining({ key: 'status', label: 'Scanner health' }),
          expect.objectContaining({ key: 'actions', label: '' }),
        ]),
      );
    });

    it('renders "No profile applied"', () => {
      expect(findAlert().exists()).toBe(false);
      expect(findTable().exists()).toBe(true);
      expect(wrapper.text()).toContain('No profile applied');
    });

    it('renders disabled apply and preview buttons', () => {
      expect(findApplyProfileBtn().props('disabled')).toBe(true);
      expect(findPreviewBtn().props('disabled')).toBe(true);
    });
  });

  describe('with securityScanProfilesStatusIndicators feature flag', () => {
    const createComponentWithFlag = (overrides = {}) =>
      createComponent({
        glFeatures: { securityScanProfilesStatusIndicators: true },
        projectProfilesResolver: createProjectProfilesResolver([mockScanner]),
        ...overrides,
      });

    describe('status cell (scanner health)', () => {
      it('shows humanized status text', async () => {
        createComponentWithFlag({
          statuses: [mockStatusWithStatus('ACTIVE')],
        });
        await waitForPromises();
        expect(wrapper.text()).toContain('Active');
      });

      it('shows consecutive success count detail for active status', async () => {
        createComponentWithFlag({
          statuses: [mockStatusWithStatus('ACTIVE')],
        });
        await waitForPromises();
        expect(wrapper.text()).toContain(
          `Last ${mockStatusWithStatus('ACTIVE').consecutiveSuccessCount} scans successful`,
        );
      });

      it('shows correct status icon and class for active status', async () => {
        createComponentWithFlag({
          statuses: [mockStatusWithStatus('ACTIVE')],
        });
        await waitForPromises();
        expect(findStatusIcon().props('status')).toBe('active');
      });

      it('shows consecutive failure count detail for failed status', async () => {
        createComponentWithFlag({ statuses: [mockStatusWithStatus('FAILED')] });
        await waitForPromises();
        expect(wrapper.text()).toContain('scans failed');
      });

      it('shows "Awaiting first pipeline" when returning a pending status', async () => {
        createComponentWithFlag({ statuses: [mockStatusWithStatus('PENDING')] });
        await waitForPromises();
        expect(wrapper.text()).toContain('Awaiting first pipeline');
      });

      it('shows correct status icon when returning a pending status', async () => {
        createComponentWithFlag({ statuses: [mockStatusWithStatus('PENDING')] });
        await waitForPromises();
        expect(findStatusIcon().props('status')).toBe('pending');
      });

      it('shows "Unconfigured" when profile is not attached', async () => {
        createComponentWithFlag({
          statuses: [],
          projectProfilesResolver: createProjectProfilesResolver([]),
        });
        await waitForPromises();
        expect(wrapper.text()).toContain('Unconfigured');
      });

      it('maps "not_configured" backend status to "unconfigured" in the UI', async () => {
        createComponentWithFlag({ statuses: [mockStatusWithStatus('NOT_CONFIGURED')] });
        await waitForPromises();
        expect(findStatusIcon().props('status')).toBe('unconfigured');
        expect(wrapper.text()).toContain('Unconfigured');
      });

      it('shows "Coverage may be outdated" for stale status', async () => {
        createComponentWithFlag({ statuses: [mockStatusWithStatus('STALE')] });
        await waitForPromises();
        expect(wrapper.text()).toContain('Coverage may be outdated');
      });
    });

    describe('popover title', () => {
      it.each([
        ['active', 'Scan successful'],
        ['warning', 'Scan warning'],
        ['failed', 'Scan failed'],
        ['stale', 'Scan outdated'],
      ])('renders popover with "%s" title for %s status', async (status, expectedTitle) => {
        createComponentWithFlag({ statuses: [mockStatusWithStatus(status)] });
        await waitForPromises();
        expect(findJobDetailsPopover().props('title')).toBe(expectedTitle);
      });

      it('returns empty string for unknown status', async () => {
        createComponentWithFlag({ statuses: [mockStatusWithStatus('pending')] });
        await waitForPromises();
        expect(findJobDetailsPopover().props('title')).toBe('');
      });
    });

    describe('lastScan cell', () => {
      it('renders formatted last scan time when lastScanAt is present', async () => {
        createComponentWithFlag({ statuses: [mockStatusWithStatus('ACTIVE')] });
        await waitForPromises();
        expect(findLastScan().text()).not.toBe('-');
      });

      it('renders "—" when lastScanAt is null', async () => {
        createComponentWithFlag({
          statuses: [{ ...mockStatusWithStatus('UNCONFIGURED'), lastScanAt: null }],
        });
        await waitForPromises();
        expect(wrapper.text()).toContain('—');
      });

      it('shows "View failed job #" link text for failed status', async () => {
        createComponentWithFlag({ statuses: [mockStatusWithStatus('FAILED')] });
        await waitForPromises();
        expect(wrapper.text()).toContain('View failed job #');
      });

      it('shows "View job #" link text for non-failed status', async () => {
        createComponentWithFlag({ statuses: [mockStatusWithStatus('ACTIVE')] });
        await waitForPromises();
        expect(wrapper.text()).toContain('View job #');
      });

      it('renders job details popover when lastScanAt is present', async () => {
        createComponentWithFlag({ statuses: [mockStatusWithStatus('ACTIVE')] });
        await waitForPromises();
        expect(findJobDetailsPopover().exists()).toBe(true);
      });

      it('shows popover when hovering the last scan link', async () => {
        createComponentWithFlag({ statuses: [mockStatusWithStatus('ACTIVE')] });
        await waitForPromises();

        await findLastScanLink().trigger('mouseenter');
        expect(findJobDetailsPopover().props('show')).toBe(true);
      });

      it('hides popover when mouse leaves the last scan link', async () => {
        createComponentWithFlag({ statuses: [mockStatusWithStatus('ACTIVE')] });
        await waitForPromises();

        await findLastScanLink().trigger('mouseenter');
        expect(findJobDetailsPopover().props('show')).toBe(true);

        let timeoutCallback;
        jest.spyOn(global, 'setTimeout').mockImplementation((cb) => {
          timeoutCallback = cb;
        });

        await findLastScanLink().trigger('mouseleave');
        timeoutCallback();
        await nextTick();

        expect(findJobDetailsPopover().props('show')).toBe(false);
        jest.restoreAllMocks();
      });
    });

    describe('drawer', () => {
      it('does not render drawer initially', async () => {
        createComponentWithFlag({ statuses: [mockStatusWithStatus('FAILED')] });
        await waitForPromises();

        expect(findTroubleshootDrawer().exists()).toBe(false);
      });

      it('opens drawer when open-drawer event is emitted from job details popover', async () => {
        createComponentWithFlag({ statuses: [mockStatusWithStatus('FAILED')] });
        await waitForPromises();
        await findLastScanLink().trigger('mouseenter');

        const jobPopover = findJobDetailsPopover();
        const mockJobData = { name: 'test-job', status: 'failed' };
        jobPopover.vm.$emit('open-drawer', mockJobData);
        await nextTick();

        expect(findTroubleshootDrawer().exists()).toBe(true);
        expect(findJobDetailsPopover().props('show')).toBe(false);
      });

      it('closes drawer when close-drawer event is emitted', async () => {
        createComponentWithFlag({ statuses: [mockStatusWithStatus('FAILED')] });
        await waitForPromises();

        await findLastScanLink().trigger('mouseenter');
        findJobDetailsPopover().vm.$emit('open-drawer', { name: 'test-job', status: 'failed' });
        await nextTick();

        findTroubleshootDrawer().vm.$emit('close-drawer');
        await nextTick();

        expect(findTroubleshootDrawer().exists()).toBe(false);
      });

      it('passes correct props to TroubleshootJobDrawer', async () => {
        createComponentWithFlag({ statuses: [mockStatusWithStatus('FAILED')] });
        await waitForPromises();

        const jobPopover = findJobDetailsPopover();
        const mockJobData = { name: 'test-job', status: 'failed' };
        jobPopover.vm.$emit('open-drawer', mockJobData);
        await nextTick();

        const drawer = findTroubleshootDrawer();
        expect(drawer.props('openDrawer')).toBe(true);
        expect(drawer.props('jobData')).toMatchObject(mockJobData);
        expect(drawer.props('buildId')).toBe('gid://gitlab/CommitStatus/123');
        expect(drawer.props('scanType')).toBe('SECRET_DETECTION');
        expect(drawer.props('fullPath')).toBe('group/project');
      });
    });
  });

  describe('apply profile', () => {
    it('calls attach mutation when apply button is clicked', async () => {
      const attachResolver = createAttachMutationResolver();
      createComponent({ attachResolver });
      await waitForPromises();

      expect(findApplyProfileBtn().exists()).toBe(true);
      await findApplyProfileBtn().trigger('click');
      await waitForPromises();

      expect(attachResolver).toHaveBeenCalledWith({
        input: {
          securityScanProfileId: mockScanner.id,
          projectIds: [mockProjectId],
        },
      });
    });

    it('applies profile by calling the mutation', async () => {
      const attachResolver = createAttachMutationResolver();
      createComponent({ attachResolver });
      await waitForPromises();

      expect(findApplyProfileBtn().exists()).toBe(true);
      expect(findApplyProfileBtn().props('loading')).toBe(false);
      await findApplyProfileBtn().trigger('click');
      await waitForPromises();

      expect(attachResolver).toHaveBeenCalled();
    });

    it('handles mutation errors', async () => {
      const attachResolver = createAttachMutationResolver(['Error message']);
      createComponent({ attachResolver });
      await waitForPromises();

      await findApplyProfileBtn().trigger('click');
      await waitForPromises();

      expect(attachResolver).toHaveBeenCalled();
    });

    it('shows error message when attach mutation throws error', async () => {
      const attachResolver = jest.fn().mockRejectedValue(new Error('Network error'));
      createComponent({ attachResolver });
      await waitForPromises();

      expect(findApplyProfileBtn().exists()).toBe(true);
      await findApplyProfileBtn().trigger('click');
      await waitForPromises();

      expect(findAlert().exists()).toBe(true);
      expect(findAlert().text()).toContain('Error applying profile');
    });

    it('refetches statuses query after applying profile', async () => {
      const statusesResolver = createScanProfileStatusesResolver();
      const attachResolver = createAttachMutationResolver();
      createComponent({
        attachResolver,
        scanProfileStatusesResolver: statusesResolver,
        glFeatures: { securityScanProfilesStatusIndicators: true },
      });
      await waitForPromises();

      await findApplyProfileBtn().trigger('click');
      await waitForPromises();

      expect(statusesResolver).toHaveBeenCalledTimes(2);
    });

    it('shows success toast after applying profile', async () => {
      const attachResolver = createAttachMutationResolver();
      createComponent({ attachResolver });
      await waitForPromises();

      await findApplyProfileBtn().trigger('click');
      await waitForPromises();

      expect(mockToastShow).toHaveBeenCalledWith(SCAN_PROFILE_I18N.successApplying);
    });

    it('closes preview modal when profile is applied while modal is open', async () => {
      const attachResolver = createAttachMutationResolver();
      createComponent({
        attachResolver,
        projectProfilesResolver: createProjectProfilesResolver([mockScanner]),
      });
      await waitForPromises();

      const profileLinks = findAllLinks().filter((link) => link.text() === mockScanner.name);
      await profileLinks.at(0).trigger('click');
      expect(findDetailsModal().props('visible')).toBe(true);

      findDetailsModal().vm.$emit('apply', mockScanner.id);
      await waitForPromises();

      expect(findDetailsModal().props('visible')).toBe(false);
    });
  });

  describe('detach profile', () => {
    describe('without securityScanProfilesStatusIndicators feature flag', () => {
      it('renders a plain Disable button (not inside a dropdown)', async () => {
        createComponent({
          projectProfilesResolver: createProjectProfilesResolver([mockScanner]),
        });
        await waitForPromises();

        expect(findDisableBtn().exists()).toBe(true);
        expect(findDropdownItems()).toHaveLength(0);
      });

      it('opens disable modal when plain Disable button is clicked', async () => {
        createComponent({
          projectProfilesResolver: createProjectProfilesResolver([mockScanner]),
        });
        await waitForPromises();

        await findDisableBtn().trigger('click');
        await nextTick();

        expect(findDisableModal().props('visible')).toBe(true);
        expect(findDisableModal().props('scannerName')).toBe('Secret detection');
      });

      it('calls detach mutation when confirmed in modal', async () => {
        const detachResolver = createDetachMutationResolver();
        createComponent({
          projectProfilesResolver: createProjectProfilesResolver([mockScanner]),
          detachResolver,
        });
        await waitForPromises();

        await findDisableBtn().trigger('click');
        await waitForPromises();

        findDisableModal().vm.$emit('confirm');
        await waitForPromises();

        expect(detachResolver).toHaveBeenCalledWith({
          input: {
            securityScanProfileId: mockScanner.id,
            projectIds: [mockProjectId],
          },
        });
      });

      it('closes modal when cancel is clicked', async () => {
        createComponent({
          projectProfilesResolver: createProjectProfilesResolver([mockScanner]),
        });
        await waitForPromises();

        await findDisableBtn().trigger('click');
        await waitForPromises();

        findDisableModal().vm.$emit('cancel');
        await nextTick();

        expect(findDisableModal().props('visible')).toBe(false);
      });
    });

    describe('with securityScanProfilesStatusIndicators feature flag', () => {
      it('renders Disable inside a 3-dot dropdown (not as a plain button)', async () => {
        createComponent({
          projectProfilesResolver: createProjectProfilesResolver([mockScanner]),
          glFeatures: { securityScanProfilesStatusIndicators: true },
          statuses: [mockStatusWithStatus('ACTIVE')],
        });
        await waitForPromises();

        expect(findDisableDropdownItem()).toBeDefined();
        expect(findDisableBtn().exists()).toBe(false);
      });

      it('opens disable modal when disable button is clicked', async () => {
        createComponent({
          projectProfilesResolver: createProjectProfilesResolver([mockScanner]),
          glFeatures: { securityScanProfilesStatusIndicators: true },
          statuses: [mockStatusWithStatus('ACTIVE')],
        });
        await waitForPromises();

        const disableItem = findDisableDropdownItem();
        expect(disableItem).toBeDefined();
        disableItem.vm.$emit('action');
        await nextTick();

        expect(findDisableModal().props('visible')).toBe(true);
        expect(findDisableModal().props('scannerName')).toBe('Secret detection');
      });

      it('calls detach mutation when confirmed in modal', async () => {
        const detachResolver = createDetachMutationResolver();
        createComponent({
          projectProfilesResolver: createProjectProfilesResolver([mockScanner]),
          glFeatures: { securityScanProfilesStatusIndicators: true },
          statuses: [mockStatusWithStatus('ACTIVE')],
          detachResolver,
        });
        await waitForPromises();

        const disableItem = findDisableDropdownItem();
        expect(disableItem).toBeDefined();
        disableItem.vm.$emit('action');
        await waitForPromises();

        findDisableModal().vm.$emit('confirm');
        await waitForPromises();

        expect(detachResolver).toHaveBeenCalledWith({
          input: {
            securityScanProfileId: mockScanner.id,
            projectIds: [mockProjectId],
          },
        });
      });

      it('detaches profile by calling the mutation', async () => {
        const detachResolver = createDetachMutationResolver();
        createComponent({
          projectProfilesResolver: createProjectProfilesResolver([mockScanner]),
          statuses: [mockStatusWithStatus('ACTIVE')],
          detachResolver,
          glFeatures: { securityScanProfilesStatusIndicators: true },
        });
        await waitForPromises();

        const disableItem = findDisableDropdownItem();
        expect(disableItem).toBeDefined();
        expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(false);
        disableItem.vm.$emit('action');
        await waitForPromises();

        findDisableModal().vm.$emit('confirm');
        await waitForPromises();

        expect(detachResolver).toHaveBeenCalled();
      });

      it('closes modal when cancel is clicked', async () => {
        createComponent({
          projectProfilesResolver: createProjectProfilesResolver([mockScanner]),
          glFeatures: { securityScanProfilesStatusIndicators: true },
          statuses: [mockStatusWithStatus('ACTIVE')],
        });
        await waitForPromises();

        const disableItem = findDisableDropdownItem();
        expect(disableItem).toBeDefined();
        expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(false);
        disableItem.vm.$emit('action');
        await waitForPromises();

        findDisableModal().vm.$emit('cancel');
        await nextTick();

        expect(findDisableModal().props('visible')).toBe(false);
      });

      it('shows success toast after detaching profile', async () => {
        const detachResolver = createDetachMutationResolver();
        createComponent({
          projectProfilesResolver: createProjectProfilesResolver([mockScanner]),
          glFeatures: { securityScanProfilesStatusIndicators: true },
          statuses: [mockStatusWithStatus('ACTIVE')],
          detachResolver,
        });
        await waitForPromises();

        const disableItem = findDisableDropdownItem();
        disableItem.vm.$emit('action');
        await waitForPromises();

        findDisableModal().vm.$emit('confirm');
        await waitForPromises();

        expect(mockToastShow).toHaveBeenCalledWith(SCAN_PROFILE_I18N.successDetaching);
      });

      it('refetches statuses query after detaching profile', async () => {
        const statusesResolver = createScanProfileStatusesResolver();
        const detachResolver = createDetachMutationResolver();
        createComponent({
          projectProfilesResolver: createProjectProfilesResolver([mockScanner]),
          glFeatures: { securityScanProfilesStatusIndicators: true },
          statuses: [mockStatusWithStatus('ACTIVE')],
          scanProfileStatusesResolver: statusesResolver,
          detachResolver,
        });
        await waitForPromises();

        findDisableDropdownItem().vm.$emit('action');
        await waitForPromises();

        findDisableModal().vm.$emit('confirm');
        await waitForPromises();

        expect(statusesResolver).toHaveBeenCalledTimes(2);
      });

      it.each([
        ['failed', mockStatusWithStatus('FAILED')],
        ['warning', mockStatusWithStatus('WARNING')],
      ])('shows troubleshoot failure item when status is %s', async (_, status) => {
        createComponent({
          projectProfilesResolver: createProjectProfilesResolver([mockScanner]),
          glFeatures: { securityScanProfilesStatusIndicators: true },
          statuses: [status],
        });
        await waitForPromises();

        const troubleshootItem = findDropdownItems().wrappers.find((item) =>
          item.text().includes('Troubleshoot'),
        );
        expect(troubleshootItem).toBeDefined();
      });

      it.each([
        ['active', mockStatusWithStatus('ACTIVE')],
        ['stale', mockStatusWithStatus('STALE')],
        ['unconfigured', mockStatusWithStatus('UNCONFIGURED')],
        ['pending', mockStatusWithStatus('PENDING')],
      ])('does not show troubleshoot failure item when status is %s', async (_, status) => {
        createComponent({
          projectProfilesResolver: createProjectProfilesResolver([mockScanner]),
          glFeatures: { securityScanProfilesStatusIndicators: true },
          statuses: [status],
        });
        await waitForPromises();

        const troubleshootItem = findDropdownItems().wrappers.find((item) =>
          item.text().includes('Troubleshoot'),
        );
        expect(troubleshootItem).toBeUndefined();
      });
    });
  });

  describe('preview profile', () => {
    it('opens details modal when preview button is clicked', async () => {
      createComponent();
      await waitForPromises();

      expect(findPreviewBtn()).toBeDefined();
      await findPreviewBtn().trigger('click');

      expect(findDetailsModal().props('visible')).toBe(true);
      expect(findDetailsModal().props('profileId')).toBe(mockScanner.id);
    });

    it('opens details modal when profile name link is clicked', async () => {
      createComponent({
        projectProfilesResolver: createProjectProfilesResolver([mockScanner]),
      });
      await waitForPromises();

      const profileLinks = findAllLinks().filter((link) => link.text() === mockScanner.name);
      expect(profileLinks.length).toBeGreaterThan(0);
      await profileLinks.at(0).trigger('click');

      expect(findDetailsModal().props('visible')).toBe(true);
      expect(findDetailsModal().props('profileId')).toBe(mockScanner.id);
    });

    it('tracks preview_scan_profile when preview button is clicked', async () => {
      createComponent();
      await waitForPromises();

      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      await findPreviewBtn().trigger('click');

      expect(trackEventSpy).toHaveBeenCalledWith('preview_scan_profile', {}, undefined);
    });

    it('closes details modal when close event is emitted', async () => {
      createComponent({
        projectProfilesResolver: createProjectProfilesResolver([mockScanner]),
      });
      await waitForPromises();

      const profileLinks = findAllLinks().filter((link) => link.text() === mockScanner.name);
      expect(profileLinks.length).toBeGreaterThan(0);
      await profileLinks.at(0).trigger('click');

      findDetailsModal().vm.$emit('close');
      await nextTick();

      expect(findDetailsModal().props('visible')).toBe(false);
    });

    it('applies profile from details modal', async () => {
      const attachResolver = createAttachMutationResolver();
      createComponent({
        attachResolver,
        projectProfilesResolver: createProjectProfilesResolver([mockScanner]),
      });
      await waitForPromises();

      const profileLinks = findAllLinks().filter((link) => link.text() === mockScanner.name);
      expect(profileLinks.length).toBeGreaterThan(0);
      await profileLinks.at(0).trigger('click');
      await waitForPromises();

      findDetailsModal().vm.$emit('apply', mockScanner.id);
      await waitForPromises();

      expect(attachResolver).toHaveBeenCalled();
    });
  });

  describe('permissions', () => {
    it('shows lock icon and popover on apply button when user cannot apply profiles', async () => {
      createComponent({ canApplyProfiles: false });
      await waitForPromises();

      expect(findApplyProfileBtn().text()).toContain('Apply default profile');
      expect(findApplyProfileBtn().html()).toContain('lock');
      expect(findPopover().exists()).toBe(true);
      expect(findPopover().props('target')).toContain('apply-button');
    });

    it('shows lock icon and popover on disable button when user cannot apply profiles', async () => {
      createComponent({
        canApplyProfiles: false,
        projectProfilesResolver: createProjectProfilesResolver([mockScanner]),
        glFeatures: { securityScanProfilesStatusIndicators: true },
        statuses: [mockStatusWithStatus('ACTIVE')],
      });
      await waitForPromises();

      const disableItem = findDropdownItems().wrappers.find((item) =>
        item.text().includes('Disable'),
      );
      expect(disableItem).toBeDefined();
      expect(disableItem.html()).toContain('lock');

      const popovers = wrapper.findAllComponents(InsufficientPermissionsPopover);
      expect(popovers.length).toBeGreaterThan(0);
      const disablePopover = popovers.wrappers.find((p) =>
        p.props('target').includes('disable-button'),
      );
      expect(disablePopover).toBeDefined();
    });

    it('allows preview button to be clicked when user cannot apply profiles', async () => {
      createComponent({ canApplyProfiles: false });
      await waitForPromises();
      expect(findPreviewBtn().props('disabled')).toBe(false);
    });
  });

  describe('ScanProfileLaunchModal', () => {
    it('renders when licensed', async () => {
      createComponent({ securityScanProfilesLicensed: true });
      await waitForPromises();

      expect(wrapper.findComponent(ScanProfileLaunchModal).exists()).toBe(true);
    });

    it('does not render when unlicensed', async () => {
      createComponent({ securityScanProfilesLicensed: false });
      await waitForPromises();

      expect(wrapper.findComponent(ScanProfileLaunchModal).exists()).toBe(false);
    });
  });

  describe('with multiple profiles for one scan type', () => {
    const customSastProfile = {
      ...mockScanner,
      id: 'gid://gitlab/Security::ScanProfile/2',
      name: 'SAST Custom A',
      gitlabRecommended: false,
    };

    const findProfilePicker = () => wrapper.findComponent(GlCollapsibleListbox);
    const multiProfileResolver = () =>
      createAvailableProfilesResolver([mockScanner, customSastProfile]);

    it('renders one row per scan type when multiple profiles share a scan type', async () => {
      createComponent({ availableProfilesResolver: multiProfileResolver() });
      await waitForPromises();

      expect(findTable().props('tableItems')).toHaveLength(1);
    });

    it('renders a profile picker when the scan type has multiple profiles and is not configured', async () => {
      createComponent({ availableProfilesResolver: multiProfileResolver() });
      await waitForPromises();

      expect(findProfilePicker().exists()).toBe(true);
      expect(findProfilePicker().props('selected')).toBe(mockScanner.id);
      expect(findProfilePicker().props('items')).toEqual([
        { value: mockScanner.id, text: mockScanner.name },
        { value: customSastProfile.id, text: customSastProfile.name },
      ]);
    });

    it('keeps default-profile labels while the recommended profile is selected', async () => {
      createComponent({ availableProfilesResolver: multiProfileResolver() });
      await waitForPromises();

      expect(findApplyProfileBtn().text()).toContain(SCAN_PROFILE_I18N.applyDefault);
      expect(findPreviewBtn().attributes('title')).toBe(SCAN_PROFILE_I18N.previewDefault);
    });

    it('switches to non-default labels when a non-recommended profile is picked', async () => {
      createComponent({ availableProfilesResolver: multiProfileResolver() });
      await waitForPromises();

      findProfilePicker().vm.$emit('select', customSastProfile.id);
      await nextTick();

      expect(findApplyProfileBtn().text()).toContain(SCAN_PROFILE_I18N.applyProfile);
      expect(findPreviewBtn().attributes('title')).toBe(SCAN_PROFILE_I18N.previewProfile);
    });

    it('applies the picked profile when the listbox selection changes', async () => {
      const attachResolver = createAttachMutationResolver();
      createComponent({
        availableProfilesResolver: multiProfileResolver(),
        attachResolver,
      });
      await waitForPromises();

      findProfilePicker().vm.$emit('select', customSastProfile.id);
      await nextTick();
      findApplyProfileBtn().vm.$emit('click');
      await waitForPromises();

      expect(attachResolver).toHaveBeenCalledWith({
        input: {
          securityScanProfileId: customSastProfile.id,
          projectIds: [mockProjectId],
        },
      });
    });

    it('renders the applied-profile link (not the picker) when a profile is attached', async () => {
      createComponent({
        availableProfilesResolver: multiProfileResolver(),
        projectProfilesResolver: createProjectProfilesResolver([mockScanner]),
      });
      await waitForPromises();

      expect(findProfilePicker().exists()).toBe(false);
      expect(findAllLinks().wrappers.some((link) => link.text() === mockScanner.name)).toBe(true);
    });
  });

  describe('apollo queries', () => {
    it('calls available profiles query with correct variables', () => {
      const resolver = createAvailableProfilesResolver();
      createComponent({ availableProfilesResolver: resolver });

      expect(resolver).toHaveBeenCalledWith({
        fullPath: 'group',
      });
    });

    it('calls project profiles query with correct variables', () => {
      const resolver = createProjectProfilesResolver();
      createComponent({ projectProfilesResolver: resolver });

      expect(resolver).toHaveBeenCalledWith({
        fullPath: 'group/project',
      });
    });

    it('calls statuses query with correct variables when feature flag is enabled', () => {
      const resolver = createScanProfileStatusesResolver();
      createComponent({
        scanProfileStatusesResolver: resolver,
        glFeatures: { securityScanProfilesStatusIndicators: true },
      });

      expect(resolver).toHaveBeenCalledWith({
        fullPath: 'group/project',
      });
    });

    it('does not call statuses query when feature flag is disabled', () => {
      const resolver = createScanProfileStatusesResolver();
      createComponent({
        scanProfileStatusesResolver: resolver,
        glFeatures: {},
      });

      expect(resolver).not.toHaveBeenCalled();
    });
  });
});
