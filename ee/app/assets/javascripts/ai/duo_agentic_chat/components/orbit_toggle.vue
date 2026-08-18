<script>
import { GlBadge, GlButton, GlIcon, GlLink, GlPopover, GlToggle, GlToastMixin } from '@gitlab/ui';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { DOCS_URL } from '~/constants';
import getOrbitUserPreference from 'ee/ai/graphql/get_orbit_user_preference.query.graphql';
import updateOrbitUserPreference from 'ee/ai/graphql/update_orbit_user_preference.mutation.graphql';
import { s__ } from '~/locale';
import { captureExceptionForDuoChat } from '../observability/sentry_utils';

// Matches any version of the standalone Orbit foundational agent
// (orbit_agent/v1, orbit_agent/v2, ...). Used to override the foundational-agent
// subsetting mapping, since Orbit-agent sessions are gated upstream by
// `orbit_agent_enabled` and are always-on locally.
const ORBIT_AGENT_REFERENCE_PREFIX = 'orbit_agent/';

// The default "GitLab Duo" agent is marked `foundational: true` in the data
// model but represents the regular agentic chat experience — it should map to
// the chat subsetting, not the foundational-agents one.
const DUO_DEFAULT_AGENT_REFERENCE = 'chat';

// Feedback work items for Orbit. Internal team members are routed to the
// internal-only intake; everyone else goes to the public feedback issue.
const ORBIT_FEEDBACK_URL_INTERNAL = 'https://gitlab.com/groups/gitlab-org/-/work_items/21994';
const ORBIT_FEEDBACK_URL_EXTERNAL = 'https://gitlab.com/gitlab-org/gitlab/-/work_items/598867';
const ORBIT_TOGGLE_BUTTON_ID = 'orbit-toggle-button';

// Subsetting keys stored inside the `orbit_settings` JSONB preference. The
// master killswitch (`enabled`) is managed elsewhere (/-/profile/preferences);
// this component only flips the per-workflow subsettings.
const SUBSETTING_CHAT = 'orbit_agentic_chat_enabled';
const SUBSETTING_FOUNDATIONAL = 'orbit_other_foundational_agents_enabled';
const SUBSETTING_CUSTOM_AGENTS = 'orbit_custom_agents_enabled';

const SUBSETTING_TOGGLES = [
  {
    key: SUBSETTING_CHAT,
    label: s__('DuoChat|Agentic chat'),
    testId: 'orbit-toggle-agentic-chat',
  },
  {
    key: SUBSETTING_FOUNDATIONAL,
    label: s__('DuoChat|Foundational agents'),
    testId: 'orbit-toggle-foundational-agents',
  },
  {
    key: SUBSETTING_CUSTOM_AGENTS,
    label: s__('DuoChat|Custom agents'),
    testId: 'orbit-toggle-custom-agents',
  },
];

export default {
  name: 'OrbitToggle',
  components: {
    GlBadge,
    GlButton,
    GlIcon,
    GlLink,
    GlPopover,
    GlToggle,
  },
  mixins: [glFeatureFlagsMixin(), GlToastMixin],
  model: {
    prop: 'value',
    event: 'change',
  },
  props: {
    value: {
      type: Boolean,
      required: true,
    },
    currentAgent: {
      type: Object,
      required: false,
      default: null,
    },
  },
  emits: ['change'],
  apollo: {
    orbitSettings: {
      query: getOrbitUserPreference,
      skip() {
        return !this.featureFlagsEnabled;
      },
      update(data) {
        return data?.currentUser?.userPreferences?.orbitSettings ?? {};
      },
      result() {
        this.$emit('change', this.activeEnabled);
      },
      error(error) {
        captureExceptionForDuoChat(error);
      },
    },
  },
  data() {
    return {
      orbitSettings: {},
      savingKey: null,
    };
  },
  computed: {
    featureFlagsEnabled() {
      return (
        this.glFeatures.orbitUserPreference &&
        this.glFeatures.knowledgeGraph &&
        this.glFeatures.orbitFoundationalAgent
      );
    },
    masterEnabled() {
      return this.orbitSettings?.enabled === true;
    },
    showOrbitToggle() {
      return this.featureFlagsEnabled && this.masterEnabled;
    },
    isOrbitAgentActive() {
      return Boolean(
        this.currentAgent?.referenceWithVersion?.startsWith(ORBIT_AGENT_REFERENCE_PREFIX),
      );
    },
    // Derived from the `currentAgent` prop (canonical source of truth, updated
    // by agent pickers and slash commands) rather than local fields which only
    // get re-assigned on workflow load and so leak the previous agent's identity
    // into a fresh "default Duo" chat.
    //
    // The standalone Orbit agent is gated by `orbit_agent_enabled` upstream and
    // isn't user-configurable here, so it returns null — OrbitToggle interprets
    // that as always-on.
    activeOrbitSubsettingKey() {
      if (this.isOrbitAgentActive) return null;
      if (this.currentAgent?.referenceWithVersion === DUO_DEFAULT_AGENT_REFERENCE) {
        return SUBSETTING_CHAT;
      }
      if (this.currentAgent?.foundational) return SUBSETTING_FOUNDATIONAL;
      if (this.currentAgent?.pinnedItemVersionId) return SUBSETTING_CUSTOM_AGENTS;
      return SUBSETTING_CHAT;
    },
    // `null` activeOrbitSubsettingKey signals the standalone Orbit agent, which
    // is gated upstream — always-on regardless of orbit_settings contents.
    activeEnabled() {
      if (this.activeOrbitSubsettingKey === null) return true;
      return this.orbitSettings?.[this.activeOrbitSubsettingKey] === true;
    },
    isSaving() {
      return Boolean(this.savingKey);
    },
    feedbackUrl() {
      return window.gon?.is_gitlab_team_member
        ? ORBIT_FEEDBACK_URL_INTERNAL
        : ORBIT_FEEDBACK_URL_EXTERNAL;
    },
  },
  watch: {
    // When the user switches between agent types mid-session, the governing
    // subsetting changes — re-emit so the parent's v-model (and the next
    // buildStartRequest payload) reflects the new key without a refetch.
    activeOrbitSubsettingKey() {
      this.$emit('change', this.activeEnabled);
    },
  },
  methods: {
    async onSubsettingChange(key, newValue) {
      if (this.savingKey) return;
      this.savingKey = key;

      const nextSettings = { ...this.orbitSettings, [key]: newValue };

      try {
        await this.$apollo.mutate({
          mutation: updateOrbitUserPreference,
          variables: {
            input: {
              orbitSettings: nextSettings,
            },
          },
          optimisticResponse: {
            userPreferencesUpdate: {
              __typename: 'UserPreferencesUpdatePayload',
              userPreferences: {
                __typename: 'UserPreferences',
                orbitSettings: nextSettings,
              },
              errors: [],
            },
          },
          update: (store, { data }) => {
            const updatedPreferences = data?.userPreferencesUpdate?.userPreferences;
            if (!updatedPreferences) return;

            try {
              const cacheData = store.readQuery({ query: getOrbitUserPreference });
              if (!cacheData?.currentUser) return;
              store.writeQuery({
                query: getOrbitUserPreference,
                data: {
                  currentUser: {
                    ...cacheData.currentUser,
                    userPreferences: {
                      ...cacheData.currentUser.userPreferences,
                      orbitSettings: updatedPreferences.orbitSettings,
                    },
                  },
                },
              });
            } catch (error) {
              // Cache miss is fine; the next query will refetch.
              captureExceptionForDuoChat(error);
            }
          },
        });

        // Keep parent in sync whenever the toggle that just changed is the one
        // governing the current chat. For the Orbit-agent (null) case the
        // emitted value is fixed at `true`, so flipping any subsetting here
        // does not change what the parent sees.
        if (key === this.activeOrbitSubsettingKey) {
          this.$emit('change', newValue);
        }
        this.$toast.show(this.$options.i18n.preferenceUpdated);
      } catch (error) {
        // Mutation errors leave the cache unchanged; the next query will reconcile.
        captureExceptionForDuoChat(error);
      } finally {
        this.savingKey = null;
      }
    },
  },
  i18n: {
    orbitOn: s__('DuoChat|Orbit: On'),
    orbitOff: s__('DuoChat|Orbit: Off'),
    popoverTitle: s__('DuoChat|Orbit'),
    betaBadge: s__('DuoChat|Beta'),
    description: s__(
      'DuoChat|Empower agents to provide deeper insights in less time with a knowledge graph of your GitLab data.',
    ),
    learnAbout: s__('DuoChat|Learn about Orbit'),
    leaveFeedback: s__('DuoChat|Leave feedback'),
    preferenceUpdated: s__('DuoChat|Preference updated.'),
  },
  orbitToggleButtonId: ORBIT_TOGGLE_BUTTON_ID,
  orbitDocsPath: `${DOCS_URL}/orbit/`,
  subsettingToggles: SUBSETTING_TOGGLES,
};
</script>

<template>
  <span v-if="showOrbitToggle">
    <!-- Trigger button shown in the chat header -->
    <gl-button
      :id="$options.orbitToggleButtonId"
      category="tertiary"
      size="small"
      data-testid="orbit-toggle-button"
      icon="orbit"
      :aria-label="value ? $options.i18n.orbitOn : $options.i18n.orbitOff"
    >
      <span class="gl-flex gl-items-center gl-gap-3">
        {{ $options.i18n.popoverTitle }}
        <span
          class="gl-border gl-inline-block gl-h-3 gl-w-3 gl-rounded-full"
          :class="
            value
              ? 'gl-border-green-400 gl-bg-green-400'
              : 'gl-border-neutral-400 gl-bg-transparent'
          "
          data-testid="orbit-status-dot"
          aria-hidden="true"
        ></span>
      </span>
    </gl-button>

    <!-- Popover panel -->
    <gl-popover
      :target="$options.orbitToggleButtonId"
      triggers="click blur"
      placement="bottomleft"
      data-testid="orbit-toggle-popover"
    >
      <!-- Wrapper prevents inner controls from stealing focus from the trigger,
           which would otherwise fire `blur` and close the popover. Click events
           still propagate normally. -->
      <div @mousedown.prevent>
        <!-- Title row -->
        <div class="gl-flex gl-items-center gl-gap-2">
          <span class="gl-font-bold" data-testid="orbit-popover-title">{{
            $options.i18n.popoverTitle
          }}</span>
          <gl-badge variant="info" size="sm" data-testid="orbit-beta-badge">{{
            $options.i18n.betaBadge
          }}</gl-badge>
        </div>

        <p
          class="gl-mb-0 gl-mt-2 gl-text-sm gl-text-subtle"
          data-testid="orbit-popover-description"
        >
          {{ $options.i18n.description }}
        </p>
        <p class="gl-mb-0 gl-mt-3 gl-text-sm gl-font-bold gl-text-subtle">{{ __('Use Orbit') }}</p>
        <div class="gl-flex gl-flex-col gl-gap-3 gl-pb-3">
          <div
            v-for="toggle in $options.subsettingToggles"
            :key="toggle.key"
            class="gl-flex gl-items-center gl-justify-between gl-gap-2"
          >
            <span>{{ toggle.label }}</span>
            <gl-toggle
              :value="orbitSettings[toggle.key] === true"
              :disabled="isSaving"
              :label="toggle.label"
              label-position="hidden"
              :data-testid="toggle.testId"
              @change="(newValue) => onSubsettingChange(toggle.key, newValue)"
            />
          </div>
        </div>

        <!-- Links -->
        <div class="gl-border-t gl-flex gl-flex-col gl-gap-3 gl-pt-3">
          <gl-link
            :href="$options.orbitDocsPath"
            class="gl-flex gl-items-center gl-gap-2"
            target="_blank"
            rel="noopener noreferrer"
            data-testid="orbit-learn-about-link"
          >
            <gl-icon name="information-o" :size="12" />
            {{ $options.i18n.learnAbout }}
          </gl-link>

          <gl-link
            :href="feedbackUrl"
            class="gl-flex gl-items-center gl-gap-2"
            target="_blank"
            rel="noopener noreferrer"
            data-testid="orbit-feedback-link"
          >
            <gl-icon name="comment" :size="12" />
            {{ $options.i18n.leaveFeedback }}
          </gl-link>
        </div>
      </div>
    </gl-popover>
  </span>
</template>
