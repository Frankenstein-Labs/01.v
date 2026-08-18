import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlBadge, GlButton, GlPopover, GlToggle } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import OrbitToggle from 'ee/ai/duo_agentic_chat/components/orbit_toggle.vue';
import getOrbitUserPreference from 'ee/ai/graphql/get_orbit_user_preference.query.graphql';
import updateOrbitUserPreference from 'ee/ai/graphql/update_orbit_user_preference.mutation.graphql';

Vue.use(VueApollo);

describe('OrbitToggle', () => {
  let wrapper;

  const ORBIT_FLAGS_ENABLED = {
    orbitUserPreference: true,
    knowledgeGraph: true,
    orbitFoundationalAgent: true,
  };

  const KEY_CHAT = 'orbit_agentic_chat_enabled';
  const KEY_FOUNDATIONAL = 'orbit_other_foundational_agents_enabled';
  const KEY_CUSTOM_AGENTS = 'orbit_custom_agents_enabled';

  // Agents that map (via OrbitToggle's internal derivation) to each subsetting key.
  const AGENT_CHAT = { referenceWithVersion: 'chat' };
  const AGENT_FOUNDATIONAL = { foundational: true, referenceWithVersion: 'foundational/v1' };
  const AGENT_CUSTOM = { pinnedItemVersionId: 'gid://gitlab/AiCatalogItemVersion/1' };
  const AGENT_ORBIT = { referenceWithVersion: 'orbit_agent/v1' };

  const agentForKey = {
    [KEY_CHAT]: AGENT_CHAT,
    [KEY_FOUNDATIONAL]: AGENT_FOUNDATIONAL,
    [KEY_CUSTOM_AGENTS]: AGENT_CUSTOM,
  };

  const buildPreferenceResponse = (orbitSettings) => ({
    data: {
      currentUser: {
        id: 'gid://gitlab/User/1',
        userPreferences: { orbitSettings },
      },
    },
  });

  const buildUpdateResponse = (orbitSettings) => ({
    data: {
      userPreferencesUpdate: {
        userPreferences: { orbitSettings },
        errors: [],
      },
    },
  });

  // Master killswitch on with all three subsettings on — happy path.
  const ALL_ON = {
    enabled: true,
    orbit_agentic_chat_enabled: true,
    orbit_other_foundational_agents_enabled: true,
    orbit_custom_agents_enabled: true,
  };

  // Master killswitch on with all subsettings off.
  const MASTER_ON_SUBS_OFF = {
    enabled: true,
    orbit_agentic_chat_enabled: false,
    orbit_other_foundational_agents_enabled: false,
    orbit_custom_agents_enabled: false,
  };

  const MASTER_OFF = { enabled: false };

  let orbitPreferenceQueryMock;
  let updatePreferenceMutationMock;

  const createComponent = ({
    props = {},
    glFeatures = ORBIT_FLAGS_ENABLED,
    queryHandler = orbitPreferenceQueryMock,
    mutationHandler = updatePreferenceMutationMock,
  } = {}) => {
    const apolloProvider = createMockApollo([
      [getOrbitUserPreference, queryHandler],
      [updateOrbitUserPreference, mutationHandler],
    ]);

    wrapper = shallowMountExtended(OrbitToggle, {
      apolloProvider,
      propsData: {
        value: true,
        currentAgent: AGENT_CHAT,
        ...props,
      },
      provide: {
        glFeatures,
      },
    });
  };

  const findButton = () => wrapper.findComponent(GlButton);
  const findPopover = () => wrapper.findComponent(GlPopover);
  const findBadge = () => wrapper.findComponent(GlBadge);
  const findToggles = () => wrapper.findAllComponents(GlToggle);
  const findAgenticChatToggle = () => wrapper.findComponentByTestId('orbit-toggle-agentic-chat');
  const findFoundationalToggle = () =>
    wrapper.findComponentByTestId('orbit-toggle-foundational-agents');
  const findCustomAgentsToggle = () => wrapper.findComponentByTestId('orbit-toggle-custom-agents');
  const findLearnAboutLink = () => wrapper.findByTestId('orbit-learn-about-link');
  const findFeedbackLink = () => wrapper.findByTestId('orbit-feedback-link');

  beforeEach(() => {
    orbitPreferenceQueryMock = jest.fn().mockResolvedValue(buildPreferenceResponse(ALL_ON));
    updatePreferenceMutationMock = jest.fn().mockResolvedValue(buildUpdateResponse(ALL_ON));
  });

  describe('when feature flags are on and the master killswitch is enabled', () => {
    beforeEach(async () => {
      orbitPreferenceQueryMock.mockResolvedValue(buildPreferenceResponse(ALL_ON));
      createComponent();
      await waitForPromises();
    });

    it('renders the trigger button', () => {
      expect(findButton().exists()).toBe(true);
    });

    it('renders the popover', () => {
      expect(findPopover().exists()).toBe(true);
    });

    it('renders the Beta badge with info variant', () => {
      expect(findBadge().exists()).toBe(true);
      expect(findBadge().props('variant')).toBe('info');
      expect(findBadge().text()).toBe('Beta');
    });

    it('renders the popover title "Orbit"', () => {
      expect(wrapper.findByTestId('orbit-popover-title').text()).toBe('Orbit');
    });

    it('renders the description', () => {
      expect(wrapper.findByTestId('orbit-popover-description').text()).toContain('knowledge graph');
    });

    it('renders three GlToggle controls — one per subsetting', () => {
      expect(findToggles()).toHaveLength(3);
      expect(findAgenticChatToggle().exists()).toBe(true);
      expect(findFoundationalToggle().exists()).toBe(true);
      expect(findCustomAgentsToggle().exists()).toBe(true);
    });

    it('renders "Learn about Orbit" link', () => {
      expect(findLearnAboutLink().exists()).toBe(true);
      expect(findLearnAboutLink().text()).toBe('Learn about Orbit');
    });

    it('renders "Learn about Orbit" link pointing to the Orbit docs', async () => {
      createComponent();
      await waitForPromises();
      expect(findLearnAboutLink().attributes('href')).toContain('/orbit/');
    });

    it('renders "Leave feedback" link', () => {
      expect(findFeedbackLink().exists()).toBe(true);
      expect(findFeedbackLink().text()).toBe('Leave feedback');
    });
  });

  describe('button aria label reflects the value prop', () => {
    beforeEach(() => {
      orbitPreferenceQueryMock.mockResolvedValue(buildPreferenceResponse(ALL_ON));
    });

    it('shows "Orbit: On" when value is true', async () => {
      createComponent({ props: { value: true } });
      await waitForPromises();

      expect(findButton().attributes('aria-label')).toBe('Orbit: On');
    });

    it('shows "Orbit: Off" when value is false', async () => {
      createComponent({ props: { value: false } });
      await waitForPromises();

      expect(findButton().attributes('aria-label')).toBe('Orbit: Off');
    });
  });

  describe('visibility gating', () => {
    it('hides the button when the master killswitch is off', async () => {
      orbitPreferenceQueryMock.mockResolvedValue(buildPreferenceResponse(MASTER_OFF));
      createComponent();
      await waitForPromises();

      expect(findButton().exists()).toBe(false);
      expect(findPopover().exists()).toBe(false);
    });

    it('hides the button when orbitSettings is empty', async () => {
      orbitPreferenceQueryMock.mockResolvedValue(buildPreferenceResponse({}));
      createComponent();
      await waitForPromises();

      expect(findButton().exists()).toBe(false);
    });

    it.each([
      ['orbitUserPreference', { ...ORBIT_FLAGS_ENABLED, orbitUserPreference: false }],
      ['knowledgeGraph', { ...ORBIT_FLAGS_ENABLED, knowledgeGraph: false }],
      ['orbitFoundationalAgent', { ...ORBIT_FLAGS_ENABLED, orbitFoundationalAgent: false }],
    ])('hides the button when %s feature flag is disabled', async (_, glFeatures) => {
      createComponent({ glFeatures });
      await waitForPromises();

      expect(findButton().exists()).toBe(false);
    });

    it('skips the GraphQL query when feature flags are disabled', () => {
      createComponent({
        glFeatures: { ...ORBIT_FLAGS_ENABLED, orbitUserPreference: false },
      });

      expect(orbitPreferenceQueryMock).not.toHaveBeenCalled();
    });
  });

  describe('subsetting toggle values', () => {
    it('reflects each subsetting key in the corresponding toggle', async () => {
      orbitPreferenceQueryMock.mockResolvedValue(
        buildPreferenceResponse({
          enabled: true,
          orbit_agentic_chat_enabled: true,
          orbit_other_foundational_agents_enabled: false,
          orbit_custom_agents_enabled: true,
        }),
      );
      createComponent();
      await waitForPromises();

      expect(findAgenticChatToggle().props('value')).toBe(true);
      expect(findFoundationalToggle().props('value')).toBe(false);
      expect(findCustomAgentsToggle().props('value')).toBe(true);
    });

    it('defaults each toggle to false when keys are missing', async () => {
      orbitPreferenceQueryMock.mockResolvedValue(buildPreferenceResponse({ enabled: true }));
      createComponent();
      await waitForPromises();

      expect(findAgenticChatToggle().props('value')).toBe(false);
      expect(findFoundationalToggle().props('value')).toBe(false);
      expect(findCustomAgentsToggle().props('value')).toBe(false);
    });
  });

  describe('change events for the parent v-model', () => {
    it('emits change with the agentic-chat value when the preference loads', async () => {
      orbitPreferenceQueryMock.mockResolvedValue(
        buildPreferenceResponse({ ...ALL_ON, orbit_agentic_chat_enabled: true }),
      );
      createComponent({ props: { value: false } });

      await waitForPromises();

      expect(wrapper.emitted('change').at(-1)).toEqual([true]);
    });

    it('emits change false when agentic chat is disabled', async () => {
      orbitPreferenceQueryMock.mockResolvedValue(
        buildPreferenceResponse({ ...ALL_ON, orbit_agentic_chat_enabled: false }),
      );
      createComponent({ props: { value: true } });

      await waitForPromises();

      expect(wrapper.emitted('change').at(-1)).toEqual([false]);
    });

    it('does not emit true on GraphQL error (falls back to disabled)', async () => {
      const errorQueryMock = jest.fn().mockRejectedValue(new Error('GraphQL error'));
      createComponent({ queryHandler: errorQueryMock });

      await waitForPromises();

      const emitted = wrapper.emitted('change') || [];
      const trueEmissions = emitted.filter(([v]) => v === true);
      expect(trueEmissions).toHaveLength(0);
    });
  });

  describe('persisting subsetting toggles', () => {
    it.each([
      ['agentic chat', () => findAgenticChatToggle(), 'orbit_agentic_chat_enabled'],
      [
        'foundational agents',
        () => findFoundationalToggle(),
        'orbit_other_foundational_agents_enabled',
      ],
      ['custom agents', () => findCustomAgentsToggle(), 'orbit_custom_agents_enabled'],
    ])('writes the %s subsetting via the mutation', async (_label, getToggle, key) => {
      orbitPreferenceQueryMock.mockResolvedValue(buildPreferenceResponse(MASTER_ON_SUBS_OFF));
      createComponent();
      await waitForPromises();

      await getToggle().vm.$emit('change', true);
      await waitForPromises();

      expect(updatePreferenceMutationMock).toHaveBeenCalledTimes(1);
      expect(updatePreferenceMutationMock).toHaveBeenCalledWith(
        expect.objectContaining({
          input: {
            orbitSettings: expect.objectContaining({
              ...MASTER_ON_SUBS_OFF,
              [key]: true,
            }),
          },
        }),
      );
    });

    it('preserves untouched subsetting keys when toggling one', async () => {
      orbitPreferenceQueryMock.mockResolvedValue(buildPreferenceResponse(ALL_ON));
      createComponent();
      await waitForPromises();

      await findFoundationalToggle().vm.$emit('change', false);
      await waitForPromises();

      expect(updatePreferenceMutationMock).toHaveBeenCalledWith(
        expect.objectContaining({
          input: {
            orbitSettings: {
              enabled: true,
              orbit_agentic_chat_enabled: true,
              orbit_other_foundational_agents_enabled: false,
              orbit_custom_agents_enabled: true,
            },
          },
        }),
      );
    });

    it('does not call mutation twice if a previous toggle is still saving', async () => {
      orbitPreferenceQueryMock.mockResolvedValue(buildPreferenceResponse(MASTER_ON_SUBS_OFF));
      updatePreferenceMutationMock.mockImplementation(() => new Promise(() => {}));
      createComponent();
      await waitForPromises();

      findAgenticChatToggle().vm.$emit('change', true);
      findFoundationalToggle().vm.$emit('change', true);
      await waitForPromises();

      expect(updatePreferenceMutationMock).toHaveBeenCalledTimes(1);
    });
  });

  describe('active subsetting key', () => {
    // Settings where each subsetting has a distinct value so a `change`
    // emission can be unambiguously traced back to the right key.
    const DISTINCT = {
      enabled: true,
      orbit_agentic_chat_enabled: false,
      orbit_other_foundational_agents_enabled: true,
      orbit_custom_agents_enabled: false,
    };

    it.each([
      ['agentic chat', KEY_CHAT, false],
      ['foundational agents', KEY_FOUNDATIONAL, true],
      ['custom agents', KEY_CUSTOM_AGENTS, false],
    ])(
      'emits change with the %s subsetting value when that agent is active',
      async (_label, activeKey, expectedValue) => {
        orbitPreferenceQueryMock.mockResolvedValue(buildPreferenceResponse(DISTINCT));
        createComponent({
          props: { value: !expectedValue, currentAgent: agentForKey[activeKey] },
        });

        await waitForPromises();

        expect(wrapper.emitted('change').at(-1)).toEqual([expectedValue]);
      },
    );

    it('re-emits with the new active key value when the agent changes mid-session', async () => {
      orbitPreferenceQueryMock.mockResolvedValue(buildPreferenceResponse(DISTINCT));
      createComponent({ props: { value: false, currentAgent: AGENT_CHAT } });
      await waitForPromises();

      // Chat is false on load — sanity check.
      expect(wrapper.emitted('change').at(-1)).toEqual([false]);

      await wrapper.setProps({ currentAgent: AGENT_FOUNDATIONAL });
      await waitForPromises();

      // Foundational is true in DISTINCT, so the latest emission flips.
      expect(wrapper.emitted('change').at(-1)).toEqual([true]);
    });

    it('emits change when the toggle matching the active key is flipped', async () => {
      orbitPreferenceQueryMock.mockResolvedValue(buildPreferenceResponse(MASTER_ON_SUBS_OFF));
      createComponent({ props: { value: false, currentAgent: AGENT_FOUNDATIONAL } });
      await waitForPromises();

      await findFoundationalToggle().vm.$emit('change', true);
      await waitForPromises();

      expect(wrapper.emitted('change').at(-1)).toEqual([true]);
    });

    it('does not change the parent emission when a non-active toggle is flipped', async () => {
      const flippedFoundational = {
        ...MASTER_ON_SUBS_OFF,
        orbit_other_foundational_agents_enabled: true,
      };
      orbitPreferenceQueryMock.mockResolvedValue(buildPreferenceResponse(MASTER_ON_SUBS_OFF));
      updatePreferenceMutationMock.mockResolvedValue(buildUpdateResponse(flippedFoundational));
      createComponent({ props: { value: false, currentAgent: AGENT_CHAT } });
      await waitForPromises();

      await findFoundationalToggle().vm.$emit('change', true);
      await waitForPromises();

      // The chat subsetting is still false in the cache, so the latest
      // emission tied to the chat key is still false.
      expect(wrapper.emitted('change').at(-1)).toEqual([false]);
    });

    it('falls back to the chat subsetting when currentAgent is null', async () => {
      orbitPreferenceQueryMock.mockResolvedValue(buildPreferenceResponse(DISTINCT));
      createComponent({ props: { value: true, currentAgent: null } });

      await waitForPromises();

      // Chat is false in DISTINCT, so we expect the null-agent (default Duo)
      // case to mirror that.
      expect(wrapper.emitted('change').at(-1)).toEqual([false]);
    });
  });

  describe('Orbit agent always-on (orbit_agent/* currentAgent)', () => {
    it('emits true on load regardless of orbit_settings contents', async () => {
      orbitPreferenceQueryMock.mockResolvedValue(buildPreferenceResponse(MASTER_ON_SUBS_OFF));
      createComponent({ props: { value: false, currentAgent: AGENT_ORBIT } });

      await waitForPromises();

      expect(wrapper.emitted('change').at(-1)).toEqual([true]);
    });

    it('renders the button as on (green status dot) when value mirrors back true', async () => {
      orbitPreferenceQueryMock.mockResolvedValue(buildPreferenceResponse(MASTER_ON_SUBS_OFF));
      createComponent({ props: { value: true, currentAgent: AGENT_ORBIT } });
      await waitForPromises();

      expect(findButton().attributes('aria-label')).toBe('Orbit: On');
    });

    it('emits true when currentAgent transitions to the Orbit agent', async () => {
      orbitPreferenceQueryMock.mockResolvedValue(buildPreferenceResponse(MASTER_ON_SUBS_OFF));
      createComponent({ props: { value: false, currentAgent: AGENT_CHAT } });
      await waitForPromises();

      await wrapper.setProps({ currentAgent: AGENT_ORBIT });
      await waitForPromises();

      expect(wrapper.emitted('change').at(-1)).toEqual([true]);
    });

    it('re-emits the cached value when transitioning from the Orbit agent back to a regular agent', async () => {
      orbitPreferenceQueryMock.mockResolvedValue(buildPreferenceResponse(MASTER_ON_SUBS_OFF));
      createComponent({ props: { value: true, currentAgent: AGENT_ORBIT } });
      await waitForPromises();

      await wrapper.setProps({ currentAgent: AGENT_CHAT });
      await waitForPromises();

      // chat subsetting is false in MASTER_ON_SUBS_OFF.
      expect(wrapper.emitted('change').at(-1)).toEqual([false]);
    });
  });

  describe('feedback link href', () => {
    let originalGon;

    beforeEach(() => {
      originalGon = window.gon;
      orbitPreferenceQueryMock.mockResolvedValue(buildPreferenceResponse(ALL_ON));
    });

    afterEach(() => {
      window.gon = originalGon;
    });

    it('points to the external work item when the user is not a GitLab team member', async () => {
      window.gon = { is_gitlab_team_member: false };
      createComponent();
      await waitForPromises();

      expect(findFeedbackLink().attributes('href')).toBe(
        'https://gitlab.com/gitlab-org/gitlab/-/work_items/598867',
      );
    });

    it('points to the internal work item when the user is a GitLab team member', async () => {
      window.gon = { is_gitlab_team_member: true };
      createComponent();
      await waitForPromises();

      expect(findFeedbackLink().attributes('href')).toBe(
        'https://gitlab.com/groups/gitlab-org/-/work_items/21994',
      );
    });
  });
});
