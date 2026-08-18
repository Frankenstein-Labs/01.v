import { GlDisclosureDropdownItem } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import LdapOverrideDropdownItem from 'ee/members/components/action_dropdowns/ldap_override_dropdown_item.vue';
import { member } from 'jest/members/mock_data';
import { MEMBERS_TAB_TYPES } from '~/members/constants';

Vue.use(Vuex);

describe('LdapOverrideDropdownItem', () => {
  let wrapper;
  let actions;
  const text = 'dummy';

  const createStore = () => {
    actions = {
      showLdapOverrideConfirmationModal: jest.fn(),
    };

    return new Vuex.Store({
      modules: {
        [MEMBERS_TAB_TYPES.user]: {
          namespaced: true,
          actions,
        },
      },
    });
  };

  const createComponent = (propsData = {}) => {
    wrapper = shallowMount(LdapOverrideDropdownItem, {
      propsData: {
        member,
        ...propsData,
      },
      store: createStore(),
      provide: {
        namespace: MEMBERS_TAB_TYPES.user,
      },
      slots: {
        default: text,
      },
    });
  };

  const findDropdownItem = () => wrapper.findComponent(GlDisclosureDropdownItem);

  beforeEach(() => {
    createComponent();
  });

  it('renders a slot', () => {
    expect(findDropdownItem().html()).toContain(text);
  });

  it('calls Vuex action to open LDAP override confirmation modal when clicked', () => {
    findDropdownItem().vm.$emit('action');

    expect(actions.showLdapOverrideConfirmationModal).toHaveBeenCalledWith(
      expect.any(Object),
      member,
    );
  });
});
