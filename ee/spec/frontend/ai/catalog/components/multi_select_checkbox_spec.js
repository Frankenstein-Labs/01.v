import Vue from 'vue';
import VueApollo from 'vue-apollo';
import {
  GlAvatarLabeled,
  GlBadge,
  GlFormCheckbox,
  GlFormCheckboxGroup,
  GlKeysetPagination,
  GlLoadingIcon,
  GlSearchBoxByType,
} from '@gitlab/ui';
import { mount, shallowMount } from '@vue/test-utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import getProjects from '~/graphql_shared/queries/get_users_projects.query.graphql';
import MultiSelectCheckbox from 'ee/ai/catalog/components/multi_select_checkbox.vue';
import { PAGE_SIZE } from 'ee/ai/catalog/constants';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  mockPageInfo,
  mockProjects,
  mockProjectsResponse,
  mockNextPageProjectsResponse,
  mockEmptyProjectsResponse,
} from '../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('MultiSelectCheckbox', () => {
  let wrapper;
  let mockApollo;

  const defaultProps = {
    id: 'test-multi-select',
    query: getProjects,
    queryVariables: {
      sort: 'similarity',
    },
    dataKey: 'projects',
    placeholderText: 'Search projects',
    itemTextFn: (item) => item?.nameWithNamespace,
    itemLabelFn: (item) => item?.name,
    itemSubLabelFn: (item) => item?.nameWithNamespace,
    projectLabelDescription: 'Select projects to enable.',
    projectInvalidFeedback: 'You must select at least one project.',
  };

  const mockQueryHandler = jest.fn().mockResolvedValue(mockProjectsResponse);

  const createComponent = ({ props = {}, mountFn = shallowMount } = {}) => {
    mockApollo = createMockApollo([[getProjects, mockQueryHandler]]);

    wrapper = mountFn(MultiSelectCheckbox, {
      apolloProvider: mockApollo,
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findSearchBox = () => wrapper.findComponent(GlSearchBoxByType);
  const findCheckboxGroup = () => wrapper.findComponent(GlFormCheckboxGroup);
  const findItemCheckboxes = () => findCheckboxGroup().findAllComponents(GlFormCheckbox);
  const findKeysetPagination = () => wrapper.findComponent(GlKeysetPagination);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders search box with the placeholder text', () => {
      expect(findSearchBox().attributes('placeholder')).toBe('Search projects');
    });

    it('passes the id prop to the checkbox group', () => {
      expect(findCheckboxGroup().attributes('id')).toBe('test-multi-select');
    });

    it('does not apply the error border when isValid is true', () => {
      expect(findCheckboxGroup().classes()).not.toContain('gl-border-control-error');
    });

    it('applies the error border when isValid is false', () => {
      createComponent({ props: { isValid: false } });

      expect(findCheckboxGroup().classes()).toContain('gl-border-control-error');
    });
  });

  describe('Apollo query', () => {
    it('calls the query with the correct variables', () => {
      createComponent();

      expect(mockQueryHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          search: '',
          first: PAGE_SIZE,
          after: null,
          last: null,
          before: null,
          sort: 'similarity',
        }),
      );
    });

    describe('when request succeeds', () => {
      beforeEach(async () => {
        createComponent({ mountFn: mount });
        await waitForPromises();
      });

      it('renders one checkbox per item plus the "Select all" checkbox', () => {
        expect(findItemCheckboxes()).toHaveLength(mockProjects.length);
      });

      it('uses itemLabelFn for the avatar label', () => {
        const avatars = wrapper.findAllComponents(GlAvatarLabeled);

        expect(avatars.at(0).props('label')).toBe(mockProjects[0].name);
        expect(avatars.at(1).props('label')).toBe(mockProjects[1].name);
      });

      it('uses itemSubLabelFn for the avatar sub-label', () => {
        const avatars = wrapper.findAllComponents(GlAvatarLabeled);

        expect(avatars.at(0).props('subLabel')).toBe(mockProjects[0].nameWithNamespace);
        expect(avatars.at(1).props('subLabel')).toBe(mockProjects[1].nameWithNamespace);
      });

      it('hides the loading icon once the query resolves', () => {
        expect(findLoadingIcon().exists()).toBe(false);
      });

      it('displays the total count in the label', () => {
        expect(wrapper.text()).toContain('(2)');
      });
    });

    describe('when the count exceeds 99', () => {
      beforeEach(async () => {
        mockQueryHandler.mockResolvedValueOnce({
          data: {
            projects: {
              ...mockProjectsResponse.data.projects,
              count: 150,
            },
          },
        });
        createComponent({ mountFn: mount });
        await waitForPromises();
      });

      it('caps the displayed count at "99+"', () => {
        expect(wrapper.text()).toContain('(99+)');
      });
    });

    describe('when request fails', () => {
      it('emits an error event and reports to Sentry', async () => {
        const error = new Error('GraphQL error');
        mockQueryHandler.mockRejectedValueOnce(error);

        createComponent();
        await waitForPromises();

        expect(wrapper.emitted('error')).toHaveLength(1);
        expect(Sentry.captureException).toHaveBeenCalledWith(error);
      });
    });

    describe('when response is empty', () => {
      beforeEach(async () => {
        mockQueryHandler.mockResolvedValueOnce(mockEmptyProjectsResponse);
        createComponent({ mountFn: mount });
        await waitForPromises();
      });

      it('renders no item checkboxes', () => {
        expect(findItemCheckboxes()).toHaveLength(0);
      });

      it('shows the default no results text', () => {
        expect(wrapper.text()).toContain('No results found');
      });
    });
  });

  describe('search functionality', () => {
    const searchAndWait = async (query) => {
      findSearchBox().vm.$emit('input', query);
      await waitForPromises();
    };

    beforeEach(async () => {
      createComponent({ mountFn: mount });
      await waitForPromises();
    });

    it('re-runs the query when the search term reaches the minimum length', async () => {
      mockQueryHandler.mockClear();

      await searchAndWait('test query');

      expect(mockQueryHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          search: 'test query',
        }),
      );
    });

    it('shows the short-query hint when the search term is too short', async () => {
      await searchAndWait('te');

      expect(wrapper.text()).toContain('Enter at least three characters to search');
    });

    it('skips the query when the search term is too short', async () => {
      mockQueryHandler.mockClear();

      await searchAndWait('te');

      expect(mockQueryHandler).not.toHaveBeenCalled();
    });

    it('renders no item checkboxes when the search term is too short', async () => {
      await searchAndWait('te');

      expect(findItemCheckboxes()).toHaveLength(0);
    });

    it('resets the cursor when the user performs a search', async () => {
      mockQueryHandler.mockResolvedValueOnce(mockNextPageProjectsResponse);
      findKeysetPagination().vm.$emit('next');
      await waitForPromises();

      mockQueryHandler.mockClear();
      await searchAndWait('test query');

      expect(mockQueryHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          search: 'test query',
          first: PAGE_SIZE,
          after: null,
          last: null,
          before: null,
        }),
      );
    });
  });

  describe('selection', () => {
    beforeEach(async () => {
      createComponent({ mountFn: mount });
      await waitForPromises();
    });

    it('emits input with multiple items when several are selected', () => {
      findItemCheckboxes().at(0).vm.$emit('input', [mockProjects[0], mockProjects[1]]);

      expect(wrapper.emitted('input').at(-1)[0]).toEqual([mockProjects[0], mockProjects[1]]);
    });
  });

  describe('per-item disabled state', () => {
    const itemDisabledFn = (item) => item?.id === mockProjects[1].id;

    beforeEach(async () => {
      createComponent({ props: { itemDisabledFn }, mountFn: mount });
      await waitForPromises();
    });

    it('marks matching item checkboxes as disabled', () => {
      const checkboxes = findItemCheckboxes();

      expect(checkboxes.at(0).props('disabled')).toBe(false);
      expect(checkboxes.at(1).props('disabled')).toBe(true);
    });
  });

  describe('per-item trailing label', () => {
    const itemTrailingLabelFn = (item) =>
      item?.id === mockProjects[1].id ? 'Already enabled' : null;

    const findBadges = () => wrapper.findAllComponents(GlBadge);

    beforeEach(async () => {
      createComponent({ props: { itemTrailingLabelFn }, mountFn: mount });
      await waitForPromises();
    });

    it('renders a badge only for rows where the function returns a string', () => {
      const badges = findBadges();

      expect(badges).toHaveLength(1);
      expect(badges.at(0).text()).toBe('Already enabled');
    });

    it('uses the "neutral" variant for the badge', () => {
      expect(findBadges().at(0).props('variant')).toBe('neutral');
    });
  });

  describe('keyset pagination', () => {
    beforeEach(async () => {
      createComponent({ mountFn: mount });
      await waitForPromises();
    });

    it('binds the page info to the pagination component', () => {
      expect(findKeysetPagination().props()).toMatchObject({
        hasNextPage: mockPageInfo.hasNextPage,
        hasPreviousPage: mockPageInfo.hasPreviousPage,
        startCursor: mockPageInfo.startCursor,
        endCursor: mockPageInfo.endCursor,
      });
    });

    it('fetches the next page when the pagination emits "next"', async () => {
      mockQueryHandler.mockClear();
      mockQueryHandler.mockResolvedValueOnce(mockNextPageProjectsResponse);

      findKeysetPagination().vm.$emit('next');
      await waitForPromises();

      expect(mockQueryHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          first: PAGE_SIZE,
          after: mockPageInfo.endCursor,
          last: null,
          before: null,
        }),
      );
    });

    it('fetches the previous page when the pagination emits "prev"', async () => {
      mockQueryHandler.mockClear();
      mockQueryHandler.mockResolvedValueOnce(mockProjectsResponse);

      findKeysetPagination().vm.$emit('prev');
      await waitForPromises();

      expect(mockQueryHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          first: null,
          after: null,
          last: PAGE_SIZE,
          before: mockPageInfo.startCursor,
        }),
      );
    });
  });
});
