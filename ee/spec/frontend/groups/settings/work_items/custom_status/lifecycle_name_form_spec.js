import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlFormInput, GlFormGroup } from '@gitlab/ui';
import { ENTER_KEY } from '~/lib/utils/keys';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import LifecycleNameForm from 'ee/groups/settings/work_items/custom_status/lifecycle_name_form.vue';
import lifecycleUpdateMutation from 'ee/groups/settings/work_items/custom_status/graphql/lifecycle_update.mutation.graphql';
import { mockLifecycles } from '../mock_data';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');

describe('LifecycleNameForm', () => {
  let wrapper;
  let mockApollo;

  const mockLifecycle = {
    ...mockLifecycles[0],
  };

  const defaultProps = {
    lifecycle: mockLifecycle,
    fullPath: 'test-group',
    cardHover: false,
  };

  const mockUpdateResponse = {
    data: {
      lifecycleUpdate: {
        lifecycle: {
          ...mockLifecycle,
          name: 'New name',
          statuses: [...mockLifecycle.statuses],
          __typename: 'WorkItemLifecycle',
        },
        __typename: 'LifecycleUpdatePayload',
        errors: [],
      },
    },
  };

  const lifecycleId = getIdFromGraphQLId(mockLifecycle.id);

  const updateLifecycleHandler = jest.fn().mockResolvedValue(mockUpdateResponse);

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findFormInput = () => wrapper.findComponent(GlFormInput);
  const findSaveButton = () => wrapper.findComponentByTestId(`rename-${lifecycleId}`);
  const findCancelButton = () => wrapper.findComponentByTestId(`cancel-rename-${lifecycleId}`);
  const findRenameButton = () => wrapper.findComponentByTestId(`trigger-rename-${lifecycleId}`);
  const findLifecycleName = () => wrapper.findByTestId(`name-${lifecycleId}`);

  const createWrapper = ({ props = {}, updateHandler = updateLifecycleHandler } = {}) => {
    mockApollo = createMockApollo([[lifecycleUpdateMutation, updateHandler]]);

    wrapper = shallowMountExtended(LifecycleNameForm, {
      apolloProvider: mockApollo,
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlFormGroup: stubComponent(GlFormGroup, {
          props: ['state', 'invalidFeedback'],
        }),
      },
    });
  };

  describe('default rendering', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('displays lifecycle name when not in editing mode', () => {
      expect(findLifecycleName().text()).toBe(mockLifecycle.name);
    });

    it('has the opacity class on rename button when cardHover is false', () => {
      expect(findRenameButton().classes()).not.toContain('!gl-opacity-10');
    });

    it('does not show editing form initially', () => {
      expect(findFormGroup().exists()).toBe(false);
      expect(findFormInput().exists()).toBe(false);
    });
  });

  describe('when cardHover is true', () => {
    beforeEach(() => {
      createWrapper({ props: { cardHover: true } });
    });

    it('has the opacity class on rename button when cardHover is true', () => {
      expect(findRenameButton().classes()).toContain('!gl-opacity-10');
    });

    it('shows rename button and enters editing mode when button is clicked', async () => {
      expect(findRenameButton().exists()).toBe(true);
      expect(findFormGroup().exists()).toBe(false);
      expect(findFormInput().exists()).toBe(false);

      await findRenameButton().vm.$emit('click');

      expect(findFormGroup().exists()).toBe(true);
      expect(findFormInput().exists()).toBe(true);
    });
  });

  describe('editing mode', () => {
    beforeEach(async () => {
      createWrapper({ props: { cardHover: true } });
      await findRenameButton().vm.$emit('click');
    });

    it('displays form input with current lifecycle name', () => {
      expect(findFormInput().props('value')).toBe(mockLifecycle.name);
    });

    it('displays save and cancel buttons', () => {
      expect(findSaveButton().exists()).toBe(true);
      expect(findCancelButton().exists()).toBe(true);
    });

    describe('form validation', () => {
      it('shows error state when form has validation errors', async () => {
        await findFormInput().vm.$emit('input', '     ');
        await findSaveButton().vm.$emit('click');
        await nextTick();

        expect(findFormGroup().props('invalidFeedback')).toBe('Lifecycle name cannot be empty');
      });

      it('shows valid state when no validation errors', () => {
        expect(findFormGroup().props('state')).toBe(true);
        expect(findFormInput().props('state')).toBe(true);
      });
    });

    it('allows input via keyboard enter', async () => {
      const newName = 'New Name';

      await findFormInput().vm.$emit('input', newName);
      findFormInput().vm.$emit('keydown', new KeyboardEvent('keydown', { key: ENTER_KEY }));
      await nextTick();

      expect(updateLifecycleHandler).toHaveBeenCalled();
    });
  });

  describe('form actions', () => {
    beforeEach(async () => {
      createWrapper({ props: { cardHover: true } });
      await findRenameButton().vm.$emit('click');
    });

    describe('cancel action', () => {
      it('closes form and resets data when cancel is clicked', async () => {
        await findFormInput().vm.$emit('input', 'Changed name');

        await findCancelButton().vm.$emit('click');

        expect(findLifecycleName().text()).toBe(mockLifecycle.name);
      });
    });

    describe('save action', () => {
      it('closes form when name is same as current', async () => {
        // Input already has the current name, just click save
        await findSaveButton().vm.$emit('click');

        expect(findLifecycleName().text()).toBe(mockLifecycle.name);
      });

      it('disables save button when mutation in progress', async () => {
        await findFormInput().vm.$emit('input', 'Changed name');

        expect(findSaveButton().props('disabled')).toBe(false);
        findSaveButton().vm.$emit('click');

        await nextTick();

        expect(findSaveButton().props('disabled')).toBe(true);
        await waitForPromises();

        expect(updateLifecycleHandler).toHaveBeenCalled();
      });

      it('handles mutation errors from response', async () => {
        const errorMessage = 'Lifecycle name already exists';
        const mockErrorUpdateResponse = {
          data: {
            lifecycleUpdate: {
              lifecycle: null,
              errors: [errorMessage],
              __typename: 'LifecycleUpdatePayload',
            },
          },
        };

        const errorUpdateLifecycleHandler = jest.fn().mockResolvedValue(mockErrorUpdateResponse);

        createWrapper({ props: { cardHover: true }, updateHandler: errorUpdateLifecycleHandler });
        await findRenameButton().vm.$emit('click');

        await findFormInput().vm.$emit('input', 'Throw error from backend');
        findSaveButton().vm.$emit('click');
        await waitForPromises();

        expect(findFormGroup().props('invalidFeedback')).toBe(errorMessage);
        expect(findFormGroup().props('state')).toBe(false);
      });
    });
  });
});
