import { GlFilteredSearchToken, GlFilteredSearchTokenSegment } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import searchIterationCadencesQuery from 'ee/vue_shared/components/filtered_search_bar/queries/search_iteration_cadences.query.graphql';
import IterationToken from 'ee/vue_shared/components/filtered_search_bar/tokens/iteration_token.vue';
import { mockIterationToken, groupCadencesResponse } from '../mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('IterationToken', () => {
  const id = '123';
  let wrapper;

  const iterationCadencesQueryHandler = jest.fn().mockResolvedValue(groupCadencesResponse);
  const mockApollo = createMockApollo([
    [searchIterationCadencesQuery, iterationCadencesQueryHandler],
  ]);

  const createComponent = ({
    config = mockIterationToken,
    value = { data: '' },
    active = false,
    stubs = {},
    provide = {},
  } = {}) =>
    mount(IterationToken, {
      apolloProvider: mockApollo,
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

  it('renders iteration value', async () => {
    wrapper = createComponent({ value: { data: id } });

    await nextTick();

    const tokenSegments = wrapper.findAllComponents(GlFilteredSearchTokenSegment);

    expect(tokenSegments).toHaveLength(3); // `Iteration` `=` `gitlab-org: #1`
    expect(tokenSegments.at(2).text()).toBe(id.toString());
  });

  it('fetches initial values', () => {
    const fetchIterationsSpy = jest.fn().mockResolvedValue();

    wrapper = createComponent({
      config: { ...mockIterationToken, fetchIterations: fetchIterationsSpy },
      value: { data: id },
    });

    expect(fetchIterationsSpy).toHaveBeenCalledWith(id);
  });

  it('fetches iterations on user input', () => {
    const search = 'hello';
    const fetchIterationsSpy = jest.fn().mockResolvedValue();

    wrapper = createComponent({
      config: { ...mockIterationToken, fetchIterations: fetchIterationsSpy },
    });

    wrapper.findComponent(GlFilteredSearchToken).vm.$emit('input', { data: search });

    expect(fetchIterationsSpy).toHaveBeenCalledWith(search);
  });

  it('fetches iteration cadences when cadence is set', () => {
    const search = 'Current&1';

    wrapper = createComponent();

    wrapper.findComponent(GlFilteredSearchToken).vm.$emit('input', { data: search });

    expect(iterationCadencesQueryHandler).toHaveBeenCalledWith({
      fullPath: mockIterationToken.fullPath,
      id: 'gid://gitlab/Iterations::Cadence/1',
      isProject: mockIterationToken.isProject,
    });
  });

  // A saved view restores the cadence as a `<wildcard>&<cadenceId>` value, so the
  // token has to resolve the cadence rather than look for an iteration with that id.
  it('renders the wildcard and cadence title when a cadence value is set', async () => {
    wrapper = createComponent({ value: { data: 'Current&72' } });

    await waitForPromises();

    const tokenSegments = wrapper.findAllComponents(GlFilteredSearchTokenSegment);

    expect(tokenSegments.at(2).text()).toBe('Current::Cadence 1');
  });

  it('renders error message when request fails', async () => {
    const fetchIterationsSpy = jest.fn().mockRejectedValue();

    wrapper = createComponent({
      config: { ...mockIterationToken, fetchIterations: fetchIterationsSpy },
    });

    await waitForPromises();

    expect(createAlert).toHaveBeenCalledWith({
      message: 'There was a problem fetching iterations.',
    });
  });
});
