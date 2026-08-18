import { shallowMount } from '@vue/test-utils';
import VueApollo from 'vue-apollo';
import Vue, { nextTick } from 'vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { createAlert } from '~/alert';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createComplianceFrameworksTokenResponse } from 'ee_jest/compliance_dashboard/mock_data';

import ComplianceFrameworksToken from 'ee/compliance_dashboard/components/shared/filter_tokens/compliance_framework_token.vue';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import getComplianceFrameworkQuery from 'ee/graphql_shared/queries/get_compliance_framework.query.graphql';
import { FRAMEWORKS_FILTER_VALUE_NO_FRAMEWORK } from 'ee/compliance_dashboard/constants';

Vue.use(VueApollo);

jest.mock('~/alert');
jest.mock('~/sentry/sentry_browser_wrapper');

describe('ComplianceFrameworksToken', () => {
  const config = {
    groupPath: 'my-group',
  };

  const value = {
    data: "Auditor's framework 1",
    operator: '=',
  };

  const complianceFrameworksResponse = createComplianceFrameworksTokenResponse();
  const complianceFrameworks =
    complianceFrameworksResponse.data.namespace.complianceFrameworks.nodes;

  function createMockApolloProvider(resolverMock) {
    return createMockApollo([[getComplianceFrameworkQuery, resolverMock]]);
  }

  const sentryError = new Error('GraphQL networkError');
  const mockGraphQlLoading = jest.fn().mockResolvedValue(new Promise(() => {}));
  const mockGraphQlSuccess = jest.fn().mockResolvedValue(complianceFrameworksResponse);
  const mockGraphQlError = jest.fn().mockRejectedValue(sentryError);

  let wrapper;

  const findBaseToken = () => wrapper.findComponent(BaseToken);

  const createComponent = (resolverMock = mockGraphQlLoading, props = {}) => {
    wrapper = extendedWrapper(
      shallowMount(ComplianceFrameworksToken, {
        apolloProvider: createMockApolloProvider(resolverMock),
        propsData: {
          config,
          value,
          active: false,
          ...props,
        },
      }),
    );
  };

  describe('base-token props', () => {
    it('passes correct props to base-token on initial load', () => {
      createComponent();

      const baseToken = findBaseToken();
      expect(baseToken.props()).toEqual(
        expect.objectContaining({
          config,
          value,
          active: false,
          suggestionsLoading: true,
          suggestions: [],
          searchBy: 'name',
        }),
      );
    });

    it('passes correct props to base-token when frameworks are loaded', async () => {
      createComponent(mockGraphQlSuccess);

      await waitForPromises();

      const baseToken = findBaseToken();
      expect(baseToken.props()).toEqual(
        expect.objectContaining({
          config,
          value,
          active: false,
          suggestionsLoading: false,
          searchBy: 'name',
        }),
      );

      expect(baseToken.props('suggestions').map((suggestion) => suggestion.id)).toStrictEqual(
        complianceFrameworks.map((framework) => framework.id),
      );
    });

    it('includes no framework option in suggestions when includeNoFramework is true', async () => {
      const configWithNoFramework = { ...config, includeNoFramework: true };

      createComponent(mockGraphQlSuccess, { config: configWithNoFramework });

      await waitForPromises();

      const baseToken = findBaseToken();
      expect(baseToken.props('suggestions')[0]).toBe(FRAMEWORKS_FILTER_VALUE_NO_FRAMEWORK);
    });

    it('uses pre-configured frameworks when provided in config', async () => {
      const configFrameworks = [complianceFrameworks[0], complianceFrameworks[1]];
      const configWithFrameworks = { ...config, frameworks: configFrameworks };

      createComponent(null, { config: configWithFrameworks });

      await waitForPromises();

      const baseToken = findBaseToken();
      expect(baseToken.props('suggestions')).toEqual(configFrameworks);
      expect(baseToken.props('suggestionsLoading')).toBe(false);
    });

    it('passes active prop correctly', () => {
      createComponent(mockGraphQlLoading, { active: true });

      const baseToken = findBaseToken();
      expect(baseToken.props('active')).toBe(true);
    });
  });

  describe('base-token prop functions', () => {
    beforeEach(async () => {
      createComponent(mockGraphQlSuccess);
      await waitForPromises();
    });

    describe('getActiveTokenValue function', () => {
      it('returns correct framework when data matches framework id', () => {
        const baseToken = findBaseToken();
        const getActiveTokenValue = baseToken.props('getActiveTokenValue');
        const expectedFramework = complianceFrameworks[0];

        const result = getActiveTokenValue(complianceFrameworks, expectedFramework.id);

        expect(result).toEqual(expectedFramework);
      });

      it('returns no framework option when data matches no framework id', () => {
        const baseToken = findBaseToken();
        const getActiveTokenValue = baseToken.props('getActiveTokenValue');

        const result = getActiveTokenValue(
          complianceFrameworks,
          FRAMEWORKS_FILTER_VALUE_NO_FRAMEWORK.id,
        );

        expect(result).toEqual(FRAMEWORKS_FILTER_VALUE_NO_FRAMEWORK);
      });

      it('returns undefined when no matching framework is found', () => {
        const baseToken = findBaseToken();
        const getActiveTokenValue = baseToken.props('getActiveTokenValue');

        const result = getActiveTokenValue(complianceFrameworks, 'non-existent-id');

        expect(result).toBeUndefined();
      });

      it('returns undefined when data is not provided', () => {
        const baseToken = findBaseToken();
        const getActiveTokenValue = baseToken.props('getActiveTokenValue');

        const result = getActiveTokenValue(complianceFrameworks, null);

        expect(result).toBeUndefined();
      });
    });

    describe('valueIdentifier function', () => {
      it('returns framework id', () => {
        const baseToken = findBaseToken();
        const valueIdentifier = baseToken.props('valueIdentifier');
        const framework = complianceFrameworks[0];

        const result = valueIdentifier(framework);

        expect(result).toBe(framework.id);
      });
    });
  });

  describe('events', () => {
    beforeEach(async () => {
      createComponent(mockGraphQlSuccess);
      await nextTick();
      return waitForPromises();
    });

    it('refetches frameworks when fetch-suggestions event is emitted', async () => {
      const baseToken = findBaseToken();

      baseToken.vm.$emit('fetch-suggestions');
      await nextTick();
      await waitForPromises();
      expect(mockGraphQlSuccess).toHaveBeenCalled();
    });
  });

  describe('error handling', () => {
    it('captures error and shows alert when GraphQL query fails', async () => {
      createComponent(mockGraphQlError);

      await waitForPromises();

      expect(Sentry.captureException).toHaveBeenCalledWith(sentryError);
      expect(createAlert).toHaveBeenCalledWith({
        message: 'There was a problem fetching compliance frameworks.',
      });

      const baseToken = findBaseToken();
      expect(baseToken.props('suggestionsLoading')).toBe(false);
      expect(baseToken.props('suggestions')).toEqual([]);
    });
  });

  describe('loading states', () => {
    it('sets suggestionsLoading to true initially', () => {
      createComponent();

      const baseToken = findBaseToken();
      expect(baseToken.props('suggestionsLoading')).toBe(true);
    });

    it('sets suggestionsLoading to false after successful load', async () => {
      createComponent(mockGraphQlSuccess);

      await waitForPromises();

      const baseToken = findBaseToken();
      expect(baseToken.props('suggestionsLoading')).toBe(false);
    });

    it('sets suggestionsLoading to false after error', async () => {
      createComponent(mockGraphQlError);

      await waitForPromises();

      const baseToken = findBaseToken();
      expect(baseToken.props('suggestionsLoading')).toBe(false);
    });
  });

  describe('GraphQL query', () => {
    it('makes GraphQL query with correct variables', () => {
      createComponent(mockGraphQlSuccess);

      expect(mockGraphQlSuccess).toHaveBeenCalledWith({
        fullPath: config.groupPath,
        ids: null,
      });
    });

    it('skips GraphQL query when frameworks are provided in config', async () => {
      const configWithFrameworks = { ...config, frameworks: complianceFrameworks };
      const mockQuery = jest.fn();

      createComponent(mockQuery, { config: configWithFrameworks });

      await waitForPromises();

      expect(mockQuery).not.toHaveBeenCalled();
    });
  });
});
