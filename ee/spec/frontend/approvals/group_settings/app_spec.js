import { GlSprintf, GlLink } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import MockAdapter from 'axios-mock-adapter';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import createMockApollo from 'helpers/mock_apollo_helper';
import axios from '~/lib/utils/axios_utils';

import ApprovalSettings from 'ee/approvals/components/approval_settings/approval_settings.vue';
import GroupSettingsApp from 'ee/approvals/group_settings/app.vue';
import { GROUP_APPROVAL_SETTINGS_LABELS_I18N } from 'ee/approvals/constants';
import { mergeRequestApprovalSettingsMappers } from 'ee/approvals/mappers';
import { createStoreOptions } from 'ee/approvals/stores';
import approvalSettingsModule from 'ee/approvals/stores/modules/approval_settings';
import groupSecurityPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_security_policies.query.graphql';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';

Vue.use(Vuex);
Vue.use(VueApollo);

const mockSecurityPoliciesResponse = {
  data: {
    namespace: {
      __typename: 'Namespace',
      id: 'gid://gitlab/Group/1',
      securityPolicies: {
        __typename: 'SecurityPolicyConnection',
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
};

describe('EE Approvals Group Settings App', () => {
  let wrapper;
  let store;
  let axiosMock;

  const defaultExpanded = true;
  const approvalSettingsPath = 'groups/22/merge_request_approval_settings';
  const fullPath = 'group/path';

  const createMockApolloProvider = () => {
    return createMockApollo([
      [groupSecurityPoliciesQuery, jest.fn().mockResolvedValue(mockSecurityPoliciesResponse)],
    ]);
  };

  const createWrapper = () => {
    wrapper = extendedWrapper(
      shallowMount(GroupSettingsApp, {
        store: new Vuex.Store(store),
        apolloProvider: createMockApolloProvider(),
        propsData: {
          defaultExpanded,
          approvalSettingsPath,
        },
        provide: {
          fullPath,
          isGroup: true,
        },
        stubs: {
          ApprovalSettings,
          GlLink,
          GlSprintf,
          SettingsBlock,
        },
      }),
    );
  };

  beforeEach(() => {
    axiosMock = new MockAdapter(axios);
    axiosMock.onGet('*');

    store = createStoreOptions({
      approvalSettings: approvalSettingsModule(mergeRequestApprovalSettingsMappers),
    });
  });

  afterEach(() => {
    store = null;
  });

  const findSettingsBlock = () => wrapper.findComponent(SettingsBlock);
  const findDescriptionLink = () => wrapper.findByTestId('group-settings-description');
  const findLearnMoreLink = () => wrapper.findByTestId('group-settings-learn-more');
  const findApprovalSettings = () => wrapper.findComponent(ApprovalSettings);

  it('renders a settings block', () => {
    createWrapper();

    expect(findSettingsBlock().exists()).toBe(true);
    expect(findSettingsBlock().props('expanded')).toBe(true);
  });

  it.each`
    findComponent          | text                      | href
    ${findDescriptionLink} | ${'separation of duties'} | ${'/help/user/compliance/compliance_center/compliance_violations_report#separation-of-duties'}
    ${findLearnMoreLink}   | ${'Learn more'}           | ${'/help/user/project/merge_requests/approvals/_index.md'}
  `('has the correct link for $text', ({ findComponent, text, href }) => {
    createWrapper();

    expect(findComponent().attributes()).toMatchObject({ href, target: '_blank' });
    expect(findComponent().text()).toBe(text);
  });

  it('renders an approval settings component', () => {
    createWrapper();

    expect(findApprovalSettings().exists()).toBe(true);
    expect(findApprovalSettings().props()).toMatchObject({
      approvalSettingsPath,
      settingsLabels: GROUP_APPROVAL_SETTINGS_LABELS_I18N,
    });
  });
});
