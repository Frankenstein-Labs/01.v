<script>
import { GlAlert, GlSprintf, GlLink } from '@gitlab/ui';
import SignupCheckbox from '~/pages/admin/application_settings/general/components/signup_checkbox.vue';

export default {
  name: 'SeatControlsMemberPromotionManagement',
  components: {
    SignupCheckbox,
    GlAlert,
    GlSprintf,
    GlLink,
  },
  inject: [
    'enableMemberPromotionManagement',
    'canDisableMemberPromotionManagement',
    'rolePromotionRequestsPath',
  ],
  data() {
    return {
      form: {
        enableMemberPromotionManagement: this.enableMemberPromotionManagement,
      },
    };
  },
};
</script>
<template>
  <div>
    <gl-alert
      v-if="!canDisableMemberPromotionManagement"
      variant="info"
      :dismissible="false"
      class="gl-mb-4"
    >
      <gl-sprintf
        :message="
          s__(
            'ApplicationSettings|Setting locked. Resolve all %{linkStart}pending approvals%{linkEnd} to unlock.',
          )
        "
      >
        <template #link="{ content }">
          <gl-link :href="rolePromotionRequestsPath">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </gl-alert>
    <signup-checkbox
      v-model="form.enableMemberPromotionManagement"
      name="application_setting[enable_member_promotion_management]"
      :label="s__('ApplicationSettings|Approve role promotions')"
      :disabled="!canDisableMemberPromotionManagement"
      :help-text="
        s__(
          'ApplicationSettings|Require admin approval when a non-billable user is moving into a billable role.',
        )
      "
    />
  </div>
</template>
