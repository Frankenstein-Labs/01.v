import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox } from '@gitlab/ui';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createAlert } from '~/alert';
import UpstreamSelector from 'ee/packages_and_registries/virtual_registries/components/common/registries/show/upstream_selector.vue';
import getUpstreamsSelectQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_maven_upstreams_select.query.graphql';
import { groupMavenUpstreamsSelect } from 'ee_jest/packages_and_registries/virtual_registries/mock_data';

jest.mock('~/alert', () => ({
  createAlert: jest.fn(),
}));

Vue.use(VueApollo);

describe('UpstreamSelector', () => {
  let wrapper;

  const defaultProps = {
    linkedUpstreamIds: [],
  };

  const { upstreams } = groupMavenUpstreamsSelect.group;
  const [upstream] = upstreams.nodes;
  const { pageInfo } = upstreams;

  const upstreamsHandler = jest.fn().mockResolvedValue({ data: { ...groupMavenUpstreamsSelect } });

  const waitForDebouncedPromises = async () => {
    jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
    await waitForPromises();
  };

  const createComponent = ({
    props = defaultProps,
    handlers = [[getUpstreamsSelectQuery, upstreamsHandler]],
  } = {}) => {
    wrapper = shallowMountExtended(UpstreamSelector, {
      apolloProvider: createMockApollo(handlers),
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        fullPath: 'full-path',
        getUpstreamsSelectQuery,
      },
    });
  };

  const findDropdown = () => wrapper.findComponent(GlCollapsibleListbox);

  it('renders GlCollapsible listbox with right props', async () => {
    createComponent();
    await waitForDebouncedPromises();

    expect(findDropdown().props()).toMatchObject({
      block: true,
      toggleId: 'upstream-select',
      toggleText: 'Select an upstream',
      infiniteScroll: true,
      searchable: true,
      searching: false,
      noResultsText: 'No matching results',
      infiniteScrollLoading: false,
    });

    const { ___typename, ...rest } = upstream;

    expect(findDropdown().props('items')).toStrictEqual([rest]);
  });

  it('calls getUpstreamsQuery on mount', async () => {
    createComponent();
    await waitForDebouncedPromises();

    expect(upstreamsHandler).toHaveBeenCalledTimes(1);
    expect(upstreamsHandler).toHaveBeenCalledWith({
      groupPath: 'full-path',
      upstreamName: '',
      first: 20,
    });
    expect(createAlert).not.toHaveBeenCalled();
  });

  describe('when linked upstreams exist', () => {
    const linkedUpstreamIds = [upstream.value];
    beforeEach(async () => {
      createComponent({
        props: {
          linkedUpstreamIds,
        },
      });
      await waitForDebouncedPromises();
    });

    it('filters out linked upstreams from the dropdown items', () => {
      expect(findDropdown().props('items')).toStrictEqual([]);
    });
  });

  describe('when `getUpstreamsSelectQuery` query fails', () => {
    const error = new Error('GraphQL error');

    beforeEach(async () => {
      createComponent({
        handlers: [[getUpstreamsSelectQuery, jest.fn().mockRejectedValue(error)]],
      });
      await waitForDebouncedPromises();
    });

    it('calls createAlert', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Failed to fetch upstreams. Please try again.',
        error,
        captureError: true,
      });
    });
  });

  describe('when listbox emits `bottom-reached` event', () => {
    describe('and does not have next page', () => {
      beforeEach(async () => {
        createComponent();
        await waitForDebouncedPromises();

        await findDropdown().vm.$emit('bottom-reached');
        await waitForDebouncedPromises();
      });

      it('does not call getUpstreamsSelect', () => {
        expect(upstreamsHandler).toHaveBeenCalledTimes(1);
        expect(upstreamsHandler).not.toHaveBeenCalledWith({
          groupPath: 'full-path',
          upstreamName: '',
          first: 20,
          after: 'end',
        });
      });
    });

    describe('and has next page', () => {
      const multiplePagesHandler = jest.fn().mockResolvedValue({
        data: {
          ...groupMavenUpstreamsSelect,
          group: {
            ...groupMavenUpstreamsSelect.group,
            upstreams: {
              ...groupMavenUpstreamsSelect.group.upstreams,
              pageInfo: {
                ...pageInfo,
                hasNextPage: true,
              },
            },
          },
        },
      });

      beforeEach(async () => {
        createComponent({
          handlers: [[getUpstreamsSelectQuery, multiplePagesHandler]],
        });
        await waitForDebouncedPromises();

        await findDropdown().vm.$emit('bottom-reached');
      });

      it('calls getUpstreamsSelect with page params', () => {
        expect(multiplePagesHandler).toHaveBeenCalledTimes(2);
        expect(multiplePagesHandler).toHaveBeenCalledWith({
          groupPath: 'full-path',
          upstreamName: '',
          first: 20,
          after: 'end',
        });
      });

      it('sets `infiniteScrollLoading` true', () => {
        expect(findDropdown().props()).toMatchObject({
          infiniteScrollLoading: true,
          searching: false,
        });
      });

      it('does not call getUpstreamsSelect multiple times when request is in progress', async () => {
        await findDropdown().vm.$emit('bottom-reached');
        await findDropdown().vm.$emit('bottom-reached');
        await waitForDebouncedPromises();

        expect(multiplePagesHandler).toHaveBeenCalledTimes(2);
        expect(multiplePagesHandler).toHaveBeenLastCalledWith({
          groupPath: 'full-path',
          upstreamName: '',
          first: 20,
          after: 'end',
        });
      });
    });
  });

  describe('when listbox emits `search` event', () => {
    beforeEach(async () => {
      createComponent();
      await waitForDebouncedPromises();
    });

    it('calls getUpstreamsQuery with search term', async () => {
      await findDropdown().vm.$emit('search', 'Maven');
      jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS);

      expect(upstreamsHandler).toHaveBeenCalledTimes(2);
      expect(upstreamsHandler).toHaveBeenLastCalledWith({
        groupPath: 'full-path',
        upstreamName: 'Maven',
        first: 20,
      });
    });

    it('sets `searching` true', async () => {
      await findDropdown().vm.$emit('search', 'Maven');
      jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
      await nextTick();

      expect(findDropdown().props()).toMatchObject({
        searching: true,
        infiniteScrollLoading: false,
      });
    });
  });

  describe('when listbox emits `select` event', () => {
    beforeEach(async () => {
      createComponent();
      await waitForDebouncedPromises();
      await findDropdown().vm.$emit('select', upstream.value);
    });

    it('emits select event with the selected upstream ID', () => {
      expect(wrapper.emitted('select')).toEqual([[upstream.value]]);
    });

    it('sets listbox toggleText prop', async () => {
      await nextTick();
      expect(findDropdown().props('toggleText')).toBe(upstream.text);
    });
  });
});
