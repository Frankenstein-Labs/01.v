import { nextTick } from 'vue';
import { mount, shallowMount } from '@vue/test-utils';
import { GlEmptyState, GlKeysetPagination, GlProgressBar, GlTable } from '@gitlab/ui';
import FrameworkCoverage from 'ee/compliance_dashboard/components/dashboard/framework_coverage.vue';
import FrameworkBadge from 'ee/compliance_dashboard/components/shared/framework_badge.vue';
import { ROUTE_PROJECTS } from 'ee/compliance_dashboard/constants';

describe('Framework coverage panel', () => {
  let wrapper;
  const pushMock = jest.fn();

  function createComponent({
    details = [],
    totalProjects = 0,
    groupNamespaceId = 'gid://gitlab/Group/1',
    coveredCount = 0,
    mountFn = shallowMount,
  } = {}) {
    wrapper = mountFn(FrameworkCoverage, {
      propsData: {
        summary: {
          totalProjects,
          coveredCount,
          details,
          groupId: groupNamespaceId,
        },
        isTopLevelGroup: true,
      },
      mocks: {
        $router: {
          push: pushMock,
        },
      },
      stubs: { FrameworkBadge },
    });
  }

  const generateDetails = (count, { totalProjects = 100 } = {}) =>
    Array.from({ length: count }, (_, idx) => ({
      id: idx + 1,
      coveredCount: Math.min(idx + 1, totalProjects),
      framework: {
        id: `gid://gitlab/ComplianceManagement::Framework/${idx + 1}`,
        name: `Framework ${idx + 1}`,
        color: '#6699CC',
        namespaceId: 'gid://gitlab/Group/1',
      },
    }));

  const findTable = () => wrapper.findComponent(GlTable);
  const findTableItems = () => findTable().props('items');
  const findFrameworkBadges = () => wrapper.findAllComponents(FrameworkBadge);
  const findProgressBars = () => wrapper.findAllComponents(GlProgressBar);
  const findPagination = () => wrapper.findComponent(GlKeysetPagination);

  beforeEach(() => {
    pushMock.mockClear();
  });

  it('renders empty state when no frameworks are available', () => {
    createComponent();
    expect(wrapper.findComponent(GlEmptyState).exists()).toBe(true);
    expect(findTable().exists()).toBe(false);
  });

  it('renders a table when frameworks are available', () => {
    createComponent({
      details: [{ id: 1, coveredCount: 10, framework: { namespaceId: 'gid://gitlab/Group/1' } }],
    });
    expect(findTable().exists()).toBe(true);
    expect(wrapper.findComponent(GlEmptyState).exists()).toBe(false);
  });

  it('takes to projects tab when a row is clicked', () => {
    createComponent({
      details: [{ id: 1, coveredCount: 10, framework: { namespaceId: 'gid://gitlab/Group/1' } }],
    });

    findTable().vm.$emit('row-clicked');
    expect(pushMock).toHaveBeenCalledWith({ name: ROUTE_PROJECTS });
  });

  describe('items building', () => {
    const totalProjects = 100;
    const groupNamespaceId = 'gid://gitlab/Group/1';
    const details = [
      {
        id: 1,
        coveredCount: 5,
        framework: { id: 1, name: 'Framework A', namespaceId: groupNamespaceId },
      },
      {
        id: 2,
        coveredCount: 15,
        framework: { id: 2, name: 'Framework B', namespaceId: groupNamespaceId },
      },
      {
        id: 3,
        coveredCount: 10,
        framework: { id: 3, name: 'Framework C', namespaceId: groupNamespaceId },
      },
    ];

    it('sorts framework rows by coverage in descending order by default, without an aggregate row', () => {
      createComponent({ details, totalProjects, groupNamespaceId, coveredCount: 30 });

      const items = findTableItems();

      expect(items).toHaveLength(3);
      expect(items.map((item) => item.framework.name)).toEqual([
        'Framework B',
        'Framework C',
        'Framework A',
      ]);
      expect(items.map((item) => item.coverage)).toEqual([15, 10, 5]);
    });

    it('re-sorts rows when the sort direction changes', async () => {
      createComponent({ details, totalProjects, groupNamespaceId, coveredCount: 30 });

      findTable().vm.$emit('sort-changed', { sortBy: 'coverage', sortDesc: false });
      await nextTick();

      expect(findTableItems().map((item) => item.coverage)).toEqual([5, 10, 15]);
    });

    it('computes coverage as a rounded percentage of total projects', () => {
      createComponent({
        details: [details[1]],
        totalProjects: 40,
        groupNamespaceId,
        coveredCount: 15,
      });

      expect(findTableItems()[0].coverage).toBe(38);
    });
  });

  describe('pagination', () => {
    it('does not render pagination when frameworks fit on one page', () => {
      createComponent({ details: generateDetails(20), totalProjects: 100 });

      expect(findPagination().exists()).toBe(false);
    });

    describe('with more than one page of frameworks', () => {
      beforeEach(() => {
        createComponent({ details: generateDetails(25), totalProjects: 100 });
      });

      it('renders pagination limited to the first page of items', () => {
        expect(findPagination().exists()).toBe(true);
        expect(findPagination().props()).toMatchObject({
          hasPreviousPage: false,
          hasNextPage: true,
        });
        expect(findTableItems()).toHaveLength(20);
      });

      it('shows the next page of items when next is clicked', async () => {
        findPagination().vm.$emit('next');
        await nextTick();

        expect(findTableItems()).toHaveLength(5);
        expect(findPagination().props()).toMatchObject({
          hasPreviousPage: true,
          hasNextPage: false,
        });
      });

      it('returns to the previous page of items when prev is clicked', async () => {
        findPagination().vm.$emit('next');
        await nextTick();
        findPagination().vm.$emit('prev');
        await nextTick();

        expect(findTableItems()).toHaveLength(20);
        expect(findPagination().props('hasPreviousPage')).toBe(false);
      });

      it('resets to the first page when the sort changes', async () => {
        findPagination().vm.$emit('next');
        await nextTick();

        findTable().vm.$emit('sort-changed', { sortBy: 'coverage', sortDesc: false });
        await nextTick();

        expect(findTableItems()).toHaveLength(20);
        expect(findPagination().props('hasPreviousPage')).toBe(false);
      });
    });
  });

  describe('per-row rendering', () => {
    const totalProjects = 100;
    const groupNamespaceId = 'gid://gitlab/Group/1';
    const details = [
      {
        id: 1,
        coveredCount: 10,
        framework: {
          id: 'gid://gitlab/ComplianceManagement::Framework/1',
          name: 'Local Framework',
          color: '#6699CC',
          namespaceId: groupNamespaceId,
        },
      },
      {
        id: 2,
        coveredCount: 20,
        framework: {
          id: 'gid://gitlab/ComplianceManagement::Framework/2',
          name: 'Centralized Framework',
          color: '#CC6699',
          namespaceId: 'gid://gitlab/Group/999',
        },
      },
    ];

    beforeEach(() => {
      createComponent({
        details,
        totalProjects,
        groupNamespaceId,
        coveredCount: 25,
        mountFn: mount,
      });
    });

    it('renders one FrameworkBadge per framework row', () => {
      expect(findFrameworkBadges()).toHaveLength(2);
    });

    it('marks the centralized framework row as centralized and the local one as not', () => {
      const items = findTableItems();

      const local = items.find((item) => item.framework.name === 'Local Framework');
      const centralized = items.find((item) => item.framework.name === 'Centralized Framework');

      expect(local.isCentralized).toBe(false);
      expect(centralized.isCentralized).toBe(true);
    });

    it('renders a GlProgressBar with correct value/max for every row', () => {
      const progressBars = findProgressBars();

      expect(progressBars).toHaveLength(2);
      expect(progressBars.at(0).props()).toMatchObject({ value: 20, max: totalProjects });
      expect(progressBars.at(1).props()).toMatchObject({ value: 10, max: totalProjects });
    });

    it('renders the coverage percentage next to each progress bar', () => {
      const rows = wrapper.findAll('tbody tr');

      expect(rows.at(0).text()).toContain('20%');
      expect(rows.at(1).text()).toContain('10%');
    });
  });
});
