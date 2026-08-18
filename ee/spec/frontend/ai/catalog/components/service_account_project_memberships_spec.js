import VueApollo from 'vue-apollo';
import Vue, { nextTick } from 'vue';
import { GlKeysetPagination, GlTable } from '@gitlab/ui';
import { MountingPortal } from 'portal-vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import ServiceAccountProjectMemberships from 'ee/ai/catalog/components/service_account_project_memberships.vue';
import DynamicPanel from '~/vue_shared/components/dynamic_panel.vue';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import UserDate from '~/vue_shared/components/user_date.vue';
import serviceAccountProjectMembershipsQuery from 'ee/ai/catalog/graphql/queries/service_account_project_memberships.query.graphql';
import { mockServiceAccount, mockServiceAccountProjectMembershipsResponse } from '../mock_data';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');

describe('ServiceAccountProjectMemberships', () => {
  let wrapper;
  let mockApolloClient;

  const mockServiceAccountProjectMembershipsQueryHandler = jest
    .fn()
    .mockResolvedValue(mockServiceAccountProjectMembershipsResponse);

  const createComponent = (
    props = {},
    queryHandler = mockServiceAccountProjectMembershipsQueryHandler,
  ) => {
    mockApolloClient = createMockApollo([[serviceAccountProjectMembershipsQuery, queryHandler]]);

    wrapper = shallowMountExtended(ServiceAccountProjectMemberships, {
      propsData: {
        serviceAccount: mockServiceAccount,
        isOpen: true,
        ...props,
      },
      apolloProvider: mockApolloClient,
      stubs: {
        MountingPortal: { template: '<div data-testid="mounting-portal"><slot /></div>' },
        DynamicPanel: {
          template: '<div><slot name="header" /><slot /></div>',
        },
        UserDate,
        ErrorsAlert,
      },
    });
  };

  const findMountingPortal = () => wrapper.findComponent(MountingPortal);
  const findDynamicPanel = () => wrapper.findComponent(DynamicPanel);
  const findTable = () => wrapper.findComponent(GlTable);
  const findErrorsAlert = () => wrapper.findComponent(ErrorsAlert);
  const findPagination = () => wrapper.findComponent(GlKeysetPagination);

  describe('when drawer is open', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the panel title as a heading', () => {
      const heading = wrapper.find('h2');

      expect(heading.exists()).toBe(true);
      expect(heading.text()).toBe('Projects using this service account');
    });

    it('emits close event when the panel is closed', async () => {
      await findDynamicPanel().vm.$emit('close');

      expect(wrapper.emitted('close')).toHaveLength(1);
    });
  });

  describe('when drawer is closed', () => {
    beforeEach(() => {
      createComponent({ isOpen: false });
    });

    it('does not render mounting portal', () => {
      expect(findMountingPortal().exists()).toBe(false);
    });
  });

  describe('lazy loading project memberships', () => {
    beforeEach(() => {
      createComponent({ isOpen: false });
    });

    it('does not fetch project memberships when drawer is closed', () => {
      expect(findTable().exists()).toBe(false);
    });

    it('passes the loading state to the table', async () => {
      await wrapper.setProps({ isOpen: true });

      expect(findTable().attributes('busy')).toBe('true');
    });

    it('displays project memberships after successful fetch', async () => {
      await wrapper.setProps({ isOpen: true });
      await waitForPromises();

      expect(findTable().attributes('busy')).toBeUndefined();
      expect(findTable().props('items')).toHaveLength(20);
    });

    describe('when the request fails', () => {
      beforeEach(async () => {
        mockServiceAccountProjectMembershipsQueryHandler.mockRejectedValueOnce(
          new Error('GraphQL error'),
        );

        await wrapper.setProps({ isOpen: true });
        await waitForPromises();
      });

      it('displays error alert', () => {
        expect(findErrorsAlert().props('errors')).toHaveLength(1);
        expect(findErrorsAlert().props('errors')[0]).toContain(
          'Failed to load project memberships',
        );
      });

      it('dismisses error when dismiss event is emitted', async () => {
        await findErrorsAlert().vm.$emit('dismiss');
        await nextTick();

        expect(findErrorsAlert().props('errors')).toHaveLength(0);
      });
    });
  });

  describe('pagination', () => {
    describe('when refetch succeeds', () => {
      beforeEach(async () => {
        createComponent({ isOpen: true });
        await waitForPromises();
      });

      it('refetches query with correct variables when paging backward', async () => {
        await findPagination().vm.$emit('prev');
        expect(mockServiceAccountProjectMembershipsQueryHandler).toHaveBeenCalledWith({
          userId: 'gid://gitlab/User/100',
          after: null,
          before: 'eyJpZCI6IjUxIn0',
          first: null,
          last: 20,
        });
      });

      it('refetches query with correct variables when paging forward', async () => {
        await findPagination().vm.$emit('next');
        expect(mockServiceAccountProjectMembershipsQueryHandler).toHaveBeenCalledWith({
          userId: 'gid://gitlab/User/100',
          after: 'eyJpZCI6IjM1In0',
          before: null,
          first: 20,
          last: null,
        });
      });
    });

    describe('when refetch fails', () => {
      beforeEach(async () => {
        createComponent({ isOpen: true });
        await waitForPromises();

        jest
          .spyOn(wrapper.vm.$apollo.queries.projectMemberships, 'refetch')
          .mockRejectedValue(new Error('GraphQL error'));
      });

      it('on prev - displays error alert', async () => {
        findPagination().vm.$emit('prev');
        await waitForPromises();

        expect(findErrorsAlert().props('errors')).toHaveLength(1);
        expect(findErrorsAlert().props('errors')[0]).toContain(
          'Failed to load project memberships',
        );
        expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
      });

      it('on next - displays error alert', async () => {
        findPagination().vm.$emit('next');
        await waitForPromises();

        expect(findErrorsAlert().props('errors')).toHaveLength(1);
        expect(findErrorsAlert().props('errors')[0]).toContain(
          'Failed to load project memberships',
        );
        expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
      });
    });
  });
});
