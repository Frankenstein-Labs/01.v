import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import getAiCatalogProjects from 'ee/ai/catalog/graphql/queries/ai_catalog_projects.query.graphql';
import getAvailableProjects from 'ee/ai/catalog/graphql/queries/ai_catalog_available_projects.query.graphql';
import FormProjectMultiSelect from 'ee/ai/catalog/components/form_project_multi_select.vue';
import MultiSelectCheckbox from 'ee/ai/catalog/components/multi_select_checkbox.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { ACCESS_LEVEL_MAINTAINER_STRING } from '~/access_level/constants';
import { mockProjects, mockProjectsResponse, mockAvailableProjectsResponse } from '../mock_data';

Vue.use(VueApollo);

describe('FormProjectMultiSelect', () => {
  let wrapper;
  let mockApollo;

  const defaultProps = {
    id: 'gl-form-field-project',
  };
  const mockAiCatalogProjectsQueryHandler = jest.fn().mockResolvedValue(mockProjectsResponse);
  const mockAvailableProjectsQueryHandler = jest
    .fn()
    .mockResolvedValue(mockAvailableProjectsResponse);

  const createComponent = ({ props = {} } = {}) => {
    mockApollo = createMockApollo([
      [getAiCatalogProjects, mockAiCatalogProjectsQueryHandler],
      [getAvailableProjects, mockAvailableProjectsQueryHandler],
    ]);

    wrapper = shallowMount(FormProjectMultiSelect, {
      apolloProvider: mockApollo,
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findMultiSelectCheckbox = () => wrapper.findComponent(MultiSelectCheckbox);

  it('renders MultiSelectCheckbox with correct props', () => {
    createComponent();

    expect(findMultiSelectCheckbox().props()).toMatchObject({
      id: 'gl-form-field-project',
      query: getAiCatalogProjects,
      queryVariables: {
        minAccessLevel: ACCESS_LEVEL_MAINTAINER_STRING,
        sort: 'similarity',
        searchNamespaces: true,
        duoLicensedFeature: 'AI_CATALOG',
      },
      dataKey: 'projects',
      placeholderText: 'Search projects',
      itemTextFn: expect.any(Function),
      itemLabelFn: expect.any(Function),
      itemSubLabelFn: expect.any(Function),
      itemDisabledFn: expect.any(Function),
      isValid: true,
    });
  });

  it('passes isValid prop to MultiSelectCheckbox', () => {
    createComponent({ props: { isValid: false } });

    expect(findMultiSelectCheckbox().props('isValid')).toBe(false);
  });

  describe('event handling', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits input event with array of ids when MultiSelectCheckbox emits input', async () => {
      await waitForPromises();

      findMultiSelectCheckbox().vm.$emit('input', mockProjects);

      expect(wrapper.emitted('input')).toEqual([[mockProjects.map((project) => project.id)]]);
    });

    it('emits input event with an empty array when MultiSelectCheckbox emits input with no items', () => {
      findMultiSelectCheckbox().vm.$emit('input', []);

      expect(wrapper.emitted('input')).toEqual([[[]]]);
    });

    it('emits error event when MultiSelectCheckbox emits error', () => {
      findMultiSelectCheckbox().vm.$emit('error');

      expect(wrapper.emitted('error')).toEqual([['Failed to load projects']]);
    });
  });

  describe('when itemId is provided', () => {
    const itemId = 'gid://gitlab/Ai::Catalog::Item/1';

    it('uses the available projects query with the itemId and duoLicensedFeature variables', () => {
      createComponent({ props: { itemId } });

      expect(findMultiSelectCheckbox().props()).toMatchObject({
        query: getAvailableProjects,
        queryVariables: {
          itemId,
          minAccessLevel: ACCESS_LEVEL_MAINTAINER_STRING,
          sort: 'similarity',
          searchNamespaces: true,
          duoLicensedFeature: 'AI_CATALOG',
        },
        dataKey: 'projects',
      });
    });

    it('marks already-enabled projects as disabled via itemDisabledFn', () => {
      createComponent({ props: { itemId } });

      const itemDisabledFn = findMultiSelectCheckbox().props('itemDisabledFn');
      const [notEnabled, alreadyEnabled] = mockAvailableProjectsResponse.data.projects.nodes;

      expect(itemDisabledFn(notEnabled)).toBe(false);
      expect(itemDisabledFn(alreadyEnabled)).toBe(true);
    });

    it('keeps the sub-label as the project namespace for all rows', () => {
      createComponent({ props: { itemId } });

      const itemSubLabelFn = findMultiSelectCheckbox().props('itemSubLabelFn');
      const [notEnabled, alreadyEnabled] = mockAvailableProjectsResponse.data.projects.nodes;

      expect(itemSubLabelFn(notEnabled)).toBe(notEnabled.nameWithNamespace);
      expect(itemSubLabelFn(alreadyEnabled)).toBe(alreadyEnabled.nameWithNamespace);
    });

    it('returns the "Already enabled" trailing label only for enabled projects', () => {
      createComponent({ props: { itemId } });

      const [notEnabled, alreadyEnabled] = mockAvailableProjectsResponse.data.projects.nodes;

      expect(wrapper.vm.itemTrailingLabelFn(notEnabled)).toBe(null);
      expect(wrapper.vm.itemTrailingLabelFn(alreadyEnabled)).toBe('Already enabled');
    });
  });
});
