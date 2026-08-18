import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox, GlIcon, GlTruncate } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { TYPENAME_SBOM_COMPONENT_VERSION } from 'ee/graphql_shared/constants';
import DependencyRefCount, {
  TRACKED_REFS_PAGE_SIZE,
} from 'ee/dependencies/components/dependency_ref_count.vue';
import getDependencyTrackedRefs from 'ee/dependencies/graphql/dependency_tracked_refs.query.graphql';
import { SEARCH_MIN_THRESHOLD } from 'ee/dependencies/components/constants';

jest.mock('~/alert');

Vue.use(VueApollo);

const MOCK_TRACKED_REFS = [
  {
    id: 'gid://gitlab/Security::ProjectTrackedContext/1',
    name: 'main',
    refType: 'BRANCH',
  },
  {
    id: 'gid://gitlab/Security::ProjectTrackedContext/2',
    name: 'v1.0.0',
    refType: 'TAG',
  },
  {
    id: 'gid://gitlab/Security::ProjectTrackedContext/3',
    name: 'release/18.8',
    refType: 'BRANCH',
  },
];

describe('DependencyRefCount component', () => {
  let wrapper;

  const fullPath = 'group/test-project';
  const componentVersionId = 1;

  const createGraphQLResponse = (nodes) => ({
    data: {
      project: {
        id: 'gid://gitlab/Project/1',
        dependencyTrackedRefs: {
          nodes,
        },
      },
    },
  });

  let apolloResolver;

  const createComponent = ({
    propsData,
    mountFn = shallowMountExtended,
    handler = apolloResolver,
    stubs = {},
  } = {}) => {
    wrapper = mountFn(DependencyRefCount, {
      propsData: {
        trackedRefsCount: 3,
        componentVersionId,
        ...propsData,
      },
      apolloProvider: createMockApollo([[getDependencyTrackedRefs, handler]]),
      provide: {
        fullPath,
      },
      stubs,
    });
  };

  const findRefCount = () => wrapper.findByTestId('ref-count');
  const findRefCountText = () => wrapper.findByTestId('ref-count-text');
  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findIcons = () => wrapper.findAllComponents(GlIcon);
  const findTruncates = () => wrapper.findAllComponents(GlTruncate);

  const openDropdown = async () => {
    findListbox().vm.$emit('shown');
    await waitForPromises();
  };

  beforeEach(() => {
    apolloResolver = jest.fn().mockResolvedValue(createGraphQLResponse(MOCK_TRACKED_REFS));
  });

  it('renders the ref count', () => {
    createComponent();

    expect(findRefCount().exists()).toBe(true);
  });

  it.each`
    trackedRefsCount | text
    ${1}             | ${'1 ref'}
    ${3}             | ${'3 refs'}
  `('renders "$text" when trackedRefsCount is $trackedRefsCount', ({ trackedRefsCount, text }) => {
    createComponent({ propsData: { trackedRefsCount } });

    expect(findRefCountText().text()).toBe(text);
  });

  describe('dropdown', () => {
    it('renders a listbox with the count as header', () => {
      createComponent();

      expect(findListbox().props()).toMatchObject({
        headerText: '3 refs',
        items: [],
      });
    });

    it('starts in the loading state', () => {
      createComponent();

      expect(findListbox().props('searching')).toBe(true);
    });

    describe('when opened', () => {
      it('queries with the expected variables', async () => {
        createComponent();

        await openDropdown();

        expect(apolloResolver).toHaveBeenCalledWith({
          fullPath,
          componentVersionId: convertToGraphQLId(
            TYPENAME_SBOM_COMPONENT_VERSION,
            componentVersionId,
          ),
          search: '',
          first: TRACKED_REFS_PAGE_SIZE,
        });
      });

      it('renders the fetched refs once loaded', async () => {
        createComponent();

        await openDropdown();

        expect(findListbox().props('searching')).toBe(false);
        expect(findListbox().props('items')).toHaveLength(MOCK_TRACKED_REFS.length);
        expect(findListbox().props('items')[0]).toMatchObject({
          value: MOCK_TRACKED_REFS[0].id,
          text: MOCK_TRACKED_REFS[0].name,
        });
      });

      it('renders no refs without throwing when dependencyTrackedRefs is null', async () => {
        apolloResolver = jest.fn().mockResolvedValue({
          data: { project: { id: 'gid://gitlab/Project/1', dependencyTrackedRefs: null } },
        });
        createComponent();

        await openDropdown();

        expect(findListbox().props('items')).toEqual([]);
      });

      describe('list items', () => {
        beforeEach(async () => {
          createComponent({ stubs: { GlCollapsibleListbox } });
          await openDropdown();
        });

        it('renders correct icon based on refType', () => {
          const [branchRef, tagRef] = MOCK_TRACKED_REFS;

          expect(findIcons().at(0).props('name')).toBe(branchRef.refType.toLowerCase());
          expect(findIcons().at(1).props('name')).toBe(tagRef.refType.toLowerCase());
        });

        it('renders the ref name', () => {
          expect(findTruncates().at(0).props('text')).toBe(MOCK_TRACKED_REFS[0].name);
        });
      });
    });

    describe('search', () => {
      beforeAll(() => {
        global.JEST_DEBOUNCE_THROTTLE_TIMEOUT = DEFAULT_DEBOUNCE_AND_THROTTLE_MS;
      });

      afterAll(() => {
        global.JEST_DEBOUNCE_THROTTLE_TIMEOUT = undefined;
      });

      it.each`
        trackedRefsCount            | searchable
        ${SEARCH_MIN_THRESHOLD - 1} | ${false}
        ${SEARCH_MIN_THRESHOLD + 1} | ${true}
      `(
        'sets searchable to $searchable when trackedRefsCount is $trackedRefsCount',
        async ({ trackedRefsCount, searchable }) => {
          createComponent({ propsData: { trackedRefsCount } });

          await openDropdown();

          expect(findListbox().props('searchable')).toBe(searchable);
        },
      );

      it('queries with the search term when the search term is updated', async () => {
        createComponent();

        await openDropdown();
        apolloResolver.mockClear();

        findListbox().vm.$emit('search', 'v1');
        jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
        await waitForPromises();

        expect(findListbox().props('searching')).toBe(false);
        expect(apolloResolver).toHaveBeenLastCalledWith(expect.objectContaining({ search: 'v1' }));
      });

      it('cancels the pending debounced search when the dropdown is hidden', async () => {
        createComponent();

        await openDropdown();
        apolloResolver.mockClear();

        findListbox().vm.$emit('search', 'v1');
        findListbox().vm.$emit('hidden');
        jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
        await waitForPromises();

        expect(apolloResolver).not.toHaveBeenCalled();
      });

      it('cancels the pending debounced search when the component is destroyed', async () => {
        createComponent();

        await openDropdown();
        apolloResolver.mockClear();

        findListbox().vm.$emit('search', 'v1');
        wrapper.destroy();
        jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
        await waitForPromises();

        expect(apolloResolver).not.toHaveBeenCalled();
      });
    });

    describe('when the query fails', () => {
      beforeEach(() => {
        apolloResolver = jest.fn().mockRejectedValue(new Error('GraphQL error'));
      });

      it('shows an alert', async () => {
        createComponent();

        await openDropdown();

        expect(createAlert).toHaveBeenCalledWith({
          message: 'There was a problem fetching the refs for this dependency.',
          captureError: true,
          error: expect.any(Error),
        });
      });

      it('stops loading', async () => {
        createComponent();

        await openDropdown();

        expect(findListbox().props('searching')).toBe(false);
      });
    });
  });
});
