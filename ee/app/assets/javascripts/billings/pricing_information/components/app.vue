<script>
import { GlButton, GlEmptyState, GlLink, GlFormSelect, GlSprintf } from '@gitlab/ui';
import { InternalEvents } from '~/tracking';
import { s__ } from '~/locale';
import { mergeUrlParams } from '~/lib/utils/url_utility';
import FreePlanSection from './free_plan_section.vue';
import PremiumPlanSection from './premium_plan_section.vue';
import TrialPlanSection from './trial_plan_section.vue';
import TrialUpgradeSection from './trial_upgrade_section.vue';

export default {
  name: 'PricingInformationApp',

  components: {
    GlButton,
    GlEmptyState,
    GlLink,
    GlFormSelect,
    FreePlanSection,
    PremiumPlanSection,
    TrialPlanSection,
    TrialUpgradeSection,
    GlSprintf,
  },
  mixins: [InternalEvents.mixin()],
  props: {
    groups: {
      type: Array,
      required: true,
    },
    dashboardGroupsHref: {
      type: String,
      required: true,
    },
  },

  data() {
    return {
      selectedGroupId: this.groups.length === 1 ? this.groups[0].id : null,
    };
  },

  computed: {
    groupOptions() {
      const defaultOption = {
        value: null,
        text: s__('Billings|Select group'),
        disabled: true,
      };

      const groupOptions = this.groups.map((group) => ({
        value: group.id,
        text: group.name,
      }));

      return [defaultOption, ...groupOptions];
    },
    selectedGroup() {
      return this.groups.find((group) => group.id === this.selectedGroupId);
    },
    trialActive() {
      return this.selectedGroup ? Boolean(this.selectedGroup.trial_active) : false;
    },
    groupIds() {
      return JSON.stringify(this.groups.map((group) => group.id));
    },
    // ref_source tracks navigation context for CDOT conversion attribution
    groupBillingsHrefWithRefSource() {
      return (
        this.selectedGroup &&
        mergeUrlParams({ ref_source: 'group_billing_page' }, this.selectedGroup.group_billings_href)
      );
    },
    upgradeToPremiumHrefWithRefSource() {
      return (
        this.selectedGroup &&
        mergeUrlParams(
          { ref_source: 'group_billing_page' },
          this.selectedGroup.upgrade_to_premium_href,
        )
      );
    },
  },
};
</script>
<template>
  <div class="gl-mx-auto gl-mt-8 gl-max-w-xl">
    <div class="gl-mb-5 gl-pt-8">
      <h2 class="gl-heading-2 gl-mb-3 gl-text-default">{{ s__('Billings|Billing') }}</h2>
      <p class="gl-text-default">
        <gl-sprintf
          :message="
            s__(
              'Billings|View subscription details and manage billing for your %{linkStart}groups%{linkEnd}.',
            )
          "
        >
          <template #link="{ content }">
            <gl-link
              :href="dashboardGroupsHref"
              data-event-tracking="click_link_navigate_to_group"
              :data-event-property="groupIds"
              >{{ content }}</gl-link
            >
          </template>
        </gl-sprintf>
      </p>
    </div>

    <div class="gl-mb-6">
      <label for="group-select" class="gl-mb-2 gl-font-[700] gl-text-strong">
        {{ s__('Billings|Group') }}
      </label>
      <gl-form-select
        id="group-select"
        v-model="selectedGroupId"
        :options="groupOptions"
        class="gl-max-w-full"
        data-testid="group-select"
        autocomplete="off"
        data-event-tracking="click_dropdown_group_selection"
        :data-event-property="groupIds"
      />
    </div>
    <div v-if="selectedGroupId" data-testid="plan-sections-container">
      <div class="gl-flex gl-flex-col @md/panel:gl-flex-row">
        <div
          class="gl-border gl-flex-1 gl-rounded-t-lg gl-bg-default gl-p-6 @md/panel:gl-rounded-l-lg @md/panel:gl-rounded-r-none"
        >
          <free-plan-section v-if="!trialActive" data-testid="free-plan-section" />
          <trial-plan-section v-else data-testid="trial-plan-section" />
        </div>
        <div
          class="gl-border gl-flex-1 gl-rounded-b-lg gl-border-t-0 gl-bg-subtle gl-p-6 @md/panel:gl-border-t @md/panel:gl-rounded-l-none @md/panel:gl-rounded-r-lg @md/panel:gl-border-l-0"
        >
          <premium-plan-section
            v-if="!trialActive"
            data-testid="premium-plan-section"
            :group-id="selectedGroupId"
            :group-billing-href="selectedGroup.group_billings_href"
          />
          <trial-upgrade-section
            v-else
            data-testid="upgrade-trial-section"
            :group-id="selectedGroupId"
            :group-billing-href="selectedGroup.group_billings_href"
            :can-access-duo-chat="selectedGroup.can_access_duo_chat"
            :explore-links="selectedGroup.explore_links"
          />
        </div>
      </div>

      <div class="gl-mt-5 gl-flex gl-grow gl-items-center gl-justify-end gl-gap-3">
        <gl-button
          variant="confirm"
          category="secondary"
          data-testid="manage-billing-button"
          data-event-tracking="click_button_manage_billing"
          :data-event-property="selectedGroupId"
          :href="groupBillingsHrefWithRefSource"
        >
          {{ s__('Billings|Manage billing') }}
        </gl-button>

        <gl-button
          variant="confirm"
          data-testid="upgrade-to-premium-button"
          data-event-tracking="click_button_upgrade_to_premium"
          :data-event-property="selectedGroupId"
          :href="upgradeToPremiumHrefWithRefSource"
        >
          {{ s__('Billings|Upgrade to Premium') }}
        </gl-button>
      </div>
    </div>
    <gl-empty-state
      v-if="!selectedGroupId"
      :compact="false"
      class="gl-border gl-p-6 @md/panel:gl-rounded-lg"
      data-testid="empty-state"
    >
      <template #description>
        {{ s__('Billings|To view subscription details and manage billing, select a group.') }}
      </template>
    </gl-empty-state>
  </div>
</template>
