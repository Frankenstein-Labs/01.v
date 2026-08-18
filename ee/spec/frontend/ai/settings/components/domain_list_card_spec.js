import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlSearchBoxByType } from '@gitlab/ui';
import { stubComponent } from 'helpers/stub_component';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import DomainListCard from 'ee/ai/settings/components/domain_list_card.vue';
import aiDomainSettingsInstanceUpdate from 'ee/ai/settings/graphql/mutations/ai_domain_settings_instance_update.mutation.graphql';
import aiDomainSettingsNamespaceUpdate from 'ee/ai/settings/graphql/mutations/ai_domain_settings_namespace_update.mutation.graphql';
import getAiDomainSettings from 'ee/ai/settings/graphql/queries/get_ai_domain_settings.query.graphql';
import getGroupAiDomainSettings from 'ee/ai/settings/graphql/queries/get_group_ai_domain_settings.query.graphql';
import {
  allowedPopulatedFixture,
  allowedEmptyFixture,
  allowedPaginatedFixture,
  instanceMutationAddSuccess,
  instanceMutationRemoveSuccess,
  namespaceMutationAddSuccess,
  namespaceMutationRemoveSuccess,
  instanceMutationErrorResponse,
  namespaceMutationErrorResponse,
  groupAllowedPopulatedFixture,
  errorResponse,
} from './mock_data';

Vue.use(VueApollo);

const DEFAULT_PROPS = {
  domainType: 'ALLOWED',
  title: 'Allowlist',
  emptyStateText: 'No allowlist entries.',
  errorText: 'Failed to load allowlist domains.',
};

describe('DomainListCard', () => {
  let wrapper;
  let mockToastShow;

  const createComponent = ({
    queryHandler = jest.fn().mockResolvedValue(allowedPopulatedFixture),
    mutationHandler = jest.fn().mockResolvedValue(instanceMutationAddSuccess),
    groupQueryHandler = jest.fn().mockResolvedValue(groupAllowedPopulatedFixture),
    props = {},
  } = {}) => {
    mockToastShow = jest.fn();

    const isNamespaceContext = Boolean(props.groupFullPath);
    const domainQuery = isNamespaceContext ? getGroupAiDomainSettings : getAiDomainSettings;
    const selectedQueryHandler = isNamespaceContext ? groupQueryHandler : queryHandler;

    wrapper = shallowMountExtended(DomainListCard, {
      apolloProvider: createMockApollo([
        [domainQuery, selectedQueryHandler],
        [aiDomainSettingsInstanceUpdate, mutationHandler],
        [aiDomainSettingsNamespaceUpdate, mutationHandler],
      ]),
      propsData: { ...DEFAULT_PROPS, ...props },
      stubs: {
        CrudComponent,
        GlSearchBoxByType: stubComponent(GlSearchBoxByType, {
          methods: { focusInput: jest.fn() },
        }),
      },
      mocks: {
        $toast: { show: mockToastShow },
      },
    });
    jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
    return waitForPromises();
  };

  const findCard = () => wrapper.findComponent(CrudComponent);
  const findErrorAlert = () => wrapper.findByTestId('domain-error');
  const findMutationError = () => wrapper.findComponentByTestId('domain-mutation-error');
  const findNoDomainEntries = () => wrapper.findByTestId('empty-state-text');
  const findEmptyAddBtn = () => wrapper.findComponentByTestId('empty-add-domain-btn');
  const findDomainRows = () => wrapper.findAllByTestId('domain-row');
  const findHeaderAddBtn = () => wrapper.findComponentByTestId('add-domain-btn');
  const findHeaderSearchBtn = () => wrapper.findComponentByTestId('search-domain-btn');
  const findDomainInput = () => wrapper.findComponentByTestId('domain-input');
  const findConfirmAddBtn = () => wrapper.findComponentByTestId('confirm-add-domain-btn');
  const findSearchInput = () => wrapper.findComponentByTestId('search-input');
  const findPagination = () => wrapper.findComponentByTestId('domain-pagination');
  const findRemoveBtns = () => wrapper.findAllComponentsByTestId('remove-domain-btn');

  describe('props', () => {
    it('passes static props to CrudComponent', async () => {
      await createComponent();

      expect(findCard().props()).toMatchObject({
        title: 'Allowlist',
        showZeroCount: true,
        isCollapsible: true,
      });
    });
  });

  describe('loading state', () => {
    it('passes isLoading=true while query is in-flight on first load', async () => {
      createComponent();
      jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
      await nextTick();
      expect(findCard().props('isLoading')).toBe(true);
    });

    it('passes isLoading=false after query resolves', async () => {
      await createComponent();
      expect(findCard().props('isLoading')).toBe(false);
    });
  });

  describe('error state', () => {
    it('shows error alert on query failure', async () => {
      await createComponent({ queryHandler: jest.fn().mockRejectedValue(errorResponse) });
      expect(findErrorAlert().exists()).toBe(true);
    });

    it('displays errorText prop in the error alert', async () => {
      await createComponent({ queryHandler: jest.fn().mockRejectedValue(errorResponse) });
      expect(findErrorAlert().text()).toBe('Failed to load allowlist domains.');
    });

    it('does not show error alert on success', async () => {
      await createComponent();
      expect(findErrorAlert().exists()).toBe(false);
    });
  });

  describe('empty state', () => {
    beforeEach(() =>
      createComponent({ queryHandler: jest.fn().mockResolvedValue(allowedEmptyFixture) }),
    );

    it('renders emptyStateText', () => {
      expect(findNoDomainEntries().text()).toBe('No allowlist entries.');
    });

    it('renders + Add domain button', () => {
      expect(findEmptyAddBtn().exists()).toBe(true);
    });

    it('does not render domain rows', () => {
      expect(findDomainRows()).toHaveLength(0);
    });
  });

  describe('populated state', () => {
    beforeEach(() => createComponent());

    it('renders one row per domain', () => {
      expect(findDomainRows()).toHaveLength(2);
    });

    it('renders first domain name in its row', () => {
      expect(findDomainRows().at(0).text()).toContain('example.com');
    });

    it('renders second domain name in its row', () => {
      expect(findDomainRows().at(1).text()).toContain('gitlab.com');
    });

    it('passes count to CrudComponent', () => {
      expect(findCard().props('count')).toBe(2);
    });

    it('does not render empty state', () => {
      expect(findNoDomainEntries().exists()).toBe(false);
    });
  });

  describe('add domain', () => {
    beforeEach(async () => {
      await createComponent();
      findHeaderAddBtn().vm.$emit('click');
      await nextTick();
    });

    it('does not show toast when input is empty', () => {
      findDomainInput().vm.$emit('input', '');
      findConfirmAddBtn().vm.$emit('click');

      expect(mockToastShow).not.toHaveBeenCalled();
    });

    it('shows toast on valid submit via button click', async () => {
      findDomainInput().vm.$emit('input', 'new-domain.com');
      findConfirmAddBtn().vm.$emit('click');
      await waitForPromises();

      expect(mockToastShow).toHaveBeenCalledWith('Domain added.');
    });

    it('shows toast on valid submit via enter keydown event', async () => {
      findDomainInput().vm.$emit('input', 'new-domain.com');
      // Vue 2 @keydown.enter on a component stub listens for $emit('keydown')
      findDomainInput().vm.$emit('keydown', new KeyboardEvent('keydown', { key: 'Enter' }));
      await waitForPromises();

      expect(mockToastShow).toHaveBeenCalledWith('Domain added.');
    });

    it('ignores rapid submit while a mutation is in-flight', async () => {
      let resolveMutation;
      const pendingMutation = new Promise((resolve) => {
        resolveMutation = resolve;
      });
      const mutationHandler = jest.fn().mockReturnValueOnce(pendingMutation);
      await createComponent({ mutationHandler });
      findHeaderAddBtn().vm.$emit('click');
      await nextTick();

      findDomainInput().vm.$emit('input', 'new-domain.com');
      findConfirmAddBtn().vm.$emit('click');
      await nextTick();

      // Second click while first is in-flight should be ignored
      findConfirmAddBtn().vm.$emit('click');
      await nextTick();

      expect(mutationHandler).toHaveBeenCalledTimes(1);

      resolveMutation(instanceMutationAddSuccess);
      await waitForPromises();
    });

    it('clears input and closes form after valid submit', async () => {
      findDomainInput().vm.$emit('input', 'new-domain.com');
      findConfirmAddBtn().vm.$emit('click');
      await waitForPromises();

      expect(findDomainInput().exists()).toBe(false);
    });

    it('closes form and clears search after adding a domain with an active search term', async () => {
      await createComponent();
      findHeaderSearchBtn().vm.$emit('click');
      await nextTick();

      findSearchInput().vm.$emit('input', 'example');
      await nextTick();

      findHeaderAddBtn().vm.$emit('click');
      await nextTick();

      findDomainInput().vm.$emit('input', 'example.com');
      findConfirmAddBtn().vm.$emit('click');
      await waitForPromises();

      expect(mockToastShow).toHaveBeenCalledWith('Domain added.');
      expect(findDomainInput().exists()).toBe(false);
      expect(findSearchInput().exists()).toBe(false);
    });
  });

  describe('remove domain', () => {
    beforeEach(() => createComponent());

    it('shows toast when remove button is clicked', async () => {
      findRemoveBtns().at(0).vm.$emit('click');
      await waitForPromises();

      expect(mockToastShow).toHaveBeenCalledWith('Domain removed.');
    });

    it('ignores remove while a mutation is in-flight', async () => {
      let resolveMutation;
      const pendingMutation = new Promise((resolve) => {
        resolveMutation = resolve;
      });
      const mutationHandler = jest.fn().mockReturnValueOnce(pendingMutation);
      await createComponent({ mutationHandler });

      findRemoveBtns().at(0).vm.$emit('click');
      await nextTick();

      // Second remove while first is in-flight should be ignored
      findRemoveBtns().at(0).vm.$emit('click');
      await nextTick();

      expect(mutationHandler).toHaveBeenCalledTimes(1);

      resolveMutation(instanceMutationRemoveSuccess);
      await waitForPromises();
    });
  });

  describe('mutation integration', () => {
    describe.each`
      context        | props                                     | addSuccess                     | removeSuccess                     | errorResp                         | baseInput
      ${'instance'}  | ${{}}                                     | ${instanceMutationAddSuccess}  | ${instanceMutationRemoveSuccess}  | ${instanceMutationErrorResponse}  | ${{ domainSettingType: 'ALLOWED' }}
      ${'namespace'} | ${{ groupFullPath: 'gitlab-org/gitlab' }} | ${namespaceMutationAddSuccess} | ${namespaceMutationRemoveSuccess} | ${namespaceMutationErrorResponse} | ${{ domainSettingType: 'ALLOWED', namespaceId: 'gid://gitlab/Namespace/42' }}
    `('$context context', ({ props, addSuccess, removeSuccess, errorResp, baseInput }) => {
      const triggerAdd = async () => {
        findHeaderAddBtn().vm.$emit('click');
        await nextTick();
        findDomainInput().vm.$emit('input', 'new-domain.com');
        findConfirmAddBtn().vm.$emit('click');
      };

      const triggerRemove = () => {
        findRemoveBtns().at(0).vm.$emit('click');
      };

      describe.each`
        action      | successResp      | toast                | trigger          | domains
        ${'ADD'}    | ${addSuccess}    | ${'Domain added.'}   | ${triggerAdd}    | ${['new-domain.com']}
        ${'REMOVE'} | ${removeSuccess} | ${'Domain removed.'} | ${triggerRemove} | ${['example.com']}
      `('$action action', ({ successResp, toast, trigger, action, domains }) => {
        it('calls mutation with expected variables and shows toast', async () => {
          const mutationHandler = jest.fn().mockResolvedValue(successResp);
          await createComponent({ props, mutationHandler });
          await trigger();
          await waitForPromises();

          expect(mutationHandler).toHaveBeenCalledWith({
            input: { ...baseInput, action, domains },
          });
          expect(mockToastShow).toHaveBeenCalledWith(toast);
        });

        it('shows mutation error on backend error response', async () => {
          await createComponent({ props, mutationHandler: jest.fn().mockResolvedValue(errorResp) });
          await trigger();
          await waitForPromises();

          expect(findMutationError().text()).toContain('evil.com is not a valid domain');
          expect(mockToastShow).not.toHaveBeenCalled();
        });

        it('shows generic error on network failure', async () => {
          await createComponent({
            props,
            mutationHandler: jest.fn().mockRejectedValue(errorResponse),
          });
          await trigger();
          await waitForPromises();

          expect(findMutationError().text()).toContain('An error occurred. Please try again.');
        });
      });

      describe('add-specific behavior', () => {
        it('closes form on add success', async () => {
          await createComponent({
            props,
            mutationHandler: jest.fn().mockResolvedValue(addSuccess),
          });
          await triggerAdd();
          await waitForPromises();

          expect(findDomainInput().exists()).toBe(false);
        });

        it('refetches domains query on add success', async () => {
          const handler = jest
            .fn()
            .mockResolvedValue(
              props.groupFullPath ? groupAllowedPopulatedFixture : allowedPopulatedFixture,
            );
          const queryOpts = props.groupFullPath
            ? { groupQueryHandler: handler }
            : { queryHandler: handler };

          await createComponent({
            ...queryOpts,
            props,
            mutationHandler: jest.fn().mockResolvedValue(addSuccess),
          });

          expect(handler).toHaveBeenCalledTimes(1);

          await triggerAdd();
          await waitForPromises();

          expect(handler).toHaveBeenCalledTimes(2);
        });

        it('shows error when trying to add an empty domain', async () => {
          const mutationHandler = jest.fn().mockResolvedValue(addSuccess);
          await createComponent({ props, mutationHandler });
          findHeaderAddBtn().vm.$emit('click');
          await nextTick();

          findDomainInput().vm.$emit('input', '   ');
          findConfirmAddBtn().vm.$emit('click');
          await nextTick();

          expect(findMutationError().text()).toContain('Domain cannot be empty.');
          expect(mutationHandler).not.toHaveBeenCalled();
        });

        it('disables and shows loading state on add button while saving', async () => {
          let resolveMutation;
          const pendingMutation = new Promise((resolve) => {
            resolveMutation = resolve;
          });
          const mutationHandler = jest.fn().mockReturnValue(pendingMutation);

          await createComponent({ props, mutationHandler });
          findHeaderAddBtn().vm.$emit('click');
          await nextTick();

          findDomainInput().vm.$emit('input', 'new-domain.com');
          findConfirmAddBtn().vm.$emit('click');
          await nextTick();

          expect(findConfirmAddBtn().props('disabled')).toBe(true);
          expect(findConfirmAddBtn().props('loading')).toBe(true);

          resolveMutation(addSuccess);
          await waitForPromises();
        });

        it('makes mutation error alert dismissible', async () => {
          await createComponent({ props, mutationHandler: jest.fn().mockResolvedValue(errorResp) });
          findHeaderAddBtn().vm.$emit('click');
          await nextTick();

          findDomainInput().vm.$emit('input', 'new-domain.com');
          findConfirmAddBtn().vm.$emit('click');
          await waitForPromises();

          findMutationError().vm.$emit('dismiss');
          await nextTick();

          expect(findMutationError().exists()).toBe(false);
        });
      });
    });
  });

  describe('search', () => {
    it('hides search button when list is empty and no search term', async () => {
      await createComponent({ queryHandler: jest.fn().mockResolvedValue(allowedEmptyFixture) });

      expect(findHeaderSearchBtn().exists()).toBe(false);
    });

    it('shows search button when list has entries', async () => {
      await createComponent();

      expect(findHeaderSearchBtn().exists()).toBe(true);
    });

    it('shows search input after clicking search button', async () => {
      await createComponent();
      findHeaderSearchBtn().vm.$emit('click');
      await nextTick();

      expect(findSearchInput().exists()).toBe(true);
    });

    it('hides search input after clicking add button', async () => {
      await createComponent();
      findHeaderSearchBtn().vm.$emit('click');
      await nextTick();
      findHeaderAddBtn().vm.$emit('click');
      await nextTick();

      expect(findSearchInput().exists()).toBe(false);
    });

    it('re-queries with search term after debounced input', async () => {
      const queryHandler = jest.fn().mockResolvedValue(allowedPopulatedFixture);
      await createComponent({ queryHandler });
      findHeaderSearchBtn().vm.$emit('click');
      await nextTick();

      findSearchInput().vm.$emit('input', 'example');
      await nextTick();
      jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
      await waitForPromises();

      expect(queryHandler).toHaveBeenLastCalledWith(expect.objectContaining({ search: 'example' }));
    });

    it('keeps search input visible after clear', async () => {
      await createComponent();
      findHeaderSearchBtn().vm.$emit('click');
      await nextTick();

      findSearchInput().vm.$emit('input', 'example');
      jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
      await waitForPromises();
      findSearchInput().vm.$emit('clear');
      await nextTick();

      expect(findSearchInput().exists()).toBe(true);
    });
  });

  describe('toggleAdd', () => {
    it('pre-populates domain input with search term when switching from search to add', async () => {
      await createComponent();
      findHeaderSearchBtn().vm.$emit('click');
      await nextTick();

      findSearchInput().vm.$emit('input', 'my-domain.com');
      await nextTick();

      findHeaderAddBtn().vm.$emit('click');
      await nextTick();

      expect(findDomainInput().attributes('value')).toBe('my-domain.com');
    });

    it('does not pre-populate domain input when not in search mode', async () => {
      await createComponent();
      findHeaderAddBtn().vm.$emit('click');
      await nextTick();

      expect(findDomainInput().attributes('value')).toBe('');
    });
  });

  describe('empty state add button', () => {
    it('opens add form when clicking empty state add button', async () => {
      await createComponent({ queryHandler: jest.fn().mockResolvedValue(allowedEmptyFixture) });
      findEmptyAddBtn().vm.$emit('click');
      await nextTick();

      expect(findDomainInput().exists()).toBe(true);
    });
  });

  describe('pagination', () => {
    beforeEach(() =>
      createComponent({ queryHandler: jest.fn().mockResolvedValue(allowedPaginatedFixture) }),
    );

    it('renders pagination component', () => {
      expect(findPagination().exists()).toBe(true);
    });

    it('passes hasNextPage=true to pagination', () => {
      expect(findPagination().props('hasNextPage')).toBe(true);
    });

    it('passes count with "+" suffix when hasNextPage is true', () => {
      expect(findCard().props('count')).toBe('20+');
    });

    it('does not update count when navigating to subsequent pages', async () => {
      const page2Fixture = {
        data: {
          aiDomainSettings: {
            __typename: 'StringConnection',
            nodes: ['domain21.example.com', 'domain22.example.com'],
            pageInfo: {
              __typename: 'PageInfo',
              hasNextPage: false,
              hasPreviousPage: true,
              startCursor: 'MjE',
              endCursor: 'MjI',
            },
          },
        },
      };
      const queryHandler = jest
        .fn()
        .mockResolvedValueOnce(allowedPaginatedFixture)
        .mockResolvedValue(page2Fixture);
      await createComponent({ queryHandler });

      expect(findCard().props('count')).toBe('20+');

      findPagination().vm.$emit('next');
      await nextTick();
      jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
      await waitForPromises();

      expect(findCard().props('count')).toBe('20+');
    });

    it('recalculates count when search is cleared and results return to first page', async () => {
      const searchFixture = {
        data: {
          aiDomainSettings: {
            __typename: 'StringConnection',
            nodes: ['domain1.example.com'],
            pageInfo: {
              __typename: 'PageInfo',
              hasNextPage: false,
              hasPreviousPage: false,
              startCursor: 'MQ',
              endCursor: 'MQ',
            },
          },
        },
      };
      const queryHandler = jest
        .fn()
        .mockResolvedValueOnce(allowedPaginatedFixture)
        .mockResolvedValueOnce(searchFixture)
        .mockResolvedValue(allowedPaginatedFixture);
      await createComponent({ queryHandler });
      expect(findCard().props('count')).toBe('20+');

      await findHeaderSearchBtn().vm.$emit('click');
      await nextTick();

      findSearchInput().vm.$emit('input', 'domain1');
      await nextTick();
      jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
      await waitForPromises();

      // Count unchanged while searching (proves searchTerm guard works)
      expect(findCard().props('count')).toBe('20+');

      findSearchInput().vm.$emit('clear');
      jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
      await waitForPromises();

      // After clear, recalculation re-runs against fresh first-page response
      expect(findCard().props('count')).toBe('20+');
    });

    it('re-queries with next cursor on @next', async () => {
      const queryHandler = jest.fn().mockResolvedValue(allowedPaginatedFixture);
      await createComponent({ queryHandler });

      findPagination().vm.$emit('next');
      await nextTick();
      jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
      await waitForPromises();

      expect(queryHandler).toHaveBeenLastCalledWith(
        expect.objectContaining({ first: 20, after: 'MjA' }),
      );
    });

    it('re-queries with prev cursor on @prev', async () => {
      const queryHandler = jest.fn().mockResolvedValue(allowedPaginatedFixture);
      await createComponent({ queryHandler });

      findPagination().vm.$emit('prev');
      await nextTick();
      jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
      await waitForPromises();

      expect(queryHandler).toHaveBeenLastCalledWith(
        expect.objectContaining({ last: 20, before: 'MQ' }),
      );
    });
  });
});
