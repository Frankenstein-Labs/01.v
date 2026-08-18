import { GlButton, GlEmptyState, GlLink, GlTable } from '@gitlab/ui';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import ListWrapper from 'ee/policy_store/components/list/list_wrapper.vue';
import StatsBar from 'ee/policy_store/components/list/stats_bar.vue';

const mockPolicies = [
  {
    id: 1,
    name: 'Production Deployment Approval',
    type: 'Deployment',
    mode: 'enforce',
    status: 'active',
    scopedProjectsCount: 3,
    updated_at: '2024-01-01T00:00:00Z',
    detailPath: 'policy_store/1',
  },
  {
    id: 2,
    name: 'Staging Before Production',
    type: 'Deployment',
    mode: 'warn',
    status: 'active',
    scopedProjectsCount: 1,
    updated_at: '2024-01-02T00:00:00Z',
    detailPath: 'policy_store/2',
  },
  {
    id: 3,
    name: 'Disabled policy',
    type: 'Merge Request',
    mode: 'audit',
    status: 'disabled',
    scopedProjectsCount: 5,
    updated_at: '2024-01-03T00:00:00Z',
    detailPath: 'policy_store/3',
  },
];

describe('ListWrapper', () => {
  let wrapper;

  const createComponent = (propsData = {}) => {
    wrapper = shallowMountExtended(ListWrapper, {
      propsData: { policies: mockPolicies, evaluationsThisWeek: 1233, ...propsData },
      provide: { emptyListSvgPath: '/empty.svg' },
      stubs: {
        GlTable: stubComponent(GlTable, { template: '<div><slot name="empty"></slot></div>' }),
        GlEmptyState: stubComponent(GlEmptyState, {
          template: '<div><slot name="actions"></slot></div>',
        }),
      },
    });
  };

  const findTable = () => wrapper.findComponent(GlTable);
  const findStatsBar = () => wrapper.findComponent(StatsBar);
  const findHeading = () => wrapper.findByTestId('policies-heading');
  const findCreateButton = () => wrapper.findComponent(GlButton);

  it('marks the table busy while the policies load', () => {
    createComponent({ loading: true });

    expect(findTable().attributes('busy')).toBe('true');
  });

  it('renders the "Policies" heading', () => {
    createComponent();

    expect(findHeading().text()).toBe('Policies');
  });

  it('links the create button to the new policy path', () => {
    createComponent({ newPolicyPath: 'policy_store/new' });

    expect(findCreateButton().attributes('href')).toBe('policy_store/new');
  });

  it('links each policy name to its detail path', () => {
    wrapper = mountExtended(ListWrapper, {
      propsData: { policies: mockPolicies, evaluationsThisWeek: 1233 },
      provide: { emptyListSvgPath: '/empty.svg' },
    });

    const links = wrapper.findAllComponents(GlLink).wrappers;

    expect(links.map((link) => link.attributes('href'))).toEqual(
      mockPolicies.map((policy) => policy.detailPath),
    );
  });

  it('passes the active policy count and weekly evaluations to the stats bar', () => {
    createComponent();

    expect(findStatsBar().props('activePolicies')).toBe(2);
    expect(findStatsBar().props('evaluationsThisWeek')).toBe(1233);
  });

  it('excludes non-active policies from the active count', () => {
    createComponent({
      policies: mockPolicies.map((policy) => ({ ...policy, status: 'disabled' })),
    });

    expect(findStatsBar().props('activePolicies')).toBe(0);
  });

  it('renders the policies as table rows without transforming them', () => {
    createComponent();

    expect(findTable().props('items')).toBe(mockPolicies);
  });

  it('makes every column sortable', () => {
    createComponent();

    expect(
      findTable()
        .props('fields')
        .every((field) => field.sortable),
    ).toBe(true);
  });

  describe('empty state', () => {
    const findEmptyState = () => wrapper.findComponent(GlEmptyState);

    it('renders the placeholder when there are no policies', () => {
      createComponent({ policies: [] });

      expect(findEmptyState().props()).toMatchObject({
        title: 'No policies found',
        svgPath: '/empty.svg',
      });
    });

    it('links the placeholder button to the new policy path', () => {
      createComponent({ policies: [], newPolicyPath: 'policy_store/new' });

      expect(wrapper.findByTestId('empty-state-create-button').attributes('href')).toBe(
        'policy_store/new',
      );
    });

    it('hides the table entirely when the fetch failed', () => {
      createComponent({ policies: [], error: true });

      expect(findTable().exists()).toBe(false);
      expect(findEmptyState().exists()).toBe(false);
    });
  });
});
