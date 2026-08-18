<script>
import { GlButton, GlTooltipDirective, GlSkeletonLoader } from '@gitlab/ui';
import { __, sprintf } from '~/locale';
import { copyToClipboard } from '~/lib/utils/copy_to_clipboard';
import showGlobalToast from '~/vue_shared/plugins/global_toast';
import {
  AGENTIC_CHAT_SHOW_ROUTE,
  AGENTIC_CHAT_HISTORY_ROUTE,
  CLASSIC_CHAT_HISTORY_ROUTE,
} from 'ee/ai/duo_agents_platform/router/constants';
import PanelActions from '~/vue_shared/components/panel_actions.vue';
import panelTitleQuery from '../graphql/panel_title.query.graphql';

const CONVERSATION_LIST_ROUTES = [AGENTIC_CHAT_HISTORY_ROUTE, CLASSIC_CHAT_HISTORY_ROUTE];

export default {
  name: 'AiContentContainer',
  components: {
    GlButton,
    GlSkeletonLoader,
    PanelActions,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  i18n: {
    closeButtonLabel: __('Close panel'),
    moreOptionsLabel: __('More options'),
    copySessionIdTooltip: __('Copy Chat Session ID: %{id}'),
    sessionIdCopiedToast: __('Session ID copied to clipboard'),
    sessionIdCopyFailedToast: __('Could not copy session ID'),
  },
  props: {
    title: {
      type: String,
      required: true,
    },
    showBackButton: {
      type: Boolean,
      required: false,
      default: false,
    },
    isMaximized: {
      type: Boolean,
      required: true,
    },
    showLoadingState: {
      type: Boolean,
      required: false,
      default: false,
    },
    showInformationButton: {
      type: Boolean,
      required: false,
      default: false,
    },
    informationButtonLabel: {
      type: String,
      required: false,
      default: __('Information'),
    },
    isSessionInformationVisible: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['close-panel', 'go-back', 'toggle-maximize', 'toggle-session-information'],
  apollo: {
    panelTitleState: {
      query: panelTitleQuery,
      update(data) {
        return data;
      },
    },
  },
  data() {
    return {
      currentTitle: null,
      panelTitleState: null,
      sessionId: null,
      isSessionDropdownVisible: false,
    };
  },
  computed: {
    panelTitle() {
      return this.panelTitleState?.panelTitle || '';
    },
    panelSubtitle() {
      return this.panelTitleState?.panelSubtitle || '';
    },
    goBackTitle() {
      return __('Go back');
    },
    maximizeButtonLabel() {
      return this.isMaximized ? __('Minimize panel') : __('Maximize panel');
    },
    showSessionId() {
      return this.sessionId && this.$route?.name === AGENTIC_CHAT_SHOW_ROUTE;
    },
    sessionText() {
      return sprintf(this.$options.i18n.copySessionIdTooltip, { id: this.sessionId });
    },
    sessionIdItems() {
      return [
        {
          text: this.sessionText,
          action: () => {
            this.copySessionIdToClipboard();
          },
        },
      ];
    },
    showSessionDropdownTooltip() {
      return !this.isSessionDropdownVisible ? this.$options.i18n.moreOptionsLabel : '';
    },
    displayTitle() {
      return this.panelTitle || this.currentTitle || this.title;
    },
  },
  watch: {
    title: {
      handler() {
        this.currentTitle = null;
        this.resetPanelOverrides();
      },
    },
    '$route.path': {
      handler() {
        this.resetPanelOverrides();
      },
    },
  },
  methods: {
    resetPanelOverrides() {
      this.panelTitleState = null;
    },
    handleGoBack() {
      this.$emit('go-back');
    },
    handleTitleChange(title) {
      // A child title describes a single conversation, so the route-derived
      // heading wins on conversation-list routes.
      if (CONVERSATION_LIST_ROUTES.includes(this.$route?.name)) {
        return;
      }

      this.currentTitle = title || null;
    },
    handleSessionIdChanged(sessionId) {
      this.sessionId = sessionId;
    },
    showSessionDropdown() {
      this.isSessionDropdownVisible = true;
    },
    hideSessionDropdown() {
      this.isSessionDropdownVisible = false;
    },
    async copySessionIdToClipboard() {
      try {
        await copyToClipboard(this.sessionId);
        showGlobalToast(this.$options.i18n.sessionIdCopiedToast);
      } catch {
        showGlobalToast(this.$options.i18n.sessionIdCopyFailedToast);
      }
    },
  },
};
</script>

<template>
  <aside id="ai-panel-portal" :aria-label="title" class="ai-panel paneled-view [contain:strict]">
    <div class="panel-header">
      <div class="panel-header-inner">
        <div class="panel-header-inner-text">
          <gl-button
            v-gl-tooltip.bottom
            class="lg:gl-flex"
            :class="{ '!gl-hidden': !showBackButton }"
            icon="go-back"
            category="tertiary"
            :aria-label="goBackTitle"
            :title="goBackTitle"
            data-testid="content-container-back-button"
            @click="handleGoBack"
          />
          <div class="gl-flex gl-w-full gl-flex-col">
            <gl-skeleton-loader v-if="showLoadingState && !panelSubtitle" :lines="2" />
            <div v-else>
              <h3 class="gl-m-0 gl-truncate gl-text-sm" data-testid="content-container-title">
                {{ displayTitle }}
              </h3>
              <h4
                v-if="panelSubtitle"
                class="gl-m-0 gl-mt-1 gl-truncate gl-text-sm gl-font-normal"
                data-testid="content-container-subtitle"
              >
                {{ panelSubtitle }}
              </h4>
            </div>
          </div>
        </div>

        <panel-actions>
          <gl-button
            v-if="showInformationButton"
            v-gl-tooltip.bottom
            icon="information-o"
            category="tertiary"
            size="small"
            :aria-label="informationButtonLabel"
            :title="informationButtonLabel"
            :aria-expanded="isSessionInformationVisible"
            data-testid="content-container-information-button"
            @click="$emit('toggle-session-information')"
          />

          <template #panel-controls>
            <gl-button
              v-gl-tooltip.bottom
              class="gl-hidden lg:gl-flex"
              :icon="isMaximized ? 'minimize' : 'maximize'"
              category="tertiary"
              size="small"
              :aria-label="maximizeButtonLabel"
              :title="maximizeButtonLabel"
              data-testid="content-container-maximize-button"
              @click="$emit('toggle-maximize')"
            />
            <gl-button
              v-gl-tooltip.bottom
              icon="close"
              category="tertiary"
              size="small"
              :aria-label="$options.i18n.closeButtonLabel"
              :title="$options.i18n.closeButtonLabel"
              data-testid="content-container-close-button"
              @click="$emit('close-panel', false)"
            />
          </template>
        </panel-actions>
      </div>
    </div>
    <div
      class="panel-content-inner gl-grow gl-flex-wrap gl-justify-center"
      data-testid="ai-panel-content"
    >
      <slot
        name="active-tab"
        :show-session-id="showSessionId"
        :show-session-dropdown-tooltip="showSessionDropdownTooltip"
        :toggle-text="$options.i18n.moreOptionsLabel"
        :items="sessionIdItems"
        :show-session-dropdown="showSessionDropdown"
        :hide-session-dropdown="hideSessionDropdown"
        :handle-title-change="handleTitleChange"
        :handle-session-id-changed="handleSessionIdChanged"
      ></slot>
    </div>
  </aside>
</template>
