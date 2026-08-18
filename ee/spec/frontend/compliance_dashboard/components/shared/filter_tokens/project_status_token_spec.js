import { GlFilteredSearchToken, GlFilteredSearchSuggestion } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import ProjectStatusToken from 'ee/compliance_dashboard/components/shared/filter_tokens/project_status_token.vue';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';

describe('ProjectStatusToken', () => {
  const config = {
    // Add any required config props
    type: 'project_status',
    title: 'Project Status',
  };

  const value = {
    data: 'archived',
    operator: '=',
  };

  let wrapper;

  const findAllFilteredSearchSuggestions = () =>
    wrapper.findAllComponents(GlFilteredSearchSuggestion);

  const createComponent = (props = {}) => {
    wrapper = extendedWrapper(
      shallowMount(ProjectStatusToken, {
        propsData: {
          config,
          value, // Always provide a valid value to avoid template rendering errors
          ...props,
        },
        stubs: {
          GlFilteredSearchToken: stubComponent(GlFilteredSearchToken, {
            mixins: [glSlotsMixin],
            template: `<div><slot name="view" v-if="glSlots().view"></slot><slot name="suggestions" v-if="glSlots().suggestions"></slot></div>`,
          }),
        },
      }),
    );
  };

  it('displays the correct number of suggestions', () => {
    createComponent();

    expect(findAllFilteredSearchSuggestions()).toHaveLength(3);
    expect(findAllFilteredSearchSuggestions().at(0).text()).toBe('All');
    expect(findAllFilteredSearchSuggestions().at(1).text()).toBe('Archived');
    expect(findAllFilteredSearchSuggestions().at(2).text()).toBe('Non-archived');
  });

  it('displays the correct values for suggestions', () => {
    createComponent();

    const suggestions = findAllFilteredSearchSuggestions();
    expect(suggestions.at(0).props('value')).toBe('all');
    expect(suggestions.at(1).props('value')).toBe('archived');
    expect(suggestions.at(2).props('value')).toBe('non-archived');
  });

  it('computes the correct check when archived value is provided', () => {
    createComponent({ value: { data: 'archived', operator: '=' } });

    const expectedCheck = {
      text: 'Archived',
      value: 'archived',
    };

    expect(wrapper.vm.findActiveCheck).toEqual(expectedCheck);
  });

  it('computes the correct check when non-archived value is provided', () => {
    createComponent({ value: { data: 'non-archived', operator: '=' } });

    const expectedCheck = {
      text: 'Non-archived',
      value: 'non-archived',
    };

    expect(wrapper.vm.findActiveCheck).toEqual(expectedCheck);
  });

  it('computes the correct check when all value is provided', () => {
    createComponent({ value: { data: 'all', operator: '=' } });

    const expectedCheck = {
      text: 'All',
      value: 'all',
    };

    expect(wrapper.vm.findActiveCheck).toEqual(expectedCheck);
  });

  it('passes props and listeners to the gl-filtered-search-token component', () => {
    createComponent();

    const token = wrapper.findComponent(GlFilteredSearchToken);
    expect(token.props('config')).toEqual(
      expect.objectContaining({
        type: 'project_status',
        title: 'Project Status',
        operators: expect.arrayContaining([
          expect.objectContaining({
            value: '=',
            description: 'is',
            default: true,
          }),
        ]),
      }),
    );
    expect(token.props('value')).toEqual(value);
  });
});
