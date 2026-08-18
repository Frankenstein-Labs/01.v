<script>
import {
  GlAnimatedChevronLgRightDownIcon,
  GlCollapse,
  GlDrawer,
  GlLink,
  GlOutsideDirective,
} from '@gitlab/ui';
import { __ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { humanize } from '~/lib/utils/text_utility';
import { formatDate } from '~/lib/utils/datetime_utility';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import CrudComponent from '~/vue_shared/components/crud_component.vue';

export default {
  name: 'AuditEvent',
  directives: {
    GlOutside: GlOutsideDirective,
  },
  components: {
    CrudComponent,
    GlAnimatedChevronLgRightDownIcon,
    GlCollapse,
    GlDrawer,
    GlLink,
  },
  props: {
    auditEvent: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      isDrawerOpen: false,
      isDetailsExpanded: false,
    };
  },
  computed: {
    eventName() {
      return humanize(this.auditEvent.eventName || '');
    },
    authorName() {
      return this.auditEvent.author?.name;
    },
    ipAddress() {
      return this.auditEvent.ipAddress || '';
    },
    entityType() {
      return this.auditEvent.entityType || '';
    },
    /**
     * The fields listed in the audit event description are not all guaranteed
     * to be non-null. Instead of adding v-if to every field in the template,
     * let's add them all to an object that we then filter so that we can loop
     * over the list of non-null fields.
     * The keys of this object can then be used to get the i18n values.
     */
    auditEventDescription() {
      const descriptionFields = {
        authorId: getIdFromGraphQLId(this.auditEvent.author?.id),
        authorName: this.authorName,
        createdAt: this.auditEvent.createdAt && formatDate(this.auditEvent.createdAt),
        entityId: this.auditEvent.entityId,
        entityPath: this.auditEvent.entityPath,
        entityType: this.entityType,
        eventName: this.eventName,
        ipAddress: this.ipAddress,
        targetId: this.auditEvent.targetId,
        targetType: this.auditEvent.targetType,
      };

      return Object.fromEntries(Object.entries(descriptionFields).filter(([, value]) => value));
    },
    details() {
      try {
        return JSON.parse(this.auditEvent.details);
      } catch (error) {
        Sentry.captureException(error);
        return {};
      }
    },
  },
  methods: {
    openDrawer() {
      this.isDrawerOpen = true;
    },
    closeDrawer() {
      this.isDrawerOpen = false;
    },
    toggleDetails() {
      this.isDetailsExpanded = !this.isDetailsExpanded;
    },
  },
  DRAWER_Z_INDEX,
  i18n: {
    authorId: __('Author ID'),
    authorName: __('Author name'),
    createdAt: __('Created at'),
    entityId: __('Entity ID'),
    entityPath: __('Entity path'),
    entityType: __('Entity type'),
    eventName: __('Event name'),
    ipAddress: __('IP address'),
    targetId: __('Target ID'),
    targetType: __('Target type'),
  },
};
</script>
<template>
  <crud-component>
    <template #title>
      {{ s__('ComplianceViolation|Audit event captured') }}
    </template>

    <template #default>
      <gl-link data-testid="audit-event-drawer-link" @click="openDrawer">
        <span v-text="authorName"></span> - {{ eventName }}:
        {{ entityType }}
      </gl-link>
      <div>
        {{ s__('ComplianceViolation|Registered event IP') }}:
        {{ ipAddress }}
      </div>
      <gl-drawer
        v-gl-outside="closeDrawer"
        :open="isDrawerOpen"
        :z-index="$options.DRAWER_Z_INDEX"
        @close="closeDrawer"
      >
        <template #title>
          <div class="gl-text-size-h1 gl-font-bold" data-testid="audit-event-drawer-title">
            {{ eventName }}
          </div>
        </template>
        <template #default>
          <div class="gl-border-b" data-testid="audit-event-drawer-summary">
            <p class="gl-text-size-h2 gl-font-bold">
              {{ __('Summary') }}
            </p>
            <div>
              <span v-text="authorName"></span> - {{ eventName }}:
              {{ entityType }}
            </div>
          </div>

          <div class="gl-border-b" data-testid="audit-event-drawer-description">
            <p class="gl-text-size-h2 gl-font-bold">
              {{ __('Description') }}
            </p>
            <p v-for="(value, key) in auditEventDescription" :key="key" class="gl-mb-3">
              {{ $options.i18n[key] || key }}:
              <span v-text="value"></span>
            </p>
          </div>

          <div>
            <div
              role="button"
              class="gl-mb-5 gl-flex gl-cursor-pointer gl-select-none gl-flex-row gl-items-center gl-justify-between"
              data-testid="audit-event-details-toggle"
              @click="toggleDetails"
            >
              <div class="gl-text-size-h2 gl-font-bold">
                {{ __('Details') }}
              </div>
              <gl-animated-chevron-lg-right-down-icon :is-on="isDetailsExpanded" />
            </div>
            <gl-collapse :visible="isDetailsExpanded">
              <p v-for="(value, key) in details" :key="key" class="gl-mb-3">
                {{ key }}:
                <span v-text="value"></span>
              </p>
            </gl-collapse>
          </div>
        </template>
      </gl-drawer>
    </template>
  </crud-component>
</template>
