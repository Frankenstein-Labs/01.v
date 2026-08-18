import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import getAiCatalogProjects from 'ee/ai/catalog/graphql/queries/ai_catalog_projects.query.graphql';
import getAvailableProjects from 'ee/ai/catalog/graphql/queries/ai_catalog_available_projects.query.graphql';
import FormProjectDropdown from 'ee/ai/catalog/components/form_project_dropdown.vue';
import SingleSelectDropdown from 'ee/ai/catalog/components/single_select_dropdown.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { ACCESS_LEVEL_MAINTAINER_STRING } from '~/access_level/constants';
import { mockProjects, mockProjectsResponse, mockAvailableProjectsResponse } from '../mock_data';

Vue.use(VueApollo);

describe('FormProjectDropdown', () => {
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

    wrapper = shallowMount(FormProjectDropdown, {
      apolloProvider: mockApollo,
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findSingleSelectDropdown = () => wrapper.findComponent(SingleSelectDropdown);

  it('renders SingleSelectDropdown with correct props', () => {
    createComponent();

    expect(findSingleSelectDropdown().props()).toMatchObject({
      id: 'gl-form-field-project',
      query: getAiCatalogProjects,
      queryVariables: {
        minAccessLevel: ACCESS_LEVEL_MAINTAINER_STRING,
        sort: 'similarity',
        searchNamespaces: true,
        duoLicensedFeature: 'AI_CATALOG',
      },
      dataKey: 'projects',
      placeholderText: 'Select a project',
      itemTextFn: expect.any(Function),
      itemLabelFn: expect.any(Function),
      itemSubLabelFn: expect.any(Function),
      itemTrailingLabelFn: expect.any(Function),
      isValid: true,
      disabled: false,
    });
  });

  it('passes value prop to SingleSelectDropdown', () => {
    createComponent({ props: { value: 'gid://gitlab/Project/1' } });

    expect(findSingleSelectDropdown().props('value')).toBe('gid://gitlab/Project/1');
  });

  it('passes isValid prop to SingleSelectDropdown', () => {
    createComponent({ props: { isValid: false } });

    expect(findSingleSelectDropdown().props('isValid')).toBe(false);
  });

  it('passes disabled prop to SingleSelectDropdown', () => {
    createComponent({ props: { disabled: true } });

    expect(findSingleSelectDropdown().props('disabled')).toBe(true);
  });

  describe('event handling', () => {
    beforeEach(() => {
      createComponent();
    });
    it('emits input event when SingleSelectDropdown emits input', async () => {
      await waitForPromises();

      findSingleSelectDropdown().vm.$emit('input', mockProjects[0]);

      expect(wrapper.emitted('input')).toEqual([[mockProjects[0].id]]);
    });

    it('emits error event when SingleSelectDropdown emits error', () => {
      findSingleSelectDropdown().vm.$emit('error');

      expect(wrapper.emitted('error')).toEqual([['Failed to load projects']]);
    });
  });

  describe('when itemId is provided', () => {
    const itemId = 'gid://gitlab/Ai::Catalog::Item/1';

    it('uses the available projects query with the itemId and duoLicensedFeature variables', () => {
      createComponent({ props: { itemId } });

      expect(findSingleSelectDropdown().props()).toMatchObject({
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

      const itemDisabledFn = findSingleSelectDropdown().props('itemDisabledFn');
      const [notEnabled, alreadyEnabled] = mockAvailableProjectsResponse.data.projects.nodes;

      expect(itemDisabledFn(notEnabled)).toBe(false);
      expect(itemDisabledFn(alreadyEnabled)).toBe(true);
    });

    it('keeps the sub-label as the project namespace for all rows', () => {
      createComponent({ props: { itemId } });

      const itemSubLabelFn = findSingleSelectDropdown().props('itemSubLabelFn');
      const [notEnabled, alreadyEnabled] = mockAvailableProjectsResponse.data.projects.nodes;

      expect(itemSubLabelFn(notEnabled)).toBe(notEnabled.nameWithNamespace);
      expect(itemSubLabelFn(alreadyEnabled)).toBe(alreadyEnabled.nameWithNamespace);
    });

    it('returns the "Already enabled" trailing label only for enabled projects', () => {
      createComponent({ props: { itemId } });

      const itemTrailingLabelFn = findSingleSelectDropdown().props('itemTrailingLabelFn');
      const [notEnabled, alreadyEnabled] = mockAvailableProjectsResponse.data.projects.nodes;

      expect(itemTrailingLabelFn(notEnabled)).toBe(null);
      expect(itemTrailingLabelFn(alreadyEnabled)).toBe('Already enabled');
    });
  });
});
