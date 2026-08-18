import { GlSprintf } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import BlockGroupBranchModificationSetting from 'ee/security_orchestration/components/policy_drawer/scan_result/block_group_branch_modification_setting.vue';
import { createMockGroups } from 'ee_jest/security_orchestration/mocks/mock_data';
import createMockApollo from 'helpers/mock_apollo_helper';
import getGroupsByIds from 'ee/security_orchestration/graphql/queries/get_groups_by_ids.query.graphql';

describe('BlockGroupBranchModificationSetting', () => {
  let wrapper;
  let requestHandler;

  const groups = createMockGroups();

  const defaultHandler = (nodes = groups) =>
    jest.fn().mockResolvedValue({
      data: {
        groups: {
          nodes,
          pageInfo: {},
        },
      },
    });

  const createMockApolloProvider = (handler) => {
    Vue.use(VueApollo);

    requestHandler = handler;

    return createMockApollo([[getGroupsByIds, handler]]);
  };

  const createComponent = ({ exceptions = [], handler = defaultHandler() } = {}) => {
    wrapper = shallowMountExtended(BlockGroupBranchModificationSetting, {
      apolloProvider: createMockApolloProvider(handler),
      propsData: { exceptions },
      stubs: { GlSprintf },
    });
  };

  const findExceptions = () => wrapper.findAll('li');

  it('renders exception list items', async () => {
    const exceptions = [{ id: 1 }, { id: 2 }];

    createComponent({ exceptions });
    await waitForPromises();

    expect(requestHandler).toHaveBeenCalledTimes(1);
    expect(findExceptions()).toHaveLength(2);
    expect(findExceptions().at(0).text()).toBe(groups[0].fullName);
    expect(findExceptions().at(1).text()).toBe(groups[1].fullName);
  });

  it('does not execute query when there are no exceptions', () => {
    createComponent();
    expect(requestHandler).toHaveBeenCalledTimes(0);
  });
});
