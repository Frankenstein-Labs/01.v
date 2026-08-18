<script>
import {
  GlDisclosureDropdownGroup,
  GlDisclosureDropdownItem,
  GlFormGroup,
  GlFormInput,
  GlIcon,
  GlLink,
  GlModal,
  GlSprintf,
} from '@gitlab/ui';

import { __, s__, sprintf } from '~/locale';
import { createAlert } from '~/alert';
import { helpPagePath } from '~/helpers/help_page_helper';
import { PROMO_URL, DOCS_URL } from '~/constants';
import { USER_MENU_TRACKING_DEFAULTS } from '~/super_sidebar/constants';
import axios from '~/lib/utils/axios_utils';
import { visitUrl, visitUrlWithAlerts } from '~/lib/utils/url_utility';

export default {
  name: 'UserMenuUpgradeSubscription',
  components: {
    GlDisclosureDropdownGroup,
    GlDisclosureDropdownItem,
    GlFormGroup,
    GlFormInput,
    GlIcon,
    GlLink,
    GlModal,
    GlSprintf,
  },
  props: {
    upgradeLink: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      disabled: false,
      showConfirmModal: false,
      confirmationPhrase: '',
    };
  },
  computed: {
    upgradeSubscriptionItem() {
      return {
        text: this.upgradeLink.text,
        extraAttrs: {
          ...USER_MENU_TRACKING_DEFAULTS,
          'data-track-label': 'upgrade_subscription',
          disabled: this.disabled,
        },
      };
    },
    alertParams() {
      return {
        title: this.$options.i18n.title,
        message: this.$options.i18n.message,
        messageLinks: { link: { href: this.$options.pricingLink, target: '_blank' } },
        primaryButton: {
          text: this.$options.i18n.primaryButtonText,
          clickHandler: this.transferPersonalProject,
        },
      };
    },
    isConfirmValid() {
      return (
        this.confirmationPhrase.trim().toLowerCase() ===
        this.upgradeLink.project_full_path.trim().toLowerCase()
      );
    },
    confirmPrimaryAction() {
      return {
        text: this.$options.i18n.confirmButton,
        attributes: {
          variant: 'confirm',
          disabled: !this.isConfirmValid,
        },
      };
    },
    confirmCancelAction() {
      return {
        text: this.$options.i18n.cancelButton,
      };
    },
  },
  methods: {
    async transferPersonalProject() {
      try {
        this.disabled = true;

        const { data } = await axios.put(this.upgradeLink.url);

        visitUrlWithAlerts(data.redirect_to, [
          {
            id: 'transfer-personal-project-success',
            message: sprintf(this.$options.i18n.successMessage, { groupName: data.group_name }),
            variant: 'success',
          },
        ]);
      } catch (error) {
        createAlert(this.alertParams);
      } finally {
        this.disabled = false;
      }
    },
    onClick() {
      if (this.upgradeLink.is_personal_project) {
        this.confirmationPhrase = '';
        this.showConfirmModal = true;
      } else {
        visitUrl(this.upgradeLink.url);
      }
    },
    onConfirm() {
      this.showConfirmModal = false;
      this.transferPersonalProject();
    },
  },
  i18n: {
    title: s__('UpgradeSubscription|Billing page is not available'),
    message: s__(
      'UpgradeSubscription|An error occurred while assigning your project to a group for billing. Try again or %{linkStart}learn more about pricing%{linkEnd}.',
    ),
    primaryButtonText: s__('UpgradeSubscription|Try again'),
    successMessage: s__(
      'UpgradeSubscription|Your personal project was assigned to %{groupName} for billing.',
    ),
    confirmTitle: s__('UpgradeSubscription|Confirm group assignment'),
    confirmMessage: s__(
      "UpgradeSubscription|To upgrade your subscription, %{projectName} will be assigned to a new group. This action changes the %{pathLinkStart}project's path%{pathLinkEnd} and can lead to %{dataLossLinkStart}data loss%{dataLossLinkEnd}. %{learnMoreLinkStart}Learn more%{learnMoreLinkEnd}.",
    ),
    confirmPhraseLabel: __('Enter the following to confirm: %{phrase}'),
    confirmButton: __('Confirm'),
    cancelButton: __('Cancel'),
  },
  pricingLink: `${PROMO_URL}/pricing`,
  namespaceChangeDocPath: helpPagePath('user/group/manage.md', {
    anchor: 'change-a-groups-path',
  }),
  dataLossDocPath: helpPagePath('user/project/repository/_index.md', {
    anchor: 'repository-path-changes',
  }),
  learnMoreUrl: `${DOCS_URL}/subscriptions/choosing_subscription/#choose-an-offering`,
};
</script>

<template>
  <gl-disclosure-dropdown-group bordered>
    <gl-disclosure-dropdown-item
      :item="upgradeSubscriptionItem"
      data-testid="upgrade-subscription-item"
      @action="onClick"
    >
      <template #list-item>
        <span class="hotspot-pulse gl-flex gl-items-center gl-gap-2">
          <gl-icon name="license" variant="subtle" class="gl-mr-2" />
          {{ upgradeSubscriptionItem.text }}
        </span>
      </template>
    </gl-disclosure-dropdown-item>

    <gl-modal
      v-if="upgradeLink.is_personal_project"
      v-model="showConfirmModal"
      modal-id="confirm-group-assignment-modal"
      :title="$options.i18n.confirmTitle"
      :action-primary="confirmPrimaryAction"
      :action-cancel="confirmCancelAction"
      @primary="onConfirm"
    >
      <p>
        <gl-sprintf :message="$options.i18n.confirmMessage">
          <template #projectName>
            <code class="gl-whitespace-pre-wrap">{{ upgradeLink.project_name }}</code>
          </template>

          <template #pathLink="{ content }">
            <gl-link :href="$options.namespaceChangeDocPath" target="_blank">{{ content }}</gl-link>
          </template>

          <template #dataLossLink="{ content }">
            <gl-link :href="$options.dataLossDocPath" target="_blank">{{ content }}</gl-link>
          </template>

          <template #learnMoreLink="{ content }">
            <gl-link :href="$options.learnMoreUrl" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </p>

      <label for="confirm_group_assignment_input" class="gl-mb-3 gl-block">
        <gl-sprintf :message="$options.i18n.confirmPhraseLabel">
          <template #phrase>
            <code class="gl-whitespace-pre-wrap">{{ upgradeLink.project_full_path }}</code>
          </template>
        </gl-sprintf>
      </label>

      <gl-form-group class="gl-mb-0">
        <gl-form-input
          id="confirm_group_assignment_input"
          v-model="confirmationPhrase"
          autocomplete="off"
        />
      </gl-form-group>
    </gl-modal>
  </gl-disclosure-dropdown-group>
</template>
