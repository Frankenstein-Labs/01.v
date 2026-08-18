import { GlCollapsibleListbox, GlFilteredSearchToken } from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import {
  FILTERED_SEARCH_TERM,
  OPERATOR_IS,
  OPERATORS_IS,
} from '~/vue_shared/components/filtered_search_bar/constants';
import FilteredSearchBarRoot from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import RepositoriesToolbar from 'ee/packages_and_registries/artifact_registry/repositories/list/repositories_toolbar.vue';
import { ORGANIZATION_GID } from '../../mock_data';

// The Artifact Registry list contract backs a format filter and a kind filter, so the
// toolbar maps to those two dimensions and nothing else.
const NO_FILTERS = { format: null, kind: null };
const ALL_FORMATS = 'ALL';

describe('ArtifactRegistryRepositoriesToolbar', () => {
  let wrapper;

  const findFormatSelector = () => wrapper.findComponent(GlCollapsibleListbox);
  const findFilteredSearch = () => wrapper.findComponent(FilteredSearchBarRoot);

  const kindToken = (data) => ({ type: 'kind', value: { data, operator: OPERATOR_IS } });
  const searchTerm = (data) => ({ type: FILTERED_SEARCH_TERM, value: { data } });

  const selectFormat = (value) => findFormatSelector().vm.$emit('select', value);
  const submitFilter = (tokens) => findFilteredSearch().vm.$emit('on-filter', tokens);

  const createComponent = ({ filters = NO_FILTERS } = {}) => {
    wrapper = shallowMountExtended(RepositoriesToolbar, {
      propsData: { filters },
      provide: { organizationGid: ORGANIZATION_GID },
    });
  };

  // The bar's own token state is the subject of the sync tests, and a stub holds none,
  // so those mount the bar for real.
  const createComponentWithSearchBar = async ({ filters = NO_FILTERS } = {}) => {
    wrapper = mountExtended(RepositoriesToolbar, {
      propsData: { filters },
      provide: { organizationGid: ORGANIZATION_GID },
    });
    // The bar normalizes its seeded tokens and echoes them back over its v-model on
    // mount. A selection change made before that settles is overwritten by the echo,
    // so these wait the mount out first.
    await waitForPromises();
  };

  describe('the format selector', () => {
    it('offers every MVP format behind an unfiltered default', () => {
      createComponent();

      expect(findFormatSelector().props('items')).toEqual([
        { value: ALL_FORMATS, text: 'All formats' },
        { value: 'DOCKER', text: 'Docker' },
        { value: 'MAVEN', text: 'Maven' },
        { value: 'NPM', text: 'npm' },
        { value: 'OCI', text: 'OCI' },
      ]);
    });

    it('shows the format the filters carry', () => {
      createComponent({ filters: { format: 'NPM', kind: null } });

      expect(findFormatSelector().props('selected')).toBe('NPM');
    });

    it('falls back to the unfiltered default when the filters carry no format', () => {
      createComponent();

      expect(findFormatSelector().props('selected')).toBe(ALL_FORMATS);
    });

    it('emits the chosen format alongside the kind it leaves untouched', () => {
      createComponent({ filters: { format: null, kind: 'HOSTED' } });

      selectFormat('MAVEN');

      expect(wrapper.emitted('apply-filter')).toEqual([[{ format: 'MAVEN', kind: 'HOSTED' }]]);
    });

    it('emits a cleared format when the unfiltered default is chosen', () => {
      createComponent({ filters: { format: 'MAVEN', kind: 'HOSTED' } });

      selectFormat(ALL_FORMATS);

      expect(wrapper.emitted('apply-filter')).toEqual([[{ format: null, kind: 'HOSTED' }]]);
    });
  });

  describe('the filtered search bar', () => {
    beforeEach(() => {
      createComponent();
    });

    it('carries the Type token alone, because the list contract backs no other', () => {
      expect(findFilteredSearch().props('tokens')).toMatchObject([
        {
          type: 'kind',
          title: 'Type',
          token: GlFilteredSearchToken,
          unique: true,
          operators: OPERATORS_IS,
          options: [
            { value: 'HOSTED', title: 'Hosted' },
            { value: 'VIRTUAL', title: 'Virtual' },
            { value: 'REMOTE', title: 'Remote' },
          ],
        },
      ]);
    });

    it('renders no sort dropdown, because sort lives in the table headers', () => {
      expect(findFilteredSearch().props('sortOptions')).toEqual([]);
    });

    it('scopes its storage to the organization', () => {
      expect(findFilteredSearch().props('namespace')).toBe(ORGANIZATION_GID);
    });

    it('keeps its recent-searches history dark until a storage key is registered', () => {
      expect(findFilteredSearch().props('recentSearchesStorageKey')).toBe('');
    });
  });

  describe('when the filters carry a kind', () => {
    it('seeds the bar with the matching token, so a shared URL renders its filters', () => {
      createComponent({ filters: { format: null, kind: 'REMOTE' } });

      expect(findFilteredSearch().props('initialFilterValue')).toEqual([kindToken('REMOTE')]);
    });
  });

  describe('when the filters carry no kind', () => {
    it('seeds the bar with no token', () => {
      createComponent();

      expect(findFilteredSearch().props('initialFilterValue')).toEqual([]);
    });
  });

  // The bar seeds `filterValue` once in `data()` and gates its re-sync watcher on
  // `syncFilterAndSort`, so without the prop a filters change that did not originate
  // in the bar leaves the old token rendered.
  describe('when the filters change from outside the bar', () => {
    const findRenderedKinds = () =>
      findFilteredSearch()
        .vm.filterValue.filter(({ type }) => type === 'kind')
        .map(({ value }) => value.data);

    const applyFilters = async (filters) => {
      await wrapper.setProps({ filters });
      await waitForPromises();
    };

    it('drops the token when the filters are cleared, as Clear filters does', async () => {
      await createComponentWithSearchBar({ filters: { format: 'MAVEN', kind: 'HOSTED' } });

      await applyFilters(NO_FILTERS);

      expect(findRenderedKinds()).toEqual([]);
    });

    it('drops the token when only the kind is cleared, as browser Back does', async () => {
      await createComponentWithSearchBar({ filters: { format: 'MAVEN', kind: 'HOSTED' } });

      await applyFilters({ format: 'MAVEN', kind: null });

      expect(findRenderedKinds()).toEqual([]);
    });

    it('renders the token the restored filters carry', async () => {
      await createComponentWithSearchBar();

      await applyFilters({ format: null, kind: 'REMOTE' });

      expect(findRenderedKinds()).toEqual(['REMOTE']);
    });

    it('keeps the token when only the format changes', async () => {
      await createComponentWithSearchBar({ filters: { format: null, kind: 'HOSTED' } });

      await applyFilters({ format: 'MAVEN', kind: 'HOSTED' });

      expect(findRenderedKinds()).toEqual(['HOSTED']);
    });

    it('syncs a clear that follows a submit made in the bar', async () => {
      await createComponentWithSearchBar({ filters: { format: 'MAVEN', kind: null } });

      submitFilter([kindToken('VIRTUAL')]);
      await applyFilters({ format: 'MAVEN', kind: 'VIRTUAL' });
      await applyFilters(NO_FILTERS);

      expect(findRenderedKinds()).toEqual([]);
    });
  });

  describe('when a filter is submitted', () => {
    it('emits the applied kind alongside the format it leaves untouched', () => {
      createComponent({ filters: { format: 'MAVEN', kind: null } });

      submitFilter([kindToken('VIRTUAL')]);

      expect(wrapper.emitted('apply-filter')).toEqual([[{ format: 'MAVEN', kind: 'VIRTUAL' }]]);
    });

    it('emits a cleared kind when the token is removed', () => {
      createComponent({ filters: { format: 'MAVEN', kind: 'HOSTED' } });

      submitFilter([]);

      expect(wrapper.emitted('apply-filter')).toEqual([[{ format: 'MAVEN', kind: null }]]);
    });

    it('ignores a free-text term, which the list contract does not honor', () => {
      createComponent({ filters: { format: 'MAVEN', kind: 'HOSTED' } });

      submitFilter([searchTerm('my-repository'), kindToken('HOSTED')]);

      expect(wrapper.emitted('apply-filter')).toEqual([[{ format: 'MAVEN', kind: 'HOSTED' }]]);
    });
  });
});
