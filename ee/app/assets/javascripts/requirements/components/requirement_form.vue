<script>
import { GlDrawer, GlButton, GlFormCheckbox, GlTooltipDirective, GlSprintf } from '@gitlab/ui';
import $ from 'jquery';
import { isEmpty } from 'lodash-es';
import IssuableBody from '~/vue_shared/issuable/show/components/issuable_body.vue';
import { TAB_KEY_CODE } from '~/lib/utils/keycodes';
import { __ } from '~/locale';
import ZenMode from '~/zen_mode';

import { renderGFM } from '~/behaviors/markdown/render_gfm';
import { TITLE_LENGTH_MAX } from '~/issues/constants';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import {
  I18N_LEGACY_REFERENCE_DEPRECATION_NOTE_TITLE,
  I18N_LEGACY_REFERENCE_DEPRECATION_NOTE_DETAIL,
  STATE_FAILED,
  STATE_PASSED,
} from '../constants';
import RequirementMeta from '../mixins/requirement_meta';
import RequirementStatusBadge from './requirement_status_badge.vue';

export default {
  name: 'RequirementForm',
  maxTitleLength: TITLE_LENGTH_MAX,
  events: {
    drawerClose: 'drawer-close',
    disableEdit: 'disable-edit',
    enableEdit: 'enable-edit',
  },
  i18n: {
    legacyReferenceDeprecationTitle: I18N_LEGACY_REFERENCE_DEPRECATION_NOTE_TITLE,
    legacyReferenceDeprecationText: I18N_LEGACY_REFERENCE_DEPRECATION_NOTE_DETAIL,
  },
  components: {
    GlDrawer,
    GlFormCheckbox,
    GlButton,
    RequirementStatusBadge,
    IssuableBody,
    GlSprintf,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [RequirementMeta],
  inject: ['descriptionPreviewPath', 'descriptionHelpPath'],
  props: {
    drawerOpen: {
      type: Boolean,
      required: true,
    },
    requirement: {
      type: Object,
      required: false,
      default: null,
    },
    enableRequirementEdit: {
      type: Boolean,
      required: false,
      default: false,
    },
    requirementRequestActive: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['save', 'drawer-close', 'disable-edit', 'enable-edit'],
  data() {
    return {
      zenModeEnabled: false,
      satisfied: this.requirement?.satisfied || false,
    };
  },
  computed: {
    isCreate() {
      return isEmpty(this.requirement);
    },
    saveButtonLabel() {
      return this.isCreate ? __('Create requirement') : __('Save changes');
    },
    canEditRequirement() {
      return this.isCreate || (this.canUpdate && !this.isArchived);
    },
    requirementObject() {
      return this.isCreate
        ? {
            iid: '',
            title: '',
            titleHtml: '',
            description: '',
            descriptionHtml: '',
          }
        : this.requirement;
    },
  },
  watch: {
    requirement: {
      handler(value) {
        this.satisfied = value?.satisfied || false;
      },
      deep: true,
    },
    drawerOpen(value) {
      // Clear `title` and `satisfied` value on drawer close.
      if (!value) {
        this.satisfied = false;
      } else {
        document.addEventListener('keydown', this.handleDocumentKeydown);
      }
    },
    enableRequirementEdit(value) {
      this.$nextTick(() => {
        this.lastEl = this.getDrawerLastEl(value);
      });
    },
  },
  mounted() {
    this.handleDocumentKeydown = this.handleDrawerKeydown.bind(this);
    this.zenMode = new ZenMode();
    renderGFM(this.$refs.gfmContainer);
    $(document).on('zen_mode:enter', () => {
      this.zenModeEnabled = true;
    });
    $(document).on('zen_mode:leave', () => {
      this.zenModeEnabled = false;
    });
  },
  beforeDestroy() {
    // eslint-disable-next-line @gitlab/no-global-event-off
    $(document).off('zen_mode:enter');
    // eslint-disable-next-line @gitlab/no-global-event-off
    $(document).off('zen_mode:leave');
  },
  methods: {
    getDrawerHeaderHeight() {
      const wrapperEl = document.querySelector('.js-requirements-container-wrapper');

      if (wrapperEl) {
        return `${wrapperEl.offsetTop}px`;
      }

      return '';
    },
    getDrawerLastEl(isEditMode) {
      return this.$el?.querySelector?.(isEditMode ? '.js-requirement-cancel' : '.js-issuable-edit');
    },
    newLastTestReportState() {
      // lastTestReportState determines whether a requirement is satisfied or not.
      // Only create a new test report when manually marking/unmarking a requirement as satisfied:

      // when 1) manually marking a requirement as satisfied for the first time.
      const updateCondition1 = this.requirement.lastTestReportState === null && this.satisfied;
      // or when 2) overriding the status in the latest test report.
      const updateCondition2 =
        this.requirement.lastTestReportState !== null &&
        this.satisfied !== this.requirement.satisfied;

      if (updateCondition1 || updateCondition2) {
        return this.satisfied ? STATE_PASSED : STATE_FAILED;
      }

      return null;
    },
    handleDrawerKeydown(e) {
      const { keyCode, shiftKey } = e;

      if (!this.firstEl) {
        this.firstEl = this.$el?.querySelector?.('.gl-drawer-close-button');
      }

      if (!this.lastEl) {
        this.lastEl = this.getDrawerLastEl(this.enableRequirementEdit || this.isCreate);
      }

      if (keyCode !== TAB_KEY_CODE) return;

      if (!this.$el.contains?.(document.activeElement)) this.firstEl.focus();

      if (shiftKey) {
        if (document.activeElement === this.firstEl) {
          this.lastEl.focus();
          e.preventDefault();
        }
      } else if (document.activeElement === this.lastEl) {
        this.firstEl.focus();
        e.preventDefault();
      }
    },
    handleDrawerClose() {
      this.$emit(this.$options.events.drawerClose);
      document.removeEventListener('keydown', this.handleDocumentKeydown);
      this.firstEl = null;
      this.lastEl = null;
    },
    handleFormInputKeyDown(e, issuableMeta) {
      const exact = !(e.ctrlKey || e.altKey || e.shiftKey || e.metaKey);
      if (e.key === 'Escape' && exact) {
        e.stopPropagation();

        if (this.zenModeEnabled) {
          // Exit Zen mode, don't close the drawer.
          this.zenModeEnabled = false;
          this.zenMode.exit();
        } else {
          this.handleCancel();
        }
      } else if (e.key === 'Enter' && e.metaKey) {
        e.stopPropagation();

        this.handleSave(issuableMeta);
      }
    },
    handleSave({ issuableTitle, issuableDescription }) {
      const eventParams = {
        title: issuableTitle,
        description: issuableDescription,
      };

      if (!this.isCreate) {
        eventParams.iid = this.requirement.iid;
        eventParams.lastTestReportState = this.newLastTestReportState();
      }

      this.$emit('save', eventParams);
    },
    handleCancel() {
      this.$emit(
        this.isCreate ? this.$options.events.drawerClose : this.$options.events.disableEdit,
      );
    },
  },
  DRAWER_Z_INDEX,
};
</script>

<template>
  <gl-drawer
    ref="drawerEl"
    :open="drawerOpen"
    :header-height="getDrawerHeaderHeight()"
    :class="{ 'zen-mode gl-absolute': zenModeEnabled }"
    :z-index="$options.DRAWER_Z_INDEX"
    class="requirement-form-drawer gl-drawer-responsive"
    @close="handleDrawerClose"
  >
    <template #title>
      <h4 v-if="isCreate" class="gl-m-0" data-testid="new-requirement-title">
        {{ __('New requirement') }}
      </h4>
      <div v-else class="gl-flex gl-items-center">
        <strong class="gl-text-subtle">{{ reference }}</strong>
        <requirement-status-badge
          v-if="testReport"
          :test-report="testReport"
          :last-test-report-manually-created="requirement.lastTestReportManuallyCreated"
          class="gl-ml-3"
        />
      </div>
    </template>
    <issuable-body
      :issuable="requirementObject"
      :enable-edit="canEditRequirement"
      :enable-autocomplete="false"
      :enable-autosave="false"
      :enable-zen-mode="false"
      :edit-form-visible="enableRequirementEdit || isCreate"
      :show-field-title="true"
      :description-preview-path="descriptionPreviewPath"
      :description-help-path="descriptionHelpPath"
      status-icon="issue-open-m"
      @edit-issuable="$emit($options.events.enableEdit, $event)"
      @keydown-title="handleFormInputKeyDown"
      @keydown-description="handleFormInputKeyDown"
    >
      <template #edit-form-actions="{ issuableMeta }">
        <gl-form-checkbox v-if="!isCreate" v-model="satisfied">{{
          __('Satisfied')
        }}</gl-form-checkbox>
        <div class="requirement-form-actions gl-flex gl-gap-3">
          <gl-button
            :disabled="
              requirementRequestActive ||
              issuableMeta.issuableTitle.length > $options.maxTitleLength ||
              !issuableMeta.issuableTitle.length
            "
            :loading="requirementRequestActive"
            data-testid="requirement-save"
            variant="confirm"
            category="primary"
            class="js-requirement-save"
            @click="handleSave(issuableMeta)"
          >
            {{ saveButtonLabel }}
          </gl-button>
          <gl-button
            data-testid="requirement-cancel"
            variant="default"
            category="primary"
            class="js-requirement-cancel"
            @click="handleCancel"
          >
            {{ __('Cancel') }}
          </gl-button>
        </div>
      </template>
      <template #secondary-content>
        <aside>
          <h2 class="gl-text-base">
            <gl-sprintf :message="$options.i18n.legacyReferenceDeprecationTitle">
              <template #legacyId
                ><span class="gl-font-normal">{{ legacyReference }}</span></template
              >
            </gl-sprintf>
          </h2>
          <p class="gl-text-sm gl-leading-20">
            <gl-sprintf :message="$options.i18n.legacyReferenceDeprecationText">
              <template #id>{{ reference }}</template>
            </gl-sprintf>
          </p>
        </aside>
      </template>
    </issuable-body>
  </gl-drawer>
</template>
