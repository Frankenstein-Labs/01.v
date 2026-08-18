<script>
import {
  GlAttributeList,
  GlAvatar,
  GlAvatarLink,
  GlButton,
  GlIcon,
  GlLink,
  GlTruncate,
} from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { formatDate } from '~/lib/utils/datetime_utility';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { formatAgentDefinition } from 'ee/ai/duo_agents_platform/utils';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { LONG_DATE_FORMAT_WITH_TZ } from '~/vue_shared/constants';
import { getClientType } from '../utils';
import SessionAuditEventsList from './session_audit_events_list.vue';

const EM_DASH = '—';

const ROW_TYPES = {
  session: 'session',
  user: 'user',
  date: 'date',
  project: 'project',
  clientType: 'clientType',
};

export default {
  name: 'SessionDetailsBody',
  components: {
    GlAttributeList,
    GlAvatar,
    GlAvatarLink,
    GlButton,
    GlIcon,
    GlLink,
    GlTruncate,
    CrudComponent,
    SessionAuditEventsList,
  },
  props: {
    activeItem: {
      type: Object,
      required: true,
    },
    sessionId: {
      type: String,
      required: false,
      default: null,
    },
    events: {
      type: Array,
      required: false,
      default: () => [],
    },
    pageInfo: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    hasError: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['select', 'next', 'prev'],
  computed: {
    formattedName() {
      return formatAgentDefinition(this.activeItem?.workflowDefinition);
    },
    formattedDate() {
      return formatDate(this.activeItem?.workflowCreatedAt, LONG_DATE_FORMAT_WITH_TZ);
    },
    sessionDetailsUrl() {
      return this.activeItem?.webPath;
    },
    formattedSessionId() {
      return getIdFromGraphQLId(this.sessionId);
    },
    downloadPath() {
      return this.activeItem?.downloadPath;
    },
    clientType() {
      return getClientType(this.activeItem);
    },
    // `text` is the plain fallback GlAttributeList validates and renders when a
    // row has no richer treatment in the #description slot.
    detailItems() {
      const { activeItem } = this;
      const items = [];

      if (activeItem.project) {
        items.push({
          type: ROW_TYPES.session,
          icon: 'session-ai',
          label: this.$options.i18n.sessionLabel,
          text: `#${this.formattedSessionId ?? ''}`,
        });
      }

      items.push(
        {
          type: ROW_TYPES.user,
          icon: 'user',
          label: this.$options.i18n.userLabel,
          text: activeItem.triggeredBy?.name || EM_DASH,
        },
        {
          type: ROW_TYPES.date,
          icon: 'clock',
          label: this.$options.i18n.dateLabel,
          text: this.formattedDate,
        },
      );

      items.push({
        type: ROW_TYPES.project,
        icon: 'project',
        label: this.$options.i18n.projectLabel,
        text: activeItem.project?.name || EM_DASH,
      });

      items.push({
        type: ROW_TYPES.clientType,
        icon: 'agent-ai',
        label: this.$options.i18n.clientTypeLabel,
        text: this.clientType.name,
      });

      return items;
    },
  },
  rowTypes: ROW_TYPES,
  i18n: {
    sessionDetailsTitle: s__('AgentArtifacts|Session details'),
    viewFullSessionDetails: s__('AgentArtifacts|View full session details'),
    downloadAuditArtifact: s__('AgentArtifacts|Download Session Artifacts'),
    sessionLabel: s__('AgentArtifacts|Session'),
    dateLabel: __('Date'),
    projectLabel: __('Project'),
    userLabel: __('User'),
    clientTypeLabel: s__('AgentArtifacts|Client type'),
  },
};
</script>

<template>
  <div>
    <div class="gl-mt-6 gl-flex gl-items-center gl-justify-between gl-gap-3">
      <h4 class="gl-m-0" data-testid="session-content-title">
        {{ formattedName }}
      </h4>
      <gl-button
        v-if="downloadPath"
        icon="download"
        :href="downloadPath"
        data-testid="download-audit-artifact-button"
      >
        {{ $options.i18n.downloadAuditArtifact }}
      </gl-button>
    </div>

    <crud-component :title="$options.i18n.sessionDetailsTitle" class="gl-mt-6" is-collapsible>
      <template #actions>
        <gl-button
          :href="sessionDetailsUrl"
          size="small"
          data-testid="view-full-session-details-button"
        >
          {{ $options.i18n.viewFullSessionDetails }}
        </gl-button>
      </template>

      <div class="gl-@container">
        <gl-attribute-list layout="horizontal" :items="detailItems">
          <template #description="{ item }">
            <gl-link
              v-if="item.type === $options.rowTypes.session"
              :href="sessionDetailsUrl"
              data-testid="session-link"
            >
              {{ item.text }}
            </gl-link>

            <template v-else-if="item.type === $options.rowTypes.user">
              <span
                v-if="activeItem.triggeredBy"
                class="gl-flex gl-items-center gl-gap-2"
                data-testid="user-content"
              >
                <gl-avatar-link :href="activeItem.triggeredBy.webPath">
                  <gl-avatar
                    :src="activeItem.triggeredBy.avatarUrl"
                    :entity-name="activeItem.triggeredBy.name"
                    :size="16"
                    data-testid="user-avatar"
                  />
                </gl-avatar-link>
                <gl-link :href="activeItem.triggeredBy.webPath" data-testid="user-link">{{
                  activeItem.triggeredBy.name
                }}</gl-link>
              </span>
              <span v-else class="gl-text-subtle" data-testid="user-empty">{{ item.text }}</span>
            </template>

            <span v-else-if="item.type === $options.rowTypes.date" data-testid="formatted-date">{{
              item.text
            }}</span>

            <template v-else-if="item.type === $options.rowTypes.project">
              <gl-link
                v-if="activeItem.project"
                :href="activeItem.project.webPath"
                class="gl-block gl-min-w-0 gl-truncate"
                data-testid="project-link"
              >
                <gl-truncate :text="item.text" with-tooltip />
              </gl-link>
              <span v-else class="gl-text-subtle" data-testid="project-empty">{{ item.text }}</span>
            </template>

            <span
              v-else-if="item.type === $options.rowTypes.clientType"
              class="gl-flex gl-items-center gl-gap-2"
              data-testid="client-type-name"
            >
              <gl-icon :name="clientType.icon" data-testid="client-type-icon" />
              {{ item.text }}
            </span>
          </template>
        </gl-attribute-list>
      </div>
    </crud-component>

    <session-audit-events-list
      v-if="sessionId"
      :events="events"
      :page-info="pageInfo"
      :is-loading="isLoading"
      :has-error="hasError"
      class="gl-mt-6"
      @select="$emit('select', $event)"
      @next="$emit('next', $event)"
      @prev="$emit('prev', $event)"
    />
  </div>
</template>
