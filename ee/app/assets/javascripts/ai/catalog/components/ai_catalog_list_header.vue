<script>
import {
  GlExperimentBadge,
  GlLink,
  GlIcon,
  GlModalDirective,
  GlPopover,
  GlSprintf,
  GlButton,
} from '@gitlab/ui';
import { uniqueId } from 'lodash-es';
import { s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import LinkToDashboardModal, {
  LINK_TO_DASHBOARD_MODAL_ID,
} from 'ee/analytics/analytics_dashboards/link_to_dashboards/link_to_dashboards_modal.vue';
import {
  TRACKING_ACTION_CLICK_DASHBOARD_LINK,
  TRACKING_LABEL_AI_CATALOG_HEADER,
} from 'ee/analytics/analytics_dashboards/link_to_dashboards/tracking';
import { AI_IMPACT_DASHBOARD } from 'ee/analytics/analytics_dashboards/constants';
import { DOCS_URL } from '~/constants';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';
import AiCatalogNavTabs from './ai_catalog_nav_tabs.vue';
import AiCatalogNavActions from './ai_catalog_nav_actions.vue';

export default {
  name: 'AiCatalogListHeader',
  components: {
    GlExperimentBadge,
    GlLink,
    GlIcon,
    AiCatalogNavTabs,
    AiCatalogNavActions,
    PageHeading,
    LinkToDashboardModal,
    GlPopover,
    GlSprintf,
    GlButton,
  },
  directives: {
    GlModal: GlModalDirective,
  },
  mixins: [glSlotsMixin],
  inject: {
    isGlobalNamespace: {},
    aiImpactDashboardEnabled: {
      default: false,
    },
    aiImpactDashboardPath: {
      default: null,
    },
    showLegalDisclaimer: {
      default: false,
    },
  },
  props: {
    heading: {
      type: String,
      required: false,
      default: undefined,
    },
    canAdmin: {
      type: Boolean,
      required: false,
      default: false,
    },
    canCreate: {
      type: Boolean,
      required: false,
      default: false,
    },
    newButtonVariant: {
      type: String,
      required: false,
      default: undefined,
    },
    isExperiment: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    title() {
      return this.heading || s__('AICatalog|AI Catalog');
    },
    aiImpactDashboardDocsLink() {
      return `${DOCS_URL}/user/analytics/duo_and_sdlc_trends/`;
    },
    aiImpactDashboardLinkAttrs() {
      return {
        'data-testid': 'ai-impact-dashboard-link',
        'data-track-action': this.$options.TRACKING_ACTION_CLICK_DASHBOARD_LINK,
        'data-track-label': this.$options.TRACKING_LABEL_AI_CATALOG_HEADER,
      };
    },
    badgeType() {
      if (this.isExperiment) {
        return 'experiment';
      }

      return '';
    },
    shouldShowLinkToDashboardsModal() {
      // Show modal when dashboard path is unavailable (path only available in project/group scope, not global scope, e.g., /explore/ai-catalog/agents)
      return this.aiImpactDashboardEnabled && !this.aiImpactDashboardPath;
    },
    hasDashboardLinkWithActions() {
      return !this.isGlobalNamespace && this.canAdmin && this.aiImpactDashboardEnabled;
    },
  },
  LINK_TO_DASHBOARD_MODAL_ID,
  TRACKING_ACTION_CLICK_DASHBOARD_LINK,
  TRACKING_LABEL_AI_CATALOG_HEADER,
  AI_IMPACT_DASHBOARD,
  AI_IMPACT_DASHBOARD_POPOVER_TARGET_ID: uniqueId('dashboard-link'),
  i18n: {
    legalDisclaimer: s__(
      'AICatalog|This catalog contains third-party content that may be subject to additional terms. GitLab does not control or assume liability for third-party content.',
    ),
    aiImpactDashboardCTA: s__('AICatalog|Explore your GitLab Duo and SDLC trends'),
  },
};
</script>

<template>
  <div>
    <page-heading>
      <template #heading>
        <span class="gl-flex">
          <span>{{ title }}</span>
          <gl-experiment-badge v-if="badgeType" :type="badgeType" class="gl-self-center" />
        </span>
      </template>
      <template v-if="glSlots().description" #description>
        <slot name="description"></slot>
      </template>
      <template #actions>
        <div
          data-testid="ai-catalog-list-header-actions"
          :class="{ 'gl-gap-5': hasDashboardLinkWithActions }"
          class="gl-flex gl-flex-wrap gl-items-center"
        >
          <template v-if="aiImpactDashboardEnabled">
            <div class="gl-flex gl-items-center gl-gap-3">
              <gl-button
                v-if="shouldShowLinkToDashboardsModal"
                v-gl-modal="$options.LINK_TO_DASHBOARD_MODAL_ID"
                v-bind="aiImpactDashboardLinkAttrs"
                variant="link"
              >
                {{ $options.i18n.aiImpactDashboardCTA }}
              </gl-button>
              <gl-link v-else v-bind="aiImpactDashboardLinkAttrs" :href="aiImpactDashboardPath">{{
                $options.i18n.aiImpactDashboardCTA
              }}</gl-link>
              <gl-icon :id="$options.AI_IMPACT_DASHBOARD_POPOVER_TARGET_ID" name="information-o" />
              <gl-popover :target="$options.AI_IMPACT_DASHBOARD_POPOVER_TARGET_ID">
                <gl-sprintf
                  :message="
                    s__(
                      'AICatalog|This key dashboard provides visibility into SDLC metrics in the context of AI adoption for projects and groups. %{linkStart}Learn more%{linkEnd}',
                    )
                  "
                >
                  <template #link="{ content }">
                    <gl-link :href="aiImpactDashboardDocsLink" target="_blank" class="!gl-text-sm">
                      {{ content }}</gl-link
                    >
                  </template>
                </gl-sprintf>
              </gl-popover>
            </div>
          </template>
          <ai-catalog-nav-actions
            v-if="!isGlobalNamespace"
            :can-admin="canAdmin"
            :can-create="canCreate"
            :new-button-variant="newButtonVariant"
          >
            <template v-if="glSlots()['nav-actions']" #default
              ><slot name="nav-actions"></slot
            ></template>
          </ai-catalog-nav-actions>
        </div>
      </template>
    </page-heading>
    <p v-if="showLegalDisclaimer" data-testid="legal-disclaimer" class="gl-text-sm gl-text-subtle">
      {{ $options.i18n.legalDisclaimer }}
    </p>

    <div v-if="isGlobalNamespace" class="gl-border-b gl-flex">
      <ai-catalog-nav-tabs />
      <ai-catalog-nav-actions can-admin />
    </div>

    <link-to-dashboard-modal
      v-if="shouldShowLinkToDashboardsModal"
      :dashboard-name="$options.AI_IMPACT_DASHBOARD"
    />
  </div>
</template>
