import {
  GlFilteredSearchToken,
  GlDropdownSectionHeader,
  GlDropdownDivider,
  GlBadge,
  GlLoadingIcon,
} from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import TrackedRefToken from 'ee/security_dashboard/components/shared/filtered_search/tokens/tracked_ref_token.vue';
import { ALL_ID } from 'ee/security_dashboard/components/shared/filtered_search/constants';
import SearchSuggestion from 'ee/security_dashboard/components/shared/filtered_search/components/search_suggestion.vue';
import securityTrackedRefsQuery from 'ee/security_dashboard/graphql/queries/security_tracked_refs.query.graphql';
import { OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';

jest.mock('~/alert');

Vue.use(VueApollo);

describe('TrackedRefToken', () => {
  let wrapper;

  const trackedContextGid = (id) => `gid://gitlab/Security::ProjectTrackedContext/${id}`;

  const mockDefaultBranchContext = {
    id: trackedContextGid(1),
    name: 'main',
    refType: 'BRANCH',
  };

  const mockTrackedRefsResponse = {
    data: {
      project: {
        id: 'gid://gitlab/Project/1',
        securityTrackedRefs: {
          nodes: [
            {
              id: trackedContextGid(1),
              name: 'main',
              refType: 'BRANCH',
              isDefault: true,
            },
            {
              id: trackedContextGid(2),
              name: 'develop',
              refType: 'BRANCH',
              isDefault: false,
            },
            {
              id: trackedContextGid(3),
              name: 'v1.0.0',
              refType: 'TAG',
              isDefault: false,
            },
            {
              id: trackedContextGid(4),
              name: 'v2.0.0',
              refType: 'TAG',
              isDefault: false,
            },
          ],
        },
      },
    },
  };

  const mockTrackedRefs = mockTrackedRefsResponse.data.project.securityTrackedRefs.nodes.map(
    (ref) => ({
      id: ref.id,
      name: ref.name,
      refType: ref.refType,
      isDefault: ref.isDefault,
    }),
  );

  const mockConfig = {
    multiSelect: true,
    unique: true,
    operators: OPERATORS_OR,
  };

  const defaultTrackedRefsQueryResolver = jest.fn().mockResolvedValue(mockTrackedRefsResponse);

  const createWrapper = ({
    value = { data: [ALL_ID], operator: '=' },
    active = false,
    config = {},
    stubs,
    mountFn = shallowMountExtended,
    provide = {},
    trackedRefsQueryResolver = defaultTrackedRefsQueryResolver,
  } = {}) => {
    wrapper = mountFn(TrackedRefToken, {
      apolloProvider: createMockApollo([[securityTrackedRefsQuery, trackedRefsQueryResolver]]),
      propsData: {
        config: { ...mockConfig, ...config },
        value,
        active,
      },
      provide: {
        defaultBranchContext: mockDefaultBranchContext,
        projectFullPath: 'test/project',
        ...provide,
      },
      stubs: {
        SearchSuggestion,
        ...stubs,
      },
    });
  };

  const findFilteredSearchToken = () => wrapper.findComponent(GlFilteredSearchToken);
  const findAllBadges = () => wrapper.findAllComponents(GlBadge);
  const findDropdownGroupHeaders = () => wrapper.findAllComponents(GlDropdownSectionHeader);
  const findDropdownDividers = () => wrapper.findAllComponents(GlDropdownDivider);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findDropdownOptions = () =>
    wrapper.findAllComponents(SearchSuggestion).wrappers.map((c) => c.props('text'));
  const isOptionChecked = (v) =>
    wrapper.findComponentByTestId(`suggestion-${v}`).props('selected') === true;
  const findToggleText = () => wrapper.findByTestId('toggle-text');

  const clickDropdownItem = async (...ids) => {
    ids.forEach((id) => {
      findFilteredSearchToken().vm.$emit('select', id);
    });

    findFilteredSearchToken().vm.$emit('complete');
    await nextTick();
  };

  const allRefIdsExcept = (value) => {
    const exempt = Array.isArray(value) ? value : [value];
    return mockTrackedRefs.map((ref) => ref.id).filter((id) => !exempt.includes(id));
  };

  describe('default values', () => {
    it.each`
      context                                               | expected
      ${{ defaultBranchContext: mockDefaultBranchContext }} | ${[{ id: trackedContextGid(1), name: 'main' }]}
      ${{ defaultBranchContext: null }}                     | ${[]}
      ${{}}                                                 | ${[]}
    `('returns $expected when context is $context', ({ context, expected }) => {
      expect(TrackedRefToken.defaultValues(context)).toEqual(expected);
    });
  });

  describe('transform filters', () => {
    it.each`
      filters                                                                                                | expectedIds
      ${[ALL_ID, { id: trackedContextGid(1), name: 'main' }, { id: trackedContextGid(2), name: 'develop' }]} | ${[trackedContextGid(1), trackedContextGid(2)]}
      ${[ALL_ID]}                                                                                            | ${undefined}
      ${[]}                                                                                                  | ${undefined}
      ${[{ id: trackedContextGid(1), name: 'main' }]}                                                        | ${[trackedContextGid(1)]}
    `('returns trackedRefIds: $expectedIds', ({ filters, expectedIds }) => {
      expect(TrackedRefToken.transformFilters(filters)).toEqual({ trackedRefIds: expectedIds });
    });
  });

  describe('transform query params', () => {
    describe('multi-select', () => {
      const tokenDef = { multiSelect: true };

      it.each`
        input                                                                                          | expected
        ${[]}                                                                                          | ${ALL_ID}
        ${[ALL_ID]}                                                                                    | ${ALL_ID}
        ${[{ id: trackedContextGid(1), name: 'main' }]}                                                | ${'1~main'}
        ${[{ id: trackedContextGid(1), name: 'main' }, { id: trackedContextGid(2), name: 'develop' }]} | ${'1~main,2~develop'}
        ${[{ id: trackedContextGid(456), name: 'release/v1.0' }]}                                      | ${'456~release/v1.0'}
        ${[{ id: trackedContextGid(50), name: '' }]}                                                   | ${'50'}
        ${[{ id: trackedContextGid(50), name: '' }, { id: trackedContextGid(1), name: 'main' }]}       | ${'50,1~main'}
      `('returns "$expected" for $input', ({ input, expected }) => {
        expect(TrackedRefToken.transformQueryParams(input, tokenDef)).toBe(expected);
      });
    });

    describe('single-select', () => {
      const tokenDef = { multiSelect: false };

      it.each`
        input                                                                                          | expected
        ${[]}                                                                                          | ${undefined}
        ${[ALL_ID]}                                                                                    | ${undefined}
        ${[{ id: trackedContextGid(1), name: 'main' }]}                                                | ${'1~main'}
        ${[{ id: trackedContextGid(1), name: 'main' }, { id: trackedContextGid(2), name: 'develop' }]} | ${'1~main,2~develop'}
        ${[{ id: trackedContextGid(456), name: 'release/v1.0' }]}                                      | ${'456~release/v1.0'}
        ${[{ id: trackedContextGid(50), name: '' }]}                                                   | ${'50'}
      `('returns "$expected" for $input', ({ input, expected }) => {
        expect(TrackedRefToken.transformQueryParams(input, tokenDef)).toBe(expected);
      });
    });
  });

  describe('parse query params', () => {
    describe('multi-select', () => {
      const tokenDef = { multiSelect: true };

      it.each`
        input                                    | expected
        ${['1~main']}                            | ${[{ id: trackedContextGid(1), name: 'main' }]}
        ${['1~main', '2~develop']}               | ${[{ id: trackedContextGid(1), name: 'main' }, { id: trackedContextGid(2), name: 'develop' }]}
        ${[ALL_ID]}                              | ${[ALL_ID]}
        ${['456~release/v1.0']}                  | ${[{ id: trackedContextGid(456), name: 'release/v1.0' }]}
        ${['50']}                                | ${[{ id: trackedContextGid(50), name: '' }]}
        ${['50~']}                               | ${[{ id: trackedContextGid(50), name: '' }]}
        ${['invalid', '1~main', 'also-invalid']} | ${[{ id: trackedContextGid(1), name: 'main' }]}
        ${['invalid', 'also-invalid']}           | ${[]}
      `('returns "$expected" for "$input"', ({ input, expected }) => {
        expect(TrackedRefToken.parseQueryParams(input, tokenDef)).toEqual(expected);
      });
    });

    describe('single-select', () => {
      const tokenDef = { multiSelect: false };

      it.each`
        input                          | expected
        ${['1~main']}                  | ${[{ id: trackedContextGid(1), name: 'main' }]}
        ${['50']}                      | ${[{ id: trackedContextGid(50), name: '' }]}
        ${['50~']}                     | ${[{ id: trackedContextGid(50), name: '' }]}
        ${[ALL_ID]}                    | ${[]}
        ${['invalid', 'also-invalid']} | ${[]}
      `('returns "$expected" for "$input"', ({ input, expected }) => {
        expect(TrackedRefToken.parseQueryParams(input, tokenDef)).toEqual(expected);
      });
    });
  });

  describe('loading state', () => {
    it('shows loading icon while fetching tracked refs and hides it after fetch completes', async () => {
      createWrapper();

      expect(findLoadingIcon().exists()).toBe(true);

      await waitForPromises();

      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('shows a loading icon in the view slot when the URL has a ref id but the tracked refs have not been fetched yet', async () => {
      createWrapper({
        value: { data: [{ id: trackedContextGid(2), name: '' }] },
        stubs: {
          GlFilteredSearchToken: stubComponent(GlFilteredSearchToken, {
            template: `
              <div>
                <div data-testid="slot-view"><slot name="view"></slot></div>
                <div data-testid="slot-suggestions"><slot name="suggestions"></slot></div>
              </div>
            `,
          }),
        },
      });

      const viewSlot = wrapper.findByTestId('slot-view');
      expect(viewSlot.findComponent(GlLoadingIcon).exists()).toBe(true);

      await waitForPromises();

      expect(viewSlot.findComponent(GlLoadingIcon).exists()).toBe(false);
    });
  });

  describe('Apollo error handling', () => {
    it('shows an alert and hides URL-parsed refs when fetch fails', async () => {
      const parsedRefs = [
        {
          id: trackedContextGid(99),
          name: 'from-url',
          refType: 'BRANCH',
        },
      ];
      createWrapper({
        value: { data: parsedRefs },
        trackedRefsQueryResolver: jest.fn().mockRejectedValue(new Error('Network error')),
      });

      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Failed to load tracked refs.',
      });
      expect(findDropdownOptions()).not.toContain(parsedRefs[0].name);
      expect(findDropdownOptions()).toContain(mockDefaultBranchContext.name);
    });
  });

  describe('default view', () => {
    beforeEach(async () => {
      createWrapper();
      await waitForPromises();
    });

    it('shows "All tracked refs" as the toggle text', () => {
      expect(findFilteredSearchToken().props('value')).toEqual({
        data: [ALL_ID],
        operator: '=',
      });
      expect(findToggleText().text()).toBe('All tracked refs');
    });

    it('shows the dropdown with correct options', () => {
      expect(findDropdownOptions()).toEqual([
        'All tracked refs',
        ...mockTrackedRefs.map((ref) => ref.name),
      ]);
    });

    it('shows the dropdown with group headers for Branches and Tags', () => {
      const headers = findDropdownGroupHeaders().wrappers.map((header) => header.text());

      expect(headers).toEqual(['Branches', 'Tags']);
    });

    it('shows badges with correct icons for groups', () => {
      const badges = findAllBadges();

      expect(badges).toHaveLength(2);
      expect(badges.at(0).props('icon')).toBe('branch');
      expect(badges.at(1).props('icon')).toBe('tag');

      badges.wrappers.forEach((badge) => {
        expect(badge.attributes('aria-hidden')).toBe('true');
      });
    });

    it.each`
      refType       | nodes
      ${'Branches'} | ${[{ id: trackedContextGid(1), name: 'main', refType: 'BRANCH', isDefault: true }, { id: trackedContextGid(2), name: 'develop', refType: 'BRANCH', isDefault: false }]}
      ${'Tags'}     | ${[{ id: trackedContextGid(3), name: 'v1.0.0', refType: 'TAG', isDefault: false }, { id: trackedContextGid(4), name: 'v2.0.0', refType: 'TAG', isDefault: false }]}
    `(
      'renders only the "$refType" group when no other ref types are present',
      async ({ refType, nodes }) => {
        createWrapper({
          provide: { defaultBranchContext: { id: nodes[0].id, name: nodes[0].name } },
          trackedRefsQueryResolver: jest.fn().mockResolvedValue({
            data: { project: { id: 'gid://gitlab/Project/1', securityTrackedRefs: { nodes } } },
          }),
        });
        await waitForPromises();

        const headers = findDropdownGroupHeaders().wrappers.map((header) => header.text());

        expect(headers).toEqual([refType]);
        expect(findAllBadges()).toHaveLength(1);
      },
    );

    it('handles empty trackedRefs response', async () => {
      createWrapper({
        provide: { defaultBranchContext: null },
        trackedRefsQueryResolver: jest.fn().mockResolvedValue({
          data: { project: { id: 'gid://gitlab/Project/1', securityTrackedRefs: { nodes: [] } } },
        }),
      });
      await waitForPromises();

      expect(findDropdownOptions()).toEqual(['All tracked refs']);
      expect(findDropdownGroupHeaders()).toHaveLength(0);
    });

    it('renders dividers between groups', () => {
      expect(findDropdownDividers()).toHaveLength(2);
    });

    it('renders one divider when only branches are present', async () => {
      const branchOnlyNodes = [
        {
          id: trackedContextGid(1),
          name: 'main',
          refType: 'BRANCH',
          isDefault: true,
        },
        {
          id: trackedContextGid(2),
          name: 'develop',
          refType: 'BRANCH',
          isDefault: false,
        },
      ];
      createWrapper({
        trackedRefsQueryResolver: jest.fn().mockResolvedValue({
          data: {
            project: {
              id: 'gid://gitlab/Project/1',
              securityTrackedRefs: { nodes: branchOnlyNodes },
            },
          },
        }),
      });
      await waitForPromises();

      expect(findDropdownDividers()).toHaveLength(1);
    });
  });

  describe('item selection', () => {
    beforeEach(async () => {
      createWrapper();
      await waitForPromises();
      // Ensure we start from a known state with ALL_ID selected
      await clickDropdownItem(ALL_ID);
    });

    it('selects "All tracked refs" and clears other selections when "All tracked refs" is selected', async () => {
      await clickDropdownItem(trackedContextGid(1), trackedContextGid(2));
      expect(isOptionChecked(trackedContextGid(1))).toBe(true);
      expect(isOptionChecked(trackedContextGid(2))).toBe(true);
      expect(isOptionChecked(ALL_ID)).toBe(false);

      await clickDropdownItem(ALL_ID);

      expect(isOptionChecked(ALL_ID)).toBe(true);
      allRefIdsExcept(ALL_ID).forEach((id) => {
        expect(isOptionChecked(id)).toBe(false);
      });
    });

    it('removes "All tracked refs" when a specific ref is selected', async () => {
      expect(isOptionChecked(ALL_ID)).toBe(true);

      await clickDropdownItem(trackedContextGid(1));

      expect(isOptionChecked(ALL_ID)).toBe(false);
      expect(isOptionChecked(trackedContextGid(1))).toBe(true);
    });

    it('allows multiple refs to be selected', async () => {
      await clickDropdownItem(trackedContextGid(1), trackedContextGid(2), trackedContextGid(3));

      expect(isOptionChecked(trackedContextGid(1))).toBe(true);
      expect(isOptionChecked(trackedContextGid(2))).toBe(true);
      expect(isOptionChecked(trackedContextGid(3))).toBe(true);
      expect(isOptionChecked(ALL_ID)).toBe(false);
    });

    it('deselects a ref when clicked again', async () => {
      await clickDropdownItem(trackedContextGid(1), trackedContextGid(2));
      expect(isOptionChecked(trackedContextGid(1))).toBe(true);
      expect(isOptionChecked(trackedContextGid(2))).toBe(true);

      await clickDropdownItem(trackedContextGid(1));

      expect(isOptionChecked(trackedContextGid(1))).toBe(false);
      expect(isOptionChecked(trackedContextGid(2))).toBe(true);
    });

    it('defaults to "All tracked refs" when all selections are cleared', async () => {
      await clickDropdownItem(trackedContextGid(1));
      expect(isOptionChecked(trackedContextGid(1))).toBe(true);

      await clickDropdownItem(trackedContextGid(1));

      expect(isOptionChecked(ALL_ID)).toBe(true);
      allRefIdsExcept(ALL_ID).forEach((id) => {
        expect(isOptionChecked(id)).toBe(false);
      });
    });

    it('updates `multiSelectValues` prop when selecting refs', async () => {
      await clickDropdownItem(trackedContextGid(1), trackedContextGid(2));

      expect(findFilteredSearchToken().props('multiSelectValues')).toEqual([
        { id: trackedContextGid(1), name: 'main', refType: 'BRANCH' },
        {
          id: trackedContextGid(2),
          name: 'develop',
          refType: 'BRANCH',
        },
      ]);
    });

    it('updates `multiSelectValues` prop when selecting `ALL_ID`', async () => {
      await clickDropdownItem(trackedContextGid(1), trackedContextGid(2));
      await clickDropdownItem(ALL_ID);

      expect(findFilteredSearchToken().props('multiSelectValues')).toEqual([ALL_ID]);
    });

    it('updates `multiSelectValues` prop when deselecting all refs', async () => {
      await clickDropdownItem(trackedContextGid(1));
      await clickDropdownItem(trackedContextGid(1));

      expect(findFilteredSearchToken().props('multiSelectValues')).toEqual([ALL_ID]);
    });

    describe('event tracking', () => {
      const { bindInternalEventDocument } = useMockInternalEventsTracking();
      const EVENT_NAME = 'applied_non_default_branch_filter';
      let trackEventSpy;

      beforeEach(() => {
        ({ trackEventSpy } = bindInternalEventDocument(wrapper.element));
      });

      it.each`
        scenario                                      | selectedRefs
        ${'all is selected'}                          | ${[ALL_ID]}
        ${'default branch with a non-default branch'} | ${[trackedContextGid(1), trackedContextGid(2)]}
        ${'only non-default branches are selected'}   | ${[trackedContextGid(2), trackedContextGid(3)]}
      `('tracks event when $scenario', async ({ selectedRefs }) => {
        await clickDropdownItem(...selectedRefs);

        expect(trackEventSpy).toHaveBeenCalledWith(EVENT_NAME, {}, undefined);
      });

      it('does not track event when only the default branch is selected', async () => {
        await clickDropdownItem(trackedContextGid(1));

        expect(trackEventSpy).not.toHaveBeenCalled();
      });
    });
  });

  describe('single-select mode', () => {
    beforeEach(async () => {
      createWrapper({ config: { multiSelect: false } });
      await waitForPromises();
    });

    it('replaces selection instead of adding to it', async () => {
      await clickDropdownItem(trackedContextGid(1));
      expect(isOptionChecked(trackedContextGid(1))).toBe(true);

      await clickDropdownItem(trackedContextGid(3));

      expect(isOptionChecked(trackedContextGid(3))).toBe(true);
      expect(isOptionChecked(trackedContextGid(1))).toBe(false);
    });

    it('does not show "All tracked refs" option', () => {
      expect(findDropdownOptions()).toEqual(mockTrackedRefs.map((ref) => ref.name));
    });

    it('does not render divider before branches when "All" option is hidden', () => {
      expect(findDropdownDividers()).toHaveLength(1);
    });

    it('shows the default ref when initialized with default value', async () => {
      createWrapper({
        config: { multiSelect: false },
        value: { data: [mockDefaultBranchContext] },
      });
      await waitForPromises();

      expect(isOptionChecked(trackedContextGid(1))).toBe(true);
    });

    it('shows "Select a ref" when nothing is selected and there is no default ref', async () => {
      createWrapper({
        config: { multiSelect: false },
        provide: { defaultBranchContext: null },
        value: { data: [] },
        trackedRefsQueryResolver: jest.fn().mockResolvedValue({
          data: { project: { id: 'gid://gitlab/Project/1', securityTrackedRefs: { nodes: [] } } },
        }),
      });
      await waitForPromises();

      expect(findToggleText().text()).toBe('Select a ref');
    });
  });

  describe('toggle text', () => {
    const findViewText = () => findToggleText().text();

    beforeEach(async () => {
      createWrapper();
      await waitForPromises();
      // Ensure we start from a known state with ALL_ID selected
      await clickDropdownItem(ALL_ID);
    });

    it.each`
      selectedRefs                                                          | expectedText
      ${[ALL_ID]}                                                           | ${'All tracked refs'}
      ${[trackedContextGid(1)]}                                             | ${'main'}
      ${[trackedContextGid(1), trackedContextGid(2)]}                       | ${'main, develop'}
      ${[trackedContextGid(3), trackedContextGid(4)]}                       | ${'v1.0.0, v2.0.0'}
      ${[trackedContextGid(1), trackedContextGid(3)]}                       | ${'main, v1.0.0'}
      ${[trackedContextGid(1), trackedContextGid(2), trackedContextGid(3)]} | ${'main, develop +1 more'}
    `(
      'shows "$expectedText" when "$selectedRefs" are selected',
      async ({ selectedRefs, expectedText }) => {
        await clickDropdownItem(...selectedRefs);

        expect(findViewText()).toBe(expectedText);
      },
    );
  });

  describe('token value', () => {
    it('sets `data` to `null` when token is active', async () => {
      createWrapper({
        active: true,
        value: {
          data: [
            {
              id: trackedContextGid(1),
              name: 'main',
              refType: 'BRANCH',
            },
            {
              id: trackedContextGid(2),
              name: 'develop',
              refType: 'BRANCH',
            },
          ],
        },
      });
      await waitForPromises();

      expect(findFilteredSearchToken().props('value')).toEqual({
        data: null,
      });
    });

    it('sets `data` to selected refs when token is not active', async () => {
      const selectedRefs = [
        { id: trackedContextGid(1), name: 'main', refType: 'BRANCH' },
        {
          id: trackedContextGid(2),
          name: 'develop',
          refType: 'BRANCH',
        },
      ];
      createWrapper({ active: false, value: { data: selectedRefs } });
      await waitForPromises();

      expect(findFilteredSearchToken().props('value')).toEqual({
        data: selectedRefs,
      });
    });
  });

  describe('component initialization', () => {
    it('initializes with provided `value` data', async () => {
      const selectedRefs = [
        { id: trackedContextGid(1), name: 'main', refType: 'BRANCH' },
        {
          id: trackedContextGid(2),
          name: 'develop',
          refType: 'BRANCH',
        },
      ];
      createWrapper({ value: { data: selectedRefs } });
      await waitForPromises();

      expect(findFilteredSearchToken().props('multiSelectValues')).toEqual(selectedRefs);
    });

    it('initializes with default branch when provided via `value` data', async () => {
      createWrapper({ value: { data: [mockDefaultBranchContext] } });
      await waitForPromises();

      expect(findFilteredSearchToken().props('multiSelectValues')).toEqual([
        mockDefaultBranchContext,
      ]);
    });
  });

  describe('tracked refs aggregation', () => {
    it('combines `defaultBranchContext` with fetched refs', async () => {
      createWrapper();
      await waitForPromises();

      expect(findDropdownOptions()).toContain(mockDefaultBranchContext.name);
      expect(findDropdownOptions()).toContain(mockTrackedRefs[1].name);
      expect(findDropdownOptions()).toContain(mockTrackedRefs[2].name);
    });
  });

  describe('removeStaleRefs', () => {
    it('removes refs that are no longer valid after fetch', async () => {
      // Start with a ref that won't be in the response
      const staleRef = {
        id: trackedContextGid(999),
        name: 'stale-branch',
        refType: 'BRANCH',
      };
      createWrapper({
        value: { data: [staleRef, mockDefaultBranchContext] },
      });

      await waitForPromises();

      expect(findFilteredSearchToken().props('multiSelectValues')).not.toContainEqual(staleRef);
    });

    it('resets to `ALL_ID` when all selected refs become stale', async () => {
      const staleRef = {
        id: trackedContextGid(999),
        name: 'stale-branch',
        refType: 'BRANCH',
      };
      createWrapper({
        value: { data: [staleRef] },
        provide: { defaultBranchContext: null },
      });

      await waitForPromises();

      expect(findFilteredSearchToken().props('multiSelectValues')).toEqual([ALL_ID]);
    });
  });
});
