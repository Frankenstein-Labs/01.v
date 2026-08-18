<script>
import { GlModal, GlButton, GlSkeletonLoader, GlIcon, GlPopover } from '@gitlab/ui';
import { s__, __, sprintf } from '~/locale';
import queryProfile from 'ee/security_configuration/graphql/scan_profiles/security_scan_profile.query.graphql';
import {
  SCAN_TRIGGER_DEFINITIONS,
  SCAN_PROFILE_CATEGORIES,
} from '~/security_configuration/constants';
import ScanTriggersDetail from './scan_triggers_detail.vue';
import InsufficientPermissionsPopover from './insufficient_permissions_popover.vue';

const i18n = {
  modalTitleTemplate: s__('ScanProfiles|%{scanTypeName} profile'),
  infoPopoverTitle: s__('ScanProfiles|What are configuration profiles?'),
  infoPopoverDetails: s__(
    'ScanProfiles|Configuration profiles are reusable settings templates for security tools. Create and manage profiles once, then apply them to multiple projects to ensure consistent security coverage.',
  ),
  profileSubtitle: s__('ScanProfiles|View profile settings and associated projects.'),
  applyProfile: s__('ScanProfiles|Apply profile'),
  currentlyActive: s__('ScanProfiles|Currently active'),
  generalDetails: s__('ScanProfiles|General Details'),
  generalDetailsInfo: s__('ScanProfiles|Information about this configuration profile.'),
  scanTriggers: s__('ScanProfiles|Scan triggers'),
  scanTriggersInfo: s__('ScanProfiles|When and how scans are run.'),
  description: __('Description'),
  analyzerType: __('Analyzer type'),
};

export default {
  name: 'ScanProfileDetailsModal',

  components: {
    GlModal,
    GlButton,
    GlSkeletonLoader,
    GlIcon,
    GlPopover,
    ScanTriggersDetail,
    InsufficientPermissionsPopover,
  },

  inject: { canApplyProfiles: { default: false } },

  props: {
    visible: {
      type: Boolean,
      required: true,
    },
    profileId: {
      type: String,
      required: true,
    },
    scanType: {
      type: String,
      required: false,
      default: '',
    },
    isAttached: {
      type: Boolean,
      required: false,
      default: false,
    },
    withApplyAction: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  emits: ['close', 'apply'],

  data() {
    return {
      modalId: 'scan-profile-details-modal',
      profile: null,
      loading: 0, // Initialized to 0 as this is used by a "loadingKey". See https://apollo.vuejs.org/api/smart-query.html#options
    };
  },

  apollo: {
    profile: {
      query: queryProfile,
      skip() {
        return !this.profileId;
      },
      variables() {
        return { id: this.profileId };
      },
      update(data) {
        return data?.securityScanProfile || null;
      },
      loadingKey: 'loading',
      error() {
        this.profile = null;
      },
    },
  },

  computed: {
    scanTypeDisplayName() {
      const type = this.profile?.scanType || this.scanType;
      return SCAN_PROFILE_CATEGORIES[type]?.name || type;
    },
    modalTitle() {
      if (!this.scanTypeDisplayName) return '';
      return sprintf(i18n.modalTitleTemplate, { scanTypeName: this.scanTypeDisplayName });
    },
    profileName() {
      return this.profile?.name;
    },
    profileHelpLink() {
      return SCAN_PROFILE_CATEGORIES[this.scanType]?.helpLink;
    },
    triggers() {
      const backendTriggers = this.profile?.triggers;

      if (!backendTriggers) return [];

      return backendTriggers.map((t) => SCAN_TRIGGER_DEFINITIONS[t]).filter(Boolean);
    },
  },

  watch: {
    visible(isVisible) {
      if (isVisible) {
        this.profile = null;
        if (this.profileId) {
          this.$apollo.queries.profile.refetch();
        }
      }
    },
  },

  methods: {
    close() {
      this.$emit('close');
    },
    applyProfile() {
      this.$emit('apply', this.profile.id);
    },
  },

  i18n,
};
</script>

<template>
  <gl-modal
    :modal-id="modalId"
    :visible="visible"
    size="lg"
    modal-class="scanner-profile-modal"
    @hidden="close"
  >
    <template #modal-title>
      <span>{{ modalTitle }}</span>
      <gl-icon id="header-info" name="question-o" class="gl-link gl-mb-1 gl-ml-1" />
      <gl-popover target="header-info" :title="$options.i18n.infoPopoverTitle">
        {{ $options.i18n.infoPopoverDetails }}
      </gl-popover>
    </template>

    <div v-if="loading > 0" class="gl-py-6">
      <gl-skeleton-loader :lines="3" />
    </div>

    <div v-else-if="profile">
      <div class="gl-border-t gl-border-b gl-mb-5 gl-border-default gl-py-5">
        <div class="gl-align-items-start gl-flex gl-justify-between">
          <div class="gl-display-flex gl-flex-direction-column gl-gap-2">
            <h3 class="gl-font-lg gl-font-weight-bold gl-m-0 gl-mb-1">
              {{ profileName }}
            </h3>
            <span class="gl-font-sm gl-text-subtle">
              {{ $options.i18n.profileSubtitle }}
            </span>
          </div>
          <div v-if="withApplyAction && !isAttached" id="modal-apply-button" class="gl-self-center">
            <gl-button variant="confirm" :disabled="!canApplyProfiles" @click="applyProfile">
              {{ $options.i18n.applyProfile }}
              <gl-icon v-if="!canApplyProfiles" name="lock" class="gl-ml-2" />
            </gl-button>
            <insufficient-permissions-popover
              v-if="!canApplyProfiles"
              target="modal-apply-button"
              placement="top"
            />
          </div>
          <span
            v-else-if="withApplyAction"
            class="gl-font-weight-bold gl-self-center gl-text-success"
          >
            {{ $options.i18n.currentlyActive }}
          </span>
        </div>
      </div>

      <div class="gl-mb-5">
        <h4 class="gl-font-sm gl-heading-4 gl-mb-2">
          {{ $options.i18n.generalDetails }}
        </h4>
        <p class="gl-font-sm gl-m-0 gl-text-subtle">
          {{ $options.i18n.generalDetailsInfo }}
        </p>
      </div>

      <div class="gl-mb-5">
        <h4 class="gl-font-sm gl-heading-4 gl-mb-2">
          {{ $options.i18n.description }}
        </h4>
        <p class="gl-font-sm gl-m-0 gl-text-subtle">
          {{ profile.description }}
        </p>
      </div>

      <div class="gl-mb-5">
        <h4 class="gl-font-sm gl-heading-4 gl-mb-2">
          {{ $options.i18n.analyzerType }}
        </h4>
        <p class="gl-font-sm gl-m-0 gl-text-subtle">
          {{ scanTypeDisplayName }}
        </p>
      </div>

      <div class="gl-mb-5">
        <h4 class="gl-font-sm gl-heading-4 gl-mb-2">
          {{ $options.i18n.scanTriggers }}
        </h4>
        <p class="gl-font-sm gl-m-0 gl-text-subtle">
          {{ $options.i18n.scanTriggersInfo }}
        </p>
      </div>

      <scan-triggers-detail :profile-help-link="profileHelpLink" :triggers="triggers" />
    </div>
    <template #modal-footer>
      <div></div>
    </template>
  </gl-modal>
</template>
