import { mount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlButton, GlBadge, GlLoadingIcon } from '@gitlab/ui';
import StatusesList from 'ee/compliance_dashboard/components/standards_adherence_report/components/details_drawer/statuses_list.vue';
import DrawerAccordion from 'ee/compliance_dashboard/components/shared/drawer_accordion.vue';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import complianceRequirementsControlsQuery from 'ee/compliance_dashboard/components/standards_adherence_report/graphql/queries/compliance_requirements_controls.query.graphql';

Vue.use(VueApollo);

jest.mock(
  'ee/compliance_dashboard/components/standards_adherence_report/components/details_drawer/statuses_info',
  () => ({
    statusesInfo: {
      'test-control': {
        description: 'Test control description',
        fixes: [
          {
            title: 'Fix 1',
            description: 'Fix 1 description',
            linkTitle: 'Fix 1 link',
            link: 'https://example.com/fix1',
            ultimate: true,
          },
        ],
      },
      'passed-control': {
        description: 'This control has passed successfully. No action is required.',
        fixes: [
          {
            title: 'Learn More',
            description: 'Learn more about this control',
            linkTitle: 'Learn more',
            link: 'https://example.com/learn-more',
            ultimate: false,
          },
        ],
      },
      'control-with-settings': {
        description: 'Control with project settings',
        projectSettingsPath: '/-/settings/merge_requests',
        fixes: [
          {
            title: 'Configure settings',
            description: 'Configure in project settings',
            linkTitle: 'Documentation',
            link: 'https://example.com/docs',
            ultimate: false,
          },
        ],
      },
    },
  }),
);

describe('StatusesList', () => {
  let wrapper;
  let mockRequirementsControlsQuery;

  const controlStatusesMock = [
    {
      status: 'FAIL',
      complianceRequirementsControl: {
        name: 'control-1',
        controlType: 'internal',
      },
    },
    {
      status: 'PENDING',
      complianceRequirementsControl: {
        name: 'control-2',
        controlType: 'internal',
      },
    },
    {
      status: 'PASS',
      complianceRequirementsControl: {
        name: 'control-3',
        controlType: 'internal',
      },
    },
    {
      status: 'FAIL',
      complianceRequirementsControl: {
        name: 'external-control',
        controlType: 'external',
        externalUrl: 'https://example.com/external',
        externalControlName: 'External control',
      },
    },
  ];

  const mockControlExpressions = [
    { id: 'control-1', name: 'Control One' },
    { id: 'control-2', name: 'Control Two' },
    { id: 'control-3', name: 'Control Three' },
    { id: 'control-with-settings', name: 'Control With Settings' },
  ];

  const mockProject = {
    webUrl: 'https://gitlab.example.com/group/project',
    name: 'Test Project',
  };

  const createMockRequirementsControlsResponse = () => ({
    data: {
      complianceRequirementControls: {
        controlExpressions: mockControlExpressions,
      },
    },
  });

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findDrawerAccordion = () => wrapper.findComponent(DrawerAccordion);
  const findAllFailedStatuses = () => wrapper.findAll('.gl-text-status-danger');
  const findAllPendingStatuses = () => wrapper.findAll('.gl-text-status-neutral');
  const findAllPassedStatuses = () => wrapper.findAll('.gl-text-status-success');
  const findFixSection = () => wrapper.findAll('h4').filter((w) => w.text() === 'How to fix');
  const findBadges = () => wrapper.findAllComponents(GlBadge);
  const findTitles = () => wrapper.findAll('h4');
  const findAllButtons = () => wrapper.findAllComponents(GlButton);
  const findSuccessMessage = () => wrapper.find('[data-testid="passed-control-message"]');
  const findLearnMoreButtons = () => wrapper.findAll('[data-testid="passed-documentation-button"]');

  function createComponent(props = {}) {
    mockRequirementsControlsQuery = jest
      .fn()
      .mockResolvedValue(createMockRequirementsControlsResponse());

    const apolloProvider = createMockApollo([
      [complianceRequirementsControlsQuery, mockRequirementsControlsQuery],
    ]);

    wrapper = mount(StatusesList, {
      propsData: {
        controlStatuses: controlStatusesMock,
        project: mockProject,
        ...props,
      },
      apolloProvider,
    });

    return wrapper;
  }

  describe('loading state', () => {
    it('shows loading icon when data is being fetched', () => {
      createComponent();

      expect(findLoadingIcon().exists()).toBe(true);
      expect(findDrawerAccordion().exists()).toBe(false);
    });
  });

  describe('after data is loaded', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
      await nextTick();
    });

    it('renders drawer accordion with control statuses', () => {
      expect(findDrawerAccordion().exists()).toBe(true);
      expect(findDrawerAccordion().props('items')).toEqual(
        expect.arrayContaining(controlStatusesMock),
      );
    });

    it('sorts control statuses by status priority (FAIL, PENDING, PASS)', () => {
      const sortedControlStatuses = [
        controlStatusesMock[0], // FAIL
        controlStatusesMock[3], // FAIL (external)
        controlStatusesMock[1], // PENDING
        controlStatusesMock[2], // PASS
      ];

      expect(findDrawerAccordion().props('items')).toEqual(sortedControlStatuses);
    });

    it('displays control name using mapping from API for internal controls', () => {
      expect(findTitles().at(0).text()).toBe('Control One');
    });

    it('displays "External control" for external control types', () => {
      expect(findTitles().at(1).text()).toContain('External control');
      expect(findTitles().at(1).text()).toContain('External');
    });
    it('displays appropriate status indicators for different statuses', () => {
      expect(findAllFailedStatuses()).toHaveLength(2); // 2 failed controls
      expect(findAllPendingStatuses()).toHaveLength(1); // 1 pending control
      expect(findAllPassedStatuses()).toHaveLength(1); // 1 passed control
    });
  });

  describe('fix information', () => {
    describe('for failed controls', () => {
      beforeEach(async () => {
        const controlWithFix = {
          status: 'FAIL',
          complianceRequirementsControl: {
            name: 'test-control',
            controlType: 'internal',
          },
        };

        createComponent({
          controlStatuses: [controlWithFix],
        });

        await waitForPromises();
        return nextTick();
      });

      it('displays fix section for failed controls with fixes', () => {
        expect(findFixSection()).toHaveLength(1);
      });

      it('renders Ultimate badge for fixes with ultimate flag', () => {
        const badges = findBadges();
        expect(badges).toHaveLength(1);
        expect(badges.at(0).text()).toBe('Ultimate');
      });

      it('continues to show "How to fix" section for failed controls', () => {
        expect(findFixSection()).toHaveLength(1);
        expect(findFixSection().at(0).text()).toBe('How to fix');
      });
    });

    describe('for pending controls', () => {
      beforeEach(async () => {
        const pendingControlWithFix = {
          status: 'PENDING',
          complianceRequirementsControl: {
            name: 'test-control',
            controlType: 'internal',
          },
        };

        createComponent({
          controlStatuses: [pendingControlWithFix],
        });

        await waitForPromises();
        return nextTick();
      });

      it('shows "How to fix" section for pending controls', () => {
        expect(findFixSection()).toHaveLength(1);
        expect(findFixSection().at(0).text()).toBe('How to fix');
      });
    });

    describe('for passed controls', () => {
      beforeEach(async () => {
        const passedControlWithFix = {
          status: 'PASS',
          complianceRequirementsControl: {
            name: 'passed-control',
            controlType: 'internal',
          },
        };

        createComponent({
          controlStatuses: [passedControlWithFix],
        });

        await waitForPromises();
        return nextTick();
      });

      it('does not display "How to fix" section for passed controls', () => {
        expect(findFixSection()).toHaveLength(0);
      });

      it('displays success message for passed controls', () => {
        expect(findSuccessMessage().text()).toContain(
          'This control has passed successfully. No action is required.',
        );
      });

      it('displays "Learn more" button for passed controls', () => {
        expect(findLearnMoreButtons()).toHaveLength(1);
        expect(findLearnMoreButtons().at(0).text()).toBe('Learn more');
      });
    });
  });

  describe('project settings button functionality', () => {
    describe('single button rendering (no project settings path)', () => {
      beforeEach(async () => {
        const controlWithoutSettings = {
          status: 'FAIL',
          complianceRequirementsControl: {
            name: 'test-control',
            controlType: 'internal',
          },
        };

        createComponent({
          controlStatuses: [controlWithoutSettings],
        });

        await waitForPromises();
        await nextTick();
      });

      it('renders only documentation button when no project settings path is available', () => {
        const buttons = findAllButtons();
        const documentationButtons = buttons.filter((button) =>
          button.text().includes('Fix 1 link'),
        );
        const settingsButtons = buttons.filter((button) =>
          button.text().includes('Go to project settings'),
        );

        expect(documentationButtons).toHaveLength(1);
        expect(settingsButtons).toHaveLength(0);
      });
    });

    describe('dual button rendering (with project settings path)', () => {
      beforeEach(async () => {
        const controlWithSettings = {
          status: 'FAIL',
          complianceRequirementsControl: {
            name: 'control-with-settings',
            controlType: 'internal',
          },
        };

        createComponent({
          controlStatuses: [controlWithSettings],
        });

        await waitForPromises();
        await nextTick();
      });

      it('renders both documentation and settings buttons when project settings path is available', () => {
        const buttons = findAllButtons();
        const documentationButtons = buttons.filter((button) =>
          button.text().includes('Documentation'),
        );
        const settingsButtons = buttons.filter((button) =>
          button.text().includes('Go to project settings'),
        );

        expect(documentationButtons).toHaveLength(1);
        expect(settingsButtons).toHaveLength(1);
      });

      it('renders settings button with correct attributes', () => {
        const buttons = findAllButtons();
        const settingsButtons = buttons.filter((button) =>
          button.text().includes('Go to project settings'),
        );

        expect(settingsButtons).toHaveLength(1);
        const settingsButton = settingsButtons.at(0);
        expect(settingsButton.props('category')).toBe('secondary');
        expect(settingsButton.props('variant')).toBe('default');
        expect(settingsButton.props('size')).toBe('small');
        expect(settingsButton.props('icon')).toBe('settings');
      });

      it('constructs correct project settings URL', () => {
        const buttons = findAllButtons();
        const settingsButtons = buttons.filter((button) =>
          button.text().includes('Go to project settings'),
        );

        expect(settingsButtons).toHaveLength(1);
        const settingsButton = settingsButtons.at(0);
        expect(settingsButton.props('href')).toBe(
          'https://gitlab.example.com/group/project/-/settings/merge_requests',
        );
      });
    });

    describe('getProjectSettingsUrl method', () => {
      let component;

      beforeEach(async () => {
        component = createComponent();
        await waitForPromises();
        await nextTick();
      });

      it('returns null when project is not provided', async () => {
        const controlStatus = {
          complianceRequirementsControl: {
            name: 'control-with-settings',
            controlType: 'internal',
          },
        };

        component.setProps({ project: null });
        await nextTick();

        const result = component.vm.getProjectSettingsUrl(controlStatus);
        expect(result).toBeNull();
      });

      it('returns null when projectSettingsPath is not available', () => {
        const controlStatus = {
          complianceRequirementsControl: {
            name: 'test-control', // This control doesn't have projectSettingsPath
            controlType: 'internal',
          },
        };

        const result = component.vm.getProjectSettingsUrl(controlStatus);
        expect(result).toBeNull();
      });

      it('constructs URL correctly when both project and projectSettingsPath are available', () => {
        const controlStatus = {
          complianceRequirementsControl: {
            name: 'control-with-settings',
            controlType: 'internal',
          },
        };

        const result = component.vm.getProjectSettingsUrl(controlStatus);
        expect(result).toBe('https://gitlab.example.com/group/project/-/settings/merge_requests');
      });
    });
  });
});
