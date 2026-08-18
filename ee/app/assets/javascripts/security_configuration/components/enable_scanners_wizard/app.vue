<script>
import {
  GlMultiStepFormTemplate,
  GlButton,
  GlBadge,
  GlLink,
  GlAlert,
  GlIcon,
  GlModal,
} from '@gitlab/ui';
import { groupBy } from 'lodash-es';
import { __, s__ } from '~/locale';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_GROUP } from '~/graphql_shared/constants';
import { InternalEvents } from '~/tracking';
import { MAX_SELECTED_COUNT } from 'ee/security_inventory/constants';
import securityScanProfileAttachMutation from 'ee/security_configuration/graphql/scan_profiles/security_scan_profile_attach.mutation.graphql';
import groupAvailableSecurityScanProfilesQuery from 'ee/security_configuration/graphql/scan_profiles/group_available_security_scan_profiles.query.graphql';
import { SCAN_PROFILE_CATEGORIES } from '~/security_configuration/constants';
import ConfirmUnsavedChangesDialog from '~/vue_shared/components/confirm_unsaved_changes_dialog.vue';
import {
  ROUTE_APPROACH,
  ROUTE_ITEMS,
  ROUTE_SCANNERS,
  ROUTE_REVIEW,
  ROUTE_CONFIRMATION,
  APPROACH_QUICK,
  EVENT_VIEW_STEP,
  EVENT_START_WIZARD,
  EVENT_SELECT_SCANNER,
  EVENT_DESELECT_SCANNER,
  EVENT_SELECT_ITEM,
  EVENT_DESELECT_ITEM,
  EVENT_APPLY_WIZARD,
  EVENT_ABANDON_WIZARD,
  ROUTE_TO_STEP_LABEL,
} from './constants';

export default {
  name: 'EnableScannersWizard',
  components: {
    GlMultiStepFormTemplate,
    GlButton,
    GlBadge,
    GlLink,
    GlAlert,
    GlIcon,
    GlModal,
    ConfirmUnsavedChangesDialog,
  },
  exitModal: {
    id: 'enable-scanners-exit-modal',
    actionPrimary: {
      text: s__('SecurityConfiguration|Exit setup'),
      attributes: { variant: 'confirm' },
    },
    actionCancel: {
      text: s__('SecurityConfiguration|Continue setup'),
    },
  },
  mixins: [InternalEvents.mixin()],
  inject: ['groupFullPath', 'groupId'],
  provide() {
    return { enableScanners: this };
  },
  beforeRouteLeave(to, from, next) {
    if (this.confirmedExit || !this.hasUnsavedChanges) {
      next();
      return;
    }
    this.pendingRoute = to.fullPath;
    this.showExitModal = true;
    next(false);
  },
  apollo: {
    availableScanners: {
      query: groupAvailableSecurityScanProfilesQuery,
      variables() {
        return { fullPath: this.groupFullPath };
      },
      update: (data) =>
        (data?.group?.availableSecurityScanProfiles ?? []).filter((profile) =>
          Boolean(SCAN_PROFILE_CATEGORIES[profile.scanType]),
        ),
    },
  },
  data() {
    return {
      approach: APPROACH_QUICK,
      selectedItems: [],
      areAllItemsSelected: false,
      selectedScanners: [],
      availableScanners: [],
      isSubmitting: false,
      submitErrors: [],
      showExitModal: false,
      confirmedExit: false,
      pendingRoute: null,
      preselectedScannerKey: this.$route?.query?.scanner ?? null,
    };
  },
  computed: {
    isLoadingAvailableScanners() {
      return this.$apollo.queries.availableScanners.loading;
    },
    profilesByScanType() {
      return groupBy(this.availableScanners, 'scanType');
    },
    allScanTypes() {
      return Object.keys(this.profilesByScanType);
    },
    currentStep() {
      return this.steps.findIndex((step) => step.route === this.$route.name);
    },
    isConfirmationRoute() {
      return this.$route.name === ROUTE_CONFIRMATION;
    },
    isReviewStep() {
      return this.$route.name === ROUTE_REVIEW;
    },
    hasUnsavedChanges() {
      if (this.isConfirmationRoute) return false;
      if (this.$route.name === ROUTE_APPROACH && this.approach === APPROACH_QUICK) return false;
      return true;
    },
    steps() {
      return [
        { route: ROUTE_APPROACH, label: s__('SecurityConfiguration|Select approach') },
        {
          route: ROUTE_ITEMS,
          label: s__('SecurityConfiguration|Select projects'),
          count: this.areAllItemsSelected ? __('All') : this.selectedItems.length,
        },
        {
          route: ROUTE_SCANNERS,
          label: s__('SecurityConfiguration|Select scanners'),
          count: this.selectedScanners.length,
        },
        { route: ROUTE_REVIEW, label: s__('SecurityConfiguration|Review configuration') },
      ];
    },
    previousStep() {
      // when using the quick approach, skip back over the manual selection steps
      if (this.$route.name === ROUTE_REVIEW && this.approach === APPROACH_QUICK) {
        return this.steps.find((step) => step.route === ROUTE_APPROACH);
      }
      return this.steps[this.currentStep - 1];
    },
    nextStep() {
      // when using the quick approach, skip forward over the manual selection steps
      if (this.$route.name === ROUTE_APPROACH && this.approach === APPROACH_QUICK) {
        return this.steps.find((step) => step.route === ROUTE_REVIEW);
      }
      // on the final step, the "next" destination is the confirmation route
      if (this.currentStep === this.steps.length - 1) {
        return {
          route: ROUTE_CONFIRMATION,
          label: s__('SecurityConfiguration|Apply configuration'),
        };
      }
      return this.steps[this.currentStep + 1];
    },
    nextLabel() {
      if (this.$route.name === ROUTE_APPROACH) {
        return this.approach === APPROACH_QUICK
          ? s__('SecurityConfiguration|Start quick setup')
          : s__('SecurityConfiguration|Start advanced setup');
      }
      return this.nextStep?.label;
    },
    currentStepLabel() {
      return ROUTE_TO_STEP_LABEL[this.$route.name];
    },
  },
  watch: {
    availableScanners(scanners) {
      if (!this.preselectedScannerKey || scanners.length === 0) return;

      const matchingProfile = scanners.find(
        (scanner) => scanner.scanType === this.preselectedScannerKey,
      );
      if (matchingProfile) {
        this.selectedScanners = [matchingProfile];
        this.areAllItemsSelected = true;
      }
      this.preselectedScannerKey = null;
    },
    currentStepLabel: {
      immediate: true,
      handler(label) {
        if (label) {
          this.trackEvent(EVENT_VIEW_STEP, { label });
        }
      },
    },
  },
  methods: {
    isStepLink(step) {
      if (this.approach === APPROACH_QUICK) {
        return step.route === ROUTE_APPROACH || step.route === ROUTE_REVIEW;
      }
      return true;
    },
    confirmExit() {
      this.trackEvent(EVENT_ABANDON_WIZARD, { label: this.currentStepLabel });
      this.confirmedExit = true;
      this.showExitModal = false;
      this.$router.push(this.pendingRoute || '/');
      this.pendingRoute = null;
    },
    keepEditing() {
      this.showExitModal = false;
      this.pendingRoute = null;
    },
    toggleItem(item, checked) {
      if (checked) {
        this.selectedItems = [...this.selectedItems, item];
        this.trackEvent(EVENT_SELECT_ITEM);
      } else {
        this.selectedItems = this.selectedItems.filter(({ id }) => id !== item.id);
        this.trackEvent(EVENT_DESELECT_ITEM);
      }
    },
    toggleVisibleItems(selected, visibleItems) {
      this.selectedItems = selected
        ? [...this.selectedItems, ...visibleItems].slice(0, MAX_SELECTED_COUNT)
        : this.selectedItems.filter(({ id }) => !visibleItems.some((item) => item.id === id));

      this.trackEvent(selected ? EVENT_SELECT_ITEM : EVENT_DESELECT_ITEM);
    },
    activeProfileForScanType(scanType) {
      return (
        this.selectedScanners.find((scanner) => scanner.scanType === scanType) ??
        this.profilesByScanType[scanType]?.[0]
      );
    },
    toggleScanner(scanType, checked) {
      if (checked) {
        this.selectedScanners = [...this.selectedScanners, this.profilesByScanType[scanType][0]];
        this.trackEvent(EVENT_SELECT_SCANNER, { label: scanType });
      } else {
        this.selectedScanners = this.selectedScanners.filter(
          (scanner) => scanner.scanType !== scanType,
        );
        this.trackEvent(EVENT_DESELECT_SCANNER, { label: scanType });
      }
    },
    selectScannerProfile(scanType, newProfile) {
      this.selectedScanners = [
        ...this.selectedScanners.filter((scanner) => scanner.scanType !== scanType),
        newProfile,
      ];
    },
    toggleAllScanners(checked) {
      const previouslySelectedTypes = this.selectedScanners.map(({ scanType }) => scanType);
      this.selectedScanners = checked
        ? this.allScanTypes.map((scanType) => this.activeProfileForScanType(scanType))
        : [];

      const event = checked ? EVENT_SELECT_SCANNER : EVENT_DESELECT_SCANNER;
      const affectedTypes = checked
        ? this.allScanTypes.filter((scanType) => !previouslySelectedTypes.includes(scanType))
        : previouslySelectedTypes;
      affectedTypes.forEach((label) => this.trackEvent(event, { label }));
    },
    goToNextStep() {
      if (this.$route.name === ROUTE_APPROACH) {
        const isQuick = this.approach === APPROACH_QUICK;
        // Set selectedScanners directly rather than via toggleAllScanners so the
        // implicit quick-setup selection doesn't emit per-scanner select events.
        this.selectedScanners = isQuick
          ? this.allScanTypes.map((scanType) => this.activeProfileForScanType(scanType))
          : [];
        this.areAllItemsSelected = isQuick;
        this.trackEvent(EVENT_START_WIZARD, { label: this.approach });
      }

      this.$router.push({ name: this.nextStep.route });
    },
    async onSubmit() {
      this.isSubmitting = true;
      this.submitErrors = [];

      const projectIds = this.areAllItemsSelected ? [] : this.selectedItems.map((item) => item.id);
      const groupIds = this.areAllItemsSelected
        ? [convertToGraphQLId(TYPENAME_GROUP, this.groupId)]
        : [];

      try {
        const results = await Promise.all(
          this.selectedScanners.map((scanner) =>
            this.$apollo.mutate({
              mutation: securityScanProfileAttachMutation,
              variables: { input: { securityScanProfileId: scanner.id, projectIds, groupIds } },
            }),
          ),
        );

        this.submitErrors = results.flatMap(
          ({ data }) => data?.securityScanProfileAttach?.errors ?? [],
        );

        if (this.submitErrors.length === 0) {
          this.trackEvent(EVENT_APPLY_WIZARD, { label: this.approach });
          this.$router.push({ name: ROUTE_CONFIRMATION });
        }
      } catch (e) {
        this.submitErrors = [e.message];
      } finally {
        this.isSubmitting = false;
      }
    },
  },
};
</script>
<template>
  <div>
    <confirm-unsaved-changes-dialog :has-unsaved-changes="hasUnsavedChanges" />
    <router-view v-if="isConfirmationRoute" />
    <template v-else>
      <gl-alert v-if="submitErrors.length" variant="danger" class="gl-mt-4" :dismissible="false">
        <ul class="gl-m-0 gl-pl-4">
          <li v-for="error in submitErrors" :key="error">{{ error }}</li>
        </ul>
      </gl-alert>
      <div class="gl-flex gl-justify-center gl-gap-4 gl-pt-5">
        <component
          :is="isStepLink(step) ? 'gl-link' : 'span'"
          v-for="(step, i) in steps"
          :key="i"
          :to="isStepLink(step) ? { name: step.route } : null"
          class="gl-cursor-default gl-rounded-full gl-bg-strong gl-px-5 gl-py-3 gl-text-default gl-no-underline hover:gl-text-default hover:gl-no-underline"
          :class="{ 'gl-bg-transparent': currentStep !== i }"
          data-testid="wizard-step"
        >
          <gl-icon
            v-if="currentStep > i"
            name="check-circle-filled"
            class="gl-mr-2 gl-h-5 gl-w-5 gl-fill-feedback-success"
          />
          <gl-badge
            v-else
            class="gl-mr-2 gl-h-5 gl-w-5 gl-rounded-full"
            :class="{
              '!gl-bg-neutral-700 !gl-text-feedback-strong': currentStep === i,
            }"
            >{{ i + 1 }}
          </gl-badge>
          {{ step.label }}
          <gl-badge v-if="currentStep > i && step.count">{{ step.count }}</gl-badge>
        </component>
      </div>
      <gl-multi-step-form-template
        :title="steps[currentStep].label"
        :current-step="currentStep + 1"
        :steps-total="steps.length"
        class="gl-mb-5 gl-max-w-full"
      >
        <template #default>
          <router-view />
        </template>
      </gl-multi-step-form-template>
      <div class="settings-sticky-footer gl-flex gl-justify-between">
        <gl-button to="/" data-testid="cancel-button">{{ __('Cancel') }}</gl-button>
        <span>
          <gl-button
            v-if="previousStep"
            :to="{ name: previousStep.route }"
            data-testid="back-button"
          >
            <gl-icon name="chevron-left" class="gl-mr-2" />{{ previousStep.label }}
          </gl-button>
          <gl-button
            v-if="isReviewStep"
            category="primary"
            variant="confirm"
            :loading="isSubmitting"
            data-testid="next-button"
            @click="onSubmit"
          >
            {{ nextLabel }}<gl-icon name="chevron-right" class="gl-ml-2" />
          </gl-button>
          <gl-button
            v-else-if="nextStep"
            category="primary"
            variant="confirm"
            data-testid="next-button"
            @click="goToNextStep"
          >
            {{ nextLabel }}<gl-icon name="chevron-right" class="gl-ml-2" />
          </gl-button>
        </span>
      </div>
      <gl-modal
        v-model="showExitModal"
        :modal-id="$options.exitModal.id"
        size="sm"
        :title="s__('SecurityConfiguration|Exit scanner setup?')"
        :action-primary="$options.exitModal.actionPrimary"
        :action-cancel="$options.exitModal.actionCancel"
        data-testid="exit-confirmation-modal"
        @primary="confirmExit"
        @canceled="keepEditing"
        @hidden="keepEditing"
      >
        {{
          s__(
            "SecurityConfiguration|Your progress won't be saved. You'll need to start over if you return.",
          )
        }}
      </gl-modal>
    </template>
  </div>
</template>
