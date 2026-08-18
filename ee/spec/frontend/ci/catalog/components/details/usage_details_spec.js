import { nextTick } from 'vue';
import {
  GlTable,
  GlLink,
  GlIcon,
  GlTruncateText,
  GlKeysetPagination,
  GlFilteredSearch,
  GlLoadingIcon,
  GlCollapsibleListbox,
} from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import UsageDetails from 'ee/ci/catalog/components/details/usage_details.vue';
import ComponentNameToken from 'ee/ci/catalog/components/details/tokens/component_name_token.vue';
import VersionToken from 'ee/ci/catalog/components/details/tokens/version_token.vue';
import {
  mockComponentUsages,
  mockOutdatedComponentUsages,
  mockMultipleComponentUsages,
  mockNullProjectComponentUsages,
  mockPageInfo,
  mockPageInfoPage2,
} from './mock_data';

describe('UsageDetails', () => {
  let wrapper;

  const resourcePath = 'root/my-component';

  const createComponent = ({
    componentUsages = mockComponentUsages,
    pageInfo = mockPageInfo,
    isLoading = false,
  } = {}) => {
    wrapper = mountExtended(UsageDetails, {
      propsData: {
        componentUsages,
        pageInfo,
        resourcePath,
        isLoading,
      },
      stubs: {
        GlFilteredSearch: true,
      },
    });
  };

  const findTable = () => wrapper.findComponent(GlTable);
  const findAllTableRows = () => findTable().findAll('tbody > tr');
  const findProjectLinks = () => wrapper.findAllComponents(GlLink);
  const findStatusIcons = () => findTable().findAllComponents(GlIcon);
  const findTruncateText = () => wrapper.findComponent(GlTruncateText);
  const findPagination = () => wrapper.findComponent(GlKeysetPagination);
  const findFilteredSearch = () => wrapper.findComponent(GlFilteredSearch);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findSortListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findSortDirectionButton = () => wrapper.findComponentByTestId('sort-direction-button');

  const buildComponentToken = (data) => ({
    type: 'component',
    value: { data, operator: '=' },
  });

  const buildVersionToken = (data) => ({
    type: 'version',
    value: { data, operator: '||' },
  });

  describe('table structure', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the table with correct fields', () => {
      expect(findTable().props('fields')).toMatchObject([
        expect.objectContaining({ key: 'project', label: 'Project path' }),
        expect.objectContaining({ key: 'status', label: 'Status' }),
        expect.objectContaining({ key: 'componentsUsed', label: 'Components used' }),
      ]);
    });
  });

  describe('with up-to-date components', () => {
    beforeEach(() => {
      createComponent({ componentUsages: mockComponentUsages });
    });

    it('displays project path', () => {
      const projectLink = findProjectLinks().at(0);
      const { project } = mockComponentUsages[0];
      expect(projectLink.attributes('href')).toBe(project.webPath);
      expect(projectLink.text()).toBe(project.nameWithNamespace);
    });

    it('shows up-to-date status with success icon', () => {
      const statusIcon = findStatusIcons().at(0);
      expect(statusIcon.props('name')).toBe('status_success');
      expect(findAllTableRows().at(0).text()).toContain('Up to date');
      expect(findAllTableRows().at(0).text()).toContain('1.0.0');
    });

    it('displays components used', () => {
      expect(findTruncateText().text()).toContain('component-1 (1.0.0)');
    });
  });

  describe('with outdated components', () => {
    beforeEach(() => {
      createComponent({ componentUsages: mockOutdatedComponentUsages });
    });

    it('shows outdated status with warning icon', () => {
      const statusIcon = findStatusIcons().at(0);
      expect(statusIcon.props('name')).toBe('warning');
      expect(findAllTableRows().at(0).text()).toContain('Outdated');
      expect(findAllTableRows().at(0).text()).toContain('0.9.0');
    });
  });

  describe('with multiple components', () => {
    beforeEach(() => {
      createComponent({ componentUsages: mockMultipleComponentUsages });
    });

    it('displays all components in sorted order', () => {
      expect(findAllTableRows().at(0).text()).toContain('component-b (1.5.0), component-a (2.0.0)');
    });

    it('uses truncate text for long component lists', () => {
      expect(findTruncateText().props('lines')).toBe(2);
      expect(findTruncateText().props('mobileLines')).toBe(4);
    });
  });

  describe('with null project (private/inaccessible)', () => {
    beforeEach(() => {
      createComponent({
        componentUsages: [...mockComponentUsages, ...mockNullProjectComponentUsages],
      });
    });

    it('renders "Private project" text instead of a link', () => {
      expect(findAllTableRows().at(1).text()).toContain('Private project');
    });

    it('displays components used for the null project row', () => {
      const rows = findAllTableRows();
      expect(rows.at(1).text()).toContain('component-5 (1.2.0)');
    });
  });

  describe('with multiple projects', () => {
    beforeEach(() => {
      createComponent({
        componentUsages: [...mockComponentUsages, ...mockOutdatedComponentUsages],
      });
    });

    it('renders a row for each project', () => {
      expect(findTable().props('items')).toHaveLength(2);
    });

    it('displays correct status for each project', () => {
      expect(findAllTableRows().at(0).text()).toContain('Up to date');
      expect(findAllTableRows().at(1).text()).toContain('Outdated');
    });
  });

  describe('pagination', () => {
    it('renders keyset pagination with correct page info', () => {
      createComponent();

      expect(findPagination().exists()).toBe(true);
      expect(findPagination().props()).toMatchObject({
        hasNextPage: mockPageInfo.hasNextPage,
        hasPreviousPage: mockPageInfo.hasPreviousPage,
        prevText: 'Previous',
        nextText: 'Next',
      });
    });

    it('emits next-page when next button is clicked', () => {
      createComponent();

      findPagination().vm.$emit('next');

      expect(wrapper.emitted('next-page')).toHaveLength(1);
    });

    it('emits prev-page when previous button is clicked', () => {
      createComponent({
        pageInfo: mockPageInfoPage2,
      });

      findPagination().vm.$emit('prev');

      expect(wrapper.emitted('prev-page')).toHaveLength(1);
    });
  });

  describe('filtered search', () => {
    it('renders the filtered search with component and version tokens', () => {
      createComponent();

      const tokens = findFilteredSearch().props('availableTokens');
      expect(tokens).toHaveLength(2);
      expect(tokens[0]).toMatchObject({
        type: 'component',
        token: ComponentNameToken,
        unique: true,
        resourcePath,
      });
      expect(tokens[1]).toMatchObject({
        type: 'version',
        token: VersionToken,
        unique: true,
        multiSelect: true,
        resourcePath,
      });
    });

    describe('on submit', () => {
      beforeEach(() => {
        createComponent();
      });

      const versionIdOne = 'gid://gitlab/Ci::Catalog::Resources::Version/1';
      const versionIdTwo = 'gid://gitlab/Ci::Catalog::Resources::Version/2';

      it.each([
        {
          scenario: 'both filters set',
          tokens: () => [buildComponentToken('build'), buildVersionToken([versionIdOne])],
          expected: { componentName: 'build', versionIds: [versionIdOne] },
        },
        {
          scenario: 'only a component name',
          tokens: () => [buildComponentToken('build')],
          expected: { componentName: 'build', versionIds: [] },
        },
        {
          scenario: 'only version ids',
          tokens: () => [buildVersionToken([versionIdOne, versionIdTwo])],
          expected: { componentName: null, versionIds: [versionIdOne, versionIdTwo] },
        },
        {
          scenario: 'no tokens',
          tokens: () => [],
          expected: { componentName: null, versionIds: [] },
        },
      ])('emits filters-changed with $scenario', ({ tokens, expected }) => {
        findFilteredSearch().vm.$emit('submit', tokens());

        expect(wrapper.emitted('filters-changed')).toEqual([[expected]]);
      });
    });

    describe('on clear', () => {
      it('emits filters-changed with cleared filters', () => {
        createComponent();

        findFilteredSearch().vm.$emit('clear');

        expect(wrapper.emitted('filters-changed')).toEqual([
          [{ componentName: null, versionIds: [] }],
        ]);
      });
    });
  });

  describe('loading state', () => {
    it('shows the in-table loading spinner when isLoading is true', () => {
      createComponent({ isLoading: true });

      expect(findLoadingIcon().exists()).toBe(true);
      expect(findTable().exists()).toBe(false);
    });

    it('shows the table when isLoading is false', () => {
      createComponent({ isLoading: false });

      expect(findLoadingIcon().exists()).toBe(false);
      expect(findTable().exists()).toBe(true);
    });
  });

  describe('empty results with active filter', () => {
    it('shows the table with no-results text when componentUsages is empty', () => {
      createComponent({ componentUsages: [] });

      expect(findTable().exists()).toBe(true);
      expect(findTable().text()).toContain('No results found');
    });
  });

  describe('sorting', () => {
    beforeEach(() => {
      createComponent();
    });

    it('defaults to oldest version, ascending', () => {
      expect(findSortListbox().props('selected')).toBe('OLDEST_VERSION');
      expect(findSortDirectionButton().props('icon')).toBe('sort-lowest');
      expect(findSortDirectionButton().attributes('aria-label')).toBe('Sort direction: ascending');
    });

    it('emits sort with the combined value when a sort option is selected', async () => {
      findSortListbox().vm.$emit('select', 'LAST_USED');
      await nextTick();

      expect(wrapper.emitted('sort')).toEqual([['LAST_USED_ASC']]);
    });

    it('emits sort with DESC and flips the icon when toggling direction', async () => {
      findSortDirectionButton().vm.$emit('click');
      await nextTick();

      expect(wrapper.emitted('sort')).toEqual([['OLDEST_VERSION_DESC']]);
      expect(findSortDirectionButton().props('icon')).toBe('sort-highest');
      expect(findSortDirectionButton().attributes('aria-label')).toBe('Sort direction: descending');
    });

    it('combines selection and direction in subsequent emits', async () => {
      findSortListbox().vm.$emit('select', 'PROJECT_NAME');
      await nextTick();
      findSortDirectionButton().vm.$emit('click');
      await nextTick();

      expect(wrapper.emitted('sort')).toEqual([['PROJECT_NAME_ASC'], ['PROJECT_NAME_DESC']]);
    });
  });
});
