import { GlDisclosureDropdown, GlLink, GlPopover } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { epicType, mockWorkItemFeaturesData } from 'jest/work_items/mock_data';
import WorkItemColor from 'ee/work_items/components/work_item_color.vue';
import SidebarColorView from '~/sidebar/components/sidebar_color_view.vue';
import SidebarColorPicker from '~/sidebar/components/sidebar_color_picker.vue';
import WorkItemSidebarWidget from '~/work_items/components/shared/work_item_sidebar_widget.vue';
import updateWorkItemMutation from '~/work_items/graphql/update_work_item.mutation.graphql';
import {
  workItemColorWidget,
  updateWorkItemMutationErrorResponse,
  updateWorkItemMutationResponseFactory,
  workItemByIidResponseFactory,
} from '../mock_data';

describe('WorkItemColor component', () => {
  Vue.use(VueApollo);

  let wrapper;
  const selectedColor = '#ffffff';

  const mockWorkItem = workItemByIidResponseFactory({
    workItemType: epicType,
    colorWidgetPresent: true,
    color: '#1068bf',
  }).data.namespace.workItem;
  const mockSelectedColorWorkItem = workItemByIidResponseFactory({
    workItemType: epicType,
    colorWidgetPresent: true,
    color: selectedColor,
  }).data.namespace.workItem;
  const successUpdateWorkItemMutationHandler = jest
    .fn()
    .mockResolvedValue(
      updateWorkItemMutationResponseFactory({ colorWidgetPresent: true, color: selectedColor }),
    );

  const createComponent = ({
    canUpdate = true,
    mutationHandler = successUpdateWorkItemMutationHandler,
    workItem = mockWorkItem,
    mountFn = shallowMountExtended,
    stubs = {},
    glFeatures = {},
  } = {}) => {
    wrapper = mountFn(WorkItemColor, {
      apolloProvider: createMockApollo([[updateWorkItemMutation, mutationHandler]]),
      provide: {
        glFeatures,
      },
      propsData: {
        canUpdate,
        workItem,
      },
      stubs: {
        WorkItemSidebarWidget,
        ...stubs,
      },
    });
  };

  const findSidebarColorView = () => wrapper.findComponent(SidebarColorView);
  const findDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findSidebarColorPicker = () => wrapper.findComponent(SidebarColorPicker);
  const findInfoPopover = () => wrapper.findComponent(GlPopover);
  const findInfoPopoverLink = () => wrapper.findComponent(GlLink);
  const findInfoIcon = () => wrapper.findByTestId('info-icon');
  const findColorHeaderTitle = () => wrapper.findByTestId('color-header-title');
  const findEditButton = () => wrapper.findComponentByTestId('edit-button');
  const findApplyButton = () => wrapper.findComponentByTestId('apply-button');

  const selectColor = async (color) => {
    findEditButton().vm.$emit('click');
    await nextTick();
    findSidebarColorPicker().vm.$emit('input', color);
    findDropdown().vm.$emit('hidden');
  };

  describe('when work item epic color can not be updated', () => {
    beforeEach(() => {
      createComponent({ canUpdate: false, workItem: mockSelectedColorWorkItem });
    });

    it('renders the color view component with provided value', () => {
      expect(findSidebarColorView().props('color')).toBe(selectedColor);
      expect(findSidebarColorView().props('colorName')).toBe('Custom');
    });

    it('does not render the color picker component and edit button', () => {
      expect(findSidebarColorPicker().exists()).toBe(false);
      expect(findEditButton().exists()).toBe(false);
    });
  });

  describe('when work item epic color can be updated', () => {
    describe('when not editing', () => {
      beforeEach(() => {
        createComponent({ workItem: mockSelectedColorWorkItem });
      });

      it('renders the color view component and the edit button', () => {
        expect(findSidebarColorView().props('color')).toBe(selectedColor);
        expect(findEditButton().exists()).toBe(true);
      });

      it('does not render the color picker component', () => {
        expect(findSidebarColorPicker().exists()).toBe(false);
      });
    });

    describe('when editing', () => {
      beforeEach(() => {
        createComponent({ workItem: mockWorkItem });
        findEditButton().vm.$emit('click');
      });

      it('renders the color picker component and the apply button', () => {
        expect(findSidebarColorPicker().exists()).toBe(true);
        expect(findApplyButton().exists()).toBe(true);
      });

      it('does not render the color view component and edit button', () => {
        expect(findSidebarColorView().exists()).toBe(false);
        expect(findEditButton().exists()).toBe(false);
      });

      it('updates the color if apply button is clicked after selecting input color', () => {
        findSidebarColorPicker().vm.$emit('input', selectedColor);
        findApplyButton().vm.$emit('click');
        findDropdown().vm.$emit('hidden');

        expect(successUpdateWorkItemMutationHandler).toHaveBeenCalledWith({
          input: {
            id: workItemColorWidget.id,
            colorWidget: {
              color: selectedColor,
            },
          },
          useWorkItemFeatures: false,
        });
      });

      it('updates the color if dropdown is closed after selecting input color', async () => {
        createComponent({ mutationHandler: successUpdateWorkItemMutationHandler });
        await selectColor(selectedColor);

        expect(successUpdateWorkItemMutationHandler).toHaveBeenCalledWith({
          input: {
            id: workItemColorWidget.id,
            colorWidget: {
              color: selectedColor,
            },
          },
          useWorkItemFeatures: false,
        });
      });

      describe('when the workItemFeaturesField feature flag is enabled', () => {
        beforeEach(() => {
          createComponent({
            mutationHandler: successUpdateWorkItemMutationHandler,
            workItem: { ...mockWorkItem, features: mockWorkItemFeaturesData() },
            glFeatures: { workItemFeaturesField: true },
          });
        });

        it('passes useWorkItemFeatures as true to the mutation', async () => {
          await selectColor(selectedColor);

          expect(successUpdateWorkItemMutationHandler).toHaveBeenCalledWith({
            input: {
              id: workItemColorWidget.id,
              colorWidget: {
                color: selectedColor,
              },
            },
            useWorkItemFeatures: true,
          });
        });
      });

      it.each`
        errorType          | expectedErrorMessage                                                 | failureHandler
        ${'graphql error'} | ${'Something went wrong while updating the Epic. Please try again.'} | ${jest.fn().mockResolvedValue(updateWorkItemMutationErrorResponse)}
        ${'network error'} | ${'Something went wrong while updating the Epic. Please try again.'} | ${jest.fn().mockRejectedValue(new Error())}
      `(
        'emits an error when there is a $errorType',
        async ({ expectedErrorMessage, failureHandler }) => {
          createComponent({ mutationHandler: failureHandler });
          await selectColor(selectedColor);
          await waitForPromises();

          expect(wrapper.emitted('error')).toEqual([[expectedErrorMessage]]);
        },
      );
    });
  });

  it('renders the title in the dropdown header', async () => {
    createComponent({ mountFn: mountExtended });
    findEditButton().vm.$emit('click');
    await nextTick();

    expect(findColorHeaderTitle().text()).toBe('Select a color');
  });

  it('renders the color name when preset color is applied', () => {
    createComponent();

    expect(findSidebarColorView().props('colorName')).toBe('Blue');
  });

  it('renders info icon and popover with text', () => {
    createComponent();

    expect(findInfoIcon().attributes('aria-label')).toBe('Learn more');
    expect(findInfoPopover().text()).toContain(
      'An epic’s color is shown in roadmaps and epic boards.',
    );
    expect(findInfoPopoverLink().attributes('href')).toBe(
      '/help/user/group/epics/manage_epics#epic-color',
    );
  });
});
