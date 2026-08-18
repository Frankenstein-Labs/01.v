import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlButton, GlTooltip } from '@gitlab/ui';
import ValidityCheck from 'ee/vulnerabilities/components/validity_check.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import TokenValidityBadge from 'ee/vue_shared/security_reports/components/token_validity_badge.vue';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { FINDING_MODAL_ERROR_CONTAINER_ID } from 'ee/security_dashboard/constants';
import refreshFindingTokenStatusMutation from 'ee/vulnerabilities/graphql/mutations/refresh_finding_token_status.mutation.graphql';
import refreshSecurityFindingTokenStatusMutation from 'ee/security_dashboard/graphql/mutations/refresh_security_finding_token_status.mutation.graphql';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';

Vue.use(VueApollo);

jest.mock('~/alert');

const securityFindingUuid = '01ca10fa-6168-55b8-a4b5-941686401930';

const defaultProps = {
  findingTokenStatus: {
    status: 'ACTIVE',
    updatedAt: '2023-01-01T00:00:00Z',
    lastVerifiedAt: '2023-01-01T02:00:00Z',
  },
  vulnerabilityId: 123,
};

const missingLastVerifiedAt = {
  findingTokenStatus: {
    status: 'ACTIVE',
    updatedAt: '2023-01-01T00:00:00Z',
  },
};

const successResponse = {
  data: {
    refreshFindingTokenStatus: {
      errors: [],
      findingTokenStatus: {
        id: 'gid://gitlab/Vulnerability/123',
        status: 'INACTIVE',
        createdAt: '2023-01-01T00:00:00Z',
        updatedAt: '2023-01-01T00:00:00Z',
        lastVerifiedAt: '2023-01-02T02:00:00Z',
      },
    },
  },
};

const errorResponse = {
  data: {
    refreshFindingTokenStatus: {
      errors: ['Validation failed', 'Token expired'],
      findingTokenStatus: null,
    },
  },
};

const securityFindingErrorResponse = {
  data: {
    refreshSecurityFindingTokenStatus: {
      errors: ['Validation failed', 'Token expired'],
      findingTokenStatus: null,
    },
  },
};

describe('ValidityCheck', () => {
  let wrapper;

  const createWrapper = (props = {}, { apolloProvider } = {}) => {
    wrapper = shallowMountExtended(ValidityCheck, {
      apolloProvider,
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findlastVerifiedTimestamp = () => wrapper.findByTestId('validity-last-checked');
  const findTimeAgoTooltip = () => wrapper.findComponent(TimeAgoTooltip);
  const findRecheckButton = () => wrapper.findComponent(GlButton);
  const findTooltip = () => wrapper.findComponent(GlTooltip);
  const findTokenValidityBadge = () => wrapper.findComponent(TokenValidityBadge);

  const createWrapperWithApollo = ({
    props = {},
    mutationQuery = refreshFindingTokenStatusMutation,
    mutationResolver,
  } = {}) => {
    const apolloProvider = createMockApollo([[mutationQuery, mutationResolver]]);

    createWrapper(props, { apolloProvider });
  };

  describe('when findingTokenStatus has lastVerifiedAt', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('displays the correct text', () => {
      expect(findlastVerifiedTimestamp().text()).toContain('Last checked:');
    });

    it('does not display the "not available" text', () => {
      expect(findlastVerifiedTimestamp().text()).not.toContain('No data available');
    });

    it('renders TimeAgoTooltip with the lastVerifiedAt value', () => {
      expect(findTimeAgoTooltip().props('time')).toBe(
        defaultProps.findingTokenStatus.lastVerifiedAt,
      );
    });
  });

  describe('when findingTokenStatus does not have lastVerifiedAt', () => {
    beforeEach(() => {
      createWrapper(missingLastVerifiedAt);
    });

    it('does display the "not available" text', () => {
      expect(findlastVerifiedTimestamp().text()).toContain('No data available');
    });
  });

  describe('when findingTokenStatus is null', () => {
    beforeEach(() => {
      createWrapper({ findingTokenStatus: null });
    });

    it('displays the unavailable text', () => {
      expect(findlastVerifiedTimestamp().text()).toMatchInterpolatedText(
        'Last checked: No data available',
      );
    });

    it('does not render TimeAgoTooltip', () => {
      expect(findTimeAgoTooltip().exists()).toBe(false);
    });
  });

  describe('recheck button', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('is rendered correctly', () => {
      expect(findRecheckButton().props()).toMatchObject({
        category: 'tertiary',
        size: 'small',
        icon: 'retry',
        loading: false,
      });
    });
  });

  describe('when user clicks recheck button', () => {
    describe('loading', () => {
      it.each`
        scenario            | mutationResolver
        ${'success'}        | ${() => jest.fn().mockResolvedValue(successResponse)}
        ${'GraphQL errors'} | ${() => jest.fn().mockResolvedValue(errorResponse)}
        ${'exceptions'}     | ${() => jest.fn().mockRejectedValue(new Error('Network error'))}
      `('shows and clears loading state for "$scenario"', async ({ mutationResolver }) => {
        createWrapperWithApollo({ mutationResolver: mutationResolver() });

        await findRecheckButton().vm.$emit('click');
        expect(findRecheckButton().props('loading')).toBe(true);

        await waitForPromises();
        expect(findRecheckButton().props('loading')).toBe(false);
      });
    });

    describe('with successful response', () => {
      const { bindInternalEventDocument } = useMockInternalEventsTracking();

      beforeEach(() => {
        createWrapperWithApollo({
          mutationResolver: jest.fn().mockResolvedValue(successResponse),
        });
      });

      it('calls trackEvent method for click_refresh_token_status_button', () => {
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
        findRecheckButton().vm.$emit('click');

        expect(trackEventSpy).toHaveBeenCalledWith(
          'click_refresh_token_status_button',
          {
            label: 'VulnerabilityDetails',
          },
          undefined,
        );
      });

      it('updates the last checked timestamp', async () => {
        await findRecheckButton().vm.$emit('click');
        await waitForPromises();

        expect(findTimeAgoTooltip().props('time')).toBe(
          successResponse.data.refreshFindingTokenStatus.findingTokenStatus.lastVerifiedAt,
        );
      });

      it('updates the TokenValidityBadge status', async () => {
        expect(findTokenValidityBadge().props('status')).toBe(
          defaultProps.findingTokenStatus.status,
        );

        await findRecheckButton().vm.$emit('click');
        await waitForPromises();

        expect(findTokenValidityBadge().props('status')).toBe(
          successResponse.data.refreshFindingTokenStatus.findingTokenStatus.status,
        );
      });

      it('does not show any error alerts', async () => {
        await findRecheckButton().vm.$emit('click');
        await waitForPromises();

        expect(createAlert).not.toHaveBeenCalled();
      });
    });

    describe('with errors', () => {
      it('shows error alert with the error message when GraphQL errors occur', async () => {
        createWrapperWithApollo({ mutationResolver: jest.fn().mockResolvedValue(errorResponse) });

        await findRecheckButton().vm.$emit('click');
        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith({
          message: 'Validation failed. Token expired',
          captureError: true,
          error: expect.any(Error),
        });
      });

      it('shows error alert with the error message when mutation exception occurs', async () => {
        createWrapperWithApollo({
          mutationResolver: jest.fn().mockRejectedValue(new Error('Network error')),
        });

        await findRecheckButton().vm.$emit('click');
        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith({
          message: 'Network error',
          captureError: true,
          error: expect.any(Error),
        });
      });

      it('calls createAlert with containerSelector when used in MR security widget', async () => {
        createWrapperWithApollo({
          props: {
            vulnerabilityId: null,
            securityFindingUuid,
          },
          mutationQuery: refreshSecurityFindingTokenStatusMutation,
          mutationResolver: jest.fn().mockResolvedValue(securityFindingErrorResponse),
        });

        await findRecheckButton().vm.$emit('click');
        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith({
          message: 'Validation failed. Token expired',
          captureError: true,
          error: expect.any(Error),
          containerSelector: `#${FINDING_MODAL_ERROR_CONTAINER_ID}`,
        });
      });
    });
  });

  describe('mutation selection', () => {
    it('calls the correct mutation when vulnerabilityId is provided (vulnerability details page)', async () => {
      const mutationResolver = jest.fn().mockResolvedValue(successResponse);
      const apolloProvider = createMockApollo([
        [refreshFindingTokenStatusMutation, mutationResolver],
      ]);
      const vulnerabilityId = 123;

      createWrapper({ vulnerabilityId }, { apolloProvider });

      await findRecheckButton().vm.$emit('click');

      expect(mutationResolver).toHaveBeenCalledWith({
        vulnerabilityId: `gid://gitlab/Vulnerability/${vulnerabilityId}`,
      });
    });

    it('calls the correct mutation when securityFindingUuid is provided (MR security widget)', async () => {
      const mutationResolver = jest.fn().mockResolvedValue(successResponse);
      const apolloProvider = createMockApollo([
        [refreshSecurityFindingTokenStatusMutation, mutationResolver],
      ]);

      createWrapper(
        {
          vulnerabilityId: null,
          securityFindingUuid,
        },
        { apolloProvider },
      );

      await findRecheckButton().vm.$emit('click');

      expect(mutationResolver).toHaveBeenCalledWith({ securityFindingUuid });
    });
  });

  describe('TokenValidityBadge', () => {
    it('renders with the correct prop', () => {
      createWrapper();

      expect(findTokenValidityBadge().props('status')).toBe(defaultProps.findingTokenStatus.status);
    });

    it('passes unknown status when findingTokenStatus is null', () => {
      createWrapper({ findingTokenStatus: null });

      expect(findTokenValidityBadge().props('status')).toBe('unknown');
    });

    it.each([true, false])('passes showHelpPopover: %s through to the badge', (showHelpPopover) => {
      createWrapper({ showHelpPopover });

      expect(findTokenValidityBadge().props('showHelpPopover')).toBe(showHelpPopover);
    });
  });

  describe('tooltip', () => {
    it('is rendered correctly', () => {
      createWrapper();

      const tooltip = findTooltip();
      expect(tooltip.text()).toBe('Recheck');
      expect(tooltip.attributes()).toMatchObject({
        target: 'vulnerability-validity-check-button',
        placement: 'top',
        triggers: 'hover focus',
      });
    });

    it('does not render when loading', async () => {
      createWrapperWithApollo({
        mutationResolver: jest.fn().mockResolvedValue(successResponse),
      });

      await findRecheckButton().vm.$emit('click');
      expect(findTooltip().exists()).toBe(false);

      await waitForPromises();
      expect(findTooltip().exists()).toBe(true);
    });
  });
});
