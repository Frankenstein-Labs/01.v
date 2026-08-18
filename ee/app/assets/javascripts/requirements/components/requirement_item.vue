<script>
import { GlPopover, GlLink, GlAvatar, GlButton, GlTooltipDirective, GlSprintf } from '@gitlab/ui';
import { __ } from '~/locale';
import timeagoMixin from '~/vue_shared/mixins/timeago';

import { filterState, I18N_LEGACY_REFERENCE_DEPRECATION_NOTE_POPOVER } from '../constants';
import RequirementMeta from '../mixins/requirement_meta';
import RequirementStatusBadge from './requirement_status_badge.vue';

export default {
  name: 'RequirementItem',
  i18n: {
    archiveLabel: __('Archive'),
    editLabel: __('Edit'),
    legacyReferencePopoverText: I18N_LEGACY_REFERENCE_DEPRECATION_NOTE_POPOVER,
  },
  components: {
    GlPopover,
    GlLink,
    GlAvatar,
    GlButton,
    RequirementStatusBadge,
    GlSprintf,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [RequirementMeta, timeagoMixin],
  props: {
    requirement: {
      type: Object,
      required: true,
      validator: (value) =>
        [
          'iid',
          'state',
          'userPermissions',
          'title',
          'createdAt',
          'updatedAt',
          'author',
          'testReports',
          'workItemIid',
        ].every((prop) => value[prop]),
    },
    stateChangeRequestActive: {
      type: Boolean,
      required: false,
      default: false,
    },
    active: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['archive-click', 'edit-click', 'reopen-click', 'show-click'],
  computed: {
    showIssuableMetaActions() {
      return Boolean(this.canUpdate || this.canArchive || this.testReport);
    },
    legacyReferencePopoverId() {
      return `legacy-reference-${this.requirement.iid}`;
    },
  },
  methods: {
    /**
     * This is needed as an independent method since
     * when user changes current page, `$refs.authorLink`
     * will be null until next page results are loaded & rendered.
     */
    getAuthorPopoverTarget() {
      if (this.$refs.authorLink) {
        return this.$refs.authorLink.$el;
      }
      return '';
    },
    handleArchiveClick() {
      this.$emit('archive-click', {
        iid: this.requirement.iid,
        state: filterState.archived,
      });
    },
    handleReopenClick() {
      this.$emit('reopen-click', {
        iid: this.requirement.iid,
        state: filterState.opened,
      });
    },
  },
};
</script>

<template>
  <li
    class="issue requirement gl-cursor-pointer @sm/panel:!gl-flex"
    :class="{ 'disabled-content': stateChangeRequestActive, 'gl-bg-blue-50': active }"
    @click="$emit('show-click', requirement)"
  >
    <div class="gl-flex-1">
      <div>
        <span :id="legacyReferencePopoverId" class="issuable-legacy-reference gl-mr-2">{{
          legacyReference
        }}</span>
        <div class="gl-inline gl-font-bold">
          <span class="issue-title-text">{{ requirement.title }}</span>
        </div>
      </div>
      <div class="">
        <span class="issuable-reference gl-inline gl-text-sm gl-text-subtle">{{ reference }}</span>

        <div class="issuable-info gl-hidden @sm/panel:!gl-inline-block">
          <span class="issuable-authored">
            <span v-gl-tooltip:tooltipcontainer.bottom :title="tooltipTitle(requirement.createdAt)"
              >&middot;
              <time :datetime="requirement.createdAt">{{ createdAtFormatted }}</time></span
            >
            {{ __('by') }}
            <gl-link ref="authorLink" class="author-link js-user-link" :href="author.webUrl">
              <span class="author">{{ author.name }}</span>
            </gl-link>
          </span>
          <span
            v-gl-tooltip:tooltipcontainer.bottom
            :title="tooltipTitle(requirement.updatedAt)"
            class="issuable-updated-at"
            >&middot; <time :datetime="requirement.updatedAt">{{ updatedAtFormatted }}</time></span
          >
        </div>
        <requirement-status-badge
          v-if="testReport"
          :test-report="testReport"
          :last-test-report-manually-created="requirement.lastTestReportManuallyCreated"
          class="gl-block @sm/panel:!gl-hidden"
        />
      </div>
    </div>
    <ul
      v-if="showIssuableMetaActions"
      class="requirement-controls gl-mt-3 gl-flex gl-list-none gl-gap-3 gl-self-start gl-pl-0 @sm/panel:gl-ml-4 @sm/panel:gl-mt-0"
    >
      <requirement-status-badge
        v-if="testReport"
        :test-report="testReport"
        :last-test-report-manually-created="requirement.lastTestReportManuallyCreated"
        element-type="li"
        class="gl-hidden @sm/panel:!gl-block"
      />
      <li v-if="canUpdate && !isArchived" class="requirement-edit">
        <gl-button
          v-gl-tooltip
          icon="pencil"
          :title="$options.i18n.editLabel"
          :aria-label="$options.i18n.editLabel"
          @click="$emit('edit-click', requirement)"
        />
      </li>
      <li v-if="!stateChangeRequestActive && canArchive && !isArchived" class="requirement-archive">
        <gl-button
          v-gl-tooltip
          icon="archive"
          :loading="stateChangeRequestActive"
          :title="$options.i18n.archiveLabel"
          :aria-label="$options.i18n.archiveLabel"
          @click.stop="handleArchiveClick"
        />
      </li>
      <li v-if="canArchive && isArchived" class="requirement-reopen">
        <gl-button :loading="stateChangeRequestActive" @click="handleReopenClick">{{
          __('Reopen')
        }}</gl-button>
      </li>
    </ul>

    <gl-popover :target="getAuthorPopoverTarget()" placement="top">
      <div class="gl-flex gl-leading-normal">
        <div class="gl-flex-shrink-1 gl-p-2">
          <gl-avatar :entity-name="author.name" :alt="author.name" :src="author.avatarUrl" />
        </div>
        <div class="gl-w-full gl-p-2">
          <h5 class="gl-m-0">{{ author.name }}</h5>
          <div class="gl-mb-3 gl-text-subtle">@{{ author.username }}</div>
        </div>
      </div>
    </gl-popover>
    <gl-popover
      data-testid="legacy-reference-popover"
      :target="legacyReferencePopoverId"
      placement="top"
    >
      <span class="gl-leading-20">
        <gl-sprintf :message="$options.i18n.legacyReferencePopoverText">
          <template #id>{{ reference }}</template>
        </gl-sprintf>
      </span>
    </gl-popover>
  </li>
</template>
