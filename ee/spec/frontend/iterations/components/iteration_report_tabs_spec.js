import { GlAlert, GlBadge, GlEmptyState, GlFormSelect, GlLabel } from '@gitlab/ui';
import { getByText } from '@testing-library/dom';
import { mount, shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import IterationReportIssues from 'ee/iterations/components/iteration_report_issues.vue';
import IterationReportTabs from 'ee/iterations/components/iteration_report_tabs.vue';
import iterationIssuesQuery from 'ee/iterations/queries/iteration_issues.query.graphql';
import iterationIssuesWithLabelFilterQuery from 'ee/iterations/queries/iteration_issues_with_label_filter.query.graphql';
import { GROUP_BY_LABEL } from 'ee/iterations/constants';
import { NAMESPACE_GROUP } from '~/issues/constants';
import LabelsSelect from '~/sidebar/components/labels/labels_select_vue/labels_select_root.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(VueApollo);

const groupIssuesResponse = {
  data: {
    group: {
      id: 'gid://gitlab/Group/1',
      issues: {
        count: 0,
        nodes: [],
        pageInfo: {
          hasNextPage: false,
          hasPreviousPage: false,
          startCursor: null,
          endCursor: null,
          __typename: 'PageInfo',
        },
        __typename: 'IssueConnection',
      },
      __typename: 'Group',
    },
  },
};

describe('Iterations report tabs', () => {
  let wrapper;
  const id = 3;
  const fullPath = 'gitlab-org';
  const defaultProps = {
    fullPath,
    iterationId: `gid://gitlab/Iteration/${id}`,
    namespaceType: NAMESPACE_GROUP,
    totalIterationIssueCount: 100,
  };

  const findGlFormSelectOptionAt = (index) =>
    wrapper.findComponent(GlFormSelect).findAll('option').at(index);
  const findNoIssuesAlert = () => wrapper.findComponent(GlAlert);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findIterationReportIssues = () => wrapper.findComponent(IterationReportIssues);
  const findAllIterationReportIssues = () => wrapper.findAllComponents(IterationReportIssues);
  const findIterationReportIssuesAt = (index) =>
    wrapper.findAllComponents(IterationReportIssues).at(index);
  const findLabelsSelect = () => wrapper.findComponent(LabelsSelect);

  const mountComponent = ({
    props = defaultProps,
    data = {},
    mountFunction = shallowMount,
    issuesQueryHandler = jest.fn().mockResolvedValue(groupIssuesResponse),
    labelFilterQueryHandler = jest.fn().mockResolvedValue(groupIssuesResponse),
  } = {}) => {
    wrapper = mountFunction(IterationReportTabs, {
      apolloProvider: createMockApollo([
        [iterationIssuesQuery, issuesQueryHandler],
        [iterationIssuesWithLabelFilterQuery, labelFilterQueryHandler],
      ]),
      propsData: props,
      data() {
        return data;
      },
      provide: {
        hasStatusFeature: true,
      },
      stubs: {
        WorkItemStatusBadge: true,
      },
    });
  };

  describe('IterationReportIssues component', () => {
    it('is rendered', () => {
      mountComponent();

      expect(findIterationReportIssues().isVisible()).toBe(true);
    });

    it('updates the issue count when issues-update is emitted', async () => {
      mountComponent({ mountFunction: mount });

      // Let the child component's query resolve first so its own issues-update
      // emission cannot race past the manual emission below.
      await waitForPromises();

      const issueCount = 7;

      findIterationReportIssues().vm.$emit('issues-update', { count: issueCount });

      await nextTick();

      expect(wrapper.findComponent(GlBadge).text()).toBe(issueCount.toString());
    });
  });

  describe('group by section', () => {
    describe('select dropdown', () => {
      beforeEach(() => {
        mountComponent({ mountFunction: mount });
      });

      it('shows label', () => {
        expect(getByText(wrapper.element, 'Group by')).not.toBeNull();
      });

      it('has `None` option', () => {
        expect(findGlFormSelectOptionAt(0).text()).toBe('None');
      });

      it('has `Label` option', () => {
        expect(findGlFormSelectOptionAt(1).text()).toBe('Label');
      });
    });

    describe('label picker', () => {
      describe('when group by `None` option is selected', () => {
        beforeEach(() => {
          mountComponent();
        });

        it('is not shown', () => {
          expect(findLabelsSelect().exists()).toBe(false);
        });
      });

      describe('when group by `Label` option is selected', () => {
        beforeEach(() => {
          mountComponent({ data: { groupBySelection: GROUP_BY_LABEL } });
        });

        it('is shown', () => {
          expect(getByText(wrapper.element, 'Filter by label')).not.toBeNull();
          expect(findLabelsSelect().exists()).toBe(true);
        });
      });
    });
  });

  describe('issues grouped by labels', () => {
    const selectedLabels = [
      {
        id: 40,
        title: 'Security',
        color: '#aaa',
        description: 'Security description',
        text_color: '#fff',
        set: true,
      },
      {
        id: 55,
        title: 'Tooling',
        color: '#bbb',
        description: 'Tooling description',
        text_color: '#eee',
        set: true,
      },
    ];

    beforeEach(() => {
      mountComponent({ data: { groupBySelection: GROUP_BY_LABEL } });
    });

    describe('when labels with issues are selected', () => {
      beforeEach(() => {
        // User groups issues by 2 labels
        findLabelsSelect().vm.$emit('update-selected-labels', selectedLabels);

        // API call updates for the 2 labels are emitted
        findIterationReportIssues().vm.$emit('issues-update', {
          count: 3,
          labelId: selectedLabels[0].id,
        });
        findIterationReportIssues().vm.$emit('issues-update', {
          count: 2,
          labelId: selectedLabels[1].id,
        });
      });

      it('does not show an alert', () => {
        expect(findNoIssuesAlert().exists()).toBe(false);
      });

      it('does not show empty state', () => {
        expect(findEmptyState().exists()).toBe(false);
      });

      it('shows 3 IterationReportIssues blocks (one for `Security`, one for `Tooling`, and one for the hidden ungrouped list)', () => {
        expect(findAllIterationReportIssues()).toHaveLength(3);
      });

      it('shows issues for `Security` label', () => {
        expect(findIterationReportIssuesAt(0).props()).toMatchObject({ label: selectedLabels[0] });
      });

      it('shows issues for `Tooling` label', () => {
        expect(findIterationReportIssuesAt(1).props()).toMatchObject({ label: selectedLabels[1] });
      });

      it('hides issues for the ungrouped issues list', () => {
        expect(findIterationReportIssuesAt(2).isVisible()).toBe(false);
      });

      it('hides label issues when the label is removed', async () => {
        expect(findAllIterationReportIssues()).toHaveLength(3);

        await findIterationReportIssues().vm.$emit('remove-label', selectedLabels[0].id);

        expect(findAllIterationReportIssues()).toHaveLength(2);
        expect(findIterationReportIssuesAt(0).props()).toMatchObject({ label: selectedLabels[1] });
        expect(findIterationReportIssuesAt(1).isVisible()).toBe(false);
      });
    });

    describe('when labels with issues and no issues are selected', () => {
      beforeEach(() => {
        // User groups issues by 2 labels
        findLabelsSelect().vm.$emit('update-selected-labels', selectedLabels);

        // API call updates for the 2 labels are emitted
        findIterationReportIssues().vm.$emit('issues-update', {
          count: 3,
          labelId: selectedLabels[0].id,
        });
        findIterationReportIssues().vm.$emit('issues-update', {
          count: 0,
          labelId: selectedLabels[1].id,
        });
      });

      it('shows an alert to tell the user that labels have no issues', () => {
        expect(findNoIssuesAlert().text()).toBe('Labels with no issues in this iteration:');
      });

      it('shows the label with no issue, `Tooling`, in the alert', () => {
        expect(findNoIssuesAlert().findComponent(GlLabel).props()).toMatchObject({
          backgroundColor: selectedLabels[1].color,
          description: selectedLabels[1].description,
          target: null,
          title: selectedLabels[1].title,
        });
      });

      it('does not show empty state', () => {
        expect(findEmptyState().exists()).toBe(false);
      });

      it('shows 2 IterationReportIssues blocks (one for `Security`, and one for the hidden ungrouped list)', () => {
        expect(findAllIterationReportIssues()).toHaveLength(2);
      });

      it('shows issues for `Security` label', () => {
        expect(findIterationReportIssuesAt(0).props()).toMatchObject({ label: selectedLabels[0] });
      });

      it('hides issues for the ungrouped issues list', () => {
        expect(findIterationReportIssuesAt(1).isVisible()).toBe(false);
      });
    });

    describe('when labels with no issues are selected', () => {
      beforeEach(() => {
        // User groups issues by 2 labels
        findLabelsSelect().vm.$emit('update-selected-labels', selectedLabels);

        // API call updates for the 2 labels are emitted
        findIterationReportIssues().vm.$emit('issues-update', {
          count: 0,
          labelId: selectedLabels[0].id,
        });
        findIterationReportIssues().vm.$emit('issues-update', {
          count: 0,
          labelId: selectedLabels[1].id,
        });
      });

      it('shows an alert to tell the user that labels have no issues', () => {
        expect(findNoIssuesAlert().text()).toBe('Labels with no issues in this iteration:');
      });

      it('shows the labels with no issue, `Security` and `Tooling`, in the alert', () => {
        const labels = findNoIssuesAlert().findAllComponents(GlLabel);

        expect(labels.at(0).props('title')).toBe(selectedLabels[0].title);
        expect(labels.at(1).props('title')).toBe(selectedLabels[1].title);
      });

      it('shows empty state', () => {
        expect(findEmptyState().props()).toMatchObject({
          description: 'Try grouping with different labels',
          title: 'There are no issues with the selected labels',
        });
      });

      it('shows 1 IterationReportIssues block (one for the hidden ungrouped list)', () => {
        expect(findAllIterationReportIssues()).toHaveLength(1);
      });

      it('hides issues for the ungrouped issues list', () => {
        expect(findIterationReportIssuesAt(0).isVisible()).toBe(false);
      });
    });
  });
});
