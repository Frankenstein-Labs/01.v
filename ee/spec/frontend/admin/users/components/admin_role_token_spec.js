import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlLoadingIcon, GlFilteredSearchSuggestion } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import AdminRoleToken from 'ee/admin/users/components/admin_role_token.vue';
import adminRolesQuery from 'ee/admin/users/graphql/admin_roles.query.graphql';
import { OPERATOR_IS } from '~/vue_shared/components/filtered_search_bar/constants';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import { RENDER_ALL_SLOTS_TEMPLATE, stubComponent } from 'helpers/stub_component';
import { createAlert } from '~/alert';
import { ADMIN_ROLE_TOKEN } from '../mock_data';
import { adminRoles } from './mock_data';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('AdminRoleToken component', () => {
  let wrapper;

  const getAdminRolesHandler = (roles = []) =>
    jest.fn().mockResolvedValue({ data: { adminMemberRoles: { nodes: roles } } });
  const defaultAdminRolesHandler = getAdminRolesHandler(adminRoles);

  const createWrapper = ({
    active = true,
    config = ADMIN_ROLE_TOKEN,
    value = { data: null, operator: OPERATOR_IS },
    adminRolesHandler = defaultAdminRolesHandler,
  } = {}) => {
    wrapper = shallowMountExtended(AdminRoleToken, {
      apolloProvider: createMockApollo([[adminRolesQuery, adminRolesHandler]]),
      propsData: { active, config, value },
      stubs: {
        BaseToken: stubComponent(BaseToken, {
          template: RENDER_ALL_SLOTS_TEMPLATE,
          props: ['active', 'config', 'value', 'suggestions', 'suggestionsLoading'],
        }),
      },
    });

    return waitForPromises();
  };

  const findBaseToken = () => wrapper.findComponent(BaseToken);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findViewSlot = () => wrapper.findByTestId('slot-view');
  const findSearchSuggestions = () => wrapper.findAllComponents(GlFilteredSearchSuggestion);
  const findSearchSuggestionAt = (index) => findSearchSuggestions().at(index);

  describe('on page load', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('shows base token component', () => {
      expect(findBaseToken().props()).toMatchObject({
        active: true,
        value: { data: null, operator: OPERATOR_IS },
        config: ADMIN_ROLE_TOKEN,
        suggestions: [],
        suggestionsLoading: true,
      });
    });

    it('starts admin roles query', () => {
      expect(defaultAdminRolesHandler).toHaveBeenCalledTimes(1);
    });
  });

  describe('when admin roles query is loading', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('shows base token component as loading', () => {
      expect(findBaseToken().props('suggestionsLoading')).toBe(true);
    });

    it('shows loading spinner', () => {
      expect(findLoadingIcon().exists()).toBe(true);
    });

    it('does not show the no results message', () => {
      expect(wrapper.findByTestId('slot-footer').exists()).toBe(false);
    });
  });

  describe('when admin roles query is done', () => {
    beforeEach(() => createWrapper());

    it('shows base token component as not loading', () => {
      expect(findBaseToken().props('suggestionsLoading')).toBe(false);
    });

    it('does not show loading spinner', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('shows search suggestions', () => {
      expect(findSearchSuggestionAt(0).text()).toBe('Admin role 1');
      expect(findSearchSuggestionAt(0).props('value')).toBe('1');
      expect(findSearchSuggestionAt(1).text()).toBe('Admin role 2');
      expect(findSearchSuggestionAt(1).props('value')).toBe('2');
    });

    it('does not show the no results message', () => {
      expect(wrapper.findByTestId('slot-footer').exists()).toBe(false);
    });
  });

  describe('when admin role is selected', () => {
    beforeEach(() => createWrapper({ value: { data: '1', operator: OPERATOR_IS } }));

    it('shows role name', () => {
      expect(findViewSlot().text()).toBe('Admin role 1');
    });
  });

  describe('when there are no admin roles', () => {
    beforeEach(() => createWrapper({ adminRolesHandler: getAdminRolesHandler([]) }));

    it('does not show search suggestions', () => {
      expect(findSearchSuggestions()).toHaveLength(0);
    });

    it('shows the no results message', () => {
      expect(wrapper.findByTestId('slot-footer').text()).toBe('No results found');
    });
  });

  describe('when query has an error', () => {
    beforeEach(() => createWrapper({ adminRolesHandler: jest.fn().mockRejectedValue() }));

    it('does not show search suggestions', () => {
      expect(findSearchSuggestions()).toHaveLength(0);
    });

    it('shows an error message', () => {
      expect(createAlert).toHaveBeenCalledTimes(1);
      expect(createAlert).toHaveBeenCalledWith({ message: 'Could not load custom admin roles.' });
    });
  });
});
