import { GlLoadingIcon, GlTable } from '@gitlab/ui';
import { RouterLinkStub } from '@vue/test-utils';
import { nextTick } from 'vue';
import repositoriesFixture from 'test_fixtures/ee/graphql/packages_and_registries/artifact_registry/graphql/queries/get_repositories.query.graphql.json';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useFakeDate } from 'helpers/fake_date';
import RepositoriesTable from 'ee/packages_and_registries/artifact_registry/repositories/list/repositories_table.vue';
import FormatLogo from 'ee/packages_and_registries/artifact_registry/repositories/components/format_logo.vue';
import RowActionsMenu from 'ee/packages_and_registries/artifact_registry/repositories/components/row_actions_menu.vue';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import { CLIENT_BASE_URL, SLUG } from '../../mock_data';

// The rows are the connection's nodes, taken from the generated GraphQL fixture rather than
// a transcription of it, so a change to the node shape fails here rather than drifting.
const mockRepositories = repositoriesFixture.data.organization.artifactRegistryRepositories.nodes;

const [mockRepository] = mockRepositories;

describe('ArtifactRegistryRepositoriesTable', () => {
  let wrapper;

  useFakeDate(2026, 6, 15);

  const FIELD_KEYS = [
    'format',
    'name',
    'kind',
    'downloadsCount',
    'sizeBytes',
    'lastUpdatedAt',
    'actions',
  ];

  const DEFAULT_SORT = { sortBy: 'lastUpdatedAt', sortDesc: true };

  const findTable = () => wrapper.findComponent(GlTable);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findRows = () => wrapper.findAllByRole('row');
  const findFormatCell = () => wrapper.findByTestId('repository-format');
  const findFormatLogo = () => wrapper.findComponent(FormatLogo);
  const findNameCell = () => wrapper.findByTestId('repository-name');
  const findNameLink = () => findNameCell().findComponent(RouterLinkStub);
  const findKindBadge = () => wrapper.findComponentByTestId('repository-kind');
  const findDownloadsCell = () => wrapper.findByTestId('repository-downloads');
  const findSizeCell = () => wrapper.findByTestId('repository-size');
  const findLastUpdatedCell = () => wrapper.findByTestId('repository-last-updated');
  const findActionsMenus = () => wrapper.findAllComponents(RowActionsMenu);
  const findCopyButtons = () => wrapper.findAllComponents(ClipboardButton);

  const createComponent = ({ mountFn = shallowMountExtended, props = {}, provide = {} } = {}) => {
    wrapper = mountFn(RepositoriesTable, {
      propsData: {
        repositories: mockRepositories,
        sort: DEFAULT_SORT,
        ...props,
      },
      provide: {
        slug: SLUG,
        clientBaseUrl: CLIENT_BASE_URL,
        ...provide,
      },
      stubs: {
        RouterLink: RouterLinkStub,
      },
    });
  };

  const createComponentWithRepository = (overrides) =>
    createComponent({
      mountFn: mountExtended,
      props: { repositories: [{ ...mockRepository, ...overrides }] },
    });

  it('renders every column the list shows, in order', () => {
    createComponent();

    expect(
      findTable()
        .props('fields')
        .map(({ key, label }) => [key, label]),
    ).toEqual([
      ['format', 'Format'],
      ['name', 'Name'],
      ['kind', 'Type'],
      ['downloadsCount', 'Downloads'],
      ['sizeBytes', 'Size'],
      ['lastUpdatedAt', 'Last updated'],
      ['actions', 'Actions'],
    ]);
  });

  it('renders one row per repository, plus the header row', () => {
    createComponent({ mountFn: mountExtended });

    expect(findRows()).toHaveLength(3);
  });

  describe('when the query is in flight', () => {
    beforeEach(() => {
      createComponent({ props: { isLoading: true, repositories: [] } });
    });

    it('marks the table busy', () => {
      expect(findTable().attributes('busy')).toBe('true');
    });

    it('renders a loading affordance in place of the rows', () => {
      expect(findLoadingIcon().exists()).toBe(true);
    });
  });

  describe('when the query has resolved', () => {
    beforeEach(() => {
      createComponent();
    });

    it('leaves the table unbusy', () => {
      expect(findTable().attributes('busy')).toBeUndefined();
    });

    it('renders no loading affordance', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });
  });

  describe('the Format column', () => {
    describe.each([
      ['MAVEN', 'Maven'],
      ['NPM', 'npm'],
      ['DOCKER', 'Docker'],
      ['OCI', 'OCI'],
    ])('for a %s repository', (format, label) => {
      beforeEach(() => {
        createComponentWithRepository({ format });
      });

      // `toContain` rather than `toBe`: a format that falls back to a letter avatar
      // renders that letter as text beside the label.
      it(`names the format ${label}`, () => {
        expect(findFormatCell().text()).toContain(label);
      });

      it('pairs it with its logo', () => {
        expect(findFormatLogo().props('format')).toBe(format);
      });
    });

    // 16px left the wordmark logos, which fit their width rather than their height,
    // too small to read.
    it('renders the logo at 32px', () => {
      createComponentWithRepository();

      expect(findFormatLogo().props('size')).toBe(32);
    });
  });

  describe('the Name column', () => {
    it('renders the repository name as the link to its detail page', () => {
      createComponentWithRepository({ name: 'a-repository' });

      expect(findNameLink().text()).toBe('a-repository');
      expect(findNameLink().props('to')).toEqual({
        name: 'repository_detail',
        params: { id: 'a-repository' },
      });
    });
  });

  describe('the Type column', () => {
    it.each([
      ['HOSTED', 'Hosted'],
      ['VIRTUAL', 'Virtual'],
      ['REMOTE', 'Remote'],
    ])('names the %s kind %s, capitalized rather than uppercased', (kind, label) => {
      createComponentWithRepository({ kind });

      expect(findKindBadge().text()).toBe(label);
    });

    it('renders the kind as a badge', () => {
      createComponentWithRepository({ kind: 'HOSTED' });

      expect(findKindBadge().exists()).toBe(true);
    });
  });

  describe('the Downloads column', () => {
    it('renders the buffered download counter, thousands-separated', () => {
      createComponentWithRepository({ downloadsCount: '1234567' });

      expect(findDownloadsCell().text()).toBe('1,234,567');
    });

    it('renders zero rather than an empty cell when the counter is absent', () => {
      createComponentWithRepository({ downloadsCount: null });

      expect(findDownloadsCell().text()).toBe('0');
    });
  });

  describe('the Size column', () => {
    it('renders the byte counter as a human-readable size', () => {
      createComponentWithRepository({ sizeBytes: '2048' });

      expect(findSizeCell().text()).toBe('2.00 KiB');
    });

    it('renders a zero size in bytes rather than as an empty cell', () => {
      createComponentWithRepository({ sizeBytes: '0' });

      expect(findSizeCell().text()).toBe('0 B');
    });

    it('renders zero bytes rather than an empty cell when the counter is absent', () => {
      createComponentWithRepository({ sizeBytes: null });

      expect(findSizeCell().text()).toBe('0 B');
    });
  });

  describe('the Last updated column', () => {
    it('renders the timestamp relative to now', () => {
      createComponentWithRepository({ lastUpdatedAt: '2026-06-01T00:00:00Z' });

      expect(findLastUpdatedCell().text()).toBe('1 month ago');
    });

    it('says the content never changed rather than leaving the cell blank', () => {
      createComponentWithRepository({ lastUpdatedAt: null });

      expect(findLastUpdatedCell().text()).toBe('Never');
    });
  });

  describe('the Actions column', () => {
    it('hosts one write affordances menu per row, each addressing its own repository', () => {
      createComponent({ mountFn: mountExtended });

      expect(findActionsMenus().wrappers.map((menu) => menu.props('repository'))).toEqual(
        mockRepositories,
      );
    });

    // The container segment names the protocol family, which is why the Docker row
    // copies `container` rather than `docker`.
    it('copies a client URL per row', () => {
      createComponent({ mountFn: mountExtended });

      expect(findCopyButtons().wrappers.map((button) => button.props('text'))).toEqual([
        `${CLIENT_BASE_URL}/${SLUG}/maven/my-repository`,
        `${CLIENT_BASE_URL}/${SLUG}/container/container-images`,
      ]);
    });

    it('offers no copy action when the instance configures no Artifact Registry', () => {
      createComponent({ mountFn: mountExtended, provide: { clientBaseUrl: null } });

      expect(findCopyButtons()).toHaveLength(0);
    });

    // The control renders as an icon, so its accessible name is all a screen reader
    // gets for it.
    it('names what the action copies', () => {
      createComponentWithRepository();

      expect(findCopyButtons().wrappers.map((button) => button.props('title'))).toEqual([
        'Copy repository URL',
      ]);
    });
  });

  describe('sorting', () => {
    const findHeaders = () => wrapper.findAllByRole('columnheader');
    const findSortStates = () =>
      Object.fromEntries(
        findHeaders().wrappers.map((header, index) => [
          FIELD_KEYS[index],
          header.attributes('aria-sort'),
        ]),
      );
    const findRowNames = () =>
      wrapper.findAllByTestId('repository-name').wrappers.map((cell) => cell.text());
    const clickHeader = (key) => findHeaders().at(FIELD_KEYS.indexOf(key)).trigger('click');

    it.each([
      [false, 'ascending'],
      [true, 'descending'],
    ])('exposes the active column, reading a sortDesc of %s as %s', (sortDesc, ariaSort) => {
      createComponent({
        mountFn: mountExtended,
        props: { sort: { sortBy: 'downloadsCount', sortDesc } },
      });

      // Format and Type carry no sort state at all: neither is in the Artifact Registry
      // list sort contract, so neither column sorts.
      expect(findSortStates()).toEqual({
        format: undefined,
        name: 'none',
        kind: undefined,
        downloadsCount: ariaSort,
        sizeBytes: 'none',
        lastUpdatedAt: 'none',
        actions: undefined,
      });
    });

    it.each(['name', 'downloadsCount', 'sizeBytes'])(
      'asks for the %s column ascending when its header is clicked, leaving the row order alone',
      async (key) => {
        createComponent({ mountFn: mountExtended });

        await clickHeader(key);

        expect(wrapper.emitted('sort-changed')).toEqual([[{ sortBy: key, sortDesc: false }]]);
        expect(findRowNames()).toEqual(mockRepositories.map(({ name }) => name));
      },
    );

    it('reverses the direction when the header of the active column is clicked', async () => {
      createComponent({ mountFn: mountExtended });

      await clickHeader('lastUpdatedAt');

      expect(wrapper.emitted('sort-changed')).toEqual([
        [{ sortBy: 'lastUpdatedAt', sortDesc: false }],
      ]);
    });

    // The sticky-sort restore and browser Back both change the sort without the table
    // raising it.
    it('follows a sort it did not ask for, so an externally applied sort reaches the header', async () => {
      createComponent({
        mountFn: mountExtended,
        props: { sort: { sortBy: 'name', sortDesc: false } },
      });

      expect(findSortStates()).toMatchObject({ name: 'ascending', sizeBytes: 'none' });

      wrapper.setProps({ sort: { sortBy: 'sizeBytes', sortDesc: true } });
      await nextTick();

      expect(findSortStates()).toMatchObject({ name: 'none', sizeBytes: 'descending' });
    });

    // Remounting on a header click would drop the focus the reader left on that header.
    it('does not remount when the sort it asked for comes back down', async () => {
      createComponent({ mountFn: mountExtended });

      const tableBefore = wrapper.findComponent(GlTable).vm;

      await clickHeader('name');
      wrapper.setProps({ sort: { sortBy: 'name', sortDesc: false } });
      await nextTick();

      expect(wrapper.findComponent(GlTable).vm).toBe(tableBefore);
      expect(findSortStates()).toMatchObject({ name: 'ascending' });
    });
  });
});
