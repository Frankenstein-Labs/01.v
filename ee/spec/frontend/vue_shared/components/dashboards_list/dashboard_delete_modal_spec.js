import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlModal, GlAlert } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { RENDER_ALL_SLOTS_TEMPLATE, stubComponent } from 'helpers/stub_component';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import DashboardDeleteModal from 'ee/vue_shared/components/dashboards_list/dashboard_delete_modal.vue';
import deleteCustomDashboardMutation from 'ee/vue_shared/components/dashboards_list/delete_custom_dashboard.mutation.graphql';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');

describe('DashboardDeleteModal', () => {
  let wrapper;

  const showModal = jest.fn();
  const hideModal = jest.fn();
  const defaultPropsData = {
    dashboardId: 'gid://gitlab/Analytics::CustomDashboard/1',
  };

  const mockMutationSuccess = () =>
    createMockApollo([
      [
        deleteCustomDashboardMutation,
        jest.fn().mockResolvedValue({
          data: {
            deleteCustomDashboard: {
              errors: [],
            },
          },
        }),
      ],
    ]);

  const mockMutationError = (errors = ['Dashboard deletion failed']) =>
    createMockApollo([
      [
        deleteCustomDashboardMutation,
        jest.fn().mockResolvedValue({
          data: {
            deleteCustomDashboard: {
              errors,
            },
          },
        }),
      ],
    ]);

  const mockMutationNetworkError = (error = new Error('Network error')) =>
    createMockApollo([[deleteCustomDashboardMutation, jest.fn().mockRejectedValue(error)]]);

  const createComponent = ({ apolloProvider = mockMutationSuccess(), props = {} } = {}) => {
    wrapper = shallowMountExtended(DashboardDeleteModal, {
      propsData: {
        ...defaultPropsData,
        ...props,
      },
      apolloProvider,
      stubs: {
        GlModal: stubComponent(GlModal, {
          template: RENDER_ALL_SLOTS_TEMPLATE,
          methods: {
            show: showModal,
            hide: hideModal,
          },
        }),
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findDeleteAction = () => findModal().props('actionPrimary');
  const findCancelAction = () => findModal().props('actionCancel');

  describe('modal visibility', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows the modal when show() is called', () => {
      expect(showModal).not.toHaveBeenCalled();

      wrapper.vm.show();
      expect(showModal).toHaveBeenCalled();
    });

    it('hides the modal when hide() is called', () => {
      expect(hideModal).not.toHaveBeenCalled();

      wrapper.vm.hide();
      expect(hideModal).toHaveBeenCalled();
    });
  });

  describe('modal content', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the correct title', () => {
      expect(findModal().props('title')).toBe('Delete dashboard');
    });

    it('renders the confirmation text', () => {
      expect(wrapper.text()).toContain(
        'Are you sure you want to permanently delete this dashboard?',
      );
    });

    it('renders a cancel action', () => {
      expect(findCancelAction().text).toBe('Cancel');
    });

    it('renders a delete action', () => {
      expect(findDeleteAction().text).toBe('Delete');
      expect(findDeleteAction().attributes.variant).toBe('danger');
    });
  });

  describe('when delete is clicked', () => {
    let mockHandler;
    let apolloCache;
    beforeEach(() => {
      mockHandler = jest.fn().mockResolvedValue({
        data: {
          deleteCustomDashboard: {
            errors: [],
          },
        },
      });

      const mockApollo = createMockApollo([[deleteCustomDashboardMutation, mockHandler]]);
      createComponent({ apolloProvider: mockApollo });

      apolloCache = mockApollo.defaultClient.cache;
      jest.spyOn(apolloCache, 'evict');

      wrapper.vm.show();

      findModal().vm.$emit('primary', { preventDefault: jest.fn() });
    });

    it('sends the delete mutation', () => {
      expect(mockHandler).toHaveBeenCalledWith({
        id: defaultPropsData.dashboardId,
      });
    });

    it('puts the delete button in a loading state', () => {
      expect(findDeleteAction().attributes.loading).toBe(true);
    });

    it('puts the cancel button in a disabled state', () => {
      expect(findCancelAction().attributes.disabled).toBe(true);
    });

    describe('when delete is successful', () => {
      beforeEach(async () => {
        await waitForPromises();
      });

      it('purges the dashboard from the apollo cache', () => {
        expect(apolloCache.evict).toHaveBeenCalledWith({
          id: 'CustomDashboard:gid://gitlab/Analytics::CustomDashboard/1',
        });
      });

      it('emits the `delete` event', () => {
        expect(wrapper.emitted('delete')).toHaveLength(1);
      });
    });
  });

  describe('when a server error is thrown', () => {
    beforeEach(async () => {
      createComponent({ apolloProvider: mockMutationError(['Server error']) });

      findModal().vm.$emit('primary', { preventDefault: jest.fn() });
      await waitForPromises();
    });

    it('removes the delete button loading state', () => {
      expect(findDeleteAction().attributes.loading).toBe(false);
    });

    it('removes the cancel button disabled state', () => {
      expect(findCancelAction().attributes.disabled).toBe(false);
    });

    it('shows the error message', () => {
      expect(findAlert().exists()).toBe(true);
      expect(findAlert().props('variant')).toBe('danger');
      expect(findAlert().text()).toContain('Server error');
    });
  });

  describe('when a client error is thrown', () => {
    const networkError = new Error('Network error');

    beforeEach(async () => {
      createComponent({ apolloProvider: mockMutationNetworkError(networkError) });

      findModal().vm.$emit('primary', { preventDefault: jest.fn() });
      await waitForPromises();
    });

    it('removes the delete button loading state', () => {
      expect(findDeleteAction().attributes.loading).toBe(false);
    });

    it('removes the cancel button disabled state', () => {
      expect(findCancelAction().attributes.disabled).toBe(false);
    });

    it('shows the error message', () => {
      expect(findAlert().exists()).toBe(true);
      expect(findAlert().props('variant')).toBe('danger');
      expect(findAlert().text()).toContain('Network error');
    });

    it('captures the exception with Sentry', () => {
      expect(Sentry.captureException).toHaveBeenCalledWith(networkError);
    });
  });
});
