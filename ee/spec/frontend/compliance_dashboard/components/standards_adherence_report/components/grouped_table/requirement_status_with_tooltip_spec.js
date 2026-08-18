import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlBadge, GlTooltip } from '@gitlab/ui';
import RequirementStatusWithTooltip from 'ee/compliance_dashboard/components/standards_adherence_report/components/grouped_table/requirement_status_with_tooltip.vue';
import RequirementStatus from 'ee/compliance_dashboard/components/standards_adherence_report/components/requirement_status.vue';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import complianceRequirementsControlsQuery from 'ee/compliance_dashboard/components/standards_adherence_report/graphql/queries/compliance_requirements_controls.query.graphql';
import { EXTERNAL_CONTROL_LABEL } from 'ee/compliance_dashboard/constants';

Vue.use(VueApollo);

describe('RequirementStatusWithTooltip', () => {
  let wrapper;
  let mockRequirementsControlsQuery;

  const mockControlExpressions = [
    { id: 'control-1', name: 'Control One' },
    { id: 'control-2', name: 'Control Two' },
    { id: 'control-3', name: 'Control Three' },
    { id: 'control-4', name: 'Control Four' },
  ];

  const mockStatus = {
    pendingCount: 2,
    passCount: 1,
    failCount: 1,
    project: {
      complianceControlStatus: {
        nodes: [
          {
            id: 'status-1',
            status: 'PENDING',
            complianceRequirementsControl: {
              id: 'control-1',
              name: 'control-1',
              controlType: 'internal',
            },
          },
          {
            id: 'status-2',
            status: 'PENDING',
            complianceRequirementsControl: {
              id: 'control-2',
              name: 'control-2',
              controlType: 'external',
              externalControlName: 'External Control Name',
            },
          },
          {
            id: 'status-3',
            status: 'PASS',
            complianceRequirementsControl: {
              id: 'control-3',
              name: 'control-3',
              controlType: 'internal',
            },
          },
          {
            id: 'status-4',
            status: 'FAIL',
            complianceRequirementsControl: {
              id: 'control-4',
              name: 'control-4',
              controlType: 'external',
              externalControlName: null,
            },
          },
        ],
      },
    },
    complianceRequirement: {
      complianceRequirementsControls: {
        nodes: [{ id: 'control-1' }, { id: 'control-2' }, { id: 'control-3' }, { id: 'control-4' }],
      },
    },
  };

  const createMockRequirementsControlsResponse = () => ({
    data: {
      complianceRequirementControls: {
        controlExpressions: mockControlExpressions,
      },
    },
  });

  const findTooltip = () => wrapper.findComponent(GlTooltip);
  const findRequirementStatus = () => wrapper.findComponent(RequirementStatus);
  const findBadges = () => wrapper.findAllComponents(GlBadge);
  const findHeader = () => wrapper.find('h3');
  const findHeaderByText = (text) =>
    wrapper.findAll('h4').wrappers.find((h) => h.text().includes(text));
  const findControlList = () =>
    wrapper.findAll('h4, li').wrappers.map((w) => w.text().replace(/\s+/g, ' '));

  function createComponent(props = {}) {
    mockRequirementsControlsQuery = jest
      .fn()
      .mockResolvedValue(createMockRequirementsControlsResponse());

    const apolloProvider = createMockApollo([
      [complianceRequirementsControlsQuery, mockRequirementsControlsQuery],
    ]);

    wrapper = shallowMount(RequirementStatusWithTooltip, {
      propsData: {
        status: mockStatus,
        ...props,
      },
      apolloProvider,
      stubs: {
        GlTooltip: false,
        GlSprintf: false,
      },
    });

    return wrapper;
  }

  describe('component structure', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
      await nextTick();
    });

    it('renders the main wrapper div', () => {
      expect(wrapper.find('div').exists()).toBe(true);
    });

    it('renders GlTooltip component', () => {
      expect(findTooltip().exists()).toBe(true);
    });

    it('renders RequirementStatus component', () => {
      expect(findRequirementStatus().exists()).toBe(true);
    });

    it('passes correct props to RequirementStatus', () => {
      const requirementStatus = findRequirementStatus();
      expect(requirementStatus.props()).toEqual({
        passCount: mockStatus.passCount,
        pendingCount: mockStatus.pendingCount,
        failCount: mockStatus.failCount,
      });
    });
  });

  describe('control name display', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
      await nextTick();
    });

    it('displays mapped names for internal controls', () => {
      expect(wrapper.text()).toContain('Control One');
      expect(wrapper.text()).toContain('Control Three');
    });

    it('displays external control labels for external controls', () => {
      const badges = findBadges();
      expect(badges).toHaveLength(2);
      badges.wrappers.forEach((badge) => {
        expect(badge.text()).toBe(EXTERNAL_CONTROL_LABEL);
      });
    });

    it('displays external control names when provided', () => {
      expect(wrapper.text()).toContain('External Control Name');
    });

    it('displays fallback label for external controls without names', () => {
      // control-4 is external with null externalControlName
      expect(wrapper.text()).toContain(EXTERNAL_CONTROL_LABEL);
    });
  });

  describe('tooltip content when pendingCount > 0', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
      await nextTick();
    });

    it('displays pending count header with GlSprintf', () => {
      const header = findHeader();
      expect(header.exists()).toBe(true);
    });

    it('displays pending controls section', () => {
      const pendingHeader = findHeaderByText('Pending controls');
      expect(pendingHeader.exists()).toBe(true);
    });
  });

  describe('tooltip content sections', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
      await nextTick();
    });

    it('displays failed controls section', () => {
      const failedHeader = findHeaderByText('Failed controls');
      expect(failedHeader.exists()).toBe(true);
    });

    it('displays pending controls section', () => {
      const pendingHeader = findHeaderByText('Pending controls');
      expect(pendingHeader.exists()).toBe(true);
    });

    it('displays passed controls section', () => {
      const passedHeader = findHeaderByText('Passed controls');
      expect(passedHeader.exists()).toBe(true);
    });

    it('correctly lists control statuses in order', () => {
      expect(findControlList()).toStrictEqual([
        'Failed controls:',
        'External External',
        'Pending controls:',
        'Control One',
        'External Control Name External',
        'Passed controls:',
        'Control Three',
      ]);
    });
  });

  describe('external control badges', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
      await nextTick();
    });

    it('displays badges for external controls', () => {
      const badges = findBadges();
      expect(badges).toHaveLength(2); // Two external controls
      badges.wrappers.forEach((badge) => {
        expect(badge.text()).toBe(EXTERNAL_CONTROL_LABEL);
      });
    });
  });

  describe('when pendingCount is 0', () => {
    beforeEach(async () => {
      const statusWithNoPending = {
        ...mockStatus,
        pendingCount: 0,
        project: {
          complianceControlStatus: {
            nodes: mockStatus.project.complianceControlStatus.nodes.filter(
              (node) => node.status !== 'PENDING',
            ),
          },
        },
      };
      createComponent({ status: statusWithNoPending });
      await waitForPromises();
      await nextTick();
    });

    it('does not display pending count header', () => {
      const header = findHeader();
      expect(header.exists()).toBe(false);
    });

    it('does not display pending controls section', () => {
      const pendingHeader = findHeaderByText('Pending controls');
      expect(pendingHeader).toBeUndefined();
    });
  });

  describe('when no failed controls exist', () => {
    beforeEach(async () => {
      const statusWithNoFailed = {
        ...mockStatus,
        failCount: 0,
        project: {
          complianceControlStatus: {
            nodes: mockStatus.project.complianceControlStatus.nodes.filter(
              (node) => node.status !== 'FAIL',
            ),
          },
        },
      };
      createComponent({ status: statusWithNoFailed });
      await waitForPromises();
      await nextTick();
    });

    it('does not display failed controls section', () => {
      const failedHeader = findHeaderByText('Failed controls');
      expect(failedHeader).toBeUndefined();
    });
  });

  describe('when no passed controls exist', () => {
    beforeEach(async () => {
      const statusWithNoPassed = {
        ...mockStatus,
        passCount: 0,
        project: {
          complianceControlStatus: {
            nodes: mockStatus.project.complianceControlStatus.nodes.filter(
              (node) => node.status !== 'PASS',
            ),
          },
        },
      };
      createComponent({ status: statusWithNoPassed });
      await waitForPromises();
      await nextTick();
    });

    it('does not display passed controls section', () => {
      const passedHeader = findHeaderByText('Passed controls');
      expect(passedHeader).toBeUndefined();
    });
  });

  describe('when all controls have same status', () => {
    it('shows only failed controls section when all are failed', async () => {
      const allFailedStatus = {
        ...mockStatus,
        pendingCount: 0,
        passCount: 0,
        failCount: 2,
        project: {
          complianceControlStatus: {
            nodes: [
              {
                id: 'status-1',
                status: 'FAIL',
                complianceRequirementsControl: {
                  id: 'control-1',
                  name: 'control-1',
                  controlType: 'internal',
                },
              },
              {
                id: 'status-2',
                status: 'FAIL',
                complianceRequirementsControl: {
                  id: 'control-2',
                  name: 'control-2',
                  controlType: 'internal',
                },
              },
            ],
          },
        },
        complianceRequirement: {
          complianceRequirementsControls: {
            nodes: [{ id: 'control-1' }, { id: 'control-2' }],
          },
        },
      };

      createComponent({ status: allFailedStatus });
      await waitForPromises();
      await nextTick();

      expect(findHeaderByText('Failed controls').exists()).toBe(true);
      expect(findHeaderByText('Pending controls')).toBeUndefined();
      expect(findHeaderByText('Passed controls')).toBeUndefined();
    });
  });
});
