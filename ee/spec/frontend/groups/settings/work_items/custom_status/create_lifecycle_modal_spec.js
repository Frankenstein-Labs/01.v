import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import {
  GlModal,
  GlForm,
  GlSearchBoxByType,
  GlFormRadioGroup,
  GlLoadingIcon,
  GlFormGroup,
} from '@gitlab/ui';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { stubComponent } from 'helpers/stub_component';
import CreateLifecycle from 'ee/groups/settings/work_items/custom_status/create_lifecycle_modal.vue';
import LifecycleDetail from 'ee/groups/settings/work_items/custom_status/lifecycle_detail.vue';
import namespaceStatusesQuery from 'ee/groups/settings/work_items/custom_status/graphql/namespace_lifecycles.query.graphql';
import namespaceDefaultLifecycleTemplatesQuery from 'ee/groups/settings/work_items/custom_status/graphql/namespace_default_lifecycle_template.query.graphql';
import createLifecycleMutation from 'ee/groups/settings/work_items/custom_status/graphql/create_lifecycle.mutation.graphql';
import ScrollScrim from '~/super_sidebar/components/scroll_scrim.vue';
import {
  mockLifecycles,
  mockDefaultLifecycle,
  mockCreateLifecycleResponse,
  mockDefaultLifecycleTemplateReponse,
} from '../mock_data';

Vue.use(VueApollo);

// Mock Sentry
jest.mock('~/sentry/sentry_browser_wrapper', () => ({
  captureException: jest.fn(),
}));

const mockNamespaceStatusesResponse = {
  data: {
    namespace: {
      __typename: 'Namespace',
      id: 'gid://gitlab/Group/1',
      lifecycles: {
        nodes: mockLifecycles,
      },
    },
  },
};

describe('CreateLifecycleModal', () => {
  let wrapper;
  let mockApollo;

  const namespacesQueryHandler = jest.fn().mockResolvedValue(mockNamespaceStatusesResponse);
  const defaultLifecycleTemplateQueryHandler = jest
    .fn()
    .mockResolvedValue(mockDefaultLifecycleTemplateReponse);
  const successUpdateLifecycleMutationHandler = jest
    .fn()
    .mockResolvedValue(mockCreateLifecycleResponse);

  const createComponent = ({
    mountFn = shallowMountExtended,
    props = {},
    namespacesHandler = namespacesQueryHandler,
    createLifecycleHandler = successUpdateLifecycleMutationHandler,
  } = {}) => {
    mockApollo = createMockApollo([
      [namespaceStatusesQuery, namespacesHandler],
      [namespaceDefaultLifecycleTemplatesQuery, defaultLifecycleTemplateQueryHandler],
      [createLifecycleMutation, createLifecycleHandler],
    ]);

    wrapper = mountFn(CreateLifecycle, {
      apolloProvider: mockApollo,
      propsData: {
        visible: true,
        fullPath: 'test/project',
        ...props,
      },
      stubs: {
        GlModal: stubComponent(GlModal, {
          template:
            '<div><slot name="modal-title"></slot><slot></slot><slot name="modal-footer"></slot></div>',
        }),
        GlFormGroup: stubComponent(GlFormGroup, {
          props: ['state', 'invalidFeedback'],
        }),
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findForm = () => wrapper.findComponent(GlForm);
  const findNameInput = () => wrapper.findComponentByTestId('new-lifecycle-name-field');
  const findSearchBox = () => wrapper.findComponent(GlSearchBoxByType);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);
  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findLifecycleDetails = () => wrapper.findAllComponents(LifecycleDetail);
  const findDefaultLifecycleDetail = () => wrapper.findAllComponents(LifecycleDetail).at(0);
  const findCreateLifecycleButton = () => wrapper.findComponentByTestId('create-lifecycle');

  describe('when component is mounted', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders the modal with correct props', () => {
      expect(findModal().exists()).toBe(true);
      expect(findModal().props()).toMatchObject({
        title: 'Create lifecycle',
        modalId: 'create-lifecycle-modal',
      });
    });

    it('renders the form elements', () => {
      expect(findForm().exists()).toBe(true);
      expect(findNameInput().exists()).toBe(true);
      expect(findRadioGroup().exists()).toBe(true);
      expect(findSearchBox().exists()).toBe(true);
    });

    it('renders the lifecycle name input field', () => {
      expect(findNameInput().exists()).toBe(true);
      expect(findNameInput().attributes('id')).toBe('new-lifecycle-name');
    });
  });

  describe('loading states', () => {
    it('shows loading icon while queries are loading', () => {
      createComponent();

      expect(findLoadingIcon().exists()).toBe(true);
      expect(findRadioGroup().exists()).toBe(false);
    });

    it('hides loading icon when queries are loaded', async () => {
      createComponent();
      await waitForPromises();

      expect(findLoadingIcon().exists()).toBe(false);
      expect(findRadioGroup().exists()).toBe(true);
    });
  });

  describe('Queries and mutations', () => {
    it('calls namespace lifecycles query with correct variables', async () => {
      createComponent();
      await waitForPromises();

      expect(namespacesQueryHandler).toHaveBeenCalledWith({
        fullPath: 'test/project',
      });
    });

    it('skips queries when not visible', () => {
      createComponent({ props: { visible: false } });

      // Since Apollo queries have skip condition, handlers won't be called
      expect(namespacesQueryHandler).not.toHaveBeenCalled();
      expect(defaultLifecycleTemplateQueryHandler).not.toHaveBeenCalled();
    });

    it('emits `lifecycle-created` event on successful creation of a lifecycle', async () => {
      createComponent({ mountFn: mountExtended });
      await waitForPromises();

      await findNameInput().vm.$emit('input', 'New lifecycle name');
      await nextTick();

      await findCreateLifecycleButton().vm.$emit('click');
      await waitForPromises();

      expect(successUpdateLifecycleMutationHandler).toHaveBeenCalled();
      expect(wrapper.emitted('lifecycle-created')[0][0]).toStrictEqual(
        mockCreateLifecycleResponse.data.lifecycleCreate.lifecycle.id,
      );
    });
  });

  describe('lifecycle selection', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders default lifecycle option', () => {
      const defaultDetail = findDefaultLifecycleDetail();

      expect(defaultDetail.exists()).toBe(true);
      expect(defaultDetail.props()).toMatchObject({
        lifecycle: mockDefaultLifecycle,
        isLifecycleTemplate: true,
        showRadioSelection: true,
      });
    });

    it('renders all lifecycle options', () => {
      const lifecycleDetails = findLifecycleDetails();

      // +1 for default lifecycle
      expect(lifecycleDetails).toHaveLength(mockLifecycles.length + 1);
    });

    it('applies selected border style to selected lifecycle', () => {
      const defaultDetail = findDefaultLifecycleDetail();

      expect(defaultDetail.classes()).toContain('gl-border-blue-500');
    });

    it('usage section props for default lifecycle details', () => {
      const defaultLifecycleDetail = findLifecycleDetails().at(0);

      expect(defaultLifecycleDetail.props()).toMatchObject({
        showUsageSection: false,
        showNotInUseSection: false,
      });
    });

    it('usage section props for existing lifecycle', () => {
      const existingLifecycleDetail = findLifecycleDetails().at(1);

      expect(existingLifecycleDetail.props()).toMatchObject({
        showUsageSection: false,
        showNotInUseSection: true,
        showRemoveLifecycleButton: false,
      });
    });

    it('is able to select any other existing lifecycle other than default lifecycle and apply border', async () => {
      findRadioGroup().vm.$emit('input', mockLifecycles[0].id);

      await nextTick();

      const firstExistingLifecycle = findLifecycleDetails().at(1);

      expect(firstExistingLifecycle.classes()).toContain('gl-border-blue-500');
    });

    it('has scroll scrim wrapper', () => {
      expect(wrapper.findComponent(ScrollScrim).findComponent(LifecycleDetail).exists()).toBe(true);
    });
  });

  describe('creating lifecycle', () => {
    describe('name validation', () => {
      beforeEach(async () => {
        createComponent({ mountFn: mountExtended });
        await waitForPromises();
      });

      it('shows validation error when name is empty and form is submitted', async () => {
        await findCreateLifecycleButton().vm.$emit('click');
        await nextTick();

        expect(findFormGroup().props('invalidFeedback')).toBe(
          'Please provide a name for the lifecycle.',
        );
        expect(findFormGroup().props('state')).toBe(false);

        expect(findNameInput().props('state')).toBe(false);
      });

      it('shows validation error when name is empty', async () => {
        await findNameInput().vm.$emit('focus');
        await findCreateLifecycleButton().vm.$emit('click');
        await nextTick();

        expect(findFormGroup().props('invalidFeedback')).toBe(
          'Please provide a name for the lifecycle.',
        );
        expect(findFormGroup().props('state')).toBe(false);
      });

      it('does not submit form when validation fails', async () => {
        await findCreateLifecycleButton().vm.$emit('click');
        await waitForPromises();

        expect(successUpdateLifecycleMutationHandler).not.toHaveBeenCalled();
      });
    });

    describe('create lifecycle', () => {
      it('emits `lifecycle-created` event on successful creation of a lifecycle', async () => {
        createComponent({ mountFn: mountExtended });
        await waitForPromises();

        await findNameInput().vm.$emit('input', 'New lifecycle name');
        await nextTick();

        await findCreateLifecycleButton().vm.$emit('click');
        await waitForPromises();

        expect(successUpdateLifecycleMutationHandler).toHaveBeenCalled();
        expect(wrapper.emitted('lifecycle-created')[0][0]).toStrictEqual(
          mockCreateLifecycleResponse.data.lifecycleCreate.lifecycle.id,
        );
      });

      it('disables create button while submitting', async () => {
        createComponent({ mountFn: mountExtended });
        await waitForPromises();

        await findNameInput().vm.$emit('input', 'New lifecycle name');
        await nextTick();

        await findCreateLifecycleButton().vm.$emit('click');

        expect(findCreateLifecycleButton().props('disabled')).toBe(true);
      });
    });
  });
});
