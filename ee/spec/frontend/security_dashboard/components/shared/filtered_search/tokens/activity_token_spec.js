import { GlFilteredSearchToken, GlDropdownSectionHeader, GlBadge } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueRouter from 'vue-router';
import ActivityToken, {
  GROUPS,
} from 'ee/security_dashboard/components/shared/filtered_search/tokens/activity_token.vue';
import {
  DASHBOARD_TYPE_PROJECT,
  DASHBOARD_TYPE_GROUP,
  DASHBOARD_TYPE_INSTANCE,
} from 'ee/security_dashboard/constants';
import SearchSuggestion from 'ee/security_dashboard/components/shared/filtered_search/components/search_suggestion.vue';
import { OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';

Vue.use(VueRouter);

describe('ActivityToken', () => {
  let wrapper;
  let router;
  const originalGon = window.gon;

  const mockConfig = {
    multiSelect: true,
    unique: true,
    operators: OPERATORS_OR,
  };

  const createWrapper = ({
    value = { data: ActivityToken.DEFAULT_VALUES, operator: '||' },
    active = false,
    stubs,
    mountFn = shallowMountExtended,
    provide,
  } = {}) => {
    router = new VueRouter({ mode: 'history' });

    wrapper = mountFn(ActivityToken, {
      router,
      propsData: {
        config: mockConfig,
        value,
        active,
      },
      provide: {
        portalName: 'fake target',
        alignSuggestions: jest.fn(),
        termsAsTokens: () => false,
        dashboardType: DASHBOARD_TYPE_PROJECT,
        duoAgentPlatformAvailable: false,
        ...provide,
      },
      stubs: {
        SearchSuggestion,
        ...stubs,
      },
    });
  };

  const findFilteredSearchToken = () => wrapper.findComponent(GlFilteredSearchToken);
  const isOptionChecked = (v) =>
    wrapper.findComponentByTestId(`suggestion-${v}`).props('selected') === true;

  const clickDropdownItem = async (...ids) => {
    await Promise.all(
      ids.map((id) => {
        findFilteredSearchToken().vm.$emit('select', id);
        return nextTick();
      }),
    );

    findFilteredSearchToken().vm.$emit('complete');
    await nextTick();
  };

  const allOptionsExcept = (value) => {
    const exempt = Array.isArray(value) ? value : [value];

    return GROUPS.flatMap((i) => i.options)
      .map((i) => i.value)
      .filter((i) => !exempt.includes(i));
  };

  describe('default view', () => {
    const findAllBadges = () => wrapper.findAllComponents(GlBadge);
    const createWrapperWithAbility = ({
      resolveVulnerabilityWithAi,
      accessAdvancedVulnerabilityManagement,
      provide = {},
    } = {}) => {
      createWrapper({
        provide: {
          glAbilities: {
            resolveVulnerabilityWithAi,
            accessAdvancedVulnerabilityManagement,
          },

          ...provide,
        },
      });
    };

    afterEach(() => {
      window.gon = originalGon;
    });

    it('shows the label', () => {
      createWrapperWithAbility();
      expect(findFilteredSearchToken().props('value')).toEqual({
        data: ['ALL'],
        operator: '||',
      });
      expect(wrapper.findByTestId('activity-token-placeholder').text()).toBe('All activity');
    });

    it('has a defaultValues function', () => {
      expect(ActivityToken.defaultValues()).toEqual(['STILL_DETECTED']);
    });

    const baseOptions = [
      'All activity',
      'Still detected',
      'No longer detected',
      'Has issue',
      'Does not have issue',
      'Has merge request',
      'Does not have merge request',
      'Has a solution',
      'Does not have a solution',
    ];

    const aiResolutionOptions = [
      'Vulnerability Resolution available',
      'Vulnerability Resolution unavailable',
    ];

    const aiFpOptions = ['False positive', 'Not identified as false positive'];

    const policyViolationOptions = ['Dismissed in MR'];
    const policyActionsOptions = [
      'Dismissed by vulnerability policy',
      'Not dismissed by vulnerability policy',
    ];
    const baseGroupHeaders = ['Detection', 'Issue', 'Merge Request', 'Solution available'];
    const aiResolutionHeaders = ['GitLab Duo resolution'];
    const aiFpHeaders = ['GitLab Duo FP detection'];
    const policyViolationsGroupHeaders = ['Policy violations'];
    const policyActionsGroupHeaders = ['Policy actions'];

    it.each`
      resolveVulnerabilityWithAi | expectedOptions
      ${true}                    | ${[...baseOptions, ...aiResolutionOptions, ...policyActionsOptions]}
      ${false}                   | ${[...baseOptions, ...policyActionsOptions]}
    `(
      'shows the dropdown with correct options when resolveVulnerabilityWithAi=$resolveVulnerabilityWithAi',
      ({ resolveVulnerabilityWithAi, expectedOptions }) => {
        createWrapperWithAbility({ resolveVulnerabilityWithAi });
        const findDropdownOptions = () =>
          wrapper.findAllComponents(SearchSuggestion).wrappers.map((c) => c.text());

        expect(findDropdownOptions()).toEqual(expectedOptions);
      },
    );

    it.each`
      accessAdvancedVulnerabilityManagement | duoAgentPlatformAvailable | expectedOptions
      ${true}                               | ${true}                   | ${[...baseOptions, ...aiFpOptions]}
      ${true}                               | ${false}                  | ${baseOptions}
      ${false}                              | ${true}                   | ${baseOptions}
    `(
      'shows the dropdown with correct options when ' +
        'accessAdvancedVulnerabilityManagement=$accessAdvancedVulnerabilityManagement and ' +
        'duoAgentPlatformAvailable=$duoAgentPlatformAvailable',
      ({ accessAdvancedVulnerabilityManagement, duoAgentPlatformAvailable, expectedOptions }) => {
        createWrapperWithAbility({
          accessAdvancedVulnerabilityManagement,
          provide: {
            duoAgentPlatformAvailable,
            dashboardType: DASHBOARD_TYPE_INSTANCE,
          },
        });
        const findDropdownOptions = () =>
          wrapper.findAllComponents(SearchSuggestion).wrappers.map((c) => c.text());

        expect(findDropdownOptions()).toEqual(expectedOptions);
      },
    );

    it.each`
      dashboardType              | accessAdvancedVulnerabilityManagement | expectedOptions
      ${DASHBOARD_TYPE_PROJECT}  | ${true}                               | ${[...baseOptions, ...policyViolationOptions, ...policyActionsOptions]}
      ${DASHBOARD_TYPE_PROJECT}  | ${false}                              | ${[...baseOptions, ...policyActionsOptions]}
      ${DASHBOARD_TYPE_GROUP}    | ${true}                               | ${[...baseOptions, ...policyViolationOptions, ...policyActionsOptions]}
      ${DASHBOARD_TYPE_INSTANCE} | ${true}                               | ${baseOptions}
    `(
      'shows the dropdown with correct options when dashboardType=$dashboardType and accessAdvancedVulnerabilityManagement=$accessAdvancedVulnerabilityManagement',
      ({ dashboardType, accessAdvancedVulnerabilityManagement, expectedOptions }) => {
        createWrapperWithAbility({
          accessAdvancedVulnerabilityManagement,
          provide: { dashboardType },
        });

        const findDropdownOptions = () =>
          wrapper.findAllComponents(SearchSuggestion).wrappers.map((c) => c.text());

        expect(findDropdownOptions()).toEqual(expectedOptions);
      },
    );

    it('shows the dropdown with correct options when both the resolveVulnerabilityWithAi and accessAdvancedVulnerabilityManagement are true', () => {
      createWrapperWithAbility({
        accessAdvancedVulnerabilityManagement: true,
        resolveVulnerabilityWithAi: true,
      });

      const findDropdownOptions = () =>
        wrapper.findAllComponents(SearchSuggestion).wrappers.map((c) => c.text());

      expect(findDropdownOptions()).toEqual([
        ...baseOptions,
        ...aiResolutionOptions,
        ...policyViolationOptions,
        ...policyActionsOptions,
      ]);
    });

    it.each`
      resolveVulnerabilityWithAi | expectedGroups
      ${true}                    | ${[...baseGroupHeaders, ...aiResolutionHeaders, ...policyActionsGroupHeaders]}
      ${false}                   | ${[...baseGroupHeaders, ...policyActionsGroupHeaders]}
    `(
      'shows the group headers correctly resolveVulnerabilityWithAi=$resolveVulnerabilityWithAi',
      ({ resolveVulnerabilityWithAi, expectedGroups }) => {
        createWrapperWithAbility({ resolveVulnerabilityWithAi });
        const findDropdownGroupHeaders = () =>
          wrapper.findAllComponents(GlDropdownSectionHeader).wrappers.map((c) => c.text());

        expect(findDropdownGroupHeaders()).toEqual(expectedGroups);
      },
    );

    it.each`
      accessAdvancedVulnerabilityManagement | duoAgentPlatformAvailable | expectedGroups
      ${true}                               | ${true}                   | ${[...baseGroupHeaders, ...aiFpHeaders]}
      ${true}                               | ${false}                  | ${baseGroupHeaders}
      ${false}                              | ${true}                   | ${baseGroupHeaders}
    `(
      'shows the group headers correctly when ' +
        'accessAdvancedVulnerabilityManagement=$accessAdvancedVulnerabilityManagement and ' +
        'duoAgentPlatformAvailable=$duoAgentPlatformAvailable',
      ({ accessAdvancedVulnerabilityManagement, duoAgentPlatformAvailable, expectedGroups }) => {
        createWrapperWithAbility({
          accessAdvancedVulnerabilityManagement,
          provide: {
            duoAgentPlatformAvailable,
            dashboardType: DASHBOARD_TYPE_INSTANCE,
          },
        });
        const findDropdownGroupHeaders = () =>
          wrapper.findAllComponents(GlDropdownSectionHeader).wrappers.map((c) => c.text());

        expect(findDropdownGroupHeaders()).toEqual(expectedGroups);
      },
    );

    it.each`
      dashboardType              | accessAdvancedVulnerabilityManagement | expectedGroups
      ${DASHBOARD_TYPE_PROJECT}  | ${true}                               | ${[...baseGroupHeaders, ...policyViolationsGroupHeaders, ...policyActionsGroupHeaders]}
      ${DASHBOARD_TYPE_PROJECT}  | ${false}                              | ${[...baseGroupHeaders, ...policyActionsGroupHeaders]}
      ${DASHBOARD_TYPE_GROUP}    | ${true}                               | ${[...baseGroupHeaders, ...policyViolationsGroupHeaders, ...policyActionsGroupHeaders]}
      ${DASHBOARD_TYPE_INSTANCE} | ${true}                               | ${baseGroupHeaders}
    `(
      'shows the correct group headers when dashboardType=$dashboardType and accessAdvancedVulnerabilityManagement=$accessAdvancedVulnerabilityManagement',
      ({ dashboardType, accessAdvancedVulnerabilityManagement, expectedGroups }) => {
        createWrapperWithAbility({
          accessAdvancedVulnerabilityManagement,
          provide: { dashboardType },
        });

        const findDropdownGroupHeaders = () =>
          wrapper.findAllComponents(GlDropdownSectionHeader).wrappers.map((c) => c.text());

        expect(findDropdownGroupHeaders()).toEqual(expectedGroups);
      },
    );

    it.each`
      dashboardType              | expectedGroups
      ${DASHBOARD_TYPE_PROJECT}  | ${[...baseGroupHeaders, ...policyActionsGroupHeaders]}
      ${DASHBOARD_TYPE_GROUP}    | ${[...baseGroupHeaders, ...policyActionsGroupHeaders]}
      ${DASHBOARD_TYPE_INSTANCE} | ${baseGroupHeaders}
    `(
      'renders policy actions group based on dashboard type',
      ({ dashboardType, expectedGroups }) => {
        createWrapper({ provide: { dashboardType } });

        const findDropdownGroupHeaders = () =>
          wrapper.findAllComponents(GlDropdownSectionHeader).wrappers.map((c) => c.text());

        expect(findDropdownGroupHeaders()).toEqual(expectedGroups);
      },
    );

    it('shows the correct group headers when both resolveVulnerabilityWithAi and accessAdvancedVulnerabilityManagement are true', () => {
      createWrapperWithAbility({
        accessAdvancedVulnerabilityManagement: true,
        resolveVulnerabilityWithAi: true,
      });

      const findDropdownGroupHeaders = () =>
        wrapper.findAllComponents(GlDropdownSectionHeader).wrappers.map((c) => c.text());

      expect(findDropdownGroupHeaders()).toEqual([
        ...baseGroupHeaders,
        ...aiResolutionHeaders,
        ...policyViolationsGroupHeaders,
        ...policyActionsGroupHeaders,
      ]);
    });

    describe('badges', () => {
      const defaultBadges = ['check-circle-dashed', 'work-item-issue', 'merge-request', 'bulb'];

      it.each`
        resolveVulnerabilityWithAi | expectedBadges
        ${true}                    | ${[...defaultBadges, 'tanuki-ai', 'clear-all']}
        ${false}                   | ${[...defaultBadges, 'clear-all']}
      `(
        'shows the correct badges when resolveVulnerabilityWithAi=$resolveVulnerabilityWithAi',
        ({ resolveVulnerabilityWithAi, expectedBadges }) => {
          createWrapperWithAbility({ resolveVulnerabilityWithAi });
          expect(findAllBadges().wrappers.map((component) => component.props('icon'))).toEqual(
            expectedBadges,
          );
        },
      );

      it.each`
        accessAdvancedVulnerabilityManagement | expectedBadges
        ${true}                               | ${[...defaultBadges, 'flag', 'clear-all']}
        ${false}                              | ${[...defaultBadges, 'clear-all']}
      `(
        'shows the correct badges when accessAdvancedVulnerabilityManagement=$accessAdvancedVulnerabilityManagement',
        ({ accessAdvancedVulnerabilityManagement, expectedBadges }) => {
          createWrapperWithAbility({ accessAdvancedVulnerabilityManagement });

          expect(findAllBadges().wrappers.map((component) => component.props('icon'))).toEqual(
            expectedBadges,
          );
        },
      );

      it('shows the policy actions badge', () => {
        createWrapper();

        expect(findAllBadges().wrappers.map((component) => component.props('icon'))).toEqual([
          ...defaultBadges,
          'clear-all',
        ]);
      });

      it('shows the correct badges when resolveVulnerabilityWithAi and accessAdvancedVulnerabilityManagement is true', () => {
        createWrapperWithAbility({
          accessAdvancedVulnerabilityManagement: true,
          resolveVulnerabilityWithAi: true,
        });

        expect(findAllBadges().wrappers.map((component) => component.props('icon'))).toEqual([
          'check-circle-dashed',
          'work-item-issue',
          'merge-request',
          'bulb',
          'tanuki-ai',
          'flag',
          'clear-all',
        ]);
      });
    });
  });

  describe('item selection', () => {
    beforeEach(async () => {
      createWrapper({});
      await clickDropdownItem('ALL');
    });

    it('allows multiple selection of items across groups', async () => {
      await clickDropdownItem('HAS_ISSUE', 'HAS_MERGE_REQUEST');

      expect(isOptionChecked('HAS_ISSUE')).toBe(true);
      expect(isOptionChecked('HAS_MERGE_REQUEST')).toBe(true);
      expect(isOptionChecked('ALL')).toBe(false);
    });

    it('allows only one item to be selected within a group', async () => {
      await clickDropdownItem('HAS_ISSUE', 'DOES_NOT_HAVE_ISSUE');

      expect(isOptionChecked('HAS_ISSUE')).toBe(false);
      expect(isOptionChecked('DOES_NOT_HAVE_ISSUE')).toBe(true);
      expect(isOptionChecked('ALL')).toBe(false);
    });

    it('selects only "All activity" when that item is selected', async () => {
      await clickDropdownItem('HAS_ISSUE', 'HAS_MERGE_REQUEST', 'ALL');

      allOptionsExcept('ALL').forEach((value) => {
        expect(isOptionChecked(value)).toBe(false);
      });
      expect(isOptionChecked('ALL')).toBe(true);
    });

    it('selects "All activity" when last selected item is deselected', async () => {
      // Select and deselect "Has issue"
      await clickDropdownItem('HAS_ISSUE', 'HAS_ISSUE');

      allOptionsExcept('ALL').forEach((value) => {
        expect(isOptionChecked(value)).toBe(false);
      });
      expect(isOptionChecked('ALL')).toBe(true);
    });
  });

  describe('toggle text', () => {
    const findViewSlot = () => wrapper.findAllByTestId('filtered-search-token-segment').at(2);

    beforeEach(async () => {
      createWrapper({ mountFn: mountExtended });

      // Let's set initial state as ALL. It's easier to manipulate because
      // selecting a new value should unselect this value automatically and
      // we can start from an empty state.
      await clickDropdownItem('ALL');
    });

    it('shows "Has issue" when only "Has issue" is selected', async () => {
      await clickDropdownItem('HAS_ISSUE');
      expect(findViewSlot().text()).toBe('Has issue');
    });

    it('shows "Has issue, Has merge request" when "Has issue" and another option is selected', async () => {
      await clickDropdownItem('HAS_ISSUE', 'HAS_MERGE_REQUEST');
      expect(findViewSlot().text()).toBe('Has issue, Has merge request');
    });

    it('shows "Still detected, Has issue +1 more" when more than 2 options are selected', async () => {
      await clickDropdownItem('STILL_DETECTED', 'HAS_ISSUE', 'HAS_MERGE_REQUEST');
      expect(findViewSlot().text()).toBe('Still detected, Has issue +1 more');
    });

    it('shows "All activity" when "All activity" is selected', async () => {
      await clickDropdownItem('ALL');
      expect(findViewSlot().text()).toBe('All activity');
    });
  });

  describe('transformFilters', () => {
    const defaultOptions = { dashboardType: DASHBOARD_TYPE_PROJECT };

    afterEach(() => {
      window.gon = originalGon;
    });

    it('returns base filters when given an empty array', () => {
      window.gon = { abilities: {} };

      expect(ActivityToken.transformFilters([], defaultOptions)).toEqual({
        hasResolution: undefined,
        hasIssues: undefined,
        hasMergeRequest: undefined,
        hasRemediations: undefined,
      });
    });

    it('sets hasResolution correctly based on filters', () => {
      window.gon = { abilities: {} };

      expect(ActivityToken.transformFilters(['STILL_DETECTED'], defaultOptions).hasResolution).toBe(
        false,
      );

      expect(
        ActivityToken.transformFilters(['NO_LONGER_DETECTED'], defaultOptions).hasResolution,
      ).toBe(true);
    });

    it('sets hasIssues correctly based on filters', () => {
      window.gon = { abilities: {} };

      expect(ActivityToken.transformFilters(['HAS_ISSUE'], defaultOptions).hasIssues).toBe(true);

      expect(
        ActivityToken.transformFilters(['DOES_NOT_HAVE_ISSUE'], defaultOptions).hasIssues,
      ).toBe(false);
    });

    it('sets hasMergeRequest correctly based on filters', () => {
      window.gon = { abilities: {} };

      expect(
        ActivityToken.transformFilters(['HAS_MERGE_REQUEST'], defaultOptions).hasMergeRequest,
      ).toBe(true);

      expect(
        ActivityToken.transformFilters(['DOES_NOT_HAVE_MERGE_REQUEST'], defaultOptions)
          .hasMergeRequest,
      ).toBe(false);
    });

    it('sets hasRemediations correctly based on filters', () => {
      window.gon = { abilities: {} };

      expect(ActivityToken.transformFilters(['HAS_SOLUTION'], defaultOptions).hasRemediations).toBe(
        true,
      );

      expect(
        ActivityToken.transformFilters(['DOES_NOT_HAVE_SOLUTION'], defaultOptions).hasRemediations,
      ).toBe(false);
    });

    describe('AI resolution filter', () => {
      describe('when resolveVulnerabilityWithAi ability is true', () => {
        it('sets hasAiResolution correctly based on filters', () => {
          window.gon = { abilities: { resolveVulnerabilityWithAi: true } };

          expect(
            ActivityToken.transformFilters(['AI_RESOLUTION_AVAILABLE'], defaultOptions)
              .hasAiResolution,
          ).toBe(true);

          expect(
            ActivityToken.transformFilters(['AI_RESOLUTION_UNAVAILABLE'], defaultOptions)
              .hasAiResolution,
          ).toBe(false);
        });
      });

      it('does not include hasAiResolution when resolveVulnerabilityWithAi ability is false', () => {
        window.gon = { abilities: { resolveVulnerabilityWithAi: false } };

        const result = ActivityToken.transformFilters(['AI_RESOLUTION_AVAILABLE'], defaultOptions);

        expect(result).not.toHaveProperty('hasAiResolution');
      });
    });

    describe('AI FP filter', () => {
      it.each`
        accessAdvancedVulnerabilityManagement | queryParam       | expected
        ${true}                               | ${['AI_FP']}     | ${true}
        ${true}                               | ${['AI_NON_FP']} | ${false}
        ${false}                              | ${['AI_NON_FP']} | ${undefined}
        ${false}                              | ${[]}            | ${undefined}
      `(
        'when accessAdvancedVulnerabilityManagement=$accessAdvancedVulnerabilityManagement it sets falsePositive=$expected',
        ({ accessAdvancedVulnerabilityManagement, queryParam, expected }) => {
          window.gon = {
            abilities: { accessAdvancedVulnerabilityManagement },
          };

          expect(ActivityToken.transformFilters(queryParam, defaultOptions).falsePositive).toBe(
            expected,
          );
        },
      );
    });

    describe('policy violation filter', () => {
      it.each([DASHBOARD_TYPE_PROJECT, DASHBOARD_TYPE_GROUP])(
        'includes policyViolations when DISMISSED_IN_MR is in filters and dashboardType is %s',
        (dashboardType) => {
          window.gon = { abilities: { accessAdvancedVulnerabilityManagement: true } };

          const result = ActivityToken.transformFilters(['DISMISSED_IN_MR'], { dashboardType });

          expect(result.policyViolations).toBe('DISMISSED_IN_MR');
        },
      );

      it('does not include policyViolations when dashboardType is instance', () => {
        window.gon = { abilities: { accessAdvancedVulnerabilityManagement: true } };

        const result = ActivityToken.transformFilters(['DISMISSED_IN_MR'], {
          dashboardType: DASHBOARD_TYPE_INSTANCE,
        });

        expect(result).not.toHaveProperty('policyViolations');
      });

      it('does not include policyViolations when feature flags are disabled', () => {
        window.gon = { abilities: { accessAdvancedVulnerabilityManagement: false } };

        const result = ActivityToken.transformFilters(['DISMISSED_IN_MR'], defaultOptions);

        expect(result).not.toHaveProperty('policyViolations');
      });

      it('does not include policyViolations when DISMISSED_IN_MR is not in filters', () => {
        window.gon = { abilities: { accessAdvancedVulnerabilityManagement: true } };

        const result = ActivityToken.transformFilters(['HAS_ISSUE'], defaultOptions);

        expect(result).not.toHaveProperty('policyViolations');
      });
    });

    describe('policy auto-dismiss filter', () => {
      it('includes policyAutoDismissed when DISMISSED_BY_POLICY is selected', () => {
        const result = ActivityToken.transformFilters(['DISMISSED_BY_POLICY'], defaultOptions);

        expect(result.policyAutoDismissed).toBe(true);
      });
    });

    it('handles multiple filters correctly', () => {
      window.gon = { abilities: { resolveVulnerabilityWithAi: true } };

      const result = ActivityToken.transformFilters(
        ['STILL_DETECTED', 'HAS_ISSUE', 'HAS_MERGE_REQUEST', 'AI_RESOLUTION_AVAILABLE'],
        defaultOptions,
      );

      expect(result).toEqual({
        hasResolution: false,
        hasIssues: true,
        hasMergeRequest: true,
        hasRemediations: undefined,
        hasAiResolution: true,
      });
    });
  });

  describe('transformQueryParams', () => {
    it('returns "ALL" when filters is an empty array', () => {
      expect(ActivityToken.transformQueryParams([])).toBe('ALL');
    });

    it('joins the filters in comma-separated string otherwise', () => {
      expect(ActivityToken.transformQueryParams(['NO_LONGER_DETECTED', 'HAS_ISSUE'])).toBe(
        'NO_LONGER_DETECTED,HAS_ISSUE',
      );
    });
  });
});
