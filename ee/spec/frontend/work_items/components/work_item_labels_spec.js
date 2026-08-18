import { GlLabel } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import workItemByIidQuery from '~/work_items/graphql/work_item_by_iid.query.graphql';
import WorkItemLabels from '~/work_items/components/work_item_labels.vue';
import { WORK_ITEM_TYPE_NAME_EPIC } from '~/work_items/constants';
import { workItemByIidResponseFactory } from '../mock_data';

Vue.use(VueApollo);

const workItemId = 'gid://gitlab/WorkItem/1';
const epicsListPath = 'groups/some-group/-/epics';

describe('WorkItemLabels component', () => {
  let wrapper;

  const createComponent = async ({
    canUpdate = true,
    workItemQueryHandler = jest.fn().mockResolvedValue(workItemByIidResponseFactory()),
    workItemIid = '1',
    fullPath = 'test-project-path',
    issuesListPath = 'test-project-path/issues',
  } = {}) => {
    wrapper = shallowMountExtended(WorkItemLabels, {
      apolloProvider: createMockApollo([[workItemByIidQuery, workItemQueryHandler]]),
      provide: {
        canAdminLabel: true,
        issuesListPath,
        epicsListPath,
        labelsManagePath: 'test-project-path/labels',
      },
      propsData: {
        fullPath,
        workItemId,
        workItemIid,
        canUpdate,
        workItemType: WORK_ITEM_TYPE_NAME_EPIC,
        isGroup: false,
      },
    });

    await waitForPromises();
  };

  const findScopedLabels = () =>
    wrapper.findAllComponents(GlLabel).filter((label) => label.props('scoped'));

  describe('allows scoped labels', () => {
    it.each([true, false])('= %s', async (allowsScopedLabels) => {
      const workItemQueryHandler = jest
        .fn()
        .mockResolvedValue(workItemByIidResponseFactory({ allowsScopedLabels }));
      await createComponent({ workItemQueryHandler });

      expect(findScopedLabels()).toHaveLength(allowsScopedLabels ? 1 : 0);
    });
  });

  it('uses the epicsListPath when the work item is an epic', async () => {
    await createComponent();

    expect(wrapper.findComponent(GlLabel).props('target')).toContain(epicsListPath);
  });
});
