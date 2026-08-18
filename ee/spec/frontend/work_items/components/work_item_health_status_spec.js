import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import WorkItemHealthStatus from 'ee/work_items/components/work_item_health_status.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mockTracking } from 'helpers/tracking_helper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import WorkItemSidebarDropdownWidget from '~/work_items/components/shared/work_item_sidebar_dropdown_widget.vue';
import updateWorkItemMutation from '~/work_items/graphql/update_work_item.mutation.graphql';
import workItemByIidQuery from '~/work_items/graphql/work_item_by_iid.query.graphql';
import { TRACKING_CATEGORY_SHOW } from '~/work_items/constants';
import {
  HEALTH_STATUS_AT_RISK,
  HEALTH_STATUS_I18N_NONE,
  HEALTH_STATUS_NEEDS_ATTENTION,
  HEALTH_STATUS_ON_TRACK,
  healthStatusTextMap,
} from 'ee/sidebar/constants';

import {
  createWorkItemQueryResponseWithFeatures,
  updateWorkItemMutationResponse,
  workItemByIidResponseFactory,
} from '../mock_data';

describe('WorkItemHealthStatus component', () => {
  Vue.use(VueApollo);

  let wrapper;

  const workItemId = 'gid://gitlab/WorkItem/1';
  const workItemType = 'Task';

  const findSidebarDropdownWidget = () => wrapper.findComponent(WorkItemSidebarDropdownWidget);

  const showDropdown = () => {
    findSidebarDropdownWidget().vm.$emit('dropdown-shown');
  };

  const createComponent = async ({
    canUpdate = true,
    healthStatus,
    mutationHandler = jest.fn().mockResolvedValue(updateWorkItemMutationResponse),
    glFeatures = {},
    workItemQueryResponse = workItemByIidResponseFactory({
      canUpdate,
      canDelete: true,
      healthStatus,
    }),
  } = {}) => {
    const workItemQueryHandler = jest.fn().mockResolvedValue(workItemQueryResponse);

    wrapper = mountExtended(WorkItemHealthStatus, {
      apolloProvider: createMockApollo([
        [workItemByIidQuery, workItemQueryHandler],
        [updateWorkItemMutation, mutationHandler],
      ]),
      provide: {
        glFeatures,
      },
      propsData: {
        workItemId,
        workItemIid: '1',
        workItemType,
        fullPath: 'gitlab-org/gitlab',
        isWorkItemClosed: false,
      },
    });

    await waitForPromises();
  };

  it('has "Health status" label for single select', () => {
    createComponent();

    expect(findSidebarDropdownWidget().props('dropdownLabel')).toBe('Health status');
  });

  it('the dropdown is not searchable', () => {
    createComponent();

    expect(findSidebarDropdownWidget().props('searchable')).toBe(false);
  });

  describe('Dropdown options', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows the health status options in dropdown', async () => {
      showDropdown();

      await nextTick();

      expect(findSidebarDropdownWidget().props('loading')).toBe(false);
      expect(findSidebarDropdownWidget().props('listItems')).toHaveLength(3);
    });
  });

  describe('health status input', () => {
    it.each`
      selected            | expectedStatus
      ${'onTrack'}        | ${'onTrack'}
      ${'needsAttention'} | ${'needsAttention'}
      ${'atRisk'}         | ${'atRisk'}
    `(
      'calls mutation with health status = "$expectedStatus"',
      async ({ selected, expectedStatus }) => {
        const mutationSpy = jest.fn().mockResolvedValue(updateWorkItemMutationResponse);
        await createComponent({
          mutationHandler: mutationSpy,
        });

        showDropdown();
        await findSidebarDropdownWidget().vm.$emit('update-value', selected);

        expect(mutationSpy).toHaveBeenCalledWith({
          input: {
            id: workItemId,
            healthStatusWidget: {
              healthStatus: expectedStatus,
            },
          },
          useWorkItemFeatures: false,
        });
      },
    );

    describe('when workItemFeaturesField feature flag is enabled', () => {
      let mutationSpy;

      beforeEach(async () => {
        mutationSpy = jest.fn().mockResolvedValue(updateWorkItemMutationResponse);
        await createComponent({
          mutationHandler: mutationSpy,
          glFeatures: { workItemFeaturesField: true },
          workItemQueryResponse: createWorkItemQueryResponseWithFeatures(),
        });
      });

      it('passes useWorkItemFeatures as true to the mutation', async () => {
        showDropdown();
        findSidebarDropdownWidget().vm.$emit('update-value', HEALTH_STATUS_ON_TRACK);
        await waitForPromises();

        expect(mutationSpy).toHaveBeenCalledWith({
          input: {
            id: workItemId,
            healthStatusWidget: {
              healthStatus: HEALTH_STATUS_ON_TRACK,
            },
          },
          useWorkItemFeatures: true,
        });
      });
    });

    it('changes the health status to null when clicked on Clear', async () => {
      const mutationSpy = jest.fn().mockResolvedValue(updateWorkItemMutationResponse);
      await createComponent({ healthStatus: HEALTH_STATUS_ON_TRACK, mutationHandler: mutationSpy });
      showDropdown();
      await nextTick();

      findSidebarDropdownWidget().vm.$emit('update-value', null);

      await nextTick();

      expect(findSidebarDropdownWidget().props('updateInProgress')).toBe(true);

      await waitForPromises();
      expect(findSidebarDropdownWidget().props('updateInProgress')).toBe(false);
      expect(mutationSpy).toHaveBeenCalledWith({
        input: {
          id: workItemId,
          healthStatusWidget: {
            healthStatus: null,
          },
        },
        useWorkItemFeatures: false,
      });
    });

    it('emits an error when there is a GraphQL error', async () => {
      const response = {
        data: {
          workItemUpdate: {
            errors: ['Error!'],
            workItem: {},
          },
        },
      };
      await createComponent({
        mutationHandler: jest.fn().mockResolvedValue(response),
      });

      showDropdown();

      await findSidebarDropdownWidget().vm.$emit('update-value', HEALTH_STATUS_ON_TRACK);
      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        ['Something went wrong while updating the Task. Please try again.'],
      ]);
    });

    it('emits an error when there is a network error', async () => {
      await createComponent({
        mutationHandler: jest.fn().mockRejectedValue(new Error()),
      });

      showDropdown();
      await findSidebarDropdownWidget().vm.$emit('update-value', HEALTH_STATUS_ON_TRACK);
      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        ['Something went wrong while updating the Task. Please try again.'],
      ]);
    });

    it('tracks updating the health status', async () => {
      const trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      await createComponent({ isEditing: true });

      showDropdown();
      await findSidebarDropdownWidget().vm.$emit('update-value', HEALTH_STATUS_ON_TRACK);

      expect(trackingSpy).toHaveBeenCalledWith(TRACKING_CATEGORY_SHOW, 'updated_health_status', {
        category: TRACKING_CATEGORY_SHOW,
        label: 'item_health_status',
        property: 'type_Task',
        extra: { viewContext: 'full_screen' },
      });
    });
  });
  describe('health status rendered text', () => {
    it.each`
      healthStatus                     | text
      ${HEALTH_STATUS_ON_TRACK}        | ${healthStatusTextMap[HEALTH_STATUS_ON_TRACK]}
      ${HEALTH_STATUS_NEEDS_ATTENTION} | ${healthStatusTextMap[HEALTH_STATUS_NEEDS_ATTENTION]}
      ${HEALTH_STATUS_AT_RISK}         | ${healthStatusTextMap[HEALTH_STATUS_AT_RISK]}
      ${null}                          | ${HEALTH_STATUS_I18N_NONE}
    `('renders "$text" when health status = "$healthStatus"', async ({ healthStatus, text }) => {
      await createComponent({ healthStatus });

      expect(wrapper.text()).toContain(text);
    });
  });
});
