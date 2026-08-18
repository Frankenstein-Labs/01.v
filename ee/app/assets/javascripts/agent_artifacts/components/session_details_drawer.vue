<script>
import { GlButton, GlButtonGroup, GlTooltipDirective } from '@gitlab/ui';
import { MountingPortal } from 'portal-vue';
import { s__ } from '~/locale';
import DynamicPanel from '~/vue_shared/components/dynamic_panel.vue';
import getProjectSessionAuditEventsQuery from '../graphql/queries/get_project_session_audit_events.query.graphql';
import getGroupSessionAuditEventsQuery from '../graphql/queries/get_group_session_audit_events.query.graphql';
import SessionDetailsBody from './session_details_body.vue';
import AuditEventDetailsPanel from './audit_event_details_panel.vue';

const DEFAULT_PAGE_SIZE = 20;

export default {
  name: 'SessionDetailsDrawer',
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    DynamicPanel,
    GlButton,
    GlButtonGroup,
    MountingPortal,
    SessionDetailsBody,
    AuditEventDetailsPanel,
  },
  inject: {
    groupFullPath: { default: null },
    projectFullPath: { default: null },
  },
  props: {
    activeItem: {
      type: Object,
      required: true,
    },
    selectedEvent: {
      type: Object,
      required: false,
      default: null,
    },
  },
  emits: ['close', 'select', 'back'],
  apollo: {
    auditEvents: {
      query() {
        return this.isProjectMode
          ? getProjectSessionAuditEventsQuery
          : getGroupSessionAuditEventsQuery;
      },
      variables() {
        const paging = {
          workflowId: this.sessionId,
          after: this.after,
          before: this.before,
          first: this.before ? null : DEFAULT_PAGE_SIZE,
          last: this.before ? DEFAULT_PAGE_SIZE : null,
        };

        if (this.isProjectMode) {
          return { projectFullPath: this.projectFullPath, ...paging };
        }

        return { groupFullPath: this.groupFullPath, ...paging };
      },
      skip() {
        return (
          !this.sessionId || (this.isProjectMode ? !this.projectFullPath : !this.groupFullPath)
        );
      },
      update(data) {
        const container = (data.project ?? data.group)?.duoWorkflowSessionArtifacts;
        this.hasError = Boolean(container) && container.nodes.length === 0;
        return container?.nodes[0]?.auditEvents;
      },
      result() {
        if (!this.isFetchingBoundary) {
          return;
        }

        this.isFetchingBoundary = false;

        const targetEvent =
          this.pendingBoundaryDirection === 'next'
            ? this.events[0]
            : this.events[this.events.length - 1];

        if (targetEvent) {
          this.$emit('select', targetEvent);
        }

        this.pendingBoundaryDirection = null;
      },
      error() {
        this.hasError = true;
        this.isFetchingBoundary = false;
        this.pendingBoundaryDirection = null;
      },
    },
  },
  data() {
    return {
      auditEvents: null,
      after: null,
      before: null,
      hasError: false,
      isFetchingBoundary: false,
      pendingBoundaryDirection: null,
    };
  },
  computed: {
    sessionId() {
      return this.activeItem?.id;
    },
    isProjectMode() {
      return Boolean(this.projectFullPath);
    },
    isLoading() {
      return this.$apollo.queries.auditEvents.loading;
    },
    events() {
      return this.auditEvents?.nodes || [];
    },
    pageInfo() {
      return this.auditEvents?.pageInfo || {};
    },
    selectedIndex() {
      if (!this.selectedEvent) {
        return -1;
      }

      return this.events.findIndex((event) => event.id === this.selectedEvent.id);
    },
    hasPrevEvent() {
      if (this.isFetchingBoundary) {
        return false;
      }

      if (this.selectedIndex > 0) {
        return true;
      }

      return this.selectedIndex === 0 && Boolean(this.pageInfo.hasPreviousPage);
    },
    hasNextEvent() {
      if (this.isFetchingBoundary) {
        return false;
      }

      if (this.selectedIndex === -1) {
        return false;
      }

      if (this.selectedIndex < this.events.length - 1) {
        return true;
      }

      return Boolean(this.pageInfo.hasNextPage);
    },
  },
  watch: {
    // Ensure cursors, in-flight boundary state, and the error flag reset when
    // session changes. Without the hasError reset, the error alert from a
    // failed or not-found session outranks the loading state in the list
    // template and stays visible while the next session's query is in flight.
    sessionId() {
      this.after = null;
      this.before = null;
      this.hasError = false;
      this.isFetchingBoundary = false;
      this.pendingBoundaryDirection = null;
    },
  },
  mounted() {
    document.addEventListener('keydown', this.closeOnEscape);
  },
  beforeDestroy() {
    document.removeEventListener('keydown', this.closeOnEscape);
  },
  methods: {
    handleClose() {
      this.$emit('close');
    },
    closeOnEscape({ key }) {
      if (key === 'Escape') {
        this.handleClose();
      }
    },
    handleNext(endCursor) {
      this.after = endCursor;
      this.before = null;
    },
    handlePrev(startCursor) {
      this.before = startCursor;
      this.after = null;
    },
    goToPrevious() {
      if (!this.hasPrevEvent) {
        return;
      }

      if (this.selectedIndex > 0) {
        this.$emit('select', this.events[this.selectedIndex - 1]);
        return;
      }

      this.isFetchingBoundary = true;
      this.pendingBoundaryDirection = 'prev';
      this.handlePrev(this.pageInfo.startCursor);
    },
    goToNext() {
      if (!this.hasNextEvent) {
        return;
      }

      if (this.selectedIndex < this.events.length - 1) {
        this.$emit('select', this.events[this.selectedIndex + 1]);
        return;
      }

      this.isFetchingBoundary = true;
      this.pendingBoundaryDirection = 'next';
      this.handleNext(this.pageInfo.endCursor);
    },
  },
  i18n: {
    downloadAuditArtifact: s__('AgentArtifacts|Download Session Artifacts'),
    auditEvents: s__('AgentArtifacts|Audit events'),
    previousEvent: s__('AgentArtifacts|Previous event'),
    nextEvent: s__('AgentArtifacts|Next event'),
  },
};
</script>

<template>
  <mounting-portal mount-to="#contextual-panel-portal" append>
    <dynamic-panel data-testid="session-details-drawer" @close="handleClose">
      <template v-if="selectedEvent" #header>
        <div class="gl-flex gl-items-center gl-gap-3">
          <gl-button
            variant="link"
            icon="arrow-left"
            data-testid="audit-event-back-button"
            @click="$emit('back')"
          >
            {{ $options.i18n.auditEvents }}
          </gl-button>
          <div class="gl-border-l gl-h-6 gl-border-l-section gl-pl-3">
            <gl-button-group>
              <gl-button
                v-gl-tooltip.bottom
                icon="chevron-left"
                size="small"
                :disabled="!hasPrevEvent"
                :aria-label="$options.i18n.previousEvent"
                :title="$options.i18n.previousEvent"
                data-testid="audit-event-prev-button"
                @click="goToPrevious"
              />
              <gl-button
                v-gl-tooltip.bottom
                icon="chevron-right"
                size="small"
                :disabled="!hasNextEvent"
                :aria-label="$options.i18n.nextEvent"
                :title="$options.i18n.nextEvent"
                data-testid="audit-event-next-button"
                @click="goToNext"
              />
            </gl-button-group>
          </div>
        </div>
      </template>

      <audit-event-details-panel
        v-if="selectedEvent"
        :event="selectedEvent"
        :workflow-definition="activeItem.workflowDefinition"
      >
        <template v-if="activeItem.downloadPath" #download-action>
          <gl-button
            icon="download"
            :href="activeItem.downloadPath"
            data-testid="download-audit-artifact-button"
          >
            {{ $options.i18n.downloadAuditArtifact }}
          </gl-button>
        </template>
      </audit-event-details-panel>
      <session-details-body
        v-else
        :active-item="activeItem"
        :session-id="sessionId"
        :events="events"
        :page-info="pageInfo"
        :is-loading="isLoading"
        :has-error="hasError"
        @select="$emit('select', $event)"
        @next="handleNext"
        @prev="handlePrev"
      />
    </dynamic-panel>
  </mounting-portal>
</template>
