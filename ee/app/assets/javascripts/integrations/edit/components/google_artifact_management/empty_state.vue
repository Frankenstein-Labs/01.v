<script>
import { GlButton, GlEmptyState, GlSprintf } from '@gitlab/ui';
import EmptyAdminAppsSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-admin-apps-md.svg';
import InviteMembersTrigger from '~/invite_members/components/invite_members_trigger.vue';

export default {
  name: 'EmptyState',
  components: {
    GlButton,
    GlEmptyState,
    InviteMembersTrigger,
    GlSprintf,
  },
  props: {
    path: {
      type: String,
      required: true,
    },
  },
  EmptyAdminAppsSvg,
};
</script>

<template>
  <gl-empty-state :svg-path="$options.EmptyAdminAppsSvg">
    <template #title>
      <h3>{{ s__('GoogleArtifactRegistry|Use Google Cloud securely') }}</h3>
    </template>
    <template #description>
      <gl-sprintf
        :message="
          s__(
            'GoogleArtifactRegistry|First, secure your usage with the %{strongStart}Google Cloud IAM%{strongEnd} integration. Simplify access without the need to manage accounts or keys.',
          )
        "
        ><template #strong="{ content }">
          <strong>{{ content }}</strong>
        </template>
      </gl-sprintf>
    </template>
    <template #actions>
      <div class="gl-flex gl-gap-3">
        <gl-button :href="path" variant="confirm">{{
          s__('GoogleArtifactRegistry|Set up Google Cloud IAM')
        }}</gl-button>
        <invite-members-trigger
          :display-text="s__('GoogleArtifactRegistry|Invite member to set up')"
          trigger-source="google_artifact_management_setup"
        />
      </div>
    </template>
  </gl-empty-state>
</template>
