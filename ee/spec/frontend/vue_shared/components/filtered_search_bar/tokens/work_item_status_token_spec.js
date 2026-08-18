import { GlFilteredSearchToken, GlFilteredSearchTokenSegment } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { createAlert } from '~/alert';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import getAllStatusesQuery from 'ee/issues/dashboard/queries/get_all_statuses.query.graphql';
import WorkItemStatusToken from 'ee/vue_shared/components/filtered_search_bar/tokens/work_item_status_token.vue';
import namespaceWorkItemTypesQuery from '~/work_items/graphql/namespace_work_item_types.query.graphql';
import {
  getAllStatusesQueryResponse,
  namespaceWorkItemTypesQueryResponse,
} from 'jest/work_items/mock_data';
import { mockStatusToken } from '../mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('WorkItemStatusToken', () => {
  const id = '123';
  let wrapper;

  const namespaceQueryHandler = jest.fn().mockResolvedValue(namespaceWorkItemTypesQueryResponse);
  const getAllStatusesQueryHandler = jest.fn().mockResolvedValue(getAllStatusesQueryResponse);
  const findBaseToken = () => wrapper.findComponent(BaseToken);

  const createComponent = ({
    config = mockStatusToken,
    value = { data: '' },
    active = false,
    stubs = {},
    provide = {},
    queryHandler = namespaceQueryHandler,
  } = {}) => {
    wrapper = mount(WorkItemStatusToken, {
      apolloProvider: createMockApollo([
        [namespaceWorkItemTypesQuery, queryHandler],
        [getAllStatusesQuery, getAllStatusesQueryHandler],
      ]),
      propsData: {
        active,
        config,
        value,
        cursorPosition: 'start',
      },
      provide: {
        portalName: 'fake target',
        alignSuggestions: function fakeAlignSuggestions() {},
        suggestionsListClass: () => 'custom-class',
        termsAsTokens: () => false,
        ...provide,
      },
      stubs,
    });
  };

  it('renders custom value', async () => {
    createComponent({ value: { data: id } });

    await nextTick();

    const tokenSegments = wrapper.findAllComponents(GlFilteredSearchTokenSegment);

    expect(tokenSegments).toHaveLength(3); // `Status` `=` `to do`
    expect(tokenSegments.at(2).text()).toBe(id.toString());
  });

  it('fetches statuses for namespace', () => {
    const search = 'Current&1';

    createComponent();

    wrapper.findComponent(GlFilteredSearchToken).vm.$emit('input', { data: search });

    expect(namespaceQueryHandler).toHaveBeenCalledWith({
      fullPath: mockStatusToken.fullPath,
    });
    expect(getAllStatusesQueryHandler).not.toHaveBeenCalled();
  });

  it('fetches all statuses when "fetchAllStatuses: true" for config', () => {
    createComponent({ config: { ...mockStatusToken, fetchAllStatuses: true } });

    wrapper.findComponent(GlFilteredSearchToken).vm.$emit('input', { data: 'search' });

    expect(getAllStatusesQueryHandler).toHaveBeenCalledWith({ name: 'search' });
    expect(namespaceQueryHandler).not.toHaveBeenCalledWith();
  });

  describe('when request fails', () => {
    const namespaceErrorQueryHandler = jest.fn().mockRejectedValue('Ooopsie, error');

    beforeEach(() => {
      createComponent({ queryHandler: namespaceErrorQueryHandler });
      findBaseToken().vm.$emit('fetch-suggestions');
      return waitForPromises();
    });

    it('calls `createAlert` with alert error message', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Options could not be loaded for field: Status. Please try again.',
        captureError: true,
        error: expect.any(Object),
      });
    });

    it('sets `loading` to false when request completes', () => {
      expect(findBaseToken().props('suggestionsLoading')).toBe(false);
    });
  });

  it('renders token item when value is selected', async () => {
    createComponent({
      value: { data: '1' },
    });

    findBaseToken().vm.$emit('fetch-suggestions');
    await waitForPromises();

    const tokenSegments = wrapper.findAllComponents(GlFilteredSearchTokenSegment);
    expect(tokenSegments).toHaveLength(3);
  });

  it('passes correct props to BaseToken', async () => {
    createComponent();

    findBaseToken().vm.$emit('fetch-suggestions');
    await waitForPromises();

    const baseTokenProps = findBaseToken().props();
    expect(baseTokenProps.active).toBe(false);
    expect(baseTokenProps.config).toEqual(mockStatusToken);
    expect(baseTokenProps.suggestions).toEqual([
      expect.objectContaining({ name: 'To do' }),
      expect.objectContaining({ name: 'In progress' }),
      expect.objectContaining({ name: 'In dev' }),
      expect.objectContaining({ name: 'In review' }),
      expect.objectContaining({ name: 'Done' }),
      expect.objectContaining({ name: 'Complete' }),
      expect.objectContaining({ name: "Won't do" }),
      expect.objectContaining({ name: 'Duplicate' }),
    ]);
  });
});
