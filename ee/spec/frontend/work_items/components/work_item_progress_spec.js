import { GlFormInput, GlPopover } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import WorkItemProgress from 'ee/work_items/components/work_item_progress.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mockTracking } from 'helpers/tracking_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { ENTER_KEY, ESC_KEY } from '~/lib/utils/keys';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { TRACKING_CATEGORY_SHOW, WIDGET_TYPE_PROGRESS } from '~/work_items/constants';
import updateWorkItemMutation from '~/work_items/graphql/update_work_item.mutation.graphql';
import WorkItemSidebarWidget from '~/work_items/components/shared/work_item_sidebar_widget.vue';
import { updateWorkItemMutationResponse } from '../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

describe('WorkItemProgress component', () => {
  Vue.use(VueApollo);

  let wrapper;

  const updateWorkItemMutationHandler = jest.fn().mockResolvedValue(updateWorkItemMutationResponse);
  const getWorkItemTypeConfiguration = jest.fn();

  const findInput = () => wrapper.findComponent(GlFormInput);
  const findEditButton = () => wrapper.findComponentByTestId('edit-button');
  const findProgressPopover = () => wrapper.findComponent(GlPopover);

  const createComponent = ({
    canUpdate = false,
    progress = 0,
    workItemType = 'Objective',
    widgetDefinitions = [],
    glFeatures = {},
  } = {}) => {
    getWorkItemTypeConfiguration.mockReturnValue({ widgetDefinitions });
    wrapper = shallowMountExtended(WorkItemProgress, {
      apolloProvider: createMockApollo([[updateWorkItemMutation, updateWorkItemMutationHandler]]),
      provide: {
        getWorkItemTypeConfiguration,
        glFeatures,
      },
      propsData: {
        canUpdate,
        progress,
        workItemId: 'gid://gitlab/WorkItem/1',
        workItemType,
      },
      stubs: {
        WorkItemSidebarWidget,
      },
    });
  };

  it.each`
    workItemType   | showPopover  | expected
    ${'Objective'} | ${true}      | ${true}
    ${'Task'}      | ${false}     | ${false}
    ${'Task'}      | ${null}      | ${false}
    ${'Objective'} | ${null}      | ${false}
    ${'Objective'} | ${undefined} | ${false}
  `(
    'displays progress popover as $expected for $workItemType when showPopover is $showPopover',
    ({ workItemType, showPopover, expected }) => {
      createComponent({
        workItemType,
        widgetDefinitions:
          showPopover !== undefined ? [{ type: WIDGET_TYPE_PROGRESS, showPopover }] : [],
      });

      expect(findProgressPopover().exists()).toBe(expected);
    },
  );

  describe('when user cannot update progress', () => {
    beforeEach(() => {
      createComponent({ canUpdate: false });
    });

    it('does not render input', () => {
      expect(findInput().exists()).toBe(false);
    });

    it('renders the progress value', () => {
      expect(wrapper.text()).toContain('0%');
    });

    it('updates displayed progress value when the progress prop changes', async () => {
      expect(wrapper.text()).toContain('0%');

      await wrapper.setProps({ progress: 20 });

      expect(wrapper.text()).toContain('20%');
    });
  });

  describe('when user can update progress', () => {
    describe('when editing', () => {
      beforeEach(async () => {
        createComponent({ canUpdate: true, progress: 10 });
        findEditButton().vm.$emit('click');
        await nextTick();
      });

      it('does not call the mutation and hides the input when the progress value is not changed', async () => {
        findInput().vm.$emit('input', '10');
        findInput().vm.$emit('keydown', new KeyboardEvent('keydown', { key: ENTER_KEY }));
        await nextTick();

        expect(updateWorkItemMutationHandler).not.toHaveBeenCalled();
        expect(findInput().exists()).toBe(false);
      });

      it.each(['-1', '101', 'abc', '--70'])(
        'does not call the mutation and closes the form when the progress value is not valid, e.g %s',
        async (value) => {
          findInput().vm.$emit('input', value);
          findInput().vm.$emit('keydown', new KeyboardEvent('keydown', { key: ENTER_KEY }));
          await nextTick();

          expect(updateWorkItemMutationHandler).not.toHaveBeenCalled();
        },
      );

      it('resets the progress value when pressing Escape key', async () => {
        findInput().vm.$emit('input', '20');
        await nextTick();

        expect(findInput().props('value')).toBe('20');

        findInput().vm.$emit('keydown', new KeyboardEvent('keydown', { key: ESC_KEY }));
        await nextTick();

        expect(wrapper.text()).toContain('10%');
        expect(wrapper.text()).not.toContain('20%');
      });

      describe('when the progress value is valid', () => {
        it('calls the mutation with the correct variables on `Apply` button click', () => {
          findInput().vm.$emit('input', '20');
          findInput().vm.$emit('keydown', new KeyboardEvent('keydown', { key: ENTER_KEY }));

          expect(updateWorkItemMutationHandler).toHaveBeenCalledWith({
            input: {
              id: 'gid://gitlab/WorkItem/1',
              progressWidget: { currentValue: 20 },
            },
            useWorkItemFeatures: false,
          });
        });

        describe('when the workItemFeaturesField feature flag is enabled', () => {
          beforeEach(async () => {
            createComponent({
              canUpdate: true,
              progress: 10,
              glFeatures: { workItemFeaturesField: true },
            });
            findEditButton().vm.$emit('click');
            await nextTick();
          });

          it('passes useWorkItemFeatures as true to the mutation', () => {
            findInput().vm.$emit('input', '20');
            findInput().vm.$emit('keydown', new KeyboardEvent('keydown', { key: ENTER_KEY }));

            expect(updateWorkItemMutationHandler).toHaveBeenCalledWith({
              input: {
                id: 'gid://gitlab/WorkItem/1',
                progressWidget: { currentValue: 20 },
              },
              useWorkItemFeatures: true,
            });
          });
        });

        it('tracks the event', () => {
          const trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);

          findInput().vm.$emit('input', '20');
          findInput().vm.$emit('keydown', new KeyboardEvent('keydown', { key: ENTER_KEY }));

          expect(trackingSpy).toHaveBeenCalledWith(TRACKING_CATEGORY_SHOW, 'updated_progress', {
            category: TRACKING_CATEGORY_SHOW,
            label: 'item_progress',
            property: 'type_Objective',
            extra: { viewContext: 'full_screen' },
          });
        });

        it('closes the form when the mutation is successful', async () => {
          findInput().vm.$emit('input', '20');
          findInput().vm.$emit('keydown', new KeyboardEvent('keydown', { key: ENTER_KEY }));
          await nextTick();

          expect(findInput().exists()).toBe(false);
        });

        describe('when mutation throws an error', () => {
          const error = new Error('GraphQL error');

          beforeEach(() => {
            updateWorkItemMutationHandler.mockRejectedValue(error);
          });

          it('emits an error and tracks it with Sentry', async () => {
            findInput().vm.$emit('input', '20');
            findInput().vm.$emit('keydown', new KeyboardEvent('keydown', { key: ENTER_KEY }));
            await waitForPromises();

            expect(Sentry.captureException).toHaveBeenCalledWith(error);
          });

          it('resets the progress value to the original value', async () => {
            findInput().vm.$emit('input', '20');
            findInput().vm.$emit('keydown', new KeyboardEvent('keydown', { key: ENTER_KEY }));
            await waitForPromises();

            expect(wrapper.text()).toContain('10%');
          });

          it('closes the form', async () => {
            findInput().vm.$emit('input', '20');
            findInput().vm.$emit('keydown', new KeyboardEvent('keydown', { key: ENTER_KEY }));
            await waitForPromises();

            expect(findInput().exists()).toBe(false);
          });
        });
      });
    });
  });
});
