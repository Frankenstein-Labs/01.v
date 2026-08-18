import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import MergeChecksComponent from '~/vue_merge_request_widget/components/merge_checks.vue';
import StateContainer from '~/vue_merge_request_widget/components/state_container.vue';
import { COMPONENTS } from '~/vue_merge_request_widget/components/checks/constants';
import requestedChangesQuery from 'ee/vue_merge_request_widget/components/checks/queries/requested_changes.query.graphql';

Vue.use(VueApollo);

let wrapper;
let apolloProvider;

function factory(mountFn, { canMerge = true, mergeabilityChecks = [] } = {}) {
  apolloProvider = createMockApollo([
    [
      requestedChangesQuery,
      jest.fn().mockResolvedValue({
        data: {
          project: {
            id: '1',
            mergeRequest: {
              id: '1',
              changeRequesters: {
                nodes: [
                  {
                    id: 'gid://gitlab/User/1',
                    avatarUrl: '/',
                    name: 'Admin',
                    username: 'root',
                    webPath: '/',
                  },
                ],
              },
              userPermissions: {
                canMerge,
              },
            },
          },
        },
      }),
    ],
  ]);

  wrapper = mountFn(MergeChecksComponent, {
    apolloProvider,
    propsData: {
      mr: {},
      service: {},
      mergeChecksState: {
        userPermissions: { canMerge },
        mergeabilityChecks,
      },
      isLoadingMergeChecks: false,
    },
  });
}

const shallowMountComponent = factory.bind(null, shallowMountExtended);

describe('Merge request merge checks component', () => {
  afterEach(() => {
    apolloProvider = null;
  });

  it.each`
    identifier             | componentName
    ${'requested_changes'} | ${'requested_changes'}
  `('renders $identifier merge check', async ({ identifier, componentName }) => {
    shallowMountComponent({
      mergeabilityChecks: [{ status: 'failed', identifier }],
    });

    wrapper.findComponent(StateContainer).vm.$emit('toggle');

    await waitForPromises();

    const { default: component } = await COMPONENTS[componentName]();

    expect(wrapper.findComponent(component).exists()).toBe(true);
  });
});
