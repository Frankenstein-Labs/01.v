<script>
import { defineComponent } from 'vue';
import { GlAvatar, GlButton, GlLink, GlModal } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { InternalEvents } from '~/tracking';
import { s__, sprintf } from '~/locale';
import { groupSettingsOrbitPath } from 'ee/lib/utils/path_helpers/group';
import { groupGroupMembersPath } from '~/lib/utils/path_helpers/group';
import { copyToClipboard } from '~/lib/utils/copy_to_clipboard';
import OrbitEmptyState from './orbit_empty_state.vue';
import TurnOnIndexingModal from './turn_on_indexing_modal.vue';

const OWNER_ACCESS_LEVEL = 50;
const COPY_RESET_MS = 1500;

export default defineComponent({
  name: 'OrbitExploreEmptyState',
  compatConfig: { MODE: 3 },
  components: {
    GlAvatar,
    GlButton,
    GlLink,
    GlModal,
    OrbitEmptyState,
    TurnOnIndexingModal,
  },
  mixins: [InternalEvents.mixin()],
  props: {
    availableGroups: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      setupGroup: null,
      copyState: 'idle',
      enableGroup: null,
    };
  },
  computed: {
    setupModalVisible() {
      return Boolean(this.setupGroup);
    },
    configurableGroups() {
      return this.availableGroups.filter(
        (g) => g.knowledgeGraphAvailable || g.knowledgeGraphEnabled,
      );
    },
    ownerGroups() {
      return this.configurableGroups.filter(
        (g) => (g.maxAccessLevel?.integerValue ?? 0) >= OWNER_ACCESS_LEVEL,
      );
    },
    nonOwnerGroups() {
      return this.configurableGroups.filter(
        (g) => (g.maxAccessLevel?.integerValue ?? 0) < OWNER_ACCESS_LEVEL,
      );
    },
    hasAnyConfigurable() {
      return this.configurableGroups.length > 0;
    },
    setupGroupName() {
      return this.setupGroup?.name || '';
    },
    setupPitchText() {
      return sprintf(
        s__(
          'Orbit|Turn on Orbit for %{groupName} to supercharge agents with deep contextual intelligence — they understand how code, pipelines, work items, and merge requests connect across GitLab. This means better recommendations, less manual context-gathering, and agents that get smarter as your graph grows.',
        ),
        { groupName: this.setupGroupName },
      );
    },
    setupHeadingText() {
      return sprintf(s__('Orbit|Turn on Orbit for %{groupName}'), {
        groupName: this.setupGroupName,
      });
    },
    setupSettingsUrl() {
      if (!this.setupGroup) return '';
      return `${window.location.origin}${groupSettingsOrbitPath(this.setupGroup.fullPath)}`;
    },
    setupClipboardText() {
      const step1 = sprintf(s__('Orbit|1. Navigate to %{link} (%{url})'), {
        link: s__('Orbit|Settings, then Orbit'),
        url: this.setupSettingsUrl,
      });
      return [
        this.setupPitchText,
        '',
        this.setupHeadingText,
        step1,
        s__('Orbit|2. Click "Get started"'),
        s__('Orbit|3. Review and confirm'),
        '',
        s__(
          'Orbit|Once indexed, team members can use Orbit data through GitLab Duo Agent Platform or via MCP and CLI connections.',
        ),
      ].join('\n');
    },
  },
  methods: {
    ownersPath(fullPath) {
      return `${groupGroupMembersPath(fullPath)}?max_role=static-${OWNER_ACCESS_LEVEL}`;
    },
    openSetupGuide(group) {
      this.trackEvent('click_orbit_setup_guide_empty_state');
      this.setupGroup = group;
    },
    onSetupModalHidden() {
      this.setupGroup = null;
    },
    openEnableModal(group) {
      this.trackEvent('click_orbit_get_started_empty_state');
      this.enableGroup = group;
    },
    onEnabled(group) {
      window.location.assign(groupSettingsOrbitPath(group.fullPath));
    },
    onEnableModalHidden() {
      this.enableGroup = null;
    },
    async copySetupInstructions() {
      try {
        await copyToClipboard(this.setupClipboardText, this.$refs.copyButton?.$el);
        this.copyState = 'copied';
      } catch (error) {
        Sentry.captureException(error);
        this.copyState = 'error';
      }
      setTimeout(() => {
        this.copyState = 'idle';
      }, COPY_RESET_MS);
    },
  },
});
</script>

<template>
  <orbit-empty-state data-testid="orbit-explore-empty-state">
    <p
      v-if="!hasAnyConfigurable"
      class="gl-border gl-mb-0 gl-mt-3 gl-rounded-lg gl-border-subtle gl-bg-subtle gl-p-5 gl-font-bold"
      data-testid="orbit-no-available-groups"
    >
      {{ s__('Orbit|No eligible groups are available for Orbit.') }}
    </p>

    <template v-else>
      <div
        v-if="ownerGroups.length"
        class="gl-flex gl-w-full gl-flex-col gl-gap-3 gl-text-left"
        data-testid="orbit-owner-groups"
      >
        <div
          v-for="group in ownerGroups"
          :key="group.fullPath"
          class="gl-border gl-flex gl-flex-col gl-items-start gl-gap-3 gl-rounded-2xl gl-border-strong gl-bg-default gl-p-4 @sm:gl-flex-row @sm:gl-items-center"
        >
          <div class="gl-flex gl-min-w-0 gl-flex-1 gl-items-center gl-gap-3">
            <gl-avatar
              :src="group.avatarUrl"
              :entity-name="group.name"
              :size="32"
              shape="rect"
              class="gl-flex-shrink-0"
            />
            <span class="gl-min-w-0 gl-break-words">{{ group.name }}</span>
          </div>
          <gl-button
            variant="confirm"
            data-testid="orbit-get-started-btn"
            @click="openEnableModal(group)"
          >
            {{ s__('Orbit|Turn on') }}
          </gl-button>
        </div>
      </div>

      <div
        v-if="nonOwnerGroups.length"
        class="gl-flex gl-w-full gl-flex-col gl-gap-3 gl-text-left"
        data-testid="orbit-non-owner-groups"
      >
        <div>
          <p class="gl-mb-0 gl-font-bold">{{ s__('Orbit|Available groups') }}</p>
          <p class="gl-mb-0 gl-text-sm gl-text-subtle">
            {{
              s__(
                'Orbit|You must have the Owner role in a top-level group to turn on Orbit. Ask an owner to turn on Orbit.',
              )
            }}
          </p>
        </div>
        <div
          v-for="group in nonOwnerGroups"
          :key="group.fullPath"
          class="gl-border gl-flex gl-flex-col gl-items-start gl-gap-3 gl-rounded-2xl gl-border-subtle gl-bg-subtle gl-p-4 @sm:gl-flex-row @sm:gl-items-center"
        >
          <div class="gl-flex gl-min-w-0 gl-flex-1 gl-items-center gl-gap-3">
            <gl-avatar
              :src="group.avatarUrl"
              :entity-name="group.name"
              :size="32"
              shape="rect"
              class="gl-flex-shrink-0"
            />
            <span class="gl-min-w-0 gl-break-words">{{ group.name }}</span>
          </div>
          <div class="gl-flex gl-flex-row-reverse gl-gap-2 @md:gl-flex-row">
            <gl-button
              size="small"
              category="tertiary"
              :href="ownersPath(group.fullPath)"
              data-event-tracking="click_orbit_view_owners_empty_state"
            >
              {{ s__('Orbit|View Owners') }}
            </gl-button>
            <gl-button
              size="small"
              data-testid="orbit-setup-guide-btn"
              @click="openSetupGuide(group)"
            >
              {{ s__('Orbit|Setup guide') }}
            </gl-button>
          </div>
        </div>
      </div>
    </template>

    <gl-modal
      :visible="setupModalVisible"
      modal-id="orbit-setup-guide-modal"
      :title="s__('Orbit|Setup Orbit')"
      :hide-footer="true"
      data-testid="orbit-setup-guide-modal"
      @hidden="onSetupModalHidden"
    >
      <template v-if="setupGroup">
        <p>
          {{
            s__(
              'Orbit|Setting up Orbit requires an Owner role in a group with at least a Premium license.',
            )
          }}
        </p>
        <div class="gl-flex gl-items-center gl-gap-3">
          <h3 class="gl-heading-4 gl-mb-0 gl-mr-auto">
            {{ s__('Orbit|Owner instructions') }}
          </h3>
          <gl-button
            ref="copyButton"
            size="small"
            icon="copy-to-clipboard"
            :aria-label="s__('Orbit|Copy to clipboard')"
            data-testid="orbit-copy-instructions-btn"
            @click="copySetupInstructions"
          >
            {{ copyState === 'copied' ? s__('Orbit|Copied') : s__('Orbit|Copy to clipboard') }}
          </gl-button>
        </div>
        <div class="gl-border gl-mt-3 gl-rounded-lg gl-border-default gl-p-5">
          <p class="gl-mb-0">{{ setupPitchText }}</p>
          <p class="gl-mb-0 gl-mt-5 gl-font-bold">{{ setupHeadingText }}</p>
          <ol class="gl-mb-0 gl-mt-2 gl-pl-5">
            <li>
              {{ s__('Orbit|Navigate to') }}
              <gl-link :href="setupSettingsUrl">{{ s__('Orbit|Settings, then Orbit') }}</gl-link>
            </li>
            <li>{{ s__('Orbit|2. Click "Turn on"') }}</li>
            <li>{{ s__('Orbit|3. Review and confirm') }}</li>
          </ol>
          <p class="gl-mb-0 gl-mt-5">
            {{
              s__(
                'Orbit|Once indexed, team members can use Orbit data through GitLab Duo Agent Platform or via MCP and CLI connections.',
              )
            }}
          </p>
        </div>
      </template>
    </gl-modal>

    <turn-on-indexing-modal
      modal-id="orbit-empty-state-enable-modal"
      :group="enableGroup"
      @enabled="onEnabled"
      @hidden="onEnableModalHidden"
    />
  </orbit-empty-state>
</template>
