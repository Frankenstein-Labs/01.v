import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import searchGroupsQuery from '~/boards/graphql/sub_groups.query.graphql';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import GroupToken from 'ee/usage_quotas/code_suggestions/tokens/group_token.vue';
import { mockGroups, mockNoGroups } from 'ee_jest/usage_quotas/code_suggestions/mock_data';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('GroupToken', () => {
  let wrapper;

  const defaultConfig = { fullPath: 'group-path' };
  const error = new Error('Something went wrong');
  const search = 'group';
  const value = { data: 'gid://gitlab/Project/20', operator: '=' };

  const loadingHandler = jest.fn().mockResolvedValue(new Promise(() => {}));
  const noGroupsHandler = jest.fn().mockResolvedValue(mockNoGroups);
  const groupsHandler = jest.fn().mockResolvedValue(mockGroups);
  const errorGroupsHandler = jest.fn().mockRejectedValue(error);

  const createMockApolloProvider = (handler) => createMockApollo([[searchGroupsQuery, handler]]);

  const findBaseToken = () => wrapper.findComponent(BaseToken);
  const triggerFetchSuggestions = (searchTerm = '') => {
    findBaseToken().vm.$emit('fetch-suggestions', searchTerm);
    return waitForPromises();
  };

  const createComponent = ({ props = {}, handler = noGroupsHandler } = {}) => {
    wrapper = shallowMount(GroupToken, {
      propsData: {
        active: false,
        config: {
          ...defaultConfig,
        },
        value,
        ...props,
      },
      apolloProvider: createMockApolloProvider(handler),
      stubs: {},
      provide: {
        portalName: 'fake target',
        alignSuggestions: function fakeAlignSuggestions() {},
        suggestionsListClass: () => 'custom-class',
        termsAsTokens: () => false,
      },
    });
  };

  describe('when rendering', () => {
    it('passes the correct props', () => {
      createComponent();

      expect(findBaseToken().props()).toMatchObject({ config: defaultConfig, value });
    });
  });

  describe('when fetching the groups', () => {
    beforeEach(async () => {
      createComponent({
        handler: loadingHandler,
      });
      await triggerFetchSuggestions(search);
      return nextTick();
    });

    it('sets loading state', () => {
      expect(findBaseToken().props('suggestionsLoading')).toBe(true);
    });

    describe('when the request is successful', () => {
      describe('with no descendants groups', () => {
        beforeEach(() => {
          createComponent({ handler: noGroupsHandler });
          return triggerFetchSuggestions(search);
        });

        it('fetches the groups', () => {
          expect(noGroupsHandler).toHaveBeenNthCalledWith(1, {
            fullPath: defaultConfig.fullPath,
            search,
          });
        });

        it('passes the correct suggestions', () => {
          expect(findBaseToken().props('suggestions')).toStrictEqual([
            {
              id: 'gid://gitlab/Group/95',
              name: 'Code Suggestions Group',
              fullName: 'Code Suggestions Group',
              fullPath: 'code-suggestions-group',
            },
          ]);
        });
      });

      describe('with descendants groups', () => {
        const {
          data: { group },
        } = mockGroups;

        const groups = [group, ...group.descendantGroups.nodes];

        beforeEach(() => {
          createComponent({ handler: groupsHandler });
          return triggerFetchSuggestions();
        });

        it('fetches the groups', () => {
          expect(groupsHandler).toHaveBeenNthCalledWith(1, {
            fullPath: defaultConfig.fullPath,
            search: '',
          });
        });

        it('passes the correct props', () => {
          expect(findBaseToken().props('suggestions')).toStrictEqual([
            {
              id: 'gid://gitlab/Group/95',
              name: 'Code Suggestions Group',
              fullName: 'Code Suggestions Group',
              fullPath: 'code-suggestions-group',
            },
            {
              id: 'gid://gitlab/Group/99',
              name: 'Code Suggestions Subgroup',
              fullName: 'Code Suggestions Group / Code Suggestions Subgroup',
              fullPath: 'code-suggestions-group/code-suggestions-subgroup',
              __typename: 'Group',
            },
          ]);
        });

        it('finds the correct value from the activeToken', () => {
          expect(findBaseToken().props('getActiveTokenValue')(groups, group.id)).toBe(group);
        });
      });
    });

    describe('when the request fails', () => {
      beforeEach(() => {
        createComponent({ handler: errorGroupsHandler });
        return triggerFetchSuggestions();
      });

      it('calls `createAlert`', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: 'There was a problem fetching groups.',
        });
      });

      it('sets `loading` to false when request completes', () => {
        expect(findBaseToken().props('suggestionsLoading')).toBe(false);
      });
    });
  });
});
