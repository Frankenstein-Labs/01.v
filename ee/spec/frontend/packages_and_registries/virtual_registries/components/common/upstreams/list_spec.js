import {
  GlAlert,
  GlEmptyState,
  GlFilteredSearch,
  GlKeysetPagination,
  GlSkeletonLoader,
} from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import UpstreamsList from 'ee/packages_and_registries/virtual_registries/components/common/upstreams/list.vue';
import UpstreamsTable from 'ee/packages_and_registries/virtual_registries/components/common/upstreams/table.vue';
import EmptyResult from '~/vue_shared/components/empty_result.vue';
import i18n from 'ee/packages_and_registries/virtual_registries/pages/maven/i18n';
import { groupMavenUpstreams } from '../../../mock_data';

describe('UpstreamsList', () => {
  let wrapper;

  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findFilteredSearch = () => wrapper.findComponent(GlFilteredSearch);
  const findPagination = () => wrapper.findComponent(GlKeysetPagination);
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findUpstreamsTable = () => wrapper.findComponent(UpstreamsTable);
  const findEmptyResult = () => wrapper.findComponent(EmptyResult);

  const createComponent = ({
    upstreams = groupMavenUpstreams.group.upstreams,
    props = {},
  } = {}) => {
    wrapper = shallowMountExtended(UpstreamsList, {
      propsData: {
        upstreams,
        ...props,
      },
      provide: {
        i18n,
      },
    });
  };

  describe('initial state', () => {
    it('shows busy state while loading', () => {
      createComponent({ props: { loading: true, upstreams: { nodes: [] } } });

      expect(findSkeletonLoader().exists()).toBe(true);
      expect(findEmptyState().exists()).toBe(false);
    });
  });

  describe('with upstreams data', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders filtered search', () => {
      expect(findFilteredSearch().props()).toMatchObject({
        placeholder: 'Filter results',
        searchTextOptionLabel: 'Search for this text',
        termsAsTokens: true,
        value: [
          {
            type: 'filtered-search-term',
            value: { data: '' },
          },
        ],
      });
    });

    it('renders upstreams table with transformed data', () => {
      expect(findUpstreamsTable().props('upstreams')).toEqual(
        groupMavenUpstreams.group.upstreams.nodes,
      );
    });

    it('does not show empty state', () => {
      expect(findEmptyState().exists()).toBe(false);
    });

    it('does not show loader', () => {
      expect(findSkeletonLoader().exists()).toBe(false);
    });

    describe('upstreams table events', () => {
      describe('when `upstreamDeleted` event is emitted', () => {
        it('shows info alert and refetches upstreams', async () => {
          await findUpstreamsTable().vm.$emit('upstream-deleted');

          expect(findAlert().props()).toMatchObject({
            variant: 'info',
            dismissible: true,
          });
          expect(findAlert().text()).toBe('Upstream has been deleted.');
          expect(wrapper.emitted('upstream-deleted')).toHaveLength(1);
        });

        it('info alert can be dismissed', async () => {
          await findUpstreamsTable().vm.$emit('upstream-deleted');

          await findAlert().vm.$emit('dismiss');

          expect(findAlert().exists()).toBe(false);
        });
      });

      describe('when `upstreamDeleteFailed` event is emitted', () => {
        it('shows error alert and does not refetch upstreams', async () => {
          await findUpstreamsTable().vm.$emit('upstream-delete-failed', 'error message');

          expect(findAlert().props()).toMatchObject({
            variant: 'danger',
            dismissible: true,
          });
          expect(findAlert().text()).toBe('error message');
        });

        it('error alert can be dismissed', async () => {
          await findUpstreamsTable().vm.$emit('upstream-delete-failed', 'error message');

          await findAlert().vm.$emit('dismiss');

          expect(findAlert().exists()).toBe(false);
        });
      });
    });
  });

  describe('empty state', () => {
    beforeEach(() => {
      createComponent({
        upstreams: { nodes: [] },
      });
    });

    it('renders empty state when no upstreams exist', () => {
      expect(findEmptyState().exists()).toBe(true);
      expect(findEmptyState().props()).toMatchObject({
        title: 'Connect Maven virtual registry to an upstream',
        description: 'Configure an upstream registry to manage Maven artifacts and cache entries.',
      });
    });

    it('does not render filtered search or table', () => {
      expect(findFilteredSearch().exists()).toBe(false);
      expect(findUpstreamsTable().exists()).toBe(false);
    });
  });

  describe('search functionality', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits submit event when filtered search is submitted', async () => {
      await findFilteredSearch().vm.$emit('submit', ['test-search']);

      expect(wrapper.emitted('submit')[0][0]).toBe('test-search');
    });

    it('emits submit event when filtered search is cleared', async () => {
      await findFilteredSearch().vm.$emit('clear');

      expect(wrapper.emitted('submit')[0][0]).toBe(null);
    });
  });

  describe('when searchTerm prop is set', () => {
    beforeEach(() => {
      createComponent({
        props: {
          searchTerm: 'test',
        },
      });
    });

    it('sets searchTerm for GlFilteredSeach', () => {
      expect(findFilteredSearch().props('value')).toStrictEqual([
        {
          type: 'filtered-search-term',
          value: { data: 'test' },
        },
      ]);
    });
  });

  describe('when searchTerm prop is set and there are no upstreams', () => {
    beforeEach(() => {
      createComponent({
        props: {
          searchTerm: 'test',
        },
        upstreams: { nodes: [] },
      });
    });

    it('renders empty result component', () => {
      expect(findEmptyResult().exists()).toBe(true);
    });
  });

  describe('pagination', () => {
    it('configures pagination with correct props', () => {
      createComponent();

      const { pageInfo } = groupMavenUpstreams.group.upstreams;
      const { __typename, ...rest } = pageInfo;

      expect(findPagination().props()).toMatchObject(rest);
    });

    it('sets table busy prop when paginating', () => {
      createComponent({ props: { loading: true } });

      expect(findUpstreamsTable().props('busy')).toBe(true);
    });

    it('emits page-change event with correct parameters on pagination change', async () => {
      createComponent();

      await findPagination().vm.$emit('next');
      await findPagination().vm.$emit('prev');
      expect(wrapper.emitted('page-change')[0][0]).toEqual({ after: 'end' });
      expect(wrapper.emitted('page-change')[1][0]).toEqual({ before: 'start' });
    });
  });
});
