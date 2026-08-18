import {
  GlTable,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlBadge,
  GlTooltip,
} from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import RequirementsSection from 'ee/compliance_dashboard/components/frameworks_report/wizard/components/requirements_section.vue';
import RequirementModal from 'ee/compliance_dashboard/components/frameworks_report/wizard/components/requirement_modal.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import {
  mockExternalControl,
  mockExternalControlWithPingDisabled,
  mockInternalControls,
  mockRequirements,
  mockGitLabStandardControls,
} from 'ee_jest/compliance_dashboard/mock_data';
import createMockApollo from 'helpers/mock_apollo_helper';
import controlsQuery from 'ee/compliance_dashboard/graphql/compliance_requirement_controls.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import {
  requirementEvents,
  emptyRequirement,
  maxRequirementsNumber,
} from 'ee/compliance_dashboard/components/frameworks_report/wizard/constants';

jest.mock('~/alert');

Vue.use(VueApollo);

describe('Requirements section', () => {
  let wrapper;

  const error = new Error('GraphQL error');

  let controlsQueryHandler;

  const findTable = () => wrapper.findComponent(GlTable);
  const findTableRow = (idx) => findTable().findAll('tbody > tr').at(idx);
  const findTableRowData = (idx) => findTableRow(idx).findAll('td');
  const findControlsCell = (idx = 0) => findTableRowData(idx).at(2);
  const findControlsBadges = (idx = 0) => findControlsCell(idx).findAllComponents(GlBadge);
  const findNewRequirementButton = () => wrapper.findComponentByTestId('add-requirement-button');
  const findRequirementModal = () => wrapper.findComponent(RequirementModal);
  const findDeleteAction = () => wrapper.findComponentByTestId('delete-action');
  const findEditAction = () => wrapper.findComponentByTestId('edit-action');
  const findPagination = () => wrapper.findComponentByTestId('requirements-pagination');
  const findUltimateOnlyAlert = () => wrapper.findByTestId('requirements-unavailable-alert');

  const createComponent = async ({
    controlsQueryHandlerMockResponse = controlsQueryHandler,
    isNewFramework = true,
    requirements = mockRequirements,
    glLicensedFeatures = { groupLevelComplianceAdherenceReport: true },
    readonly = false,
  } = {}) => {
    const mockApollo = createMockApollo([[controlsQuery, controlsQueryHandlerMockResponse]]);

    wrapper = mountExtended(RequirementsSection, {
      propsData: {
        requirements,
        isNewFramework,
        readonly,
      },
      apolloProvider: mockApollo,
      stubs: { GlDisclosureDropdown, GlDisclosureDropdownItem },
      provide: {
        glLicensedFeatures,
      },
    });

    await waitForPromises();
  };

  it('loads requirement controls on mount (section is always expanded)', async () => {
    controlsQueryHandler = jest.fn().mockResolvedValue({
      data: {
        complianceRequirementControls: {
          controlExpressions: mockGitLabStandardControls,
        },
      },
    });
    await createComponent({ isNewFramework: false });
    await waitForPromises();
    expect(controlsQueryHandler).toHaveBeenCalled();
  });

  describe('Rendering', () => {
    controlsQueryHandler = jest.fn().mockResolvedValue({
      data: {
        complianceRequirementControls: {
          controlExpressions: mockGitLabStandardControls,
        },
      },
    });
    beforeEach(async () => {
      await createComponent();
    });

    it('Has title', () => {
      const title = wrapper.findByText('Requirements');
      expect(title.exists()).toBe(true);
    });

    it('correctly displays description', () => {
      const description = wrapper.findByText(
        'Configure requirements set forth by laws, regulations, and industry standards.',
      );
      expect(description.exists()).toBe(true);
    });

    it('passes correct items prop to a table', () => {
      const items = findTable().props('items');
      expect(items).toHaveLength(mockRequirements.length);
    });

    it.each`
      idx  | expectedRequirement    | expectedControls
      ${0} | ${mockRequirements[0]} | ${[]}
      ${1} | ${mockRequirements[1]} | ${mockInternalControls}
      ${2} | ${mockRequirements[2]} | ${[mockExternalControl]}
    `(
      'passes the correct items prop to the table at index $idx',
      async ({ idx, expectedRequirement, expectedControls }) => {
        await createComponent();
        const items = findTable().props('items');
        const item = items[idx];
        expect(item.name).toBe(expectedRequirement.name);
        expect(item.description).toBe(expectedRequirement.description);
        expect(item.controls).toMatchObject(expectedControls);
      },
    );

    it.each`
      idx  | name          | description                            | controls                                          | externalBadgeCount
      ${0} | ${'SOC2'}     | ${'Controls for SOC2'}                 | ${[]}                                             | ${0}
      ${1} | ${'GitLab'}   | ${'Controls used by GitLab'}           | ${['Minimum approvals required', 'SAST Running']} | ${0}
      ${2} | ${'External'} | ${'Requirement with external control'} | ${['external_name']}                              | ${1}
    `(
      'has the correct data for row $idx',
      ({ idx, name, description, controls, externalBadgeCount }) => {
        const frameworkRequirements = findTableRowData(idx);

        expect(frameworkRequirements.at(0).text()).toBe(name);
        expect(frameworkRequirements.at(1).text()).toBe(description);

        const listItems = frameworkRequirements
          .at(2)
          .findAll('li')
          .wrappers.map((w) =>
            w
              .text()
              .replace(/\s+External$/, '')
              .replace(/\s+Disabled$/, '')
              .trim(),
          );
        expect(listItems).toEqual(controls);

        const badges = frameworkRequirements.at(2).findAllComponents(GlBadge);
        expect(badges).toHaveLength(externalBadgeCount);
      },
    );

    describe('Create requirement button', () => {
      beforeEach(() => {
        controlsQueryHandler = jest.fn().mockResolvedValue({
          data: {
            complianceRequirementControls: {
              controlExpressions: mockGitLabStandardControls,
            },
          },
        });
      });

      it('renders create requirement', () => {
        expect(findNewRequirementButton().text()).toBe('New requirement');
      });

      it('disables the add requirement button when maximum requirements limit is reached', async () => {
        const requirements = Array(maxRequirementsNumber).fill(mockRequirements[0]);
        await createComponent({
          controlsQueryHandlerMockResponse: controlsQueryHandler,
          isNewFramework: true,
          requirements,
        });

        expect(wrapper.vm.addingRequirementsDisabled).toBe(true);
        expect(findNewRequirementButton().props('disabled')).toBe(true);
      });

      it('shows a tooltip with max limit message when button is disabled', async () => {
        const requirements = Array(maxRequirementsNumber).fill(mockRequirements[0]);
        await createComponent({
          controlsQueryHandlerMockResponse: controlsQueryHandler,
          isNewFramework: true,
          requirements,
        });

        const tooltip = wrapper.findComponent(GlTooltip);
        expect(tooltip.exists()).toBe(true);
        expect(tooltip.attributes('title')).toBe(
          `You can create a maximum of ${maxRequirementsNumber} requirements`,
        );
      });

      it('enables the add requirement button when below maximum requirements limit', async () => {
        const requirements = Array(maxRequirementsNumber - 1).fill(mockRequirements[0]);
        await createComponent({
          controlsQueryHandlerMockResponse: controlsQueryHandler,
          isNewFramework: true,
          requirements,
        });

        expect(wrapper.vm.addingRequirementsDisabled).toBe(false);
        expect(findNewRequirementButton().props('disabled')).toBe(false);
      });

      it('does not show the tooltip when button is enabled', async () => {
        await createComponent({
          requirements: Array(maxRequirementsNumber - 1).fill(mockRequirements[0]),
          isNewFramework: true,
        });

        const tooltip = wrapper.findComponent(GlTooltip);
        expect(tooltip.exists()).toBe(false);
      });
    });
  });

  describe('Fetching data', () => {
    beforeEach(() => {
      controlsQueryHandler = jest.fn().mockResolvedValue({
        data: {
          complianceRequirementControls: {
            controlExpressions: mockGitLabStandardControls,
          },
        },
      });
      createComponent();
    });

    it('calls the complianceRequirementControls query', () => {
      expect(controlsQueryHandler).toHaveBeenCalled();
    });

    it('updates data', async () => {
      await findNewRequirementButton().trigger('click');
      expect(findRequirementModal().props('gitlabStandardControls')).toMatchObject(
        mockGitLabStandardControls,
      );
    });
  });

  describe('Error handling', () => {
    beforeEach(async () => {
      controlsQueryHandler = jest.fn().mockRejectedValue(error);
      await createComponent({ controlsQueryHandler });
    });

    it('calls createAlert with the correct message on query error', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Error fetching compliance requirements controls data. Please refresh the page.',
        captureException: true,
        error,
      });
    });
  });

  describe('Creating requirement', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('passes correct props to requirement modal', async () => {
      await findNewRequirementButton().trigger('click');
      expect(findRequirementModal().props('requirement')).toMatchObject({
        ...emptyRequirement,
        index: null,
      });
    });

    it('emits a create event with the correct data when the requirement is created', async () => {
      await findNewRequirementButton().trigger('click');

      const newRequirement = {
        ...mockRequirements[0],
        name: 'New Requirement',
      };

      await findRequirementModal().vm.$emit(requirementEvents.create, {
        requirement: newRequirement,
        index: null,
      });
      expect(wrapper.emitted('create')).toEqual([[{ requirement: newRequirement, index: null }]]);
      expect(findRequirementModal().exists()).toBe(false);
    });
  });

  describe('Delete requirement', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('emits a delete event with the correct index when delete action is clicked', async () => {
      await findDeleteAction().vm.$emit('action');
      expect(wrapper.emitted(requirementEvents.delete)).toStrictEqual([[0]]);
    });

    it('emits a delete event with the correct absolute index when on page 2', async () => {
      const generateRequirements = (count) => {
        return Array(count)
          .fill()
          .map((_, i) => ({ ...mockRequirements[0], name: `Requirement ${i + 1}` }));
      };

      const manyRequirements = generateRequirements(15);
      await createComponent({
        requirements: manyRequirements,
      });

      // Navigate to page 2
      await findPagination().vm.$emit('input', 2);
      await nextTick();

      // Click delete on the first item visible on page 2 (which is index 10 overall)
      await findDeleteAction().vm.$emit('action');
      expect(wrapper.emitted(requirementEvents.delete)).toStrictEqual([[10]]);
    });
  });

  describe('Update requirement', () => {
    const index = 0;
    beforeEach(async () => {
      await createComponent();
    });

    it('passes correct props to requirement modal', async () => {
      await findEditAction().vm.$emit('action');
      expect(findRequirementModal().props('requirement')).toMatchObject({
        ...mockRequirements[index],
        index,
      });
    });

    it('emits an update event with the correct data when the requirement is updated', async () => {
      await findEditAction().vm.$emit('action');

      const updatedRequirement = {
        ...mockRequirements[index],
        name: 'Updated SOC2 Requirement',
      };

      await findRequirementModal().vm.$emit(requirementEvents.update, {
        requirement: updatedRequirement,
        index,
      });
      expect(wrapper.emitted('update')).toEqual([[{ requirement: updatedRequirement, index }]]);
      expect(findRequirementModal().exists()).toBe(false);
    });
  });

  describe('paginate requirements', () => {
    const generateRequirements = (count) => {
      return Array(count)
        .fill()
        .map((_, i) => ({ ...mockRequirements[0], name: `Requirement ${i + 1}` }));
    };

    beforeEach(() => {
      controlsQueryHandler = jest.fn().mockResolvedValue({
        data: {
          complianceRequirementControls: {
            controlExpressions: mockGitLabStandardControls,
          },
        },
      });
    });

    it('does not render pagination when there are fewer items than per-page limit', async () => {
      const fewRequirements = generateRequirements(10);
      await createComponent({ requirements: fewRequirements });
      expect(findPagination().exists()).toBe(false);
    });

    it('renders pagination when there are more items than per-page limit', async () => {
      const manyRequirements = generateRequirements(15);
      await createComponent({ requirements: manyRequirements });
      expect(findPagination().exists()).toBe(true);
    });

    it('passes correct props to pagination component', async () => {
      const manyRequirements = generateRequirements(25);
      await createComponent({ requirements: manyRequirements });

      expect(findPagination().props()).toMatchObject({
        value: 1,
        perPage: 10,
        totalItems: 25,
        align: 'center',
      });
    });

    it('updates currentPage when pagination is changed', async () => {
      const manyRequirements = generateRequirements(25);
      await createComponent({ requirements: manyRequirements });

      expect(wrapper.vm.currentPage).toBe(1);
      await findPagination().vm.$emit('input', 2);
      expect(wrapper.vm.currentPage).toBe(2);
    });

    it('resets to page 1 when pagination is no longer needed', async () => {
      const manyRequirements = generateRequirements(11);
      await createComponent({ requirements: manyRequirements });

      // Navigate to page 2
      await findPagination().vm.$emit('input', 2);
      await nextTick();
      expect(wrapper.vm.currentPage).toBe(2);

      // Simulate deleting an item so only 10 remain (triggers showPagination computed property)
      await wrapper.setProps({ requirements: generateRequirements(10) });
      await nextTick();

      // Should reset to page 1 and hide pagination
      expect(wrapper.vm.currentPage).toBe(1);
      expect(findPagination().exists()).toBe(false);
    });
  });

  describe('Ping disabled badge', () => {
    beforeEach(() => {
      controlsQueryHandler = jest.fn().mockResolvedValue({
        data: {
          complianceRequirementControls: {
            controlExpressions: mockGitLabStandardControls,
          },
        },
      });
    });

    it('shows ping disabled badge for external controls with pingEnabled false', async () => {
      const requirementsWithPingDisabled = [
        {
          ...mockRequirements[0],
          stagedControls: [mockExternalControlWithPingDisabled],
        },
      ];

      await createComponent({
        controlsQueryHandlerMockResponse: controlsQueryHandler,
        requirements: requirementsWithPingDisabled,
      });

      const badges = findControlsBadges(0);

      expect(badges).toHaveLength(2);
      expect(badges.at(0).text()).toBe('External');
      expect(badges.at(1).text()).toBe('Disabled');
      expect(badges.at(1).props('variant')).toBe('warning');
    });

    it('does not show ping disabled badge for external controls with pingEnabled true', async () => {
      const requirementsWithPingEnabled = [
        {
          ...mockRequirements[0],
          stagedControls: [{ ...mockExternalControl, pingEnabled: true }],
        },
      ];

      await createComponent({
        controlsQueryHandlerMockResponse: controlsQueryHandler,
        requirements: requirementsWithPingEnabled,
      });

      const badges = findControlsBadges(0);

      expect(badges).toHaveLength(1);
      expect(badges.at(0).text()).toBe('External');
    });

    it('does not show ping disabled badge for external controls with pingEnabled undefined', async () => {
      const requirementsWithUndefinedPing = [
        {
          ...mockRequirements[0],
          stagedControls: [mockExternalControl],
        },
      ];

      await createComponent({
        controlsQueryHandlerMockResponse: controlsQueryHandler,
        requirements: requirementsWithUndefinedPing,
      });

      const badges = findControlsBadges(0);

      expect(badges).toHaveLength(1);
      expect(badges.at(0).text()).toBe('External');
    });

    it('does not show ping disabled badge for internal controls', async () => {
      const requirementsWithInternalControls = [
        {
          ...mockRequirements[0],
          stagedControls: mockInternalControls.map((control) => ({
            ...control,
            pingEnabled: false,
          })),
        },
      ];

      await createComponent({
        controlsQueryHandlerMockResponse: controlsQueryHandler,
        requirements: requirementsWithInternalControls,
      });

      const badges = findControlsBadges(0);

      expect(badges).toHaveLength(0);
    });
  });

  describe('readonly mode', () => {
    beforeEach(async () => {
      controlsQueryHandler = jest.fn().mockResolvedValue({
        data: { complianceRequirementControls: { controlExpressions: mockGitLabStandardControls } },
      });
      await createComponent({ readonly: true });
    });

    it('hides the Add requirement button', () => {
      expect(findNewRequirementButton().exists()).toBe(false);
    });

    it('hides the per-row action menu', () => {
      expect(findEditAction().exists()).toBe(false);
      expect(findDeleteAction().exists()).toBe(false);
    });

    it('does not render the requirement modal', () => {
      expect(findRequirementModal().exists()).toBe(false);
    });

    it('still renders the requirements table with rows', () => {
      expect(findTable().exists()).toBe(true);
      expect(findTable().props('items')).toHaveLength(mockRequirements.length);
    });

    it('hides the Action column from the table', () => {
      const fieldKeys = findTable()
        .props('fields')
        .map((f) => f.key);
      expect(fieldKeys).not.toContain('action');
    });
  });

  describe('CSP framework behavior', () => {
    beforeEach(() => {
      controlsQueryHandler = jest.fn().mockResolvedValue({
        data: {
          complianceRequirementControls: {
            controlExpressions: mockGitLabStandardControls,
          },
        },
      });
    });

    describe('when framework is inherited', () => {
      beforeEach(async () => {
        await createComponent({
          controlsQueryHandlerMockResponse: controlsQueryHandler,
          isInherited: true,
        });

        await wrapper.setProps({ isInherited: true });
      });

      it('passes isInherited prop correctly', () => {
        expect(wrapper.props('isInherited')).toBe(true);
      });
    });

    describe('when framework is not inherited', () => {
      beforeEach(async () => {
        await createComponent({
          controlsQueryHandlerMockResponse: controlsQueryHandler,
          isInherited: false,
        });
      });

      it('passes isInherited prop correctly', () => {
        expect(wrapper.props('isInherited')).toBe(false);
      });
    });
  });

  describe('License check for requirements feature', () => {
    beforeEach(() => {
      controlsQueryHandler = jest.fn().mockResolvedValue({
        data: {
          complianceRequirementControls: {
            controlExpressions: mockGitLabStandardControls,
          },
        },
      });
    });

    describe('when Ultimate license is available', () => {
      beforeEach(async () => {
        await createComponent({
          controlsQueryHandlerMockResponse: controlsQueryHandler,
          glLicensedFeatures: { groupLevelComplianceAdherenceReport: true },
        });
      });

      it('does not show the Ultimate-only alert', () => {
        expect(findUltimateOnlyAlert().exists()).toBe(false);
      });

      it('renders the add requirement button', () => {
        expect(findNewRequirementButton().exists()).toBe(true);
      });
    });

    describe('when Ultimate license is not available', () => {
      beforeEach(async () => {
        await createComponent({
          controlsQueryHandlerMockResponse: controlsQueryHandler,
          glLicensedFeatures: { groupLevelComplianceAdherenceReport: false },
        });
      });

      it('shows the Ultimate-only alert', () => {
        expect(findUltimateOnlyAlert().exists()).toBe(true);
      });

      it('does not render the add requirement button', () => {
        expect(findNewRequirementButton().exists()).toBe(false);
      });
    });
  });
});
