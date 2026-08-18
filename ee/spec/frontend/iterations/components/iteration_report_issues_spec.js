import {
  GlAlert,
  GlAvatar,
  GlBadge,
  GlButton,
  GlLabel,
  GlKeysetPagination,
  GlSkeletonLoader,
  GlTable,
} from '@gitlab/ui';
import { mount, shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import IterationReportIssues from 'ee/iterations/components/iteration_report_issues.vue';
import iterationIssuesQuery from 'ee/iterations/queries/iteration_issues.query.graphql';
import iterationIssuesWithLabelFilterQuery from 'ee/iterations/queries/iteration_issues_with_label_filter.query.graphql';
import { NAMESPACE_GROUP, NAMESPACE_PROJECT } from '~/issues/constants';
import WorkItemTypeIcon from '~/work_items/components/work_item_type_icon.vue';
import WorkItemStatusBadge from 'ee/work_items/components/shared/work_item_status_badge.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

jest.mock('ee/work_items/components/shared/work_item_status_badge.vue', () => ({
  name: 'WorkItemStatusBadge',
  template: '<div class="work-item-status-badge-mock"></div>',
  props: ['item'],
}));

Vue.use(VueApollo);

const emptyIssuesConnection = {
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
};

const groupIssuesResponse = {
  data: {
    group: {
      id: 'gid://gitlab/Group/1',
      issues: emptyIssuesConnection,
      __typename: 'Group',
    },
  },
};

const projectIssuesResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      issues: emptyIssuesConnection,
      __typename: 'Project',
    },
  },
};

describe('Iterations report issues', () => {
  let wrapper;
  const id = 3;
  const fullPath = 'gitlab-org';
  const label = {
    id: 17,
    title: 'Bug',
    color: '#123456',
    description: 'Bug label description',
    scoped: false,
  };
  const defaultProps = {
    fullPath,
    iterationId: `gid://gitlab/Iteration/${id}`,
    hasInaccessibleIssues: false,
  };

  const findGlBadge = () => wrapper.findComponent(GlBadge);
  const findGlButton = () => wrapper.findComponent(GlButton);
  const findGlLabel = () => wrapper.findComponent(GlLabel);
  const findGlSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findGlKeysetPagination = () => wrapper.findComponent(GlKeysetPagination);
  const findGlTable = () => wrapper.findComponent(GlTable);
  const findHeading = () => wrapper.find('h4');
  const findSection = () => wrapper.find('section');
  const findInaccessibleIssuesLabel = () =>
    wrapper.find('[data-testid="has-inaccessible-issues-label"]');

  const mountComponent = ({
    props = defaultProps,
    data = {},
    mountFunction = shallowMount,
    issuesQueryHandler = jest.fn().mockResolvedValue(groupIssuesResponse),
    labelFilterQueryHandler = jest.fn().mockResolvedValue(groupIssuesResponse),
  } = {}) => {
    wrapper = mountFunction(IterationReportIssues, {
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
        WorkItemStatusBadge,
      },
    });
  };

  it('shows warning about inaccessible confidential issues', () => {
    mountComponent({
      props: {
        ...defaultProps,
        hasInaccessibleIssues: true,
      },
    });

    expect(findInaccessibleIssuesLabel().exists()).toBe(true);
  });

  it('shows spinner while loading', () => {
    mountComponent();

    expect(findGlSkeletonLoader().exists()).toBe(true);
    expect(findGlTable().isVisible()).toBe(false);
  });

  it('shows iterations list when not loading', async () => {
    mountComponent({ mountFunction: mount });

    await waitForPromises();

    expect(findGlSkeletonLoader().isVisible()).toBe(false);
    expect(findGlTable().exists()).toBe(true);
    expect(wrapper.text()).toContain('No issues found');
  });

  it('shows error in a gl-alert', () => {
    const error = 'Oh no!';

    mountComponent({
      data: {
        error,
      },
    });

    expect(wrapper.findComponent(GlAlert).text()).toContain(error);
  });

  describe('with issues', () => {
    const pageSize = 20;
    const totalIssues = pageSize + 1;

    const assignees = Array(totalIssues)
      .fill(null)
      .map((_, i) => ({
        id: i,
        name: `User ${i}`,
        username: `user${i}`,
        state: 'active',
        avatarUrl: 'http://invalid/avatar.png',
        webUrl: `https://localhost:3000/user${i}`,
      }));

    const labels = Array(2)
      .fill(null)
      .map((_, i) => ({
        id: i,
        color: '#000',
        description: `Label ${i} description`,
        text_color: '#fff',
        title: `Label ${i}`,
      }));

    const issues = Array(totalIssues)
      .fill(null)
      .map((_, i) => ({
        id: i,
        title: `Issue ${i}`,
        assignees: assignees.slice(0, i),
        labels,
        weight: i,
        type: 'ISSUE',
        status: {
          name: i % 2 ? 'In Progress' : 'Open',
          iconName: i % 2 ? 'status-in-progress' : 'status-open',
          color: i % 2 ? '#00b140' : '#418644',
        },
      }));

    const findIssues = () => wrapper.findAll('table tbody tr');
    const findAssigneesForIssue = (index) => findIssues().at(index).findAllComponents(GlAvatar);
    const findLabelsForIssue = (index) => findIssues().at(index).findAllComponents(GlLabel);
    const findWeightsForIssue = (index) => findIssues().at(index).findAll('td').at(1);
    const findWorkItemTypeIconForIssue = (index) =>
      findIssues().at(index).findComponent(WorkItemTypeIcon);

    describe('issue_list', () => {
      beforeEach(() => {
        const data = {
          issues: {
            list: issues.map((issue) => ({
              ...issue,
              status: issue.status
                ? {
                    name: issue.status.name,
                    iconName: issue.status.iconName,
                    color: issue.status.color,
                  }
                : null,
            })),
            pageInfo: {
              hasNextPage: true,
              hasPreviousPage: false,
              startCursor: 'first-item',
              endCursor: 'last-item',
            },
            count: issues.length,
          },
        };

        mountComponent({
          data,
          mountFunction: mount,
          provide: {
            hasStatusFeature: true,
          },
        });
      });

      it('shows issue list in table', () => {
        expect(findGlTable().exists()).toBe(true);
        expect(findIssues()).toHaveLength(issues.length);
      });

      it('shows work item type icon for each issue, with the correct workItemType prop passed', () => {
        const workItemTypeIconForFirstIssue = findWorkItemTypeIconForIssue(0);
        expect(workItemTypeIconForFirstIssue.exists()).toBe(true);
        expect(workItemTypeIconForFirstIssue.props().workItemType).toBe('ISSUE');
      });

      it('shows labels', () => {
        const labelsForFirstIssue = findLabelsForIssue(0);
        expect(labelsForFirstIssue).toHaveLength(2);
        expect(labelsForFirstIssue.at(0).props('title')).toBe(labels[0].title);
        expect(labelsForFirstIssue.at(1).props('title')).toBe(labels[1].title);
      });

      it('shows assignees', () => {
        expect(findAssigneesForIssue(0)).toHaveLength(0);
        expect(findAssigneesForIssue(1)).toHaveLength(1);
        expect(findAssigneesForIssue(10)).toHaveLength(10);
      });

      it('shows weight', () => {
        expect(findWeightsForIssue(0).text()).toBe('0');
        expect(findWeightsForIssue(5).text()).toBe('5');
        expect(findWeightsForIssue(8).text()).toBe('8');
      });

      it('shows status badges', () => {
        const statusBadges = wrapper.findAllComponents(WorkItemStatusBadge);
        expect(statusBadges).toHaveLength(issues.length);
        expect(statusBadges.at(0).props().item).toEqual({
          name: 'Open',
          iconName: 'status-open',
          color: '#418644',
        });
      });
    });

    describe('pagination', () => {
      beforeEach(() => {
        const data = {
          issues: {
            list: issues,
            pageInfo: {
              hasNextPage: true,
              hasPreviousPage: false,
              startCursor: 'first-item',
              endCursor: 'last-item',
            },
            count: issues.length,
          },
        };

        mountComponent({ data });
      });

      const findPagination = () => wrapper.findComponent(GlKeysetPagination);

      it('passes hasNextPage and hasPreviousPage props', () => {
        expect(findPagination().exists()).toBe(true);
        expect(findPagination().props()).toMatchObject({
          hasNextPage: true,
          hasPreviousPage: false,
        });
      });

      it('updates query variables when going to previous page', async () => {
        findPagination().vm.$emit('prev');
        await nextTick();

        expect(wrapper.vm.queryVariables).toEqual({
          beforeCursor: 'first-item',
          fullPath,
          id,
          lastPageSize: 20,
          isGroup: true,
        });
      });

      it('updates query variables when going to next page', async () => {
        findPagination().vm.$emit('next');
        await nextTick();

        expect(wrapper.vm.queryVariables).toEqual({
          afterCursor: 'last-item',
          fullPath,
          id,
          firstPageSize: 20,
          isGroup: true,
        });
      });
    });
  });

  describe('IterationReportTabs query variables', () => {
    const expected = {
      afterCursor: undefined,
      firstPageSize: 20,
      fullPath: defaultProps.fullPath,
      id,
    };

    describe('when group', () => {
      it('has expected query variable values', () => {
        mountComponent({
          props: {
            ...defaultProps,
            namespaceType: NAMESPACE_GROUP,
          },
        });

        expect(wrapper.vm.queryVariables).toEqual({
          ...expected,
          isGroup: true,
        });
      });
    });

    describe('when project', () => {
      it('has expected query variable values', () => {
        mountComponent({
          props: {
            ...defaultProps,
            namespaceType: NAMESPACE_PROJECT,
          },
          issuesQueryHandler: jest.fn().mockResolvedValue(projectIssuesResponse),
        });

        expect(wrapper.vm.queryVariables).toEqual({
          ...expected,
          isGroup: false,
        });
      });
    });
  });

  describe('when a label is provided', () => {
    const count = 4;

    beforeEach(() => {
      mountComponent({
        props: { ...defaultProps, label },
        data: {
          issues: {
            pageInfo: {
              hasNextPage: true,
              hasPreviousPage: false,
            },
            count,
          },
        },
      });
    });

    it('has heading (that contains the label) that is visually hidden', () => {
      expect(findHeading().text()).toBe(`Issues with label ${label.title}`);
      expect(findHeading().classes('gl-sr-only')).toBe(true);
    });

    it('has section that is labelled by the heading', () => {
      const headingId = findHeading().attributes('id');
      expect(findSection().attributes('aria-labelledby')).toBe(headingId);
    });

    it('shows button to expand/collapse the table', () => {
      expect(findGlButton().props('icon')).toBe('chevron-down');
      expect(findGlButton().attributes('aria-label')).toBe('Collapse issues');
    });

    it('shows label with the label title', () => {
      expect(findGlLabel().props()).toMatchObject({
        backgroundColor: label.color,
        description: label.description,
        showCloseButton: true,
        target: null,
        title: label.title,
      });
    });

    it('emits remove-label event when label `x` is clicked', () => {
      findGlLabel().vm.$emit('close');

      expect(wrapper.emitted('remove-label')).toEqual([[label.id]]);
    });

    it('shows badge with issue count', () => {
      expect(findGlBadge().text()).toBe(count.toString());
      expect(findGlBadge().attributes('aria-label')).toBe(`${count} issues`);
    });

    it('shows table with grey background', () => {
      expect(findGlTable().attributes('tbody-tr-class')).toBe('gl-bg-subtle');
    });
  });

  describe('when a label is not provided', () => {
    beforeEach(() => {
      mountComponent();
    });

    it('has heading that is visually hidden', () => {
      expect(findHeading().text()).toBe('All issues');
      expect(findHeading().classes('gl-sr-only')).toBe(true);
    });

    it('has section that is labelled by the heading', () => {
      const headingId = findHeading().attributes('id');
      expect(findSection().attributes('aria-labelledby')).toBe(headingId);
    });

    it('hides button to expand/collapse the table', () => {
      expect(findGlButton().exists()).toBe(false);
    });

    it('hides label with the label title', () => {
      expect(findGlLabel().exists()).toBe(false);
    });

    it('hides badge with issue count', () => {
      expect(findGlBadge().exists()).toBe(false);
    });

    it('does not show table with grey background', () => {
      expect(findGlTable().attributes('tbody-tr-class')).toBeUndefined();
    });
  });

  describe('expand/collapse behaviour', () => {
    describe('when expanded', () => {
      beforeEach(async () => {
        mountComponent({
          props: { ...defaultProps, label },
          data: { isExpanded: true },
        });

        await waitForPromises();
      });

      it('hides the issues when the `Collapse` button is clicked', async () => {
        expect(findGlButton().props('icon')).toBe('chevron-down');
        expect(findGlButton().attributes('aria-label')).toBe('Collapse issues');
        expect(findGlTable().isVisible()).toBe(true);
        expect(findGlKeysetPagination().isVisible()).toBe(true);

        await findGlButton().vm.$emit('click');

        expect(findGlButton().props('icon')).toBe('chevron-right');
        expect(findGlButton().attributes('aria-label')).toBe('Expand issues');
        expect(findGlTable().isVisible()).toBe(false);
        expect(findGlKeysetPagination().isVisible()).toBe(false);
      });
    });

    describe('when collapsed', () => {
      beforeEach(async () => {
        mountComponent({
          props: { ...defaultProps, label },
          data: { isExpanded: false },
        });

        await waitForPromises();
      });

      it('shows the issues when the `Expand` button is clicked', async () => {
        expect(findGlButton().props('icon')).toBe('chevron-right');
        expect(findGlButton().attributes('aria-label')).toBe('Expand issues');
        expect(findGlTable().isVisible()).toBe(false);
        expect(findGlKeysetPagination().isVisible()).toBe(false);

        await findGlButton().vm.$emit('click');

        expect(findGlButton().props('icon')).toBe('chevron-down');
        expect(findGlButton().attributes('aria-label')).toBe('Collapse issues');
        expect(findGlTable().isVisible()).toBe(true);
        expect(findGlKeysetPagination().isVisible()).toBe(true);
      });
    });
  });
});
