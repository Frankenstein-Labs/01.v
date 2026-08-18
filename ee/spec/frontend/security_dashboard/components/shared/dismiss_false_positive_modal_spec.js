import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlModal } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import DismissFalsePositiveModal from 'ee/security_dashboard/components/shared/dismiss_false_positive_modal.vue';
import dismissFalsePositiveFlagMutation from 'ee/security_dashboard/graphql/mutations/vulnerability_dismiss_false_positive_flag.mutation.graphql';
import projectVulnerabilitiesQuery from 'ee/security_dashboard/graphql/queries/project_vulnerabilities.query.graphql';

jest.mock('~/alert');

Vue.use(VueApollo);

describe('DismissFalsePositiveModal', () => {
  let wrapper;
  let mutationHandler;
  let vulnerabilitiesQueryHandler;

  const defaultVulnerability = {
    id: 'gid://gitlab/Vulnerability/123',
  };

  const mockMutationResponse = {
    data: {
      vulnerabilityDismissFalsePositiveFlag: {
        __typename: 'VulnerabilityDismissFalsePositiveFlagPayload',
        errors: [],
        vulnerability: {
          __typename: 'Vulnerability',
          id: defaultVulnerability.id,
          latestFlag: {
            __typename: 'VulnerabilityFlag',
            id: 'gid://gitlab/Vulnerabilities::Flag/1',
            confidenceScore: 0.9,
            status: 'DISMISSED',
          },
        },
      },
    },
  };

  const createComponent = (props = {}, options = {}) => {
    mutationHandler = options.mutationHandler ?? jest.fn().mockResolvedValue(mockMutationResponse);
    vulnerabilitiesQueryHandler = jest.fn().mockResolvedValue({
      data: {
        project: {
          __typename: 'Project',
          id: 'gid://gitlab/Project/1',
          vulnerabilities: {
            __typename: 'VulnerabilityConnection',
            nodes: [],
            pageInfo: {
              __typename: 'PageInfo',
              hasNextPage: false,
              hasPreviousPage: false,
              startCursor: null,
              endCursor: null,
            },
          },
        },
      },
    });

    const provideVulnerabilitiesQuery =
      'vulnerabilitiesQuery' in options
        ? options.vulnerabilitiesQuery
        : projectVulnerabilitiesQuery;

    const apolloProvider = createMockApollo([
      [dismissFalsePositiveFlagMutation, mutationHandler],
      [projectVulnerabilitiesQuery, vulnerabilitiesQueryHandler],
    ]);
    // `refetchQueries` only refetches active queries, so registering a handler is not
    // enough; watch the query so it is observable and its refetch is triggered.
    apolloProvider.defaultClient
      .watchQuery({ query: projectVulnerabilitiesQuery, variables: { fullPath: 'group/project' } })
      .subscribe();

    wrapper = shallowMountExtended(DismissFalsePositiveModal, {
      propsData: {
        vulnerability: defaultVulnerability,
        ...props,
      },
      provide: {
        vulnerabilitiesQuery: provideVulnerabilitiesQuery,
        ...options.provide,
      },
      mocks: {
        $toast: {
          show: jest.fn(),
        },
        ...options.mocks,
      },
      apolloProvider,
    });
    return wrapper;
  };

  const findModal = () => wrapper.findComponent(GlModal);

  describe('rendering', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('renders the modal with correct props', () => {
      expect(findModal().exists()).toBe(true);
      expect(findModal().props('modalId')).toBe('dismiss-fp-confirm-modal');
      expect(findModal().props('title')).toBe('Dismiss False Positive Flag');
      expect(findModal().props('actionPrimary')).toEqual({
        text: 'Dismiss False Positive Flag',
        attributes: {
          variant: 'danger',
        },
      });
      expect(findModal().props('actionSecondary')).toEqual({
        text: 'Cancel',
        attributes: {
          variant: 'default',
        },
      });
    });

    it('renders the modal text', () => {
      expect(findModal().text()).toContain(
        "Removing this flag will not change the vulnerability's status. The vulnerability will remain in its current state but will no longer be marked as a false positive.",
      );
    });

    it('uses custom modal ID when provided', () => {
      wrapper = createComponent({ modalId: 'custom-modal-id' });
      expect(findModal().props('modalId')).toBe('custom-modal-id');
    });
  });

  describe('dismissing flag', () => {
    it('calls Apollo mutation with correct parameters when primary action is triggered', async () => {
      wrapper = createComponent();

      findModal().vm.$emit('primary');
      await waitForPromises();

      expect(mutationHandler).toHaveBeenCalledWith({
        id: defaultVulnerability.id,
      });
    });

    it('refetches the vulnerabilities query after a successful mutation', async () => {
      wrapper = createComponent();

      // Watched once on setup.
      expect(vulnerabilitiesQueryHandler).toHaveBeenCalledTimes(1);

      findModal().vm.$emit('primary');
      await waitForPromises();

      // Refetched after the mutation resolves.
      expect(vulnerabilitiesQueryHandler).toHaveBeenCalledTimes(2);
    });

    it('emits success event after successful mutation', async () => {
      wrapper = createComponent();

      findModal().vm.$emit('primary');
      await waitForPromises();

      expect(wrapper.emitted('success')).toHaveLength(1);
    });

    it('emits success event without calling toast (toast is parent responsibility)', async () => {
      wrapper = createComponent();

      findModal().vm.$emit('primary');
      await waitForPromises();

      expect(wrapper.emitted('success')).toHaveLength(1);
    });

    it('handles case when $toast is not available', async () => {
      wrapper = createComponent(
        {},
        {
          mocks: {
            $toast: null,
          },
        },
      );

      findModal().vm.$emit('primary');
      await waitForPromises();

      expect(wrapper.emitted('success')).toHaveLength(1);
    });

    it('does not refetch when vulnerabilitiesQuery is not provided', async () => {
      wrapper = createComponent({}, { vulnerabilitiesQuery: null });

      // Watched once on setup.
      expect(vulnerabilitiesQueryHandler).toHaveBeenCalledTimes(1);

      findModal().vm.$emit('primary');
      await waitForPromises();

      expect(mutationHandler).toHaveBeenCalledWith({
        id: defaultVulnerability.id,
      });
      // No refetch triggered.
      expect(vulnerabilitiesQueryHandler).toHaveBeenCalledTimes(1);
    });

    describe('when mutation fails', () => {
      const mockError = new Error('Mutation failed');

      beforeEach(async () => {
        wrapper = createComponent(
          {},
          {
            mutationHandler: jest.fn().mockRejectedValue(mockError),
          },
        );

        findModal().vm.$emit('primary');
        await waitForPromises();
      });

      it('creates an alert with error message', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: 'Something went wrong while dismissing the vulnerability.',
          captureError: true,
          error: mockError,
        });
      });

      it('emits error event', () => {
        expect(wrapper.emitted('error')).toHaveLength(1);
        expect(wrapper.emitted('error')[0]).toEqual([mockError]);
      });

      it('does not emit success event', () => {
        expect(wrapper.emitted('success')).toBe(undefined);
      });
    });
  });
});
