import { GlPopover } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import issueQueryResponse from 'test_fixtures/ee/graphql/issuable/popover/queries/issue.query.graphql.json';
import issueQuery from 'ee_else_ce/issuable/popover/queries/issue.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import WorkItemPopover from '~/issuable/popover/components/work_item_popover.vue';
import IssueWeight from 'ee/issues/components/issue_weight.vue';
import IssueStatus from 'ee/work_items/components/shared/work_item_status_badge.vue';

describe('Issue Popover', () => {
  /** @type {import('@vue/test-utils').Wrapper} */
  let wrapper;

  Vue.use(VueApollo);

  const findGlPopover = () => wrapper.findComponent(GlPopover);

  const mountComponent = ({
    queryResponse = jest.fn().mockResolvedValue(issueQueryResponse),
  } = {}) => {
    wrapper = shallowMount(WorkItemPopover, {
      apolloProvider: createMockApollo([[issueQuery, queryResponse]]),
      propsData: {
        target: document.createElement('a'),
        namespacePath: 'foo/bar',
        iid: '1',
        cachedTitle: 'Cached title',
      },
      stubs: {
        IssueWeight,
        IssueStatus,
      },
    });
  };

  beforeAll(async () => {
    // We're doing this Vue3-specific workaround because
    // the first render of GlPopover under Vue3 is empty and only subsequent
    // renders include fully mounted GlPopover.
    if (process.env.VUE_VERSION === '3') {
      mountComponent();
      findGlPopover().vm.$emit('show');
      await waitForPromises();
      wrapper.destroy();
    }
  });

  describe('when loaded', () => {
    beforeEach(async () => {
      mountComponent();
      findGlPopover().vm.$emit('show');
      await waitForPromises();
    });

    it('shows weight', () => {
      const component = wrapper.findComponent(IssueWeight);

      expect(component.exists()).toBe(true);
      expect(component.props('weight')).toBe(3);
    });

    it('shows status', () => {
      const workItemStatus = issueQueryResponse.data.namespace.workItem.widgets.find(
        (w) => w.type === 'STATUS',
      );
      const component = wrapper.findComponent(IssueStatus);

      expect(component.exists()).toBe(true);
      expect(component.props('item')).toEqual(workItemStatus.status);
    });
  });
});
