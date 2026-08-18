import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlFormRadio, GlFormRadioGroup, GlButton, GlLoadingIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import SelectLifecycle from 'ee/groups/settings/work_items/custom_status/change_lifecycle/select_lifecycle.vue';
import LifecycleDetail from 'ee/groups/settings/work_items/custom_status/lifecycle_detail.vue';
import CreateLifecycleModal from 'ee/groups/settings/work_items/custom_status/create_lifecycle_modal.vue';
import namespaceLifecyclesQuery from 'ee/groups/settings/work_items/custom_status/graphql/namespace_lifecycles.query.graphql';
import { mockLifecycles } from '../../mock_data';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');

describe('SelectLifecycle', () => {
  let wrapper;
  let mockApollo;

  const defaultProps = {
    workItemType: 'Issue',
    fullPath: 'test-group',
  };

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findCurrentLifecycleContainer = () => wrapper.findByTestId('current-lifecycle-container');
  const findExistingLifecyclesContainer = () =>
    wrapper.findByTestId('existing-lifecycles-container');
  const findFormRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);
  const findLifecycleDetails = () => wrapper.findAllComponents(LifecycleDetail);
  const findCreateButton = () => wrapper.findComponent(GlButton);
  const findCreateLifecycleModal = () => wrapper.findComponent(CreateLifecycleModal);

  const lifecyclesQueryResponse = () => ({
    data: {
      namespace: {
        id: 'gid://gitlab/Group/1',
        lifecycles: {
          nodes: [
            {
              ...mockLifecycles[0],
              workItemTypes: [
                {
                  id: 'gid://gitlab/WorkItems::Type/1',
                  name: 'Issue',
                  iconName: 'work-item-issue',
                  __typename: 'WorkItemType',
                },
              ],
            },
            {
              ...mockLifecycles[1],
              workItemTypes: [
                {
                  id: 'gid://gitlab/WorkItems::Type/2',
                  name: 'Task',
                  iconName: 'work-item-task',
                  __typename: 'WorkItemType',
                },
              ],
            },
            {
              ...mockLifecycles[2],
            },
          ],
        },
      },
    },
  });

  const namespacesQueryHandler = jest.fn().mockResolvedValue(lifecyclesQueryResponse());

  const createWrapper = (props = {}, queryHandler = namespacesQueryHandler) => {
    mockApollo = createMockApollo([[namespaceLifecyclesQuery, queryHandler]]);

    wrapper = shallowMountExtended(SelectLifecycle, {
      propsData: { ...defaultProps, ...props },
      apolloProvider: mockApollo,
      stubs: {
        LifecycleDetail,
        GlFormRadio,
        GlFormRadioGroup,
        GlButton,
        GlLoadingIcon,
        CreateLifecycleModal,
      },
    });
  };

  describe('Default', () => {
    beforeEach(async () => {
      createWrapper();
      await waitForPromises();
    });

    it('renders current lifecycle container', () => {
      expect(findCurrentLifecycleContainer().exists()).toBe(true);
      expect(findCurrentLifecycleContainer().text()).toContain('Current lifecycle');
    });

    it('renders existing lifecycles container', () => {
      expect(findExistingLifecyclesContainer().exists()).toBe(true);
      expect(findExistingLifecyclesContainer().text()).toContain('Select new lifecycle');
    });

    it('renders create lifecycle button with correct properties', () => {
      expect(findCreateButton().exists()).toBe(true);
      expect(findCreateButton().props()).toMatchObject({
        category: 'tertiary',
        icon: 'plus',
      });
      expect(findCreateButton().text()).toBe('Create lifecycle');
    });

    it('renders create lifecycle modal with correct props', () => {
      expect(findCreateLifecycleModal().exists()).toBe(true);
      expect(findCreateLifecycleModal().props()).toMatchObject({
        visible: false,
        fullPath: 'test-group',
      });
    });
  });

  describe('Loading State', () => {
    it('shows loading icon when lifecycles are loading', () => {
      createWrapper();

      expect(findLoadingIcon().exists()).toBe(true);
      expect(findLoadingIcon().props()).toMatchObject({
        size: 'lg',
      });
      expect(findCurrentLifecycleContainer().exists()).toBe(false);
    });

    it('hides content when loading', () => {
      createWrapper();

      expect(findCurrentLifecycleContainer().exists()).toBe(false);
      expect(findExistingLifecyclesContainer().exists()).toBe(false);
      expect(findCreateButton().exists()).toBe(false);
    });
  });

  describe('Current Lifecycle', () => {
    beforeEach(async () => {
      createWrapper();
      await waitForPromises();
    });

    it('renders current lifecycle detail component with correct props', () => {
      const currentLifecycleDetail = findLifecycleDetails().at(0);

      expect(currentLifecycleDetail.exists()).toBe(true);
      expect(currentLifecycleDetail.props()).toMatchObject({
        lifecycle: {
          ...mockLifecycles[0],
          workItemTypes: [
            {
              id: 'gid://gitlab/WorkItems::Type/1',
              name: 'Issue',
              iconName: 'work-item-issue',
              __typename: 'WorkItemType',
            },
          ],
        }, // Current lifecycle for 'Issue' work item type
        fullPath: 'test-group',
        showUsageSection: false,
        showNotInUseSection: false,
        showChangeLifecycleButton: false,
        showRenameButton: false,
      });
    });
  });

  describe('Alternative Lifecycles', () => {
    beforeEach(async () => {
      createWrapper();
      await waitForPromises();
    });

    it('renders form radio group when filtered lifecycles exist', () => {
      expect(findFormRadioGroup().exists()).toBe(true);
    });

    it('renders lifecycle details for non-current lifecycles', () => {
      const filteredLifecycleDetails = findLifecycleDetails().wrappers.slice(1); // Skip current lifecycle

      expect(filteredLifecycleDetails).toHaveLength(3); // Alternative and Unused lifecycles
    });
  });

  describe('Create Lifecycle Modal', () => {
    beforeEach(async () => {
      createWrapper();
      await waitForPromises();
    });

    it('opens modal when create button is clicked', async () => {
      await findCreateButton().vm.$emit('click');

      expect(findCreateLifecycleModal().props('visible')).toBe(true);
    });
  });
});
