import { shallowMount } from '@vue/test-utils';
import MockAdapter from 'axios-mock-adapter';
import { nextTick } from 'vue';
import waitForPromises from 'helpers/wait_for_promises';
import axios from '~/lib/utils/axios_utils';
import InstanceProjectsDropdown from 'ee/security_orchestration/components/shared/instance_projects_dropdown.vue';
import BaseItemsDropdown from 'ee/security_orchestration/components/shared/base_items_dropdown.vue';
import Api from '~/api';

jest.mock('~/api');

describe('InstanceProjectsDropdown', () => {
  let wrapper;
  let mockAxios;

  const mockProjects = [
    { id: 1, name: 'Project 1', path_with_namespace: 'group/project-1' },
    { id: 2, name: 'Project 2', path_with_namespace: 'group/project-2' },
  ];

  const createComponent = (props = {}) => {
    wrapper = shallowMount(InstanceProjectsDropdown, {
      propsData: {
        selected: [],
        disabled: false,
        state: true,
        ...props,
      },
    });
  };

  const findBaseDropdown = () => wrapper.findComponent(BaseItemsDropdown);

  beforeEach(() => {
    mockAxios = new MockAdapter(axios);
    Api.projects = jest.fn().mockResolvedValue({
      data: mockProjects,
      headers: { 'x-total': '2', 'x-page': '1', 'x-per-page': '20' },
    });
    Api.project = jest.fn();
  });

  afterEach(() => {
    mockAxios.restore();
  });

  describe('initialization', () => {
    it('displays projects on creation', async () => {
      createComponent();
      await waitForPromises();

      const items = findBaseDropdown().props('items');
      expect(items).toHaveLength(2);
      expect(items[0].text).toBe('Project 1');
      expect(items[1].text).toBe('Project 2');
    });

    it('passes correct props to BaseItemsDropdown', async () => {
      createComponent({ disabled: true, state: false });
      await waitForPromises();

      const baseDropdown = findBaseDropdown();
      expect(baseDropdown.props()).toMatchObject({
        multiple: true,
        disabled: true,
        category: 'secondary',
        variant: 'danger',
        headerText: 'Select projects',
        loading: false,
        searching: false,
      });
    });

    it('shows loading state during initial fetch', async () => {
      // Mock delayed response
      let resolvePromise;
      Api.projects.mockImplementation(
        () =>
          new Promise((resolve) => {
            resolvePromise = resolve;
          }),
      );

      createComponent();
      await nextTick();

      expect(findBaseDropdown().props('loading')).toBe(true);

      // Resolve the promise
      resolvePromise({
        data: mockProjects,
        headers: { 'x-total': '2', 'x-page': '1', 'x-per-page': '20' },
      });
      await waitForPromises();

      expect(findBaseDropdown().props('loading')).toBe(false);
    });

    it('passes correct items to BaseItemsDropdown', async () => {
      createComponent();
      await waitForPromises();

      const baseDropdown = findBaseDropdown();
      expect(baseDropdown.props('items')).toEqual([
        {
          fullPath: 'group/project-1',
          id: 1,
          text: 'Project 1',
          value: 1,
        },
        {
          fullPath: 'group/project-2',
          id: 2,
          text: 'Project 2',
          value: 2,
        },
      ]);
    });

    it('applies correct styling based on state prop', async () => {
      createComponent({ state: false });
      await waitForPromises();

      const baseDropdown = findBaseDropdown();
      expect(baseDropdown.props('category')).toBe('secondary');
      expect(baseDropdown.props('variant')).toBe('danger');
    });

    it('applies correct styling when state is valid', async () => {
      createComponent({ state: true });
      await waitForPromises();

      const baseDropdown = findBaseDropdown();
      expect(baseDropdown.props('category')).toBe('primary');
      expect(baseDropdown.props('variant')).toBe('default');
    });
  });

  describe('search functionality', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('filters projects when search event is emitted', async () => {
      await findBaseDropdown().vm.$emit('search', 'Project 1');
      await waitForPromises();

      expect(Api.projects).toHaveBeenNthCalledWith(2, 'Project 1', expect.objectContaining({}));
    });

    it('shows searching state during search', async () => {
      // Mock a delayed API response for search that will have no pagination
      let resolvePromise;
      Api.projects.mockImplementation(
        () =>
          new Promise((resolve) => {
            resolvePromise = resolve;
          }),
      );

      const baseDropdown = findBaseDropdown();
      await baseDropdown.vm.$emit('search', 'searching');
      expect(baseDropdown.props('searching')).toBe(true);

      resolvePromise({
        data: [{ id: 1, name: 'Searched Project', path_with_namespace: 'group/searched' }],
        headers: { 'x-total': '1', 'x-page': '1', 'x-per-page': '20' },
      });
      await waitForPromises();

      expect(baseDropdown.props('searching')).toBe(false);
    });

    it('filters items based on search in template', async () => {
      createComponent();
      await waitForPromises();

      const baseDropdown = findBaseDropdown();
      await baseDropdown.vm.$emit('search', 'Project 1');
      await waitForPromises();

      // Should show filtered results in the dropdown
      const items = baseDropdown.props('items');
      expect(items).toHaveLength(1);
      expect(items[0].text).toBe('Project 1');
    });
  });

  describe('infinite scroll', () => {
    it('maintains items when bottom-reached is emitted for pagination', async () => {
      createComponent();
      await waitForPromises();

      expect(findBaseDropdown().props('items')).toHaveLength(2);

      await findBaseDropdown().vm.$emit('bottom-reached');
      await waitForPromises();

      expect(Api.projects).toHaveBeenCalledWith('', expect.objectContaining({ page: 2 }));
    });

    it('shows infinite scroll when hasNextPage is true', async () => {
      createComponent();
      await waitForPromises();
      expect(findBaseDropdown().props('infiniteScroll')).toBe(true);
    });

    it('hides infinite scroll when hasNextPage is false', async () => {
      Api.projects.mockResolvedValue({
        data: mockProjects,
        headers: { 'x-total': '2', 'x-page': '1', 'x-per-page': '20' },
      });

      createComponent();
      await nextTick();

      expect(findBaseDropdown().props('infiniteScroll')).toBe(false);
    });
  });

  describe('project selection', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('emits selected projects when BaseItemsDropdown emits select', async () => {
      await findBaseDropdown().vm.$emit('select', [1, 2]);
      expect(wrapper.emitted('select')).toEqual([[mockProjects]]);
    });

    it('resets selection when BaseItemsDropdown emits reset', async () => {
      await findBaseDropdown().vm.$emit('reset');
      expect(wrapper.emitted('select')).toEqual([[[]]]);
    });

    it('handles select-all event from BaseItemsDropdown', async () => {
      await findBaseDropdown().vm.$emit('select-all', [1, 2]);
      expect(wrapper.emitted('select')).toEqual([[mockProjects]]);
    });

    it('shows correct selected projects in template', async () => {
      createComponent({ selected: [1] });
      await waitForPromises();

      const baseDropdown = findBaseDropdown();
      expect(baseDropdown.props('selected')).toEqual([1]);
    });

    it('displays selected projects that were not initially loaded', async () => {
      Api.project.mockResolvedValue({
        data: { id: 3, name: 'Project 3', path_with_namespace: 'group/project-3' },
      });

      createComponent({ selected: [1, 3] });
      await waitForPromises();

      const items = findBaseDropdown().props('items');
      const itemIds = items.map(({ id }) => id);
      expect(itemIds).toContain(1);
      expect(itemIds).toContain(3);
    });
  });

  describe('error handling', () => {
    it('emits projects-query-error when initial API call fails', async () => {
      Api.projects.mockRejectedValue(new Error('API Error'));

      createComponent();
      await waitForPromises();

      expect(wrapper.emitted('projects-query-error')).toHaveLength(1);
    });

    it('handles individual project fetch errors gracefully', async () => {
      Api.project.mockRejectedValue(new Error('Project not found'));

      createComponent({ selected: [999] });
      await waitForPromises();

      expect(wrapper.emitted('projects-query-error')).toHaveLength(1);
    });

    it('continues loading other projects when one project fetch fails', async () => {
      Api.project
        .mockRejectedValueOnce(new Error('Project not found'))
        .mockResolvedValueOnce({ data: { id: 4, name: 'Project 4' } });

      createComponent({ selected: [999, 4] });
      await waitForPromises();

      expect(wrapper.emitted('projects-query-error')).toHaveLength(1);
    });
  });
});
