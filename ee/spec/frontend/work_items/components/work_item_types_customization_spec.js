import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlButton, GlIcon, GlLoadingIcon, GlModal } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import WorkItemTypesCustomization from 'ee/work_items/components/work_item_types_customization.vue';
import namespaceWorkItemSettingsQuery from 'ee/work_items/graphql/namespace_work_item_settings.query.graphql';
import orgWorkItemSettingsQuery from 'ee/work_items/graphql/organization_work_item_settings.query.graphql';
import updateWorkItemSettingsMutation from 'ee/work_items/graphql/update_work_item_settings.mutation.graphql';

Vue.use(VueApollo);
jest.mock('~/sentry/sentry_browser_wrapper');

describe('WorkItemTypesCustomization component', () => {
  let wrapper;
  let apolloProvider;

  const fullPath = 'test-group';

  const mockWorkItemSettings = (customizableTypeVisibility = false) => ({
    __typename: 'WorkItemSettings',
    customizableTypeVisibility,
  });

  const mockNamespaceQueryHandler = (customizableTypeVisibility = false) =>
    jest.fn().mockResolvedValue({
      data: {
        namespace: {
          __typename: 'Namespace',
          id: 'gid://gitlab/Group/1',
          workItemSettings: mockWorkItemSettings(customizableTypeVisibility),
        },
      },
    });

  const mockOrgQueryHandler = (customizableTypeVisibility = false) =>
    jest.fn().mockResolvedValue({
      data: {
        organization: {
          __typename: 'Organization',
          id: 'gid://gitlab/Organization/1',
          workItemSettings: mockWorkItemSettings(customizableTypeVisibility),
        },
      },
    });

  const mockUpdateSettingsHandler = (customizableTypeVisibility = true) =>
    jest.fn().mockResolvedValue({
      data: {
        workItemSettingsUpdate: {
          __typename: 'WorkItemSettingsUpdatePayload',
          workItemSettings: mockWorkItemSettings(customizableTypeVisibility),
          errors: [],
        },
      },
    });

  const createComponent = ({
    props = {},
    namespaceQueryHandler = mockNamespaceQueryHandler(),
    orgQueryHandler = mockOrgQueryHandler(),
    updateSettingsHandler = mockUpdateSettingsHandler(),
  } = {}) => {
    apolloProvider = createMockApollo([
      [namespaceWorkItemSettingsQuery, namespaceQueryHandler],
      [orgWorkItemSettingsQuery, orgQueryHandler],
      [updateWorkItemSettingsMutation, updateSettingsHandler],
    ]);

    wrapper = shallowMountExtended(WorkItemTypesCustomization, {
      apolloProvider,
      propsData: { fullPath, ...props },
    });
  };

  const findButton = () => wrapper.findComponent(GlButton);
  const findIcon = () => wrapper.findComponent(GlIcon);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findModal = () => wrapper.findComponent(GlModal);
  const findStatusBlock = () => wrapper.findByTestId('status-block');
  const findAlert = () =>
    wrapper.findComponentByTestId('work-item-types-customization-error-alert');

  describe('while loading', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows a loading icon in place of the status icon', () => {
      expect(findLoadingIcon().exists()).toBe(true);
      expect(findIcon().exists()).toBe(false);
    });

    it('disables the button', () => {
      expect(findButton().props('disabled')).toBe(true);
    });
  });

  describe('after query resolves', () => {
    describe('when customizableTypeVisibility is false', () => {
      beforeEach(async () => {
        createComponent({ namespaceQueryHandler: mockNamespaceQueryHandler(false) });
        await waitForPromises();
      });

      it('renders the heading and description', () => {
        expect(wrapper.find('h3').text()).toBe('Type customization in projects');
        expect(wrapper.text()).toContain('Allow types to be disabled in projects.');
      });

      it('shows disabled state', () => {
        expect(findLoadingIcon().exists()).toBe(false);
        expect(findIcon().props('name')).toBe('cancel');
        expect(findStatusBlock().text()).toContain('Disabled');
        expect(findButton().text()).toBe('Enable');
      });
    });

    describe('when customizableTypeVisibility is true', () => {
      beforeEach(async () => {
        createComponent({ namespaceQueryHandler: mockNamespaceQueryHandler(true) });
        await waitForPromises();
      });

      it('shows enabled state', () => {
        expect(findLoadingIcon().exists()).toBe(false);
        expect(findIcon().props('name')).toBe('check');
        expect(findStatusBlock().text()).toContain('Enabled');
        expect(findStatusBlock().classes()).toContain('gl-text-success');
        expect(findButton().text()).toBe('Disable');
      });
    });
  });

  describe('enabling type customization', () => {
    let updateSettingsHandler;

    beforeEach(async () => {
      updateSettingsHandler = mockUpdateSettingsHandler(true);
      createComponent({
        namespaceQueryHandler: mockNamespaceQueryHandler(false),
        updateSettingsHandler,
      });
      await waitForPromises();
    });

    it('calls the mutation with customizableTypeVisibility: true on Enable click', async () => {
      findButton().vm.$emit('click');
      await waitForPromises();

      expect(updateSettingsHandler).toHaveBeenCalledWith({
        input: { fullPath, customizableTypeVisibility: true },
      });
    });

    it('updates to enabled state after successful mutation', async () => {
      findButton().vm.$emit('click');
      await waitForPromises();

      expect(findIcon().props('name')).toBe('check');
      expect(findStatusBlock().text()).toContain('Enabled');
      expect(findButton().text()).toBe('Disable');
    });

    it('updates the namespace settings cache so that we see it in real time', async () => {
      findButton().vm.$emit('click');
      await waitForPromises();

      const cached = apolloProvider.defaultClient.cache.readQuery({
        query: namespaceWorkItemSettingsQuery,
        variables: { fullPath },
      });

      expect(cached.namespace.workItemSettings.customizableTypeVisibility).toBe(true);
    });
  });

  describe('disabling type customization', () => {
    let updateSettingsHandler;

    beforeEach(async () => {
      updateSettingsHandler = mockUpdateSettingsHandler(false);
      createComponent({
        namespaceQueryHandler: mockNamespaceQueryHandler(true),
        updateSettingsHandler,
      });
      await waitForPromises();
    });

    it('opens the confirmation modal on Disable click without calling mutation', async () => {
      findButton().vm.$emit('click');
      await nextTick();

      expect(findModal().props('title')).toBe('Disable type customization in projects');
      expect(updateSettingsHandler).not.toHaveBeenCalled();
    });

    it('calls the mutation with customizableTypeVisibility: false when modal is confirmed', async () => {
      findButton().vm.$emit('click');
      await nextTick();
      findModal().vm.$emit('primary');
      await waitForPromises();

      expect(updateSettingsHandler).toHaveBeenCalledWith({
        input: { fullPath, customizableTypeVisibility: false },
      });
    });

    it('updates to disabled state after confirming the modal', async () => {
      findButton().vm.$emit('click');
      await nextTick();
      findModal().vm.$emit('primary');
      await waitForPromises();

      expect(findIcon().props('name')).toBe('cancel');
      expect(findStatusBlock().text()).toContain('Disabled');
      expect(findButton().text()).toBe('Enable');
    });

    it('updates the namespace settings cache so that we it in real time', async () => {
      findButton().vm.$emit('click');
      await nextTick();
      findModal().vm.$emit('primary');
      await waitForPromises();

      const cached = apolloProvider.defaultClient.cache.readQuery({
        query: namespaceWorkItemSettingsQuery,
        variables: { fullPath },
      });

      expect(cached.namespace.workItemSettings.customizableTypeVisibility).toBe(false);
    });
  });

  describe('error handling', () => {
    it('captures exception to Sentry when the query fails', async () => {
      const error = new Error('Query failed');
      createComponent({
        namespaceQueryHandler: jest.fn().mockRejectedValue(error),
      });
      await waitForPromises();

      expect(Sentry.captureException).toHaveBeenCalledWith(error);
    });

    it('captures exception to Sentry when the mutation fails', async () => {
      const error = new Error('Mutation failed');
      createComponent({
        namespaceQueryHandler: mockNamespaceQueryHandler(false),
        updateSettingsHandler: jest.fn().mockRejectedValue(error),
      });
      await waitForPromises();

      findButton().vm.$emit('click');
      await waitForPromises();

      expect(Sentry.captureException).toHaveBeenCalledWith(error);
    });

    it('shows error alert when mutation fails', async () => {
      const error = new Error('Mutation failed');
      createComponent({
        namespaceQueryHandler: mockNamespaceQueryHandler(false),
        updateSettingsHandler: jest.fn().mockRejectedValue(error),
      });
      await waitForPromises();

      expect(findAlert().exists()).toBe(false);

      findButton().vm.$emit('click');
      await waitForPromises();

      expect(findAlert().exists()).toBe(true);
      expect(findAlert().props('variant')).toBe('danger');
      expect(findAlert().text()).toBe('Mutation failed');
    });

    it('shows error alert when mutation returns errors array', async () => {
      const errorMessage = 'Update failed';
      createComponent({
        namespaceQueryHandler: mockNamespaceQueryHandler(false),
        updateSettingsHandler: jest.fn().mockResolvedValue({
          data: {
            workItemSettingsUpdate: {
              __typename: 'WorkItemSettingsUpdatePayload',
              workItemSettings: null,
              errors: [errorMessage],
            },
          },
        }),
      });
      await waitForPromises();

      findButton().vm.$emit('click');
      await waitForPromises();

      expect(findAlert().exists()).toBe(true);
      expect(findAlert().text()).toBe(errorMessage);
    });

    it('dismisses error alert when dismiss button is clicked', async () => {
      const error = new Error('Mutation failed');
      createComponent({
        namespaceQueryHandler: mockNamespaceQueryHandler(false),
        updateSettingsHandler: jest.fn().mockRejectedValue(error),
      });
      await waitForPromises();

      findButton().vm.$emit('click');
      await waitForPromises();

      expect(findAlert().exists()).toBe(true);

      findAlert().vm.$emit('dismiss');
      await nextTick();

      expect(findAlert().exists()).toBe(false);
    });
  });

  describe('when fullPath is not provided', () => {
    it('calls the organization query', async () => {
      const orgQueryHandler = mockOrgQueryHandler();
      createComponent({ props: { fullPath: '' }, orgQueryHandler });
      await waitForPromises();

      expect(orgQueryHandler).toHaveBeenCalled();
    });

    it('defaults to disabled state', () => {
      createComponent({ props: { fullPath: '' } });

      expect(findButton().text()).toBe('Enable');
    });

    it('updates the organization settings cache after a successful mutation', async () => {
      createComponent({
        props: { fullPath: '' },
        orgQueryHandler: mockOrgQueryHandler(false),
        updateSettingsHandler: mockUpdateSettingsHandler(true),
      });
      await waitForPromises();

      findButton().vm.$emit('click');
      await waitForPromises();

      const cached = apolloProvider.defaultClient.cache.readQuery({
        query: orgWorkItemSettingsQuery,
      });

      expect(cached.organization.workItemSettings.customizableTypeVisibility).toBe(true);
    });
  });
});
